<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="Default.aspx.vb" Inherits="PressGuruFinal._Default" %>

<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>PressGuru AI</title>
    
    <!-- NEW: Importing a professional font from Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;700&display=swap" rel="stylesheet">

    <style>
        /* =========================================== */
        /* ===         NEW PROFESSIONAL UI         === */
        /* =========================================== */

        :root {
            --bg-dark-primary: #202123;      /* Sidebar background */
            --bg-dark-secondary: #343541;   /* Main chat background */
            --text-primary: #ffffff;
            --text-secondary: #d1d5db;      /* Lighter text for details */
            --border-color: rgba(255, 255, 255, 0.2);
            --accent-blue: #3b82f6;
            --user-bubble: #3b82f6;
            --bot-bubble: #444654;
        }

        /* --- GENERAL & TYPOGRAPHY --- */
        html, body {
            height: 100%;
            margin: 0;
            overflow: hidden; /* Prevent body scrollbars */
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        body {
            background-color: var(--bg-dark-secondary);
            display: flex;
            color: var(--text-primary);
        }

        /* --- CUSTOM SCROLLBAR --- */
        ::-webkit-scrollbar {
            width: 8px;
        }
        ::-webkit-scrollbar-track {
            background: rgba(0,0,0,0.1);
        }
        ::-webkit-scrollbar-thumb {
            background-color: #555;
            border-radius: 4px;
        }
        ::-webkit-scrollbar-thumb:hover {
            background-color: #666;
        }

        /* --- SIDEBAR --- */
        .sidebar {
            width: 260px;
            background-color: var(--bg-dark-primary);
            display: flex;
            flex-direction: column;
            padding: 10px;
            flex-shrink: 0;
            border-right: 1px solid #000;
        }
        .sidebar-header {
            padding: 12px;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            cursor: pointer;
            font-size: 14px;
            margin-bottom: 20px;
            text-align: center;
            transition: background-color 0.2s;
        }
        .sidebar-header:hover { background-color: rgba(255, 255, 255, 0.05); }
        .history-list {
            flex-grow: 1;
            list-style: none;
            padding: 0;
            margin: 0;
            overflow-y: auto;
        }
        .history-list li {
            padding: 12px 10px;
            border-radius: 8px;
            cursor: pointer;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            font-size: 14px;
            margin-bottom: 5px;
            transition: background-color 0.2s;
        }
        .history-list li:hover { background-color: var(--bg-dark-secondary); }
        .history-list li.active { background-color: var(--accent-blue); font-weight: 500; }

        /* --- MAIN CONTENT & CHAT CONTAINER --- */
        .main-content {
            flex-grow: 1;
            display: flex;
            flex-direction: column;
            height: 100vh;
        }
        .chat-container {
            flex-grow: 1;
            max-width: 800px;
            margin: 0 auto;
            display: flex;
            flex-direction: column;
            width: 100%;
            height: 100%;
        }
        .chat-box {
            flex-grow: 1;
            overflow-y: auto;
            padding: 20px 10px;
            display: flex;
            flex-direction: column;
        }

        /* --- WELCOME SCREEN --- */
        .welcome-screen {
            flex-grow: 1;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            text-align: center;
            color: var(--text-secondary);
            padding: 20px;
        }
        .welcome-screen h1 {
            font-size: 3rem;
            font-weight: 700;
            color: var(--text-primary);
        }
        
        /* --- CHAT BUBBLES & AVATARS --- */
        .message-wrapper {
            display: flex;
            align-items: flex-start;
            gap: 15px;
            padding: 15px 10px;
            max-width: 100%;
        }
        .avatar {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            background-color: #555;
            display: flex;
            justify-content: center;
            align-items: center;
            font-size: 20px;
            flex-shrink: 0;
        }
        .message {
            max-width: calc(100% - 60px);
            padding: 12px 18px;
            border-radius: 12px;
            line-height: 1.6;
            word-wrap: break-word;
            position: relative;
        }
        .message-wrapper.user { justify-content: flex-end; }
        .message-wrapper.user .message { background-color: var(--user-bubble); order: 1; }
        .message-wrapper.user .avatar { background-color: #1e40af; order: 2; }
        .message-wrapper.bot .message { background-color: var(--bot-bubble); }
        .message-wrapper.bot .avatar { background-color: #166534; }
        .message p { margin: 0; }
        .copy-btn {
            position: absolute;
            bottom: 8px;
            right: -35px;
            background: transparent;
            border: none;
            cursor: pointer;
            font-size: 16px;
            color: var(--text-secondary);
            opacity: 0;
            transition: opacity 0.2s;
        }
        .message-wrapper:hover .copy-btn { opacity: 0.7; }
        .copy-btn:hover { opacity: 1; }

        /* --- INPUT AREA --- */
        .input-area-wrapper {
            padding: 20px 0;
            background: var(--bg-dark-secondary);
            border-top: 1px solid #171717;
        }
        .input-area {
            max-width: 800px;
            margin: 0 auto;
            padding: 10px;
            background-color: var(--bot-bubble);
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 12px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        #userInput {
            flex-grow: 1;
            background: transparent;
            border: none;
            outline: none;
            color: var(--text-primary);
            font-size: 16px;
            padding: 10px;
        }
        #sendButton, #voiceButton, #analyzeButton, #uploadButton {
            border: none;
            background-color: transparent;
            color: var(--text-secondary);
            border-radius: 8px;
            cursor: pointer;
            font-size: 22px;
            width: 44px;
            height: 44px;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
            transition: background-color 0.2s, color 0.2s;
        }
        #sendButton:hover, #voiceButton:hover, #analyzeButton:hover, #uploadButton:hover {
            background-color: rgba(255, 255, 255, 0.1);
            color: var(--text-primary);
        }
        .spinner { border: 3px solid rgba(255,255,255,0.2); width: 20px; height: 20px; border-radius: 50%; border-left-color: var(--text-primary); animation: spin 1s ease-in-out infinite; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <form id="form1" runat="server" style="display: contents;">
        <div class="sidebar">
            <div id="newChatButton" class="sidebar-header">+ New Chat</div>
            <ul id="historyList" class="history-list"></ul>
        </div>
        
        <div class="main-content">
            <div class="chat-container">
                <div id="chat-box" class="chat-box">
                    <div class="welcome-screen" id="welcomeScreen">
                        <h1>PressGuru AI</h1>
                        <p>Your expert partner in printing and packaging. Start a new chat to begin.</p>
                    </div>
                </div>
            </div>
            <div class="input-area-wrapper">
                <div class="input-area">
                    <button type="button" id="uploadButton" title="Upload Image">📎</button>
                    <input type="file" id="imageUploadInput" accept="image/*" style="display: none;" />
                    <input type="text" id="userInput" placeholder="Ask PressGuru..." autocomplete="off" />
                    <button type="button" id="sendButton" title="Send">➤</button>
                    <button type="button" id="voiceButton" title="Use Voice">🎙️</button>
                    <button type="button" id="analyzeButton" title="Analyze Personality">👤</button> 
                </div>
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
                const historyList = document.getElementById("historyList");
                const newChatButton = document.getElementById("newChatButton");
                const welcomeScreen = document.getElementById("welcomeScreen");

                let userGuid = localStorage.getItem("pressGuruUserGuid") || crypto.randomUUID();
                localStorage.setItem("pressGuruUserGuid", userGuid);
                let currentSessionId = sessionStorage.getItem("pressGuruCurrentSessionId") || crypto.randomUUID();
                sessionStorage.setItem("pressGuruCurrentSessionId", currentSessionId);

                async function handleError(response, messageWrapper) {
                    let errorMessage = `An error has occurred (Status: ${response.status}).`;
                    try {
                        const errorData = await response.json();
                        if (errorData && errorData.ExceptionMessage) {
                            errorMessage = errorData.ExceptionMessage;
                        } else if (errorData && errorData.Message) {
                            errorMessage = errorData.Message;
                        }
                    } catch (e) {
                        errorMessage = `A server error occurred: ${response.statusText}`;
                    }
                    const p = messageWrapper.querySelector("p");
                    p.innerText = `Request failed: ${errorMessage}`;
                    console.error("API Error Response:", response);
                }

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

                function addMessageToChatBox(sender, text, imageUrl = null) {
                    welcomeScreen.style.display = 'none';
                    const wrapper = document.createElement("div");
                    wrapper.className = `message-wrapper ${sender.toLowerCase()}`;
                    const avatar = document.createElement("div");
                    avatar.className = 'avatar';
                    avatar.textContent = (sender.toLowerCase() === 'bot') ? '🤖' : '👤';
                    const messageDiv = document.createElement("div");
                    messageDiv.className = 'message';
                    const p = document.createElement("p");
                    p.innerHTML = text.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/\n/g, '<br>');
                    messageDiv.appendChild(p);

                    if (sender.toLowerCase() === 'bot' && !text) {
                        const spinner = document.createElement('div');
                        spinner.className = 'spinner';
                        p.appendChild(spinner);
                    } else if (sender.toLowerCase() === 'bot' && text) {
                        addCopyButton(messageDiv);
                    }
                    if (imageUrl) {
                        const img = document.createElement('img');
                        img.src = imageUrl;
                        img.className = 'thumbnail';
                        messageDiv.appendChild(img);
                    }

                    wrapper.appendChild(avatar);
                    wrapper.appendChild(messageDiv);
                    chatBox.appendChild(wrapper);
                    setTimeout(() => { chatBox.scrollTop = chatBox.scrollHeight; }, 0);
                    return messageDiv;
                }

                async function loadSidebar() {
                    historyList.innerHTML = '';
                    try {
                        const response = await fetch(`api/user/conversations/${userGuid}`);
                        if (!response.ok) throw new Error("Failed to fetch conversations.");
                        const conversations = await response.json();
                        conversations.forEach(conv => {
                            const li = document.createElement("li");
                            li.textContent = conv.title;
                            li.dataset.sessionId = conv.sessionId;
                            if (conv.sessionId === currentSessionId) {
                                li.classList.add("active");
                            }
                            li.addEventListener("click", handleSidebarClick);
                            historyList.appendChild(li);
                        });
                    } catch (error) {
                        console.error("Failed to load history sidebar:", error);
                    }
                }

                function handleSidebarClick(event) {
                    const newSessionId = event.target.dataset.sessionId;
                    if (newSessionId && newSessionId !== currentSessionId) {
                        currentSessionId = newSessionId;
                        sessionStorage.setItem("pressGuruCurrentSessionId", currentSessionId);
                        loadHistory(currentSessionId);
                        document.querySelectorAll('.history-list li').forEach(item => item.classList.remove('active'));
                        event.target.classList.add('active');
                    }
                }

                async function loadHistory(sessionId) {
                    chatBox.innerHTML = '';
                    welcomeScreen.style.display = 'flex';
                    try {
                        const response = await fetch(`api/chat/history/${sessionId}`);
                        if (!response.ok) throw new Error(`Server error: ${response.status}`);
                        const history = await response.json();
                        if (history.length > 0) {
                            welcomeScreen.style.display = 'none';
                            history.forEach(msg => addMessageToChatBox(msg.sender, msg.text));
                        } else {
                            addMessageToChatBox("Bot", "Hello! I am PressGuru. How can I help you?");
                        }
                    } catch (error) {
                        welcomeScreen.style.display = 'none';
                        addMessageToChatBox("Bot", "Sorry, I had trouble loading our previous chat.");
                        console.error('Failed to load chat history:', error);
                    }
                }

                async function handleSendMessage() {
                    const messageText = userInput.value.trim();
                    if (messageText === "") return;
                    addMessageToChatBox("User", messageText);
                    userInput.value = "";
                    const thinkingMessageDiv = addMessageToChatBox("Bot", "");
                    try {
                        const response = await fetch('api/chat/send', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json; charset=utf-8' },
                            body: JSON.stringify({ message: messageText, sessionId: currentSessionId, userGuid: userGuid })
                        });
                        if (!response.ok) { return await handleError(response, thinkingMessageDiv); }
                        const data = await response.json();
                        const p = thinkingMessageDiv.querySelector("p");
                        p.innerHTML = data.response.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/\n/g, '<br>');
                        addCopyButton(thinkingMessageDiv);
                        loadSidebar();
                    } catch (error) {
                        const p = thinkingMessageDiv.querySelector("p");
                        p.innerText = `Request failed: ${error.message}`;
                    }
                }

                async function handleAnalysis() {
                    const thinkingMessageDiv = addMessageToChatBox("Bot", "");
                    try {
                        const response = await fetch('api/chat/analyze', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ sessionId: currentSessionId, userGuid: userGuid })
                        });
                        if (!response.ok) { return await handleError(response, thinkingMessageDiv); }
                        const data = await response.json();
                        const p = thinkingMessageDiv.querySelector("p");
                        p.innerHTML = `<strong>Personality Analysis:</strong><br>${data.response.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/\n/g, '<br>')}`;
                        addCopyButton(thinkingMessageDiv);
                    } catch (error) {
                        const p = thinkingMessageDiv.querySelector("p");
                        p.innerText = `Analysis failed: ${error.message}`;
                    }
                }

                async function handleImageUpload(event) {
                    const file = event.target.files[0];
                    if (!file) return;
                    const thumbnailUrl = URL.createObjectURL(file);
                    addMessageToChatBox("User", "Analyzing this image...", thumbnailUrl);
                    const thinkingMessageDiv = addMessageToChatBox("Bot", "");
                    const formData = new FormData();
                    formData.append("image", file);
                    formData.append("sessionId", currentSessionId);
                    formData.append("userGuid", userGuid);
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
                        loadSidebar();
                    } catch (error) {
                        const p = thinkingMessageDiv.querySelector("p");
                        p.innerText = `Image analysis failed: ${error.message}`;
                    } finally {
                        event.target.value = '';
                    }
                }

                newChatButton.addEventListener("click", () => {
                    currentSessionId = crypto.randomUUID();
                    sessionStorage.setItem("pressGuruCurrentSessionId", currentSessionId);
                    chatBox.innerHTML = '';
                    loadSidebar();
                    addMessageToChatBox("Bot", "Hello! I am PressGuru. How can I help you?");
                });

                sendButton.addEventListener("click", handleSendMessage);
                analyzeButton.addEventListener("click", handleAnalysis);
                userInput.addEventListener("keypress", e => { if (e.key === 'Enter') handleSendMessage(); });
                uploadButton.addEventListener("click", () => imageUploadInput.click());
                imageUploadInput.addEventListener("change", handleImageUpload);

                const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
                if (SR) {
                    const r = new SR();
                    r.onstart = () => { voiceButton.style.color = '#3b82f6'; };
                    r.onend = () => { voiceButton.style.color = 'var(--text-secondary)'; };
                    r.onresult = e => {
                        userInput.value = e.results[0][0].transcript;
                        handleSendMessage();
                    };
                    voiceButton.addEventListener("click", () => r.start());
                } else {
                    voiceButton.style.display = "none";
                }

                async function initializeApp() {
                    await loadSidebar();
                    await loadHistory(currentSessionId);
                }

                initializeApp();
            });
        </script>
    </form>
</body>
</html>