/**
 * @fileoverview FocusEcho MV3 Service Worker — Phase 1
 *
 * Architecture:
 *   All Chrome API events → dispatch(event) → transition() → executeActions()
 *   State is ONLY in chrome.storage.session (auto-cleared on browser restart).
 *   Content scripts receive state via message pushing (no direct storage access).
 *
 * SW persistence strategy:
 *   MV3 SWs are ephemeral (terminated after ~30 s inactivity). We persist every
 *   state change to chrome.storage.session synchronously. On any wake-up we
 *   reconstruct in-memory context from storage. No derived values are stored —
 *   only raw timestamps, from which we recompute everything on wakeup.
 *
 * Dashboard origin assumed: https://focusecho-app.vercel.app
 *   Change via config.dashboard_origins. No wildcard on shared Vercel host.
 */

import { STATE, EV, SK, ALARM, IDLE_THRESHOLD_SEC, MSG, QUEUE_TTL_MS } from '../shared/constants.js';
import { transition, levelForCount, classifyRecovery } from './state-machine.js';
import { snapshotForPause, snapshotForResume } from './timing-engine.js';
import { ensureHeartbeat, clearHeartbeat } from './alarm-manager.js';
import { markTabActive, markTabInactive, removeTab } from './tab-tracker.js';
import { normalizeHost, isDistracting, isWebUrl } from '../shared/host-utils.js';
import { mkDistractionEvent, mkRecoveryEvent, mkEmergencyExitEvent } from '../shared/event-schema.js';
import { defaultConfig } from '../shared/storage-schema.js';
import { syncEventQueue, saveSyncCredentials } from './database-sync.js';

// ---------------------------------------------------------------------------
// Logging — structured, consistent prefix
// ---------------------------------------------------------------------------
const LOG = {
  sm:    (msg, ...a) => console.log(`[FE SM]  ${msg}`, ...a),
  sw:    (msg, ...a) => console.log(`[FE SW]  ${msg}`, ...a),
  act:   (msg, ...a) => console.log(`[FE ACT] ${msg}`, ...a),
  warn:  (msg, ...a) => console.warn(`[FE ⚠]  ${msg}`, ...a),
  err:   (msg, ...a) => console.error(`[FE ✖]  ${msg}`, ...a),
};

// ---------------------------------------------------------------------------
// Install / Activate
// ---------------------------------------------------------------------------
self.addEventListener('install', () => {
  LOG.sw('installed — skipping waiting');
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    await self.clients.claim();
    await ensureHeartbeat();
    // NOTE: We do NOT call chrome.storage.session.setAccessLevel here.
    // Content scripts receive state exclusively via message passing (SHOW_OVERLAY,
    // SYNC_STATE). Session storage remains SW-only, which is the more secure choice.
    LOG.sw('activated — reconstructing state from storage');
    await reconstructAndSync();
  })());
});

// ---------------------------------------------------------------------------
// Grace timer management (dedicated 3-second timer with timestamp catch-up)
// ---------------------------------------------------------------------------
let _graceTimer = null;

// ---------------------------------------------------------------------------
// Navigation deduplication (onUpdated + onCommitted both fire; drop duplicate)
// ---------------------------------------------------------------------------
/** @type {string|null} last dispatched nav key — cleared after 500 ms */
let _lastNavKey = null;
let _lastNavClearTimer = null;

function _deduplicateNav(tabId, host) {
  const key = `${tabId}|${host}`;
  if (_lastNavKey === key) return true; // duplicate — suppress
  _lastNavKey = key;
  if (_lastNavClearTimer) clearTimeout(_lastNavClearTimer);
  _lastNavClearTimer = setTimeout(() => { _lastNavKey = null; }, 500);
  return false;
}

