// Isolated-world bridge between the FocusEcho Flutter page and the extension.
// Page messages are deliberately narrow and never include page content.
window.addEventListener('message', (message) => {
  if (message.source !== window || message.data?.source !== 'focusecho-web') return;
  if (message.data.type === 'register') {
    chrome.runtime.sendMessage({ type: 'focusecho-register' }, (response) => {
      window.postMessage({ source: 'focusecho-extension', type: 'connection', connected: Boolean(response?.connected) }, '*');
    });
  }
  if (message.data.type === 'configure') {
    chrome.runtime.sendMessage({
      type: 'focusecho-config',
      active: Boolean(message.data.active),
      distractingSites: message.data.distractingSites || []
    });
  }
});

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === 'focusecho-browser-event') {
    window.postMessage({ source: 'focusecho-extension', type: 'activity', event: message.event }, '*');
  }
});
