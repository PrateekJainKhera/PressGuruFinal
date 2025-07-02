<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="Default.aspx.vb" Inherits="PressGuruFinal._Default" %>

<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>PressGuru AI</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; background-color: #f0f2f5; margin: 0; padding: 0; }
        .chat-container { max-width: 800px; margin: 2rem auto; border: 1px solid #ddd; border-radius: 8px; background: #ffffff; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1); display: flex; flex-direction: column; height: 85vh; }
        .chat-box { flex-grow: 1; overflow-y: auto; padding: 20px; display: flex; flex-direction: column; }
        .message { max-width: 75%; padding: 12px 18px; border-radius: 20px; margin-bottom: 10px; line-height: 1.4; word-wrap: break-word; }
        .user-message { background-color: #007bff; color: white; align-self: flex-end; border-bottom-right-radius: 5px; }
        .bot-message { background-color: #e9ecef; color: #333; align-self: flex-start; border-bottom-left-radius: 5px; }
        .message p { margin: 0; }
        .input-area { display: flex; align-items: center; padding: 15px; border-top: 1px solid #ddd; background: #f9f9f9; }
        #userInput { flex-grow: 1; padding: 10px 15px; border: 1px solid #ccc; border-radius: 20px; margin-right: 10px; font-size: 16px; }
        #sendButton, #voiceButton { padding: 10px 20px; border: none; background-color: #007bff; color: white; border-radius: 20px; cursor: pointer; font-size: 16px; }
        #voiceButton { background-color: #28a745; margin-left: 5px; }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <%-- Web API को चलाने के लिए ScriptManager की ज़रूरत नहीं होती, लेकिन अगर आप भविष्य में 
             ASP.NET AJAX का कोई फीचर इस्तेमाल करें तो यह काम आएगा। इसे रखने में कोई हर्ज़ नहीं। --%>
        <asp:ScriptManager ID="ScriptManager1" runat="server" />

        <div class="chat-container">
            <div id="chat-box" class="chat-box">
                <div class="message bot-message"><p>Hello! I am PressGuru. How can I help?</p></div>
            </div>
            <div class="input-area">
                <input type="text" id="userInput" placeholder="Ask about printing..." autocomplete="off" />
                <button type="button" id="sendButton">Send</button>
                <button type="button" id="voiceButton">🎙️</button>
            </div>
        </div>

        <%-- ========================================================================= --%>
        <%-- **FINAL, ROBUST JAVASCRIPT CODE** --%>
        <%-- ========================================================================= --%>
        <script type="text/javascript">
            document.addEventListener("DOMContentLoaded", function () {
                const sendButton = document.getElementById("sendButton");
                const voiceButton = document.getElementById("voiceButton");
                const userInput = document.getElementById("userInput");
                const chatBox = document.getElementById("chat-box");
                let sessionId = sessionStorage.getItem("pressGuruSessionId") || crypto.randomUUID();
                sessionStorage.setItem("pressGuruSessionId", sessionId);

                sendButton.addEventListener("click", handleSendMessage);
                userInput.addEventListener("keypress", e => { if (e.key === 'Enter') handleSendMessage(); });

                async function handleSendMessage() {
                    const messageText = userInput.value.trim();
                    if (messageText === "") return;

                    addMessageToChatBox("User", messageText);
                    userInput.value = "";
                    const thinkingMessage = addMessageToChatBox("Bot", "...");

                    try {
                        // सर्वर के API Controller को रिक्वेस्ट भेजें
                        const response = await fetch('api/chat/send', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json; charset=utf-8' },
                            body: JSON.stringify({ message: messageText, sessionId: sessionId })
                        });

                        // सर्वर के जवाब को JSON में बदलें
                        const data = await response.json();

                        if (!response.ok) {
                            // अगर सर्वर ने कोई एरर (जैसे 400, 500) भेजा
                            // data.Message Web API के डिटेल्ड एरर को दिखाता है
                            throw new Error(data.Message || `Server responded with status: ${response.status}`);
                        }

                        if (data && data.response) {
                            // अगर जवाब सही है और उसमें 'response' प्रॉपर्टी है
                            thinkingMessage.querySelector("p").innerText = data.response;
                        } else {
                            // अगर जवाब तो आया, लेकिन वह खाली या गलत फॉर्मेट में है
                            thinkingMessage.querySelector("p").innerText = "Received an unexpected response format. Raw: " + JSON.stringify(data);
                        }

                    } catch (error) {
                        // अगर कोई भी बड़ी गड़बड़ हुई (नेटवर्क कनेक्शन, JSON एरर)
                        console.error('Full Error:', error);
                        thinkingMessage.querySelector("p").innerText = `Sorry, a critical error occurred: ${error.message}`;
                    }
                }

                function addMessageToChatBox(sender, text) {
                    const d = document.createElement("div");
                    d.className = `message ${sender.toLowerCase()}-message`;
                    const p = document.createElement("p");
                    p.innerText = text;
                    d.appendChild(p);
                    chatBox.appendChild(d);
                    chatBox.scrollTop = chatBox.scrollHeight;
                    return d;
                }

                // Voice Recognition Code
                const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
                if (SR) {
                    const r = new SR();
                    voiceButton.addEventListener("click", () => r.start());
                    r.onstart = () => { voiceButton.textContent = "🔊"; };
                    r.onresult = e => { userInput.value = e.results[0][0].transcript; handleSendMessage(); };
                    r.onend = () => { voiceButton.textContent = "🎙️"; };
                } else { voiceButton.style.display = "none"; }
            });
        </script>
    </form>
</body>
</html>