function scheduleGraceTimer(delayMs = 3000) {
  clearGraceTimer();
  if (self._disableGraceTimer) {
    LOG.sw('grace timer suppressed by negative control flag');
    return;
  }
  _graceTimer = setTimeout(async () => {
    _graceTimer = null;
    const session = await loadSession();
    if (session?.active && session?.state === STATE.COUNTING_GRACE) {
      LOG.sw('3s grace timer fired -> dispatching GRACE_ELAPSED');
      await dispatch({ type: EV.GRACE_ELAPSED, payload: {} });
    }
  }, Math.max(0, delayMs));
  LOG.sw(`scheduled dedicated grace timer for ${delayMs}ms`);
}

function clearGraceTimer() {
  if (_graceTimer) {
    clearTimeout(_graceTimer);
    _graceTimer = null;
    LOG.sw('cleared active grace timer');
  }
}

// ---------------------------------------------------------------------------
// State reconstruction on SW wake-up
// ---------------------------------------------------------------------------
async function reconstructAndSync() {
  const session = await loadSession();
  if (!session?.active) {
    LOG.sw('no active session — staying IDLE');
    return;
  }
  LOG.sw(`state on wake: ${session.state} | count: ${session.distraction_count}`);
  if (session.state === STATE.COUNTING_GRACE) {
    const distraction = await loadDistraction();
    const now = Date.now();
    const elapsed = now - (distraction?.grace_entered_at ?? now);
    if (elapsed >= 3000) {
      LOG.sw(`grace catch-up on wake: elapsed ${elapsed}ms >= 3000ms -> dispatching GRACE_ELAPSED`);
      await dispatch({ type: EV.GRACE_ELAPSED, payload: {} });
    } else {
      scheduleGraceTimer(3000 - elapsed);
    }
  }
}

// ---------------------------------------------------------------------------
// Session / distraction storage helpers
// ---------------------------------------------------------------------------
/** @returns {Promise<import('../shared/storage-schema.js').SessionState|null>} */
async function loadSession() {
  const r = await chrome.storage.session.get(SK.SESSION);
  return r[SK.SESSION] ?? null;
}

async function saveSession(session) {
  await chrome.storage.session.set({ [SK.SESSION]: session });
}

/** @returns {Promise<import('../shared/storage-schema.js').CurrentDistraction|null>} */
async function loadDistraction() {
  const r = await chrome.storage.session.get(SK.CURRENT_DISTRACTION);
  return r[SK.CURRENT_DISTRACTION] ?? null;
}

async function saveDistraction(d) {
  await chrome.storage.session.set({ [SK.CURRENT_DISTRACTION]: d });
}

async function clearDistraction() {
  await chrome.storage.session.remove(SK.CURRENT_DISTRACTION);
}

/** @returns {Promise<import('../shared/storage-schema.js').ExtensionConfig>} */
async function loadConfig() {
  const r = await chrome.storage.local.get(SK.CONFIG);
  return r[SK.CONFIG] ?? defaultConfig();
}

// ---------------------------------------------------------------------------
// Offline event queue (purge on sync or 7-day TTL; NOT on session end)
// ---------------------------------------------------------------------------
async function enqueueEvent(feEvent) {
  const r = await chrome.storage.local.get(SK.EVENT_QUEUE);
  const queue = r[SK.EVENT_QUEUE] ?? [];
  queue.push({ event: feEvent, queued_at: Date.now() });
  // Prune stale entries (7-day TTL) while we're here
  const cutoff = Date.now() - QUEUE_TTL_MS;
  const pruned = queue.filter(e => e.queued_at >= cutoff);
  await chrome.storage.local.set({ [SK.EVENT_QUEUE]: pruned });
  LOG.act(`queued event: ${feEvent.event_type} | queue size: ${pruned.length}`);
}

// ---------------------------------------------------------------------------
// Core dispatch — the single entry point for all SM events
// ---------------------------------------------------------------------------
/** @type {Promise<void>|null} internal serialisation lock */
let _dispatchLock = null;

/**
 * Dispatch an event to the state machine, persist the new state, execute actions.
 * Serialised to prevent concurrent state mutations from async Chrome events.
 *
 * @param {{ type: string, payload?: any }} event
 */
