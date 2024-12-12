(function() {
    const input = document.getElementById('chat-input');
    const sendButton = document.getElementById('send-button');
    const messagesContainer = document.getElementById('chat-messages');

    function addMessage(text, isUser = true) {
        const message = document.createElement('div');
        message.className = `message ${isUser ? 'message-user' : 'message-bot'}`;

        const content = document.createElement('div');
        content.textContent = text;

        const timestamp = document.createElement('div');
        timestamp.className = 'timestamp';
        timestamp.textContent = new Date().toLocaleTimeString();

        message.appendChild(content);
        message.appendChild(timestamp);

        messagesContainer.appendChild(message);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;

        if (!isUser) {
            message.style.opacity = '0';
            setTimeout(() => message.style.opacity = '1', 100);
        }
    }

    function handleSend() {
        const text = input.value.trim();
        if (text) {
            addMessage(text, true);
            input.value = '';

            // Імітація відповіді бота
            setTimeout(() => {
                addMessage('Received your message: ' + text, false);
            }, 1000);
        }
    }

    sendButton.addEventListener('click', handleSend);
    input.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            handleSend();
        }
    });
})();