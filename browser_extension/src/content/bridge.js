/**
 * @fileoverview Dashboard bridge content script (Phase 1 stub).
 * Injected only into the FocusEcho dashboard origin(s) declared in manifest.json.
 *
 * Full implementation in Phase 4. This stub:
 *   1. Registers the tab with the SW so it can be tracked as the dashboard tab.
 *   2. Relays window.postMessage from the dashboard → SW.
 *   3. Relays SW push events (SHOW_OVERLAY, SYNC_STATE) → dashboard via postMessage.
 *
 * PRIVACY: This script runs ONLY on the FocusEcho dashboard origin.
 *          It does NOT run on distraction sites.
 */

// Register this tab as the dashboard
chrome.runtime.sendMessage({ type: 'fe:register_dashboard' }, (response) => {
  if (chrome.runtime.lastError) return; // SW may be sleeping; it'll pick it up on next wake
  if (response?.connected) {
    window.postMessage({ source: 'focusecho-extension', type: 'connection', connected: true }, '*');
  }
});

// Dashboard → SW: relay configure / session events
window.addEventListener('message', (msg) => {
  if (msg.source !== window || msg.data?.source !== 'focusecho-web') return;
  // Phase 4: handle configure, session-start, etc.
});

// SW → Dashboard: relay push events
chrome.runtime.onMessage.addListener((message) => {
  if (message?.type?.startsWith('fe:')) {
    window.postMessage({ source: 'focusecho-extension', type: 'activity', event: message }, '*');
  }
});