async function dispatch(event) {
  // Serialise: wait for any in-flight dispatch to finish before starting.
  const prev = _dispatchLock ?? Promise.resolve();
  let resolveCurrent;
  _dispatchLock = new Promise(r => { resolveCurrent = r; });
  try {
    await prev;
    await _dispatchInner(event);
  } finally {
    resolveCurrent();
  }
}

async function _dispatchInner(event) {
  const session = await loadSession();
  if (!session?.active && event.type !== EV.SESSION_STARTED) return;

  const distraction = await loadDistraction();
  const currentState = session?.state ?? STATE.IDLE;

  // Build context for the pure transition function
  const ctx = {
    distractionCount:     session?.distraction_count ?? 0,
    graceEnteredAt:       distraction?.grace_entered_at ?? null,
    distractionStartedAt: distraction?.started_at ?? null,
    postExpiryAt:         distraction?.post_expiry_at ?? null,
    resumeToState:        session?.resume_to_state ?? null,
    graceConfirmed:       distraction?.grace_confirmed ?? false,
  };

  const now = Date.now();
  const { nextState, actions } = transition(currentState, event, ctx, now);

  if (nextState !== currentState || actions.length > 0) {
    LOG.sm(
      `${currentState} --[${event.type}${event.payload?.host ? ':' + event.payload.host : ''}]--> ${nextState}` +
      (actions.length ? ` | actions: [${actions.join(', ')}]` : '')
    );
  }

  // Persist new state
  if (session && nextState !== currentState) {
    session.state = nextState;
    await saveSession(session);
  }

  // Execute side effects
  await executeActions(actions, { session, distraction, event, now });

  // Back from PAUSED (window refocus / idle ended) into the 3 s grace window:
  // the user is on the site again right now, so give a fresh 3 s grace and re-arm the timer.
  // (Before this, the timer had already fired while paused and was ignored, so the
  //  session sat in COUNTING_GRACE until the 60 s heartbeat.)
  if (currentState === STATE.PAUSED && nextState === STATE.COUNTING_GRACE) {
    const d = await loadDistraction();
    if (d) { d.grace_entered_at = now; await saveDistraction(d); }
    scheduleGraceTimer(3000);
  }
}

// ---------------------------------------------------------------------------
// Realtime Messaging & Overlay Communication Helpers
// ---------------------------------------------------------------------------
async function sendToActiveDistractionTab(msg) {
  try {
    const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    if (tab?.id) {
      await chrome.tabs.sendMessage(tab.id, msg).catch(() => {});
    }
  } catch (err) {
    LOG.err('sendToActiveDistractionTab error:', err?.message);
  }
}

async function notifyDashboard(msg) {
  try {
    const r = await chrome.storage.local.get(SK.DASHBOARD_TAB_ID);
    const tabId = r[SK.DASHBOARD_TAB_ID];
    if (tabId !== undefined) {
      await chrome.tabs.sendMessage(tabId, msg).catch(() => {});
    }
  } catch (_) {}
}

// ---------------------------------------------------------------------------
// Action executor
// ---------------------------------------------------------------------------
async function executeActions(actions, { session, distraction, event, now }) {
  for (const action of actions) {
    const [name, param] = action.split(':');
    try {
      await _executeAction(name, param, { session, distraction, event, now });
    } catch (e) {
      LOG.err(`action "${action}" threw:`, e);
    }
  }
}

