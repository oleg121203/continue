import * as vscode from 'vscode';

export function activate(context: vscode.ExtensionContext) {
    console.log('Chat extension is now active!');

    let disposable = vscode.commands.registerCommand('myChatExtension.openChat', () => {
        try {
            const panel = vscode.window.createWebviewPanel(
                'vsCodeChat',
                'VS Code Chat',
                vscode.ViewColumn.Two,
                {
                    enableScripts: true,
                    retainContextWhenHidden: true,
                    localResourceRoots: [
                        vscode.Uri.joinPath(context.extensionUri, 'media')
                    ]
                }
            );

            // Restore previous state if it exists
            const previousState = context.workspaceState.get('chatMessages', []);
            panel.webview.html = getWebviewContent(previousState);

            panel.webview.onDidReceiveMessage(
                async message => {
                    try {
                        switch (message.command) {
                            case 'sendMessage':
                                await context.workspaceState.update('chatMessages', message.messages);
                                vscode.window.showInformationMessage(message.text);
                                return;
                            case 'clearMessages':
                                await context.workspaceState.update('chatMessages', []);
                                return;
                        }
                    } catch (error) {
                        vscode.window.showErrorMessage(`Error processing message: ${error}`);
                    }
                },
                undefined,
                context.subscriptions
            );
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to open chat: ${error}`);
        }
    });

    context.subscriptions.push(disposable);
}

function getWebviewContent(previousMessages: string[] = []) {
    return `<!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>VS Code Chat</title>
            <style>
                body {
                    padding: 0;
                    color: var(--vscode-foreground);
                    font-family: var(--vscode-font-family);
                    background-color: var(--vscode-editor-background);
                }
                .chat-container {
                    display: flex;
                    flex-direction: column;
                    height: 100vh;
                    padding: 20px;
                    box-sizing: border-box;
                }
                .chat-messages {
                    flex: 1;
                    overflow-y: auto;
                    margin-bottom: 20px;
                    border: 1px solid var(--vscode-input-border);
                    padding: 10px;
                    border-radius: 4px;
                    background-color: var(--vscode-editor-background);
                }
                .chat-input {
                    display: flex;
                    gap: 8px;
                }
                input {
                    flex: 1;
                    padding: 8px;
                    border-radius: 4px;
                    border: 1px solid var(--vscode-input-border);
                    background-color: var(--vscode-input-background);
                    color: var(--vscode-input-foreground);
                }
                button {
                    padding: 8px 16px;
                    border-radius: 4px;
                    border: 1px solid var(--vscode-button-border);
                    background-color: var(--vscode-button-background);
                    color: var(--vscode-button-foreground);
                    cursor: pointer;
                }
                button:hover {
                    background-color: var(--vscode-button-hoverBackground);
                }
                .message {
                    margin: 8px 0;
                    padding: 8px;
                    background: var(--vscode-input-background);
                    border-radius: 4px;
                    border: 1px solid var(--vscode-input-border);
                }
            </style>
        </head>
        <body>
            <div class="chat-container">
                <div class="chat-messages" id="chat-messages">
                    ${previousMessages.map(msg => `<div class="message">${msg}</div>`).join('')}
                </div>
                <div class="chat-input">
                    <input type="text" id="chat-input" placeholder="Type your message...">
                    <button id="send-button">Send</button>
                    <button id="clear-button">Clear</button>
                </div>
            </div>
            <script>
                const vscode = acquireVsCodeApi();
                const messages = ${JSON.stringify(previousMessages)};
                const chatInput = document.getElementById('chat-input');
                const sendButton = document.getElementById('send-button');
                const clearButton = document.getElementById('clear-button');
                const messagesContainer = document.getElementById('chat-messages');

                sendButton.addEventListener('click', () => {
                    const message = chatInput.value;
                    if (message) {
                        vscode.postMessage({
                            command: 'sendMessage',
                            text: message,
                            messages: [...messages, message]
                        });
                        // Додаємо повідомлення в чат
                        const messageElement = document.createElement('div');
                        messageElement.className = 'message';
                        messageElement.textContent = message;
                        messagesContainer.appendChild(messageElement);
                        chatInput.value = '';
                    }
                });

                clearButton.addEventListener('click', () => {
                    messagesContainer.innerHTML = '';
                    vscode.postMessage({
                        command: 'clearMessages'
                    });
                });
            </script>
        </body>
        </html>`;
}

export function deactivate() {}