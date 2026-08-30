// FocusEcho Browser Monitor. No browsing history is persisted or sent to a
// server; only live host-level activity is relayed to the active FocusEcho tab.
let focusEchoTabId = null;
let monitoring = { active: false, distractingSites: [] };

function normalizeHost(value) {
  return String(value || '').trim().toLowerCase().replace(/^https?:\/\//, '').replace(/^www\./, '').split('/')[0];
}

function isDistracting(url) {
  try {
    const host = normalizeHost(new URL(url).hostname);
    return monitoring.distractingSites.some((site) => {
      const target = normalizeHost(site);
      return target && (host === target || host.endsWith(`.${target}`));
    });
  } catch (_) {
    return false;
  }
}

function sendToFocusEcho(event) {
  if (focusEchoTabId === null) return;
  chrome.tabs.sendMessage(focusEchoTabId, { type: 'focusecho-browser-event', event }, () => {
    // A closed/reloaded app tab is normal; stop targeting it until it registers again.
    if (chrome.runtime.lastError) focusEchoTabId = null;
  });
}

async function reportTab(tabId) {
  if (!monitoring.active || tabId === focusEchoTabId) return;
  try {
    const tab = await chrome.tabs.get(tabId);
    if (!tab.url || !/^https?:/.test(tab.url)) return;
    const host = normalizeHost(new URL(tab.url).hostname);
    if (isDistracting(tab.url)) {
      sendToFocusEcho({ kind: 'distraction', host, timestamp: new Date().toISOString() });
    } else {
      sendToFocusEcho({ kind: 'away', host, timestamp: new Date().toISOString() });
    }
  } catch (_) {}
}

chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (message?.type === 'focusecho-register' && sender.tab?.id !== undefined) {
    focusEchoTabId = sender.tab.id;
    respond({ connected: true, monitoring: monitoring.active });
    return;
  }
  if (message?.type === 'focusecho-config') {
    monitoring = {
      active: Boolean(message.active),
      distractingSites: Array.isArray(message.distractingSites) ? message.distractingSites : []
    };
    chrome.storage.local.set({ monitoring });
    respond({ configured: true });
  }
});

chrome.tabs.onActivated.addListener(({ tabId }) => reportTab(tabId));
chrome.webNavigation.onCommitted.addListener(({ tabId, frameId, url }) => {
  if (frameId === 0 && monitoring.active && isDistracting(url)) reportTab(tabId);
});
chrome.windows.onFocusChanged.addListener((windowId) => {
  if (windowId === chrome.windows.WINDOW_ID_NONE && monitoring.active) {
    sendToFocusEcho({ kind: 'away', host: 'outside-browser', timestamp: new Date().toISOString() });
  }
});

chrome.storage.local.get('monitoring', ({ monitoring: stored }) => {
  if (stored) monitoring = stored;
});
