' ChatController.vb
' =========================================================
' === CORRECTED FOR v1 ENDPOINT (gemini-2.0-flash) ===
' =========================================================
Imports System.Net
Imports System.Net.Http
Imports System.Text
Imports System.Threading.Tasks
Imports System.Web.Http
Imports Newtonsoft.Json
Imports System.Configuration
Imports System.Data.SqlClient

Public Class ChatController
    Inherits ApiController

    ' --- Models for API Requests ---
    Public Class ChatRequestModel
        Public Property Message As String
        Public Property SessionId As String
    End Class

    Public Class AnalyzeRequestModel
        Public Property SessionId As String
    End Class

    ' <<< CHANGE 1: USING YOUR PREFERRED v1 ENDPOINT >>>
    Private Shared ReadOnly GEMINI_API_URL_TEMPLATE As String = "https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key={0}"

    ' --- System Prompts (remain the same) ---
    Private Shared ReadOnly PRESSGURU_SYSTEM_PROMPT As String = "You are 'PressGuru', a world-class expert in the printing and packaging industry. Your role is to assist print shop workers, graphic designers, and business owners. Answer all questions clearly, accurately, and professionally. Your knowledge includes, but is not limited to: offset printing, digital printing, flexography, screen printing, CMYK vs. RGB color models, paper types and weights (GSM), lamination, UV coating, die-cutting, die-lines, packaging design, prepress, proofing, and cost estimation. When asked for an opinion, provide a balanced view. When a user asks a question, assume they are in a professional context. Do not break character. Use markdown for formatting, like **bolding** key terms."
    Private Shared ReadOnly ANALYSIS_SYSTEM_PROMPT As String = "You are a psycho-linguistic analyst specializing in professional contexts. The following is a transcript of a user's conversation with a printing expert AI. Based only on the user's questions and statements, analyze their personality and professional profile. Determine their likely role (e.g., Student, Graphic Designer, Print Shop Owner, Business Manager), their expertise level (Beginner, Intermediate, Expert), and their primary interests (e.g., Cost Savings, High-End Quality, Specific Materials, Technical Processes). Present your analysis as a brief, bulleted summary formatted with markdown. Do not be conversational; just provide the analysis."

    ' --- API Endpoint for Sending a Chat Message ---
    <HttpPost>
    <Route("api/chat/send")>
    Public Async Function SendMessage(<FromBody> ByVal request As ChatRequestModel) As Task(Of IHttpActionResult)
        If String.IsNullOrWhiteSpace(request?.Message) OrElse String.IsNullOrWhiteSpace(request?.SessionId) Then
            Return BadRequest("Message and SessionId are required.")
        End If

        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
        SaveMessageToDb(request.SessionId, "User", request.Message)

        Dim apiKey = ConfigurationManager.AppSettings("GeminiApiKey")
        Dim requestUrl = String.Format(GEMINI_API_URL_TEMPLATE, apiKey)

        Using client As New HttpClient()
            ' <<< CHANGE 2: Correct payload structure for the v1 endpoint >>>
            ' We create a conversation history where the system prompt acts as the first message.
            ' This is how you provide context without a dedicated 'system_instruction' field.
            Dim payload = New With {
                .contents = {
                    New With {
                        .role = "user",
                        .parts = {New With {.text = PRESSGURU_SYSTEM_PROMPT}}
                    },
                    New With {
                        .role = "model",
                        .parts = {New With {.text = "Yes, I am PressGuru. I am ready to answer your printing questions."}}
                    },
                    New With {
                        .role = "user",
                        .parts = {New With {.text = request.Message}}
                    }
                }
            }
            Dim content = New StringContent(JsonConvert.SerializeObject(payload), Encoding.UTF8, "application/json")

            Try
                Dim response = Await client.PostAsync(requestUrl, content)
                Dim jsonResponse = Await response.Content.ReadAsStringAsync()

                If response.IsSuccessStatusCode Then
                    Dim geminiResponse = JsonConvert.DeserializeObject(Of GeminiResponse)(jsonResponse)
                    Dim botResponseContent = geminiResponse.candidates(0).content.parts(0).text.Trim()
                    SaveMessageToDb(request.SessionId, "Bot", botResponseContent)
                    Return Ok(New With {.response = botResponseContent})
                Else
                    Return BadRequest($"API Error ({response.StatusCode}): {jsonResponse}")
                End If
            Catch ex As Exception
                Return InternalServerError(ex)
            End Try
        End Using
    End Function

    ' --- API Endpoint for Personality Analysis ---
    <HttpPost>
    <Route("api/chat/analyze")>
    Public Async Function AnalyzeConversation(<FromBody> ByVal request As AnalyzeRequestModel) As Task(Of IHttpActionResult)
        If String.IsNullOrWhiteSpace(request?.SessionId) Then
            Return BadRequest("SessionId is required.")
        End If

        Dim userTranscript = GetUserTranscript(request.SessionId)
        If String.IsNullOrWhiteSpace(userTranscript) Then
            Return Ok(New With {.response = "Not enough conversation history to perform an analysis."})
        End If

        Dim apiKey = ConfigurationManager.AppSettings("GeminiApiKey")
        Dim requestUrl = String.Format(GEMINI_API_URL_TEMPLATE, apiKey)

        Using client As New HttpClient()
            ' <<< CHANGE 3: Also update the payload structure for the analysis call >>>
            Dim payload = New With {
                .contents = {
                    New With {
                        .role = "user",
                        .parts = {New With {.text = ANALYSIS_SYSTEM_PROMPT & vbCrLf & "--- USER TRANSCRIPT ---" & vbCrLf & userTranscript}}
                    }
                }
            }
            Dim content = New StringContent(JsonConvert.SerializeObject(payload), Encoding.UTF8, "application/json")

            Try
                Dim response = Await client.PostAsync(requestUrl, content)
                Dim jsonResponse = Await response.Content.ReadAsStringAsync()

                If response.IsSuccessStatusCode Then
                    Dim geminiResponse = JsonConvert.DeserializeObject(Of GeminiResponse)(jsonResponse)
                    Dim analysisResult = geminiResponse.candidates(0).content.parts(0).text.Trim()
                    Return Ok(New With {.response = analysisResult})
                Else
                    Return BadRequest($"API Error during analysis ({response.StatusCode}): {jsonResponse}")
                End If
            Catch ex As Exception
                Return InternalServerError(ex)
            End Try
        End Using
    End Function

    ' --- GetHistory endpoint and Database helpers remain the same ---
    ' (No changes needed for the code below this line)

    <HttpGet>
    <Route("api/chat/history/{sessionId}")>
    Public Function GetHistory(ByVal sessionId As String) As IHttpActionResult
        Dim messages As New List(Of Object)()
        Dim conversationId = GetOrCreateConversation(sessionId)
        Try
            Using conn As New SqlConnection(ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString)
                conn.Open()
                Dim cmd As New SqlCommand("SELECT Sender, Content FROM Messages WHERE ConversationId = @ConversationId ORDER BY Id ASC", conn)
                cmd.Parameters.AddWithValue("@ConversationId", conversationId)
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

    Private Shared Sub SaveMessageToDb(ByVal sessionId As String, ByVal sender As String, ByVal content As String)
        Dim convId = GetOrCreateConversation(sessionId)
        Using conn As New SqlConnection(ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString)
            conn.Open()
            Dim cmd As New SqlCommand("INSERT INTO Messages (ConversationId, Sender, Content) VALUES (@ConversationId, @Sender, @Content)", conn)
            cmd.Parameters.AddWithValue("@ConversationId", convId)
            cmd.Parameters.AddWithValue("@Sender", sender)
            cmd.Parameters.AddWithValue("@Content", content)
            cmd.ExecuteNonQuery()
        End Using
    End Sub

    Private Shared Function GetOrCreateConversation(ByVal sessionId As String) As Integer
        Using conn As New SqlConnection(ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString)
            conn.Open()
            Dim sql = "
                DECLARE @ConvId INT;
                SELECT @ConvId = Id FROM Conversations WHERE SessionId = @SessionId;
                IF @ConvId IS NULL
                BEGIN
                    INSERT INTO Conversations (SessionId) VALUES (@SessionId);
                    SET @ConvId = SCOPE_IDENTITY();
                END
                SELECT @ConvId;"
            Dim cmd As New SqlCommand(sql, conn)
            cmd.Parameters.AddWithValue("@SessionId", sessionId)
            Return CInt(cmd.ExecuteScalar())
        End Using
    End Function

    Private Shared Function GetUserTranscript(ByVal sessionId As String) As String
        Dim transcript As New StringBuilder()
        Dim conversationId = GetOrCreateConversation(sessionId)
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
End Class