async function _executeAction(name, param, { session, distraction, event, now }) {
  switch (name) {

    case 'RESET_SESSION': {
      const { payload } = event; // SESSION_STARTED payload
      clearGraceTimer();
      const newSession = {
        active:               true,
        mode:                 payload.mode ?? 'focus',
        session_id:           payload.session_id,
        intention:            payload.intention,
        started_at:           now,
        distraction_list:     payload.distraction_list,
        distraction_count:    0,
        state:                STATE.MONITORING,
        resume_to_state:      null,
        last_productive_tab_id: null,
      };
      await saveSession(newSession);
      await clearDistraction();
      LOG.act(`session started | intention: "${payload.intention}" | sites: [${payload.distraction_list.join(', ')}]`);
      await notifyDashboard({ type: 'fe:session_started', session: newSession });
      break;
    }

    case 'START_HEARTBEAT':
      await ensureHeartbeat();
      break;

    case 'RECORD_GRACE_ENTRY': {
      const host = event.payload?.host ?? '';
      const config = await loadConfig();
      const siteConf = config.distraction_list.find(s => normalizeHost(s.hostname) === host);
      const d = {
        host,
        category:        siteConf?.category ?? 'unknown',
        grace_entered_at: now,
        started_at:      null,   // set when grace is confirmed
        grace_confirmed: false,
        post_expiry_at:  null,
        active_ms:       0,
        paused_at:       null,
        level:           0,
      };
      await saveDistraction(d);
      scheduleGraceTimer(3000);
      LOG.act(`grace entry recorded for ${host} at ${new Date(now).toISOString()}`);
      break;
    }

    case 'INCREMENT_DISTRACTION_COUNT': {
      session.distraction_count += 1;
      await saveSession(session);
      LOG.act(`distractionCount → ${session.distraction_count}`);
      break;
    }

    case 'CONFIRM_GRACE': {
      clearGraceTimer();
      if (distraction) {
        distraction.grace_confirmed = true;
        // Anchor started_at to grace_entered_at (first arrival), NOT to now
        // (grace-elapsed moment). This matches the Android app which counts
        // distraction time from first detection, so time_on_site_ms always
        // includes the full 3 s grace period and any time spent before grace
        // confirmation. Rule: time_on_site_ms = leave_time − grace_entered_at.
        distraction.started_at = distraction.grace_entered_at ?? now;
        await saveDistraction(distraction);
        LOG.act(`grace confirmed for ${distraction.host} | active since ${new Date(distraction.started_at).toISOString()}`);
      }
      break;
    }

    case 'EMIT_DISTRACTION_EVENT': {
      const level = parseInt(param, 10);
      if (!session || !distraction) break;
      const ev = mkDistractionEvent({
        domain:           distraction.host,
        category:         distraction.category,
        escalation_level: level,
        session_id:       session.session_id,
        distraction_count: session.distraction_count,
      });
      await enqueueEvent(ev);
      // Update distraction level
      distraction.level = level;
      await saveDistraction(distraction);
      LOG.act(`distraction event | host: ${distraction.host} | level: ${level} | count: ${session.distraction_count}`);

      // Sync directly to Supabase cloud database & FastAPI backend (fire-and-forget)
      syncEventQueue(session).catch(e => LOG.err('cloud db sync error:', e.message));

      // Realtime notification to registered Web Dashboard tab
      notifyDashboard({
        type: 'fe:dashboard_activity',
        kind: 'away',
        host: distraction.host,
        timestamp: ev.timestamp,
        escalation_level: level,
        intention: session.intention,
        category: distraction.category,
      });
      break;
    }

    case 'EMIT_RECOVERY_EVENT': {
      const classification = param; // 'ignored' | 'intentional_switch' | 'recovery'
      if (!session || !distraction || classification === 'ignored') {
        if (classification === 'ignored') LOG.act('recovery: ignored (< 3 s)');
        break;
      }
      const leaveTime = now;
      const startedAt = distraction.started_at ?? distraction.grace_entered_at ?? now;
      const timeOnSiteMs = leaveTime - startedAt;
      const ev = mkRecoveryEvent({
        event_type:             classification,
        domain:                 distraction.host,
        time_on_site_ms:        timeOnSiteMs,
        distraction_started_at: startedAt,
        session_id:             session.session_id,
        from_level:             distraction.level || 0,
      });
      await enqueueEvent(ev);
      LOG.act(`recovery event: ${classification} | time_on_site: ${timeOnSiteMs} ms`);

      // Sync recovery event to Supabase cloud database & FastAPI backend
      syncEventQueue(session).catch(e => LOG.err('cloud db sync error:', e.message));

      // Realtime notification to registered Web Dashboard tab
      notifyDashboard({
        type: 'fe:dashboard_activity',
        kind: 'return',
        host: distraction.host,
        timestamp: ev.timestamp,
        escalation_level: distraction.level || 1,
        intention: session.intention,
      });
      break;
    }

    case 'LOG_GRACE_IGNORED':
      LOG.act(`grace ignored: visit < 3 000 ms | no count, no overlay`);
      break;

    case 'CLEAR_DISTRACTION':
      clearGraceTimer();
      await clearDistraction();
      if (session) {
        session.resume_to_state = null;
        await saveSession(session);
      }
      break;

    case 'UPDATE_LAST_PRODUCTIVE_TAB': {
      const tabId = event.payload?.tabId ?? null;
      if (tabId && session) {
        session.last_productive_tab_id = tabId;
        await saveSession(session);
        LOG.act(`lastProductiveTab → ${tabId}`);
      }
      break;
    }

    case 'UPDATE_LAST_PRODUCTIVE_TAB_CLEAR':
      // Entering distraction site — do not update lastProductiveTab
      break;

    case 'NAVIGATE_BACK_TO_FOCUS': {
      const targetTabId = session?.last_productive_tab_id;
      if (targetTabId) {
        try {
          await chrome.tabs.update(targetTabId, { active: true });
          LOG.act(`navigated back to tab ${targetTabId}`);
        } catch (_) {
          // Tab was closed — open new tab
          await chrome.tabs.create({});
          LOG.act('lastProductiveTab closed — opened new tab');
        }
      } else {
        await chrome.tabs.create({});
        LOG.act('no lastProductiveTab — opened new tab');
      }
      break;
    }

    case 'SHOW_OVERLAY': {
      const level = parseInt(param, 10);
      LOG.act(`▶ SHOW_OVERLAY level ${level} | intention: "${session?.intention}"`);
      await sendToActiveDistractionTab({
        type: MSG.SHOW_OVERLAY,
        level,
        intention: session?.intention || 'Focus Session',
      });
      await notifyDashboard({
        type: MSG.SHOW_OVERLAY,
        level,
        intention: session?.intention || 'Focus Session',
      });
      break;
    }

    case 'HIDE_OVERLAY':
      LOG.act('▼ HIDE_OVERLAY');
      await sendToActiveDistractionTab({ type: MSG.HIDE_OVERLAY });
      await notifyDashboard({ type: MSG.HIDE_OVERLAY });
      break;

    case 'SET_RESUME_TO': {
      session.resume_to_state = param;
      await saveSession(session);
      break;
    }

    case 'PAUSE_TIMER': {
      if (distraction && distraction.paused_at === null) {
        const snap = snapshotForPause(distraction, now);
        distraction.paused_at  = snap.paused_at;
        distraction.active_ms  = snap.active_ms;
        await saveDistraction(distraction);
        LOG.act(`timer paused | accumulated: ${distraction.active_ms} ms`);
      }
      break;
    }

    case 'RESUME_TIMER': {
      if (distraction && distraction.paused_at !== null) {
        const snap = snapshotForResume(now);
        distraction.started_at = snap.started_at;
        distraction.paused_at  = snap.paused_at;
        await saveDistraction(distraction);
        LOG.act(`timer resumed`);
      }
      break;
    }

    case 'SET_POST_EXPIRY_MARKER': {
      if (distraction) {
        distraction.post_expiry_at = now;
        await saveDistraction(distraction);
        LOG.act(`post-expiry marker set — new distraction in 60 s if still on site`);
      }
      break;
    }

    case 'CLEAR_POST_EXPIRY': {
      if (distraction) {
        distraction.post_expiry_at = null;
        await saveDistraction(distraction);
      }
      break;
    }

    case 'LOG_COUNTDOWN_EXPIRED':
      LOG.act(`L2 countdown expired | overlay dismissed | user still on site`);
      break;

    case 'LOG_EMERGENCY_EXIT': {
      if (!session || !distraction) break;
      const ev = mkEmergencyExitEvent({
        domain:     distraction.host,
        from_level: distraction.level,
        session_id: session.session_id,
      });
      await enqueueEvent(ev);
      LOG.act(`⚠ EMERGENCY EXIT | from level ${distraction.level}`);
      syncEventQueue(session).catch(e => LOG.err('cloud sync error:', e.message));
      break;
    }

    case 'LOG_SESSION_ENDED':
      LOG.act(`session ended | total distractions: ${session?.distraction_count ?? 0}`);
      break;

    case 'CLEAR_SESSION': {
      clearGraceTimer();
      if (session) {
        session.active = false;
        session.ended_at = now;
        syncEventQueue(session).catch(e => LOG.err('cloud sync error on end:', e.message));
        notifyDashboard({ type: 'fe:session_stopped', session }).catch(() => {});
      }
      await chrome.storage.session.remove([SK.SESSION, SK.CURRENT_DISTRACTION]);
      LOG.act('session state cleared from storage');
      break;
    }

    case 'LOG_SESSION_PAUSED':
      LOG.act('session paused by user');
      break;

    case 'LOG_SESSION_RESUMED':
      LOG.act('session resumed');
      break;

    case 'LOG_PAUSED':
      LOG.act(`timer paused (event: ${name})`);
      break;

    case 'LOG_RESUMED':
      LOG.act('timer resumed');
      break;

    default:
      LOG.warn(`unknown action: "${name}"`);
  }
}

