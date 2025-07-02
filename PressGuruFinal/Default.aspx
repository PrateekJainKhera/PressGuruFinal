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
        .chat-box { flex-grow: 1; overflow-y: auto; padding: 20px; display: flex; flex-direction: column; gap: 10px; }
        .message { max-width: 75%; padding: 12px 18px; border-radius: 20px; line-height: 1.4; word-wrap: break-word; }
        .user-message { background-color: #007bff; color: white; align-self: flex-end; border-bottom-right-radius: 5px; }
        .bot-message { background-color: #e9ecef; color: #333; align-self: flex-start; border-bottom-left-radius: 5px; position: relative; padding-right: 40px; }
        .message p { margin: 0; }
        .input-area { display: flex; align-items: center; padding: 10px 15px; border-top: 1px solid #ddd; background: #f9f9f9; gap: 5px; }
        #userInput { flex-grow: 1; padding: 10px 15px; border: 1px solid #ccc; border-radius: 20px; font-size: 16px; }
        #sendButton, #voiceButton, #analyzeButton, #uploadButton { padding: 10px; border: none; background-color: #007bff; color: white; border-radius: 50%; cursor: pointer; font-size: 16px; width: 44px; height: 44px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
        #sendButton { background-color: #007bff; }
        #voiceButton { background-color: #28a745; }
        #analyzeButton { background-color: #6c757d; }
        #uploadButton { background-color: #17a2b8; }
        .message img.thumbnail { max-width: 200px; border-radius: 10px; margin-top: 8px; }
        .spinner { border: 4px solid rgba(0, 0, 0, 0.1); width: 24px; height: 24px; border-radius: 50%; border-left-color: #007bff; animation: spin 1s ease-in-out infinite; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        .copy-btn { position: absolute; top: 8px; right: 8px; background: transparent; border: none; cursor: pointer; font-size: 18px; color: #555; opacity: 0.5; transition: opacity 0.2s; }
        .bot-message:hover .copy-btn { opacity: 1; }
        .copy-btn:hover { color: #000; }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <div class="chat-container">
            <div id="chat-box" class="chat-box"></div>
            <div class="input-area">
                <button type="button" id="uploadButton" title="Upload Image">📎</button>
                <input type="file" id="imageUploadInput" accept="image/*" style="display: none;" />

                <input type="text" id="userInput" placeholder="Ask or upload an image..." autocomplete="off" />
                <button type="button" id="sendButton" title="Send">➤</button>
                <button type="button" id="voiceButton" title="Use Voice">🎙️</button>
                <button type="button" id="analyzeButton" title="Analyze Personality">👤</button> 
            </div>
        </div>
        
        <script type="text/javascript">
            document.addEventListener("DOMContentLoaded", function () {
                const sendButton = document.getElementById("sendButton");
                const voiceButton = document.getElementById("voiceButton");
                const analyzeButton = document.getElementById("analyzeButton");
                const userInput = document.getElementById("userInput");
                const chatBox = document.getElementById("chat-box");
                const uploadButton = document.getElementById("uploadButton");
                const imageUploadInput = document.getElementById("imageUploadInput");

                let sessionId = sessionStorage.getItem("pressGuruSessionId") || crypto.randomUUID();
                sessionStorage.setItem("pressGuruSessionId", sessionId);

                // --- Helper to display API errors in a chat bubble ---
                async function handleError(response, thinkingBubble) {
                    let errorMessage = `An error has occurred (Status: ${response.status}).`;
                    try {
                        const errorData = await response.json();
                        if (errorData && errorData.ExceptionMessage) {
                            errorMessage = errorData.ExceptionMessage; // Get specific .NET exception
                        } else if (errorData && errorData.Message) {
                            errorMessage = errorData.Message;
                        }
                    } catch (e) {
                        errorMessage = `A server error occurred: ${response.statusText}`;
                    }
                    thinkingBubble.querySelector("p").innerText = `Request failed: ${errorMessage}`;
                    console.error("API Error Response:", response);
                }

                // --- Helper to add a copy button ---
                function addCopyButton(messageDiv) {
                    const copyBtn = document.createElement("button");
                    copyBtn.className = 'copy-btn';
                    copyBtn.innerHTML = '📋';
                    copyBtn.title = 'Copy text';

                    copyBtn.addEventListener('click', (e) => {
                        e.stopPropagation();
                        const textToCopy = messageDiv.querySelector('p').innerText;
                        navigator.clipboard.writeText(textToCopy).then(() => {
                            copyBtn.innerHTML = '✅';
                            setTimeout(() => { copyBtn.innerHTML = '📋'; }, 1500);
                        });
                    });
                    messageDiv.appendChild(copyBtn);
                }

                // --- Helper to add a message bubble ---
                function addMessageToChatBox(sender, text, imageUrl = null) {
                    const msgDiv = document.createElement("div");
                    msgDiv.className = `message ${sender.toLowerCase()}-message`;
                    const p = document.createElement("p");
                    p.innerHTML = text.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/\n/g, '<br>');
                    msgDiv.appendChild(p);

                    if (imageUrl) {
                        const img = document.createElement('img');
                        img.src = imageUrl;
                        img.className = 'thumbnail';
                        msgDiv.appendChild(img);
                    }

                    if (sender.toLowerCase() === 'bot' && text) {
                        addCopyButton(msgDiv);
                    }
                    chatBox.appendChild(msgDiv);
                    setTimeout(() => { chatBox.scrollTop = chatBox.scrollHeight; }, 0);
                    return msgDiv;
                }

                // --- Load chat history ---
                async function loadHistory() {
                    chatBox.innerHTML = '';
                    try {
                        const response = await fetch(`api/chat/history/${sessionId}`);
                        if (!response.ok) throw new Error(`Server error: ${response.status}`);
                        const history = await response.json();
                        if (history.length === 0) {
                            addMessageToChatBox("Bot", "Hello! I am PressGuru. How can I help you with your printing needs?");
                        } else {
                            history.forEach(msg => addMessageToChatBox(msg.sender, msg.text));
                        }
                    } catch (error) {
                        console.error('Failed to load chat history:', error);
                        addMessageToChatBox("Bot", "Welcome back! I had trouble loading our previous chat.");
                    }
                }

                // --- Send a regular message ---
                async function handleSendMessage() {
                    const messageText = userInput.value.trim();
                    if (messageText === "") return;

                    addMessageToChatBox("User", messageText);
                    userInput.value = "";

                    const thinkingMessageDiv = addMessageToChatBox("Bot", "");
                    const spinner = document.createElement('div');
                    spinner.className = 'spinner';
                    thinkingMessageDiv.querySelector('p').appendChild(spinner);

                    try {
                        const response = await fetch('api/chat/send', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json; charset=utf-8' },
                            body: JSON.stringify({ message: messageText, sessionId: sessionId })
                        });

                        if (!response.ok) { return await handleError(response, thinkingMessageDiv); }

                        const data = await response.json();
                        const p = thinkingMessageDiv.querySelector("p");
                        p.innerHTML = data.response.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/\n/g, '<br>');
                        addCopyButton(thinkingMessageDiv);

                    } catch (error) {
                        thinkingMessageDiv.querySelector("p").innerText = `Request failed: ${error.message}`;
                        console.error('Full Error:', error);
                    }
                }

                // --- Handle personality analysis ---
                async function handleAnalysis() {
                    const thinkingMessageDiv = addMessageToChatBox("Bot", "");
                    const spinner = document.createElement('div');
                    spinner.className = 'spinner';
                    thinkingMessageDiv.querySelector('p').appendChild(spinner);

                    try {
                        const response = await fetch('api/chat/analyze', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ sessionId: sessionId })
                        });

                        if (!response.ok) { return await handleError(response, thinkingMessageDiv); }

                        const data = await response.json();
                        const p = thinkingMessageDiv.querySelector("p");
                        p.innerHTML = `<strong>Personality Analysis:</strong><br>${data.response.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/\n/g, '<br>')}`;
                        addCopyButton(thinkingMessageDiv);

                    } catch (error) {
                        thinkingMessageDiv.querySelector("p").innerText = `Analysis failed: ${error.message}`;
                        console.error("Analysis Error:", error);
                    }
                }

                // --- Handle image upload ---
                async function handleImageUpload(event) {
                    const file = event.target.files[0];
                    if (!file) return;

                    const thumbnailUrl = URL.createObjectURL(file);
                    addMessageToChatBox("User", "Analyzing this image...", thumbnailUrl);

                    const thinkingMessageDiv = addMessageToChatBox("Bot", "");
                    const spinner = document.createElement('div');
                    spinner.className = 'spinner';
                    thinkingMessageDiv.querySelector('p').appendChild(spinner);

                    const formData = new FormData();
                    formData.append("image", file);
                    formData.append("sessionId", sessionId);

                    try {
                        const response = await fetch('api/chat/analyzeImage', {
                            method: 'POST',
                            body: formData
                        });

                        if (!response.ok) { return await handleError(response, thinkingMessageDiv); }

                        const data = await response.json();
                        const p = thinkingMessageDiv.querySelector("p");
                        p.innerHTML = data.response.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/\n/g, '<br>');
                        addCopyButton(thinkingMessageDiv);

                    } catch (error) {
                        thinkingMessageDiv.querySelector("p").innerText = `Image analysis failed: ${error.message}`;
                        console.error("Image Analysis Error:", error);
                    } finally {
                        event.target.value = '';
                    }
                }

                // --- Set up all event listeners ---
                sendButton.addEventListener("click", handleSendMessage);
                analyzeButton.addEventListener("click", handleAnalysis);
                userInput.addEventListener("keypress", e => { if (e.key === 'Enter') handleSendMessage(); });
                uploadButton.addEventListener("click", () => imageUploadInput.click());
                imageUploadInput.addEventListener("change", handleImageUpload);

                // --- Set up Voice Recognition ---
                const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
                if (SR) {
                    const r = new SR();
                    r.onstart = () => { voiceButton.textContent = "🔊"; };
                    r.onend = () => { voiceButton.textContent = "🎙️"; };
                    r.onresult = e => {
                        userInput.value = e.results[0][0].transcript;
                        handleSendMessage();
                    };
                    voiceButton.addEventListener("click", () => r.start());
                } else {
                    voiceButton.style.display = "none";
                }

                // --- Load history on startup ---
                loadHistory();
            });
        </script>
    </form>
</body>
</html>