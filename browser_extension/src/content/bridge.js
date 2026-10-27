/**
 * @fileoverview Complete Dashboard Bridge Content Script (EXT-4).
 * Injected on the FocusEcho Web Dashboard origin to enable seamless bidirectional
 * communication between the Web App and the Browser Extension.
 *
 * Responsibilities:
 *   1. Handshake with the Web App (connection status)
 *   2. Relays start_session, stop_session, configure, and credentials from Web App -> Service Worker
 *   3. Relays real-time distraction & recovery events from Service Worker -> Web App
 *   4. Stores Supabase auth tokens & project credentials in extension for cloud syncing
 */

// Register this tab as the active FocusEcho dashboard tab with the Service Worker
function registerDashboard() {
  // First get current session state from service worker
  chrome.runtime.sendMessage({ type: 'fe:debug_get_state' }, (stateResponse) => {
    if (chrome.runtime.lastError) return;
    const activeSession = stateResponse?.session?.active ? stateResponse.session : null;

    chrome.runtime.sendMessage({ type: 'fe:register_dashboard' }, (response) => {
      if (chrome.runtime.lastError) return;
      if (response?.connected) {
        // Send connection + current session state in one message
        window.postMessage({
          source: 'focusecho-extension',
          type: 'connection',
          connected: true,
          version: '2.0.0',
          activeSession: activeSession,  // null if no session running
        }, '*');
      }
    });
  });
}

registerDashboard();

// Listen for messages from the Web Dashboard (window.postMessage)
window.addEventListener('message', async (event) => {
  if (event.source !== window || event.origin !== window.location.origin ||
      !event.data || event.data.source !== 'focusecho-web') {
    return;
  }

  const data = event.data;
  const type = data.type;

  if (type === 'fe:parking_items') {
    chrome.runtime.sendMessage({
      type: 'fe:parking_set',
      items: Array.isArray(data.items) ? data.items : [],
    }).catch(() => {});
    return;
  }

  // Handshake registration request from Flutter Web
  if (type === 'register') {
    registerDashboard();
    window.postMessage(
      { source: 'focusecho-extension', type: 'registered', version: '2.0.0' },
      '*'
    );
    return;
  }

  // Session configuration from Flutter Web (BrowserMonitor.startSession / stopSession)
  if (type === 'configure') {
    if (data.active) {
      // Save cloud credentials if provided
      if (data.supabaseUrl || data.token || data.userId) {
        chrome.runtime.sendMessage({
          type: 'fe:save_credentials',
          supabaseUrl:     data.supabaseUrl,
          supabaseAnonKey: data.supabaseAnonKey,
          authToken:       data.token,
          userId:          data.userId,
          backendUrl:      data.backendUrl,
        }).catch(() => {});
      }

      // Start focus session in extension
      chrome.runtime.sendMessage({
        type: 'fe:start_session',
        session_id:       data.sessionId || crypto.randomUUID(),
        intention:        data.intention || 'Web Focus Session',
        distraction_list: data.distractingSites || [],
        user_id:          data.userId,
      }, (resp) => {
        window.postMessage({
          source: 'focusecho-extension',
          type: 'session_started',
          success: resp?.ok ?? true,
        }, '*');
      });
    } else {
      // End session in extension
      chrome.runtime.sendMessage({ type: 'fe:debug_stop_session' }, (resp) => {
        window.postMessage({
          source: 'focusecho-extension',
          type: 'session_stopped',
          success: resp?.ok ?? true,
        }, '*');
      });
    }
    return;
  }

  // Credentials sync request
  if (type === 'sync_credentials' || type === 'fe:save_credentials') {
    chrome.runtime.sendMessage({
      type: 'fe:save_credentials',
      supabaseUrl:     data.supabaseUrl,
      supabaseAnonKey: data.supabaseAnonKey,
      authToken:       data.authToken || data.token,
      userId:          data.userId,
      backendUrl:      data.backendUrl,
    }).catch(() => {});
    return;
  }

  // Get current extension state
  if (type === 'get_state') {
    chrome.runtime.sendMessage({ type: 'fe:debug_get_state' }, (response) => {
      window.postMessage({
        source: 'focusecho-extension',
        type: 'state',
        data: response,
      }, '*');
    });
  }
});

// Listen for push notifications from the Background Service Worker and relay to Web App
chrome.runtime.onMessage.addListener((message) => {
  if (!message || typeof message !== 'object') return;

  // Relay distraction and recovery events to the Web Dashboard
  if (message.type === 'fe:dashboard_activity') {
    window.postMessage({
      source: 'focusecho-extension',
      type: 'activity',
      event: {
        kind:             message.kind || 'away',
        host:             message.host || 'unknown',
        timestamp:        message.timestamp || new Date().toISOString(),
        escalation_level: message.escalation_level || 1,
        intention:        message.intention || '',
        category:         message.category || 'unknown',
      },
    }, '*');
  }

  // Relay overlay state
  if (message.type === 'fe:show_overlay' || message.type === 'fe:hide_overlay') {
    window.postMessage({
      source: 'focusecho-extension',
      type: message.type,
      level: message.level,
      intention: message.intention,
    }, '*');
  }

  // Relay session lifecycle state changes
  if (message.type === 'fe:session_started' || message.type === 'fe:session_stopped') {
    window.postMessage({
      source: 'focusecho-extension',
      type: message.type,
      session: message.session,
    }, '*');
  }
});