// ---------------------------------------------------------------------------
// chrome.tabs events
// ---------------------------------------------------------------------------
/**
 * Classify a tab URL.
 *  web     - http(s) page, hostname is evaluated against the distraction list
 *  own     - one of this extension's own pages (debug/options). Ignored so that
 *            reading the debug page never changes the session being observed.
 *  other   - New Tab page, chrome://, about:, file:// ... Counts as "not on a
 *            distraction site", so it ends a distraction visit.
 *  unknown - URL not available yet (tab still loading). Ignored; onUpdated
 *            fires again when the real URL is committed.
 * Hostname only: path, query and hash are never read beyond this point.
 */
function describeTab(url) {
  if (!url) return { kind: 'unknown', host: '' };
  if (isWebUrl(url)) return { kind: 'web', host: normalizeHost(url) };
  if (url.startsWith(chrome.runtime.getURL(''))) return { kind: 'own', host: '' };
  return { kind: 'other', host: '' };
}

/** Evaluate the tab the user is on right now (used when a session starts). */
async function scanActiveTab() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    if (!tab) return;
    const session = await loadSession();
    if (!session?.active) return;
    const info = describeTab(tab.url);
    if (info.kind !== 'web') return;
    const distracting = isDistracting(info.host, session.distraction_list);
    await markTabActive(tab.id, info.host, distracting);
    await dispatch({
      type: EV.TAB_ACTIVATED,
      payload: { tabId: tab.id, host: info.host, isDistracting: distracting, windowId: tab.windowId },
    });
  } catch (e) {
    LOG.err('scanActiveTab:', e.message);
  }
}

