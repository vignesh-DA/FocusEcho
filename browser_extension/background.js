// FocusEcho Browser Monitor. No browsing history is persisted or sent to a
// server; only live host-level activity is relayed to the active FocusEcho tab.
//
// Feature 2 — escalating intervention: a per-session relapse counter drives
// an `escalation_level` field on every distraction event (1 = heads-up,
// 2 = full-screen alert, 3 = forced choice). The counter resets when a new
// session is configured.
//
// Feature 3 — recovery: when focus returns to the FocusEcho tab after a
// logged distraction, a `return` event closes the open distraction so the
// web app can stamp recovered_at / recovery_time.
let focusEchoTabId = null;
let monitoring = { active: false, distractingSites: [] };
let relapseCount = 0;
let openDistraction = null;

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

function escalationLevelFor(count) {
  if (count <= 1) return 1;
  if (count <= 3) return 2;
  return 3;
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
      relapseCount += 1;
      const level = escalationLevelFor(relapseCount);
      const event = { kind: 'distraction', host, timestamp: new Date().toISOString(), escalation_level: level };
      openDistraction = event;
      sendToFocusEcho(event);
    } else {
      sendToFocusEcho({ kind: 'away', host, timestamp: new Date().toISOString() });
    }
  } catch (_) {}
}

function reportReturnToFocus() {
  if (!openDistraction) return;
  const event = {
    kind: 'return',
    host: openDistraction.host,
    timestamp: new Date().toISOString(),
    distraction_started_at: openDistraction.timestamp,
  };
  openDistraction = null;
  sendToFocusEcho(event);
}

chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (message?.type === 'focusecho-register' && sender.tab?.id !== undefined) {
    focusEchoTabId = sender.tab.id;
    respond({ connected: true, monitoring: monitoring.active });
    return;
  }
  if (message?.type === 'focusecho-config') {
    const wasActive = monitoring.active;
    monitoring = {
      active: Boolean(message.active),
      distractingSites: Array.isArray(message.distractingSites) ? message.distractingSites : []
    };
    // A newly started session resets the relapse ladder.
    if (monitoring.active && !wasActive) {
      relapseCount = 0;
      openDistraction = null;
    }
    if (!monitoring.active) {
      relapseCount = 0;
      openDistraction = null;
    }
    chrome.storage.local.set({ monitoring });
    respond({ configured: true });
  }
});

chrome.tabs.onActivated.addListener(({ tabId }) => {
  if (tabId === focusEchoTabId) {
    // Feature 3 — the user came back to the FocusEcho tab: close any open
    // distraction with a return timestamp.
    reportReturnToFocus();
    return;
  }
  reportTab(tabId);
});
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