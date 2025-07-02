' =========================================================
' ===           PressGuru - ChatController.vb           ===
' ===      UPGRADED with Contextual Conversation Memory ===
' ===             100% COMPLETE AND FINAL CODE          ===
' =========================================================
Imports System.Net
Imports System.Net.Http
Imports System.Text
Imports System.Threading.Tasks
Imports System.Web.Http
Imports Newtonsoft.Json
Imports System.Configuration
Imports System.Data.SqlClient
Imports System.Web
Imports System.IO

Public Class ChatController
    Inherits ApiController

    ' --- Models for API Requests ---
    Public Class ChatRequestModel
        Public Property Message As String
        Public Property SessionId As String
        Public Property UserGuid As String
    End Class

    Public Class AnalyzeRequestModel
        Public Property SessionId As String
        Public Property UserGuid As String
    End Class

    ' --- API & Prompt Configuration ---
    Private Shared ReadOnly GEMINI_API_URL_TEMPLATE As String = "https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key={0}"
    Private Shared ReadOnly PRESSGURU_SYSTEM_PROMPT As String = "You are 'PressGuru', a world-class expert in the printing and packaging industry. Your role is to assist print shop workers, graphic designers, and business owners. Answer all questions clearly, accurately, and professionally. Your knowledge includes, but is not limited to: offset printing, digital printing, flexography, screen printing, CMYK vs. RGB color models, paper types and weights (GSM), lamination, UV coating, die-cutting, die-lines, packaging design, prepress, proofing, and cost estimation. When asked for an opinion, provide a balanced view. When a user asks a question, assume they are in a professional context. Do not break character. Use markdown for formatting, like **bolding** key terms."
    Private Shared ReadOnly ANALYSIS_SYSTEM_PROMPT As String = "You are a psycho-linguistic analyst specializing in professional contexts. The following is a transcript of a user's conversation with a printing expert AI. Based only on the user's questions and statements, analyze their personality and professional profile. Determine their likely role (e.g., Student, Graphic Designer, Print Shop Owner, Business Manager), their expertise level (Beginner, Intermediate, Expert), and their primary interests (e.g., Cost Savings, High-End Quality, Specific Materials, Technical Processes). Present your analysis as a brief, bulleted summary formatted with markdown. Do not be conversational; just provide the analysis."
    Private Shared ReadOnly IMAGE_ANALYSIS_PROMPT As String = "You are 'PressGuru', a printing industry expert. A user has uploaded an image of a printed item. The text extracted from this image is provided below. Based *only* on this text, do the following: 1. Identify the probable type of printed product (e.g., Business card, Flyer, Product label, Book page, Menu). 2. Provide a brief, actionable analysis or printing-related advice about the item. 3. If the text is nonsensical or not from a printed product, state that the text could not be analyzed. Here is the text:"

    ' =========================================================================
    ' ===                       API ENDPOINTS                             ===
    ' =========================================================================

    ' --- Get all conversations for a user's sidebar ---
    <HttpGet>
    <Route("api/user/conversations/{userGuid}")>
    Public Function GetUserConversations(ByVal userGuid As String) As IHttpActionResult
        Dim conversations As New List(Of Object)()
        Try
            Using conn As New SqlConnection(ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString)
                conn.Open()
                Dim sql = "
                    WITH FirstMessages AS (
                        SELECT 
                            ConversationId, 
                            Content,
                            ROW_NUMBER() OVER(PARTITION BY ConversationId ORDER BY Id ASC) as rn
                        FROM Messages
                        WHERE Sender = 'User'
                    )
                    SELECT 
                        c.SessionId, 
                        ISNULL(SUBSTRING(fm.Content, 1, 50), 'New Conversation...') AS Title
                    FROM Conversations c
                    LEFT JOIN FirstMessages fm ON c.Id = fm.ConversationId AND fm.rn = 1
                    WHERE c.UserGuid = @UserGuid
                    ORDER BY c.Id DESC;"

                Dim cmd As New SqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@UserGuid", userGuid)
                Using reader As SqlDataReader = cmd.ExecuteReader()
                    While reader.Read()
                        conversations.Add(New With {
                            .sessionId = reader("SessionId").ToString(),
                            .title = reader("Title").ToString()
                        })
                    End While
                End Using
            End Using
            Return Ok(conversations)
        Catch ex As Exception
            Return InternalServerError(ex)
        End Try
    End Function

    ' --- Send a regular chat message with conversation context ---
    <HttpPost>
    <Route("api/chat/send")>
    Public Async Function SendMessage(<FromBody> ByVal request As ChatRequestModel) As Task(Of IHttpActionResult)
        If String.IsNullOrWhiteSpace(request?.Message) OrElse String.IsNullOrWhiteSpace(request?.SessionId) OrElse String.IsNullOrWhiteSpace(request?.UserGuid) Then
            Return BadRequest("Message, SessionId, and UserGuid are required.")
        End If

        Try
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
            SaveMessageToDb(request.SessionId, "User", request.Message, request.UserGuid)

            Dim recentHistory = GetRecentHistory(request.SessionId, request.UserGuid)

            Dim geminiContents As New List(Of Object)()
            geminiContents.Add(New With {.role = "user", .parts = {New With {.text = PRESSGURU_SYSTEM_PROMPT}}})
            geminiContents.Add(New With {.role = "model", .parts = {New With {.text = "Yes, I am PressGuru. I am ready to answer your printing questions."}}})

            For Each msg In recentHistory
                Dim role = If(msg.Sender.Equals("User", StringComparison.OrdinalIgnoreCase), "user", "model")
                geminiContents.Add(New With {.role = role, .parts = {New With {.text = msg.Content}}})
            Next

            geminiContents.Add(New With {.role = "user", .parts = {New With {.text = request.Message}}})

            Dim payload = New With {.contents = geminiContents}
            Dim geminiResponseText = Await GetAnalysisFromPayload(payload)

            SaveMessageToDb(request.SessionId, "Bot", geminiResponseText, request.UserGuid)
            Return Ok(New With {.response = geminiResponseText})
        Catch ex As Exception
            Return InternalServerError(ex)
        End Try
    End Function

    ' --- Analyze conversation for personality ---
    <HttpPost>
    <Route("api/chat/analyze")>
    Public Async Function AnalyzeConversation(<FromBody> ByVal request As AnalyzeRequestModel) As Task(Of IHttpActionResult)
        If String.IsNullOrWhiteSpace(request?.SessionId) OrElse String.IsNullOrWhiteSpace(request?.UserGuid) Then
            Return BadRequest("SessionId and UserGuid are required.")
        End If

        Try
            Dim userTranscript = GetUserTranscript(request.SessionId, request.UserGuid)
            If String.IsNullOrWhiteSpace(userTranscript) Then
                Return Ok(New With {.response = "There's not enough conversation history to perform an analysis yet."})
            End If

            Dim fullPrompt = ANALYSIS_SYSTEM_PROMPT & vbCrLf & "--- USER TRANSCRIPT ---" & vbCrLf & userTranscript
            Dim analysisResult = Await GetAnalysisFromGemini(fullPrompt)
            Return Ok(New With {.response = analysisResult})

        Catch ex As Exception
            Return InternalServerError(ex)
        End Try
    End Function

    ' --- Analyze an uploaded image ---
    <HttpPost>
    <Route("api/chat/analyzeImage")>
    Public Async Function AnalyzeImage() As Task(Of IHttpActionResult)
        If Not Request.Content.IsMimeMultipartContent() Then
            Return BadRequest("Unsupported media type.")
        End If

        Dim sessionId As String = HttpContext.Current.Request.Form("sessionId")
        Dim userGuid As String = HttpContext.Current.Request.Form("userGuid")

        If String.IsNullOrWhiteSpace(sessionId) OrElse String.IsNullOrWhiteSpace(userGuid) Then
            Return BadRequest("SessionId and UserGuid are required.")
        End If

        Dim file = HttpContext.Current.Request.Files(0)
        If file Is Nothing OrElse file.ContentLength = 0 Then
            Return BadRequest("No image file received.")
        End If

        Try
            Dim extractedText = Await GetTextFromImageOcrSpace(file.InputStream, file.FileName)

            If String.IsNullOrWhiteSpace(extractedText) Then
                Return Ok(New With {.response = "I couldn't read any text from that image. Please try a clearer picture."})
            End If

            Dim fullPrompt = IMAGE_ANALYSIS_PROMPT & vbCrLf & extractedText
            Dim geminiAnalysis = Await GetAnalysisFromGemini(fullPrompt)

            SaveMessageToDb(sessionId, "User", "[Image Uploaded]", userGuid)
            SaveMessageToDb(sessionId, "Bot", geminiAnalysis, userGuid)
            Return Ok(New With {.response = geminiAnalysis})

        Catch ex As Exception
            Return InternalServerError(ex)
        End Try
    End Function

    ' --- Get message history for a specific conversation ---
    <HttpGet>
    <Route("api/chat/history/{sessionId}")>
    Public Function GetHistory(ByVal sessionId As String) As IHttpActionResult
        Dim messages As New List(Of Object)()
        Try
            Using conn As New SqlConnection(ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString)
                conn.Open()
                Dim cmd As New SqlCommand("SELECT m.Sender, m.Content FROM Messages m INNER JOIN Conversations c ON m.ConversationId = c.Id WHERE c.SessionId = @SessionId ORDER BY m.Id ASC", conn)
                cmd.Parameters.AddWithValue("@SessionId", sessionId)
                Using reader As SqlDataReader = cmd.ExecuteReader()
                    While reader.Read()
                        messages.Add(New With {
                            .sender = reader("Sender").ToString(),
                            .text = reader("Content").ToString()
                        })
                    End While
                End Using
            End Using
            Return Ok(messages)
        Catch ex As Exception
            Return InternalServerError(ex)
        End Try
    End Function

    ' =========================================================================
    ' ===                       HELPER FUNCTIONS                          ===
    ' =========================================================================

    ' --- HELPER: Gets the last 6 messages for context ---
    Public Class ChatMessage
        Public Property Sender As String
        Public Property Content As String
    End Class

    Private Function GetRecentHistory(ByVal sessionId As String, ByVal userGuid As String) As List(Of ChatMessage)
        Dim history As New List(Of ChatMessage)()
        Dim conversationId = GetOrCreateConversation(sessionId, userGuid)

        Dim sql = "SELECT TOP 6 Sender, Content FROM Messages WHERE ConversationId = @ConversationId ORDER BY Id DESC"

        Using conn As New SqlConnection(ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString)
            conn.Open()
            Dim cmd As New SqlCommand(sql, conn)
            cmd.Parameters.AddWithValue("@ConversationId", conversationId)
            Using reader As SqlDataReader = cmd.ExecuteReader()
                While reader.Read()
                    history.Add(New ChatMessage With {
                        .Sender = reader("Sender").ToString(),
                        .Content = reader("Content").ToString()
                    })
                End While
            End Using
        End Using

        history.Reverse()
        Return history
    End Function

    ' --- HELPER: Calls OCR.space API to get text from an image ---
    Private Async Function GetTextFromImageOcrSpace(ByVal imageStream As Stream, ByVal fileName As String) As Task(Of String)
        Dim apiKey = ConfigurationManager.AppSettings("OcrSpaceApiKey")
        Dim ocrUrl = "https://api.ocr.space/parse/image"

        Using client As New HttpClient()
            Using formData As New MultipartFormDataContent()
                formData.Add(New StringContent(apiKey), "apikey")
                formData.Add(New StreamContent(imageStream), "file", fileName)
                Dim response = Await client.PostAsync(ocrUrl, formData)

                If response.IsSuccessStatusCode Then
                    Dim jsonResponse = Await response.Content.ReadAsStringAsync()
                    Dim ocrResult = JsonConvert.DeserializeObject(Of OcrSpaceResponse)(jsonResponse)

                    If ocrResult IsNot Nothing AndAlso ocrResult.OCRExitCode = 1 AndAlso ocrResult.ParsedResults?.Count > 0 Then
                        Return ocrResult.ParsedResults(0).ParsedText
                    Else
                        Return String.Empty
                    End If
                Else
                    Dim errorContent = Await response.Content.ReadAsStringAsync()
                    Throw New HttpRequestException($"OCR API call failed with status {response.StatusCode}. Details: {errorContent}")
                End If
            End Using
        End Using
    End Function

    ' --- HELPER: Generic function for one-off analysis tasks ---
    Private Async Function GetAnalysisFromGemini(ByVal text As String) As Task(Of String)
        Dim payload = New With {
            .contents = {
                New With {.role = "user", .parts = {New With {.text = text}}}
            }
        }
        Return Await GetAnalysisFromPayload(payload)
    End Function

    ' --- HELPER: Takes a pre-built payload object and calls the Gemini API ---
    Private Async Function GetAnalysisFromPayload(ByVal payload As Object) As Task(Of String)
        Dim apiKey = ConfigurationManager.AppSettings("GeminiApiKey")
        Dim requestUrl = String.Format(GEMINI_API_URL_TEMPLATE, apiKey)

        Using client As New HttpClient()
            Dim content = New StringContent(JsonConvert.SerializeObject(payload), Encoding.UTF8, "application/json")
            Dim response = Await client.PostAsync(requestUrl, content)

            If response.IsSuccessStatusCode Then
                Dim jsonResponse = Await response.Content.ReadAsStringAsync()
                Dim geminiResponse = JsonConvert.DeserializeObject(Of GeminiResponse)(jsonResponse)
                If geminiResponse.candidates IsNot Nothing AndAlso geminiResponse.candidates.Count > 0 Then
                    Return geminiResponse.candidates(0).content.parts(0).text.Trim()
                Else
                    Return "The AI returned an empty response."
                End If
            Else
                Dim errorContent = Await response.Content.ReadAsStringAsync()
                Throw New HttpRequestException($"AI API call failed with status {response.StatusCode}. Details: {errorContent}")
            End If
        End Using
    End Function

    ' --- DATABASE HELPER: Get a full conversation transcript for analysis ---
    Private Shared Function GetUserTranscript(ByVal sessionId As String, ByVal userGuid As String) As String
        Dim transcript As New StringBuilder()
        Dim conversationId = GetOrCreateConversation(sessionId, userGuid)

        Using conn As New SqlConnection(ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString)
            conn.Open()
            Dim cmd As New SqlCommand("SELECT Content FROM Messages WHERE ConversationId = @ConversationId AND Sender = 'User' ORDER BY Id ASC", conn)
            cmd.Parameters.AddWithValue("@ConversationId", conversationId)
            Using reader As SqlDataReader = cmd.ExecuteReader()
                While reader.Read()
                    transcript.AppendLine(reader("Content").ToString())
                End While
            End Using
        End Using
        Return transcript.ToString()
    End Function

    ' --- DATABASE HELPER: Save any message to the database ---
    Private Shared Sub SaveMessageToDb(ByVal sessionId As String, ByVal sender As String, ByVal content As String, ByVal userGuid As String)
        Dim convId = GetOrCreateConversation(sessionId, userGuid)
        Using conn As New SqlConnection(ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString)
            conn.Open()
            Dim cmd As New SqlCommand("INSERT INTO Messages (ConversationId, Sender, Content) VALUES (@ConversationId, @Sender, @Content)", conn)
            cmd.Parameters.AddWithValue("@ConversationId", convId)
            cmd.Parameters.AddWithValue("@Sender", sender)
            cmd.Parameters.AddWithValue("@Content", content)
            cmd.ExecuteNonQuery()
        End Using
    End Sub

    ' --- DATABASE HELPER: Find or create a conversation record ---
    Private Shared Function GetOrCreateConversation(ByVal sessionId As String, ByVal userGuid As String) As Integer
        Using conn As New SqlConnection(ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString)
            conn.Open()
            Dim sql = "
                DECLARE @ConvId INT;
                SELECT @ConvId = Id FROM Conversations WHERE SessionId = @SessionId;
                IF @ConvId IS NULL
                BEGIN
                    INSERT INTO Conversations (SessionId, UserGuid) VALUES (@SessionId, @UserGuid);
                    SET @ConvId = SCOPE_IDENTITY();
                END
                ELSE
                BEGIN
                    UPDATE Conversations SET UserGuid = @UserGuid WHERE Id = @ConvId AND UserGuid IS NULL;
                END
                SELECT @ConvId;"
            Dim cmd As New SqlCommand(sql, conn)
            cmd.Parameters.AddWithValue("@SessionId", sessionId)
            cmd.Parameters.AddWithValue("@UserGuid", userGuid)
            Return CInt(cmd.ExecuteScalar())
        End Using
    End Function

    ' =========================================================================
    ' ===               JSON HELPER CLASSES FOR API RESPONSES             ===
    ' =========================================================================

    ' --- Classes for parsing Gemini API response ---
    Public Class GeminiResponse
        Public Property candidates As List(Of Candidate)
    End Class
    Public Class Candidate
        Public Property content As Content
    End Class
    Public Class Content
        Public Property parts As List(Of Part)
        Public Property role As String
    End Class
    Public Class Part
        Public Property text As String
    End Class

    ' --- Classes for parsing OCR.space API response ---
    Public Class OcrSpaceResponse
        Public Property ParsedResults As List(Of ParsedResult)
        Public Property OCRExitCode As Integer
        Public Property IsErroredOnProcessing As Boolean
        Public Property ErrorMessage As String
    End Class
    Public Class ParsedResult
        Public Property ParsedText As String
    End Class

End Class