chrome.tabs.onActivated.addListener(async ({ tabId, windowId }) => {
  try {
    const tab = await chrome.tabs.get(tabId);
    const session = await loadSession();
    if (!session?.active) return;

    const info = describeTab(tab.url);
    if (info.kind === 'unknown' || info.kind === 'own') return;

    if (info.kind === 'other') {
      // New Tab page / chrome:// / about: -> the user left whatever site they were on.
      // tabId is null so this page is never remembered as the "productive tab" to return to.
      await dispatch({
        type: EV.TAB_ACTIVATED,
        payload: { tabId: null, host: '', isDistracting: false, windowId },
      });
      return;
    }

    const distracting = isDistracting(info.host, session.distraction_list);
    await markTabActive(tabId, info.host, distracting);
    await dispatch({
      type: EV.TAB_ACTIVATED,
      payload: { tabId, host: info.host, isDistracting: distracting, windowId },
    });
  } catch (e) {
    LOG.err('onActivated:', e.message);
  }
});

chrome.tabs.onRemoved.addListener(async (tabId) => {
  await removeTab(tabId);
});

chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  // Only care about URL changes on the active tab; SPA navigation is handled
  // via webNavigation.onHistoryStateUpdated which is more reliable.
  if (changeInfo.status !== 'complete' || !tab.active) return;
  const info = describeTab(tab.url);
  if (info.kind === 'unknown' || info.kind === 'own') return;
  const host = info.host;
  // Dedup: onCommitted fires ~simultaneously for the same navigation.
  if (_deduplicateNav(tabId, host)) { LOG.sw(`onUpdated dedup skip for ${host || info.kind}`); return; }
  const session = await loadSession();
  if (!session?.active) return;
  if (info.kind === 'other') {
    // Active tab navigated to the New Tab page / chrome:// -> left the site.
    await dispatch({
      type: EV.TAB_NAVIGATED,
      payload: { tabId: null, host: '', isDistracting: false },
    });
    return;
  }
  const distracting = isDistracting(host, session.distraction_list);
  await markTabActive(tabId, host, distracting);
  await dispatch({
    type: EV.TAB_NAVIGATED,
    payload: { tabId, host, isDistracting: distracting },
  });
});

