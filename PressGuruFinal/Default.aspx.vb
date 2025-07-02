Imports System.Web.Services, System.Configuration, System.Data.SqlClient, System.Threading.Tasks, System.Net.Http, System.Text, System.Net, Newtonsoft.Json, System.IO

Public Class _Default
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
    End Sub

    ' =========================================================================
    ' DEBUGGING HELPER: This writes messages to a log file
    ' =========================================================================
    Private Shared Sub Log(ByVal message As String)
        Try
            Dim logFilePath = HttpContext.Current.Server.MapPath("~/Logs/debug_log.txt")
            File.AppendAllText(logFilePath, $"{DateTime.Now}: {message}" & Environment.NewLine)
        Catch ex As Exception
            ' If logging fails, we can't do much, but we won't crash the app.
        End Try
    End Sub

    Private Shared ReadOnly GEMINI_API_URL_TEMPLATE As String = "https://generativelanguage.googleapis.com/v1/models/gemini-1.0-pro:generateContent?key={0}"

    <WebMethod()>
    Public Shared Async Function SendMessage(ByVal message As String, ByVal sessionId As String) As Task(Of String)
        Log("================ NEW REQUEST ===============")
        Log($"SendMessage called with message: '{message}' and session: '{sessionId}'")

        Try
            SaveMessageToDb(sessionId, "User", message)
            Log("User message saved to DB.")

            Dim apiKey = ConfigurationManager.AppSettings("GeminiApiKey")
            If String.IsNullOrEmpty(apiKey) Then
                Log("FATAL ERROR: GeminiApiKey is missing from Web.config.")
                Return "FATAL ERROR: GeminiApiKey is missing from Web.config."
            End If
            Log("API Key loaded successfully.")

            Dim requestUrl = String.Format(GEMINI_API_URL_TEMPLATE, apiKey)
            Dim systemPrompt = "You are 'PressGuru', a world-class printing industry expert. Answer questions on printing technology clearly."
            Dim userMessage = $"{systemPrompt} Now, answer: {message}"

            Using client As New HttpClient()
                Dim payload = New With {.contents = {New With {.parts = {New With {.text = userMessage}}}}}
                Dim jsonPayload = JsonConvert.SerializeObject(payload)
                Dim content = New StringContent(jsonPayload, Encoding.UTF8, "application/json")
                Log("Payload created. Sending request to Google...")

                Dim response = Await client.PostAsync(requestUrl, content)
                Log($"Response received. Status Code: {response.StatusCode}")

                Dim jsonResponse = Await response.Content.ReadAsStringAsync()
                Log("Raw JSON Response: " & jsonResponse)

                If response.IsSuccessStatusCode Then
                    Dim geminiResponse = JsonConvert.DeserializeObject(Of GeminiResponse)(jsonResponse)

                    If geminiResponse IsNot Nothing AndAlso geminiResponse.candidates IsNot Nothing AndAlso geminiResponse.candidates.Count > 0 Then
                        Dim botResponseContent = geminiResponse.candidates(0).content.parts(0).text.Trim()
                        Log("SUCCESS: Bot response parsed: " & botResponseContent)

                        SaveMessageToDb(sessionId, "Bot", botResponseContent)
                        Log("Bot response saved to DB.")

                        Return botResponseContent
                    Else
                        Log("ERROR: AI response was valid but empty or in a different format.")
                        Return "Error: AI response was empty or malformed."
                    End If
                Else
                    Log($"API ERROR: {jsonResponse}")
                    Return $"API Error ({response.StatusCode})"
                End If
            End Using
        Catch ex As Exception
            Log("!!!!!!!!!! CRITICAL EXCEPTION !!!!!!!!!!!")
            Log("Exception Type: " & ex.GetType().ToString())
            Log("Exception Message: " & ex.Message)
            Log("Stack Trace: " & ex.StackTrace)
            Log("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
            Return "A critical server error occurred. Please check the logs."
        End Try
    End Function

    ' --- The rest of the file (helper classes and database functions) remains exactly the same ---
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

    Private Shared Function GetOrCreateConversation(ByVal sessionId As String) As Integer
        Using conn As New SqlConnection(ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString)
            conn.Open()
            Dim cmd As New SqlCommand("IF NOT EXISTS (SELECT 1 FROM Conversations WHERE SessionId = @SessionId) BEGIN INSERT INTO Conversations (SessionId) VALUES (@SessionId) END; SELECT Id FROM Conversations WHERE SessionId = @SessionId;", conn)
            cmd.Parameters.AddWithValue("@SessionId", sessionId)
            Return CInt(cmd.ExecuteScalar())
        End Using
    End Function
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
End Class