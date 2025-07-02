<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="Default.aspx.vb" Inherits="PressGuruFinal._Default" %>

<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>PressGuru AI</title>
    <style>
        /* --- Base Styles (No Changes) --- */
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; background-color: #f0f2f5; margin: 0; padding: 0; }
        .chat-container { max-width: 800px; margin: 2rem auto; border: 1px solid #ddd; border-radius: 8px; background: #ffffff; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1); display: flex; flex-direction: column; height: 85vh; }
        .chat-box { flex-grow: 1; overflow-y: auto; padding: 20px; display: flex; flex-direction: column; }
        .message { max-width: 75%; padding: 12px 18px; border-radius: 20px; margin-bottom: 10px; line-height: 1.4; word-wrap: break-word; }
        .user-message { background-color: #007bff; color: white; align-self: flex-end; border-bottom-right-radius: 5px; }
        .message p { margin: 0; }
        .input-area { display: flex; align-items: center; padding: 15px; border-top: 1px solid #ddd; background: #f9f9f9; }
        #userInput { flex-grow: 1; padding: 10px 15px; border: 1px solid #ccc; border-radius: 20px; margin-right: 10px; font-size: 16px; }
        #sendButton, #voiceButton, #analyzeButton { padding: 10px 20px; border: none; background-color: #007bff; color: white; border-radius: 20px; cursor: pointer; font-size: 16px; }
        #voiceButton { background-color: #28a745; margin-left: 5px; }
        #analyzeButton { background-color: #6c757d; margin-left: 5px; }

        /* === UPDATED AND NEW STYLES === */

        /* Add position:relative so we can position the copy button inside it */
        .bot-message {
            background-color: #e9ecef;
            color: #333;
            align-self: flex-start;
            border-bottom-left-radius: 5px;
            position: relative; /* <-- REQUIRED FOR COPY BUTTON */
            padding-right: 40px; /* <-- Make space for the copy button */
        }
        
        /* 1. Styles for the animated loading spinner */
        .spinner {
            border: 4px solid rgba(0, 0, 0, 0.1);
            width: 24px;
            height: 24px;
            border-radius: 50%;
            border-left-color: #007bff;
            animation: spin 1s ease-in-out infinite;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        /* 2. Styles for the new "Copy" button */
        .copy-btn {
            position: absolute;
            top: 8px;
            right: 8px;
            background: transparent;
            border: none;
            cursor: pointer;
            font-size: 18px;
            color: #555;
            opacity: 0.5;
            transition: opacity 0.2s;
        }

        .bot-message:hover .copy-btn {
            opacity: 1; /* Show button clearly on hover */
        }

        .copy-btn:hover {
            color: #000;
        }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <asp:ScriptManager ID="ScriptManager1" runat="server" />

        <div class="chat-container">
            <div id="chat-box" class="chat-box">
                <%-- Chat messages will be dynamically inserted here by JavaScript --%>
            </div>
            <div class="input-area">
                <input type="text" id="userInput" placeholder="Ask about printing..." autocomplete="off" />
                <button type="button" id="sendButton">Send</button>
                <button type="button" id="voiceButton">🎙️</button>
                <button type="button" id="analyzeButton" title="Analyze Personality">👤</button> 
            </div>
        </div>
        
        <%-- ========================================================================= --%>
        <%-- ** COMPLETE UPDATED JAVASCRIPT CODE ** --%>
        <%-- ========================================================================= --%>
        <script type="text/javascript">
            document.addEventListener("DOMContentLoaded", function () {
                // Get all UI elements
                const sendButton = document.getElementById("sendButton");
                const voiceButton = document.getElementById("voiceButton");
                const analyzeButton = document.getElementById("analyzeButton");
                const userInput = document.getElementById("userInput");
                const chatBox = document.getElementById("chat-box");

                // Get or create a unique session ID for the user
                let sessionId = sessionStorage.getItem("pressGuruSessionId") || crypto.randomUUID();
                sessionStorage.setItem("pressGuruSessionId", sessionId);

                // --- Function to add a message bubble to the chat window ---
                function addMessageToChatBox(sender, text) {
                    const msgDiv = document.createElement("div");
                    msgDiv.className = `message ${sender.toLowerCase()}-message`;

                    const p = document.createElement("p");
                    // Use innerHTML to render bold tags and newlines
                    p.innerHTML = text.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/\n/g, '<br>');
                    msgDiv.appendChild(p);

                    // If the message is from the bot and has content, add a copy button
                    if (sender.toLowerCase() === 'bot' && text) {
                        addCopyButton(msgDiv);
                    }

                    chatBox.appendChild(msgDiv);
                    // Scroll to the bottom of the chat box
                    setTimeout(() => { chatBox.scrollTop = chatBox.scrollHeight; }, 0);
                    return msgDiv; // Return the entire message div
                }

                // --- Helper function to create and add a copy button ---
                function addCopyButton(messageDiv) {
                    const copyBtn = document.createElement("button");
                    copyBtn.className = 'copy-btn';
                    copyBtn.innerHTML = '📋'; // Clipboard emoji
                    copyBtn.title = 'Copy text';

                    copyBtn.addEventListener('click', (e) => {
                        e.stopPropagation(); // Prevents other click events from firing
                        const textToCopy = messageDiv.querySelector('p').innerText;
                        navigator.clipboard.writeText(textToCopy).then(() => {
                            copyBtn.innerHTML = '✅'; // Checkmark emoji
                            setTimeout(() => {
                                copyBtn.innerHTML = '📋';
                            }, 1500); // Revert back after 1.5 seconds
                        });
                    });
                    messageDiv.appendChild(copyBtn);
                }

                // --- Function to load chat history when the page opens ---
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

                // --- Function to send a regular message to the bot ---
                async function handleSendMessage() {
                    const messageText = userInput.value.trim();
                    if (messageText === "") return;

                    addMessageToChatBox("User", messageText);
                    userInput.value = "";

                    // Show the animated loading spinner
                    const thinkingMessageDiv = addMessageToChatBox("Bot", ""); // Create an empty bot bubble
                    const spinner = document.createElement('div');
                    spinner.className = 'spinner';
                    thinkingMessageDiv.querySelector('p').appendChild(spinner); // Put spinner inside the <p> tag

                    try {
                        const response = await fetch('api/chat/send', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json; charset=utf-8' },
                            body: JSON.stringify({ message: messageText, sessionId: sessionId })
                        });
                        const data = await response.json();
                        if (!response.ok) throw new Error(data.Message || `Server responded with status: ${response.status}`);

                        // Update the thinking bubble with the actual response
                        const p = thinkingMessageDiv.querySelector("p");
                        p.innerHTML = data.response.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/\n/g, '<br>');

                        // Add the copy button to the final response
                        addCopyButton(thinkingMessageDiv);

                    } catch (error) {
                        console.error('Full Error:', error);
                        thinkingMessageDiv.querySelector("p").innerText = `Sorry, a critical error occurred: ${error.message}`;
                    }
                }

                // --- Function to handle the personality analysis request ---
                async function handleAnalysis() {
                    // Use the spinner for analysis
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
                        const data = await response.json();
                        if (!response.ok) throw new Error(data.Message || "Failed to get analysis.");

                        // Update the thinking bubble with the analysis result
                        const p = thinkingMessageDiv.querySelector("p");
                        p.innerHTML = `<strong>Personality Analysis:</strong><br>${data.response.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/\n/g, '<br>')}`;

                        // Add the copy button to the analysis result
                        addCopyButton(thinkingMessageDiv);

                    } catch (error) {
                        thinkingMessageDiv.querySelector("p").innerText = `Analysis failed: ${error.message}`;
                        console.error("Analysis Error:", error);
                    }
                }

                // --- Set up all event listeners ---
                sendButton.addEventListener("click", handleSendMessage);
                analyzeButton.addEventListener("click", handleAnalysis);
                userInput.addEventListener("keypress", e => { if (e.key === 'Enter') handleSendMessage(); });

                // --- Set up Voice Recognition (No changes) ---
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

                // --- Load history as soon as the page is ready ---
                loadHistory();
            });
        </script>
    </form>
</body>
</html>