// ---------------------------------------------------------------------------
// webNavigation — primary SPA signal (onHistoryStateUpdated)
// ---------------------------------------------------------------------------
chrome.webNavigation.onHistoryStateUpdated.addListener(async ({ tabId, frameId, url }) => {
  if (frameId !== 0) return; // main frame only
  if (!isWebUrl(url)) return;

  const session = await loadSession();
  if (!session?.active) return;

  // Check if this is the currently active tab
  let isActiveTab = false;
  try {
    const [activeTab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    isActiveTab = activeTab?.id === tabId;
  } catch (_) {}
  if (!isActiveTab) return;

  // Hostname only — path discarded
  const host = normalizeHost(url);
  const distracting = isDistracting(host, session.distraction_list);
  await markTabActive(tabId, host, distracting);

  await dispatch({
    type: EV.URL_CHANGED,
    payload: { tabId, host, isDistracting: distracting },
  });
});

// webNavigation.onCommitted — non-SPA main-frame navigation
chrome.webNavigation.onCommitted.addListener(async ({ tabId, frameId, url, transitionType }) => {
  if (frameId !== 0) return;
  if (!isWebUrl(url)) return;
  // Skip SPA navigations — handled by onHistoryStateUpdated
  if (transitionType === 'auto_subframe' || transitionType === 'manual_subframe') return;

  const session = await loadSession();
  if (!session?.active) return;

  let isActiveTab = false;
  try {
    const [activeTab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    isActiveTab = activeTab?.id === tabId;
  } catch (_) {}
  if (!isActiveTab) return;

  const host = normalizeHost(url);
  // Dedup: onUpdated fires ~simultaneously for the same navigation.
  if (_deduplicateNav(tabId, host)) { LOG.sw(`onCommitted dedup skip for ${host}`); return; }
  const distracting = isDistracting(host, session.distraction_list);

  await dispatch({
    type: EV.TAB_NAVIGATED,
    payload: { tabId, host, isDistracting: distracting },
  });
});

// ---------------------------------------------------------------------------
// Window focus
// ---------------------------------------------------------------------------
chrome.windows.onFocusChanged.addListener(async (windowId) => {
  if (windowId === chrome.windows.WINDOW_ID_NONE) {
    await dispatch({ type: EV.WINDOW_BLURRED });
  } else {
    await dispatch({ type: EV.WINDOW_FOCUSED, payload: { windowId } });
  }
});

// ---------------------------------------------------------------------------
// System idle
// ---------------------------------------------------------------------------
chrome.idle.setDetectionInterval(IDLE_THRESHOLD_SEC);
chrome.idle.onStateChanged.addListener(async (idleState) => {
  if (idleState === 'idle' || idleState === 'locked') {
    await dispatch({ type: EV.IDLE_DETECTED });
  } else if (idleState === 'active') {
    await dispatch({ type: EV.IDLE_ENDED });
  }
});

// ---------------------------------------------------------------------------
// Alarms
// ---------------------------------------------------------------------------
chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === ALARM.HEARTBEAT) {
    LOG.sw('heartbeat ♥');
    const session = await loadSession();
    // Flush queued events to cloud database on heartbeat
    syncEventQueue(session).catch(() => {});
    await dispatch({ type: EV.HEARTBEAT });
  }
});

