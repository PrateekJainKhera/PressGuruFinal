Imports System.Net, System.Net.Http, System.Text, System.Threading.Tasks, System.Web.Http, Newtonsoft.Json, System.Configuration, System.Data.SqlClient

Public Class ChatController
    Inherits ApiController

    Public Class ChatRequestModel
        Public Property Message As String
        Public Property SessionId As String
    End Class

    Private Shared ReadOnly GEMINI_API_URL_TEMPLATE As String = "https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key={0}"

    <HttpPost>
    <Route("api/chat/send")>
    Public Async Function SendMessage(<FromBody> ByVal request As ChatRequestModel) As Task(Of IHttpActionResult)
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
        SaveMessageToDb(request.SessionId, "User", request.Message)

        Dim apiKey = ConfigurationManager.AppSettings("GeminiApiKey")
        Dim requestUrl = String.Format(GEMINI_API_URL_TEMPLATE, apiKey)
        Dim systemPrompt = "You are 'PressGuru', a world-class printing industry expert."
        Dim userMessage = $"{systemPrompt} Now, answer: {request.Message}"

        Using client As New HttpClient()
            Dim payload = New With {.contents = {New With {.parts = {New With {.text = userMessage}}}}}
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
    ' ChatController.vb

    ' ... your existing SendMessage function is here ...

    ' =========================================================================
    ' === PASTE THE NEW FUNCTION HERE  (Inside the ChatController class) ===
    ' =========================================================================
    <HttpGet>
    <Route("api/chat/history/{sessionId}")>
    Public Function GetHistory(ByVal sessionId As String) As IHttpActionResult
        Dim messages As New List(Of Object)()
        Dim conversationId As Integer = 0

        Try
            ' Step 1: Find the ConversationId for the given SessionId from the database
            Using conn As New SqlConnection(ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString)
                conn.Open()
                Dim cmd As New SqlCommand("SELECT Id FROM Conversations WHERE SessionId = @SessionId", conn)
                cmd.Parameters.AddWithValue("@SessionId", sessionId)
                Dim result = cmd.ExecuteScalar()
                If result IsNot Nothing AndAlso result IsNot DBNull.Value Then
                    conversationId = CInt(result)
                Else
                    ' If no history exists for this session, return an empty list. This is normal for a new user.
                    Return Ok(messages)
                End If
            End Using

            ' Step 2: If we found a conversation, get all of its messages in the correct order
            If conversationId > 0 Then
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
            End If

            Return Ok(messages)

        Catch ex As Exception
            ' If there's any database error, send a server error response to the browser
            Return InternalServerError(ex)
        End Try
    End Function
    ' ... your helper classes (GeminiResponse, etc.) are here ...

    Public Class GeminiResponse
        Public Property candidates As List(Of Candidate)
    End Class
    Public Class Candidate
        Public Property content As Content
    End Class
    Public Class Content
        Public Property parts As List(Of Part)
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
            Dim cmd As New SqlCommand("IF NOT EXISTS (SELECT 1 FROM Conversations WHERE SessionId = @SessionId) BEGIN INSERT INTO Conversations (SessionId) VALUES (@SessionId) END; SELECT Id FROM Conversations WHERE SessionId = @SessionId;", conn)
            cmd.Parameters.AddWithValue("@SessionId", sessionId)
            Return CInt(cmd.ExecuteScalar())
        End Using
    End Function
End Class