// ---------------------------------------------------------------------------
// Messages from popup / options / content scripts
// ---------------------------------------------------------------------------
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  _handleMessage(message, sender).then(sendResponse).catch(e => {
    LOG.err('message handler:', e);
    sendResponse({ ok: false, error: e.message });
  });
  return true; // keep channel open for async response
});

async function _handleMessage(message, sender) {
  const { type } = message;

  // --- Production & Web Bridge session start ---
  if (type === 'fe:start_session') {
    const { intention, distraction_list, session_id, user_id } = message;
    const currentSession = await loadSession();
    const wasActive = currentSession?.active;
    await dispatch({
      type: EV.SESSION_STARTED,
      payload: {
        intention: intention || 'Focus Session',
        distraction_list: (distraction_list || []).map(h => normalizeHost(h)).filter(Boolean),
        mode: 'focus',
        session_id: session_id || crypto.randomUUID(),
        user_id,
      },
    });
    await scanActiveTab();
    return { ok: true, restarted: !!wasActive };
  }

  // --- Cloud credentials sync from Web dashboard ---
  if (type === 'fe:save_credentials') {
    await saveSyncCredentials(message);
    const session = await loadSession();
    if (session?.active) {
      await syncEventQueue(session);
    }
    return { ok: true, saved: true };
  }

  // --- Manual cloud sync trigger ---
  if (type === 'fe:sync_now') {
    const session = await loadSession();
    const res = await syncEventQueue(session);
    return { ok: true, ...res };
  }

  // --- Debug / options page actions ---
  if (type === 'fe:debug_start_session') {
    const { intention, distraction_list } = message;
    const currentSession = await loadSession();
    const wasActive = currentSession?.active;
    await dispatch({
      type: EV.SESSION_STARTED,
      payload: {
        intention,
        distraction_list: distraction_list.map(h => normalizeHost(h)).filter(Boolean),
        mode: 'focus',
        session_id: crypto.randomUUID(),
      },
    });
    // The user may already be on a distraction site when they press Start.
    await scanActiveTab();
    return { ok: true, restarted: !!wasActive };
  }

  if (type === 'fe:debug_stop_session') {
    await dispatch({ type: EV.USER_END_SESSION });
    return { ok: true };
  }

  if (type === 'fe:debug_get_state') {
    const session    = await loadSession();
    const distraction = await loadDistraction();
    const q = (await chrome.storage.local.get(SK.EVENT_QUEUE))[SK.EVENT_QUEUE] ?? [];
    return { ok: true, session, distraction, recent_events: q.slice(-10).map(e => e.event) };
  }

  if (type === 'fe:debug_dispatch') {
    await dispatch({ type: message.ev_type, payload: message.payload ?? {} });
    return { ok: true };
  }

  // --- Content script events ---
  if (type === MSG.CS_EV) {
    await dispatch({ type: message.ev_type, payload: message.payload });
    return { ok: true };
  }

  // --- Dashboard bridge registration ---
  if (type === 'fe:register_dashboard') {
    const tabId = sender.tab?.id;
    if (tabId !== undefined) {
      await chrome.storage.local.set({ [SK.DASHBOARD_TAB_ID]: tabId });
      LOG.sw(`dashboard registered | tabId: ${tabId}`);
      return { ok: true, connected: true };
    }
  }

  return { ok: false, error: 'unknown message type' };
}

// ---------------------------------------------------------------------------
// Test & Debug Exposure
// ---------------------------------------------------------------------------
self.__fe = {
  dispatch,
  loadSession,
  loadDistraction,
  reconstructAndSync,
  handleMessage: _handleMessage,
};

