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
import { mkDistractionEvent, mkRecoveryEvent, mkEmergencyExitEvent, mkAllowedSiteEvent } from '../shared/event-schema.js';
import { defaultConfig } from '../shared/storage-schema.js';
import { syncEventQueue, saveSyncCredentials } from './database-sync.js';
import { Logger } from '../shared/logger.js';

// ---------------------------------------------------------------------------
// Logging — structured, Python-style tracing with levels & timestamps
// ---------------------------------------------------------------------------
const LOG = {
  sm:    (msg, ...a) => Logger.debug('SM', msg, ...a),
  sw:    (msg, ...a) => Logger.info('SW', msg, ...a),
  d:     (msg, ...a) => Logger.debug('SW', msg, ...a),
  act:   (msg, ...a) => Logger.info('ACT', msg, ...a),
  warn:  (msg, ...a) => Logger.warn('SW', msg, ...a),
  err:   (msg, ...a) => Logger.error('SW', msg, ...a),
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

/**
 * The most recently committed host for the active tab.
 * Set SYNCHRONOUSLY when onCommitted / onHistoryStateUpdated fires so that
 * onUpdated (which arrives later) can validate against it without an async
 * chrome.tabs.get call — eliminating the race window that caused stale
 * intermediate-page events to slip through during rapid bounces.
 * @type {string|null}
 */
let _lastCommittedHost = null;
let _lastCommittedTabId = null;

function _setLastCommitted(tabId, host) {
  _lastCommittedTabId = tabId;
  _lastCommittedHost  = host;
}

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

async function saveSessionSites(hosts) {
  const config = await loadConfig();
  const existing = new Map((config.distraction_list || []).map(site => [
    normalizeHost(site.hostname), site,
  ]));
  config.distraction_list = hosts.map(host => {
    const hostname = normalizeHost(host);
    return existing.get(hostname) || { hostname, category: 'unknown', limit_minutes: 0 };
  }).filter(site => site.hostname);
  await chrome.storage.local.set({ [SK.CONFIG]: config });
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

/**
 * Sends an overlay message to the active tab.
 * If the content script isn't listening yet (page just loaded or content
 * script injection failed), we programmatically inject overlay.js + overlay.css
 * via chrome.scripting and then retry the message send after a short delay.
 */
async function sendToActiveDistractionTab(msg) {
  try {
    const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    if (!tab?.id) return;

    const tabId = tab.id;

    // Helper: try to send message; returns true if the content script replied.
    async function trySend() {
      try {
        const resp = await chrome.tabs.sendMessage(tabId, msg);
        return resp?.ok === true;
      } catch (_) {
        return false;
      }
    }

    // 1. Optimistic send — works when the CS is already running.
    const ok = await trySend();
    if (ok) return;

    // 2. Content script not ready — inject overlay.js + overlay.css now.
    LOG.sw(`CS not ready on tab ${tabId} — injecting overlay script programmatically`);
    try {
      await chrome.scripting.insertCSS({
        target: { tabId },
        files: ['src/content/overlay.css'],
      });
      await chrome.scripting.executeScript({
        target: { tabId },
        files: ['src/content/overlay.js'],
      });
    } catch (injErr) {
      LOG.warn(`scripting injection failed for tab ${tabId}: ${injErr?.message}`);
      return;
    }

    // 3. Give the injected script a moment to register its message listener, then retry.
    await new Promise(resolve => setTimeout(resolve, 150));
    await trySend();
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
        parked_items:         [],
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
      // Opt-in Strict Setting: Forced tab redirect is only performed if strict_focus_mode is enabled.
      // Default is FALSE to avoid involuntary tab hijacking unless explicitly enabled by the user.
      const storedConfig = (await chrome.storage.local.get(SK.CONFIG))?.[SK.CONFIG];
      const isStrict = Boolean(storedConfig?.strict_focus_mode ?? session?.strict_focus_mode ?? false);
      if (!isStrict) {
        LOG.act('NAVIGATE_BACK_TO_FOCUS skipped: strict_focus_mode is disabled (opt-in)');
        break;
      }

      const targetTabId = session?.last_productive_tab_id;
      const distractionList = session?.distraction_list ?? [];

      // Helper: try to activate a known tab id; returns true on success.
      async function tryActivate(tabId) {
        try {
          await chrome.tabs.update(tabId, { active: true });
          // Also bring its window to the foreground.
          const tab = await chrome.tabs.get(tabId);
          if (tab?.windowId) await chrome.windows.update(tab.windowId, { focused: true });
          return true;
        } catch (_) {
          return false;
        }
      }

      // 1. Try the stored productive tab first.
      if (targetTabId && await tryActivate(targetTabId)) {
        LOG.act(`switched to lastProductiveTab ${targetTabId}`);
        break;
      }

      // 2. Scan all tabs for a non-distracting one to switch to.
      try {
        const allTabs = await chrome.tabs.query({});
        const currentTab = (await chrome.tabs.query({ active: true, lastFocusedWindow: true }))[0];
        const productive = allTabs.find(t => {
          if (!t.url || !t.id) return false;
          if (t.id === currentTab?.id) return false; // skip current blocked tab
          try {
            const host = new URL(t.url).hostname.replace(/^www\./, '');
            return !isDistracting(host, distractionList);
          } catch (_) {
            return false;
          }
        });

        if (productive && await tryActivate(productive.id)) {
          LOG.act(`switched to non-distracting tab ${productive.id} (${productive.url})`);
          break;
        }
      } catch (e) {
        LOG.warn('tab scan failed:', e.message);
      }

      // 3. Last resort: open a new tab (all existing tabs are distracting or closed).
      await chrome.tabs.create({});
      LOG.act('all tabs distracting or no tabs — opened new tab');
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

    case 'ALLOW_SITE_FOR_SESSION': {
      if (!session) break;
      const host = normalizeHost(event.payload?.host || distraction?.host || '');
      if (!host) break;
      const list = Array.isArray(session.distraction_list) ? session.distraction_list : [];
      session.distraction_list = list.filter(site => !isDistracting(host, [site]));
      await saveSession(session);
      LOG.act(`allowed site for session | host: ${host}`);
      break;
    }

    case 'LOG_ALLOWED_SITE': {
      if (!session) break;
      const domain = normalizeHost(event.payload?.host || distraction?.host || '');
      if (!domain) break;
      const ev = mkAllowedSiteEvent({ domain, session_id: session.session_id });
      await enqueueEvent(ev);
      syncEventQueue(session).catch(() => {});
      LOG.act(`allowed_site event | host: ${domain}`);
      break;
    }

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

  // Guard against stale intermediate-page events during rapid bounces.
  // During a bounce (A→B→A within < 500 ms), Chrome queues onUpdated for the
  // intermediate host B. By the time it fires, we are already back on A.
  // _lastCommittedHost is set SYNCHRONOUSLY in onCommitted / onHistoryStateUpdated,
  // so this check has zero async race window — no chrome.tabs.get needed.
  if (isWebUrl(tab.url) && _lastCommittedTabId === tabId) {
    const eventHost = normalizeHost(tab.url);
    if (eventHost && _lastCommittedHost && eventHost !== _lastCommittedHost) {
      LOG.sw(`onUpdated stale-host skip: event=${eventHost}, last_committed=${_lastCommittedHost}`);
      return;
    }
  }

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

  // Set synchronously so onUpdated's stale-host guard is always up to date.
  const host = normalizeHost(url);
  _setLastCommitted(tabId, host);

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

  // Set synchronously so onUpdated's stale-host guard is always up to date.
  const host = normalizeHost(url);
  _setLastCommitted(tabId, host);

  const session = await loadSession();
  if (!session?.active) return;

  let isActiveTab = false;
  try {
    const [activeTab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    isActiveTab = activeTab?.id === tabId;
  } catch (_) {}
  if (!isActiveTab) return;

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

  if (type === 'fe:get_config') {
    const config = await loadConfig();
    return { ok: true, distraction_list: (config.distraction_list || [])
      .map(site => ({ hostname: normalizeHost(site.hostname), category: site.category || 'unknown' }))
      .filter(site => site.hostname) };
  }

  // --- Production & Web Bridge session start ---
  if (type === 'fe:start_session') {
    const { intention, distraction_list, session_id, user_id } = message;
    const currentSession = await loadSession();
    const wasActive = currentSession?.active;
    const sites = (distraction_list || []).map(h => normalizeHost(h)).filter(Boolean);
    await saveSessionSites(sites);
    await dispatch({
      type: EV.SESSION_STARTED,
      payload: {
        intention: intention || 'Focus Session',
        distraction_list: sites,
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

  if (type === 'fe:parking_set') {
    const session = await loadSession();
    if (!session?.active) return { ok: false, error: 'no active session' };
    const items = Array.isArray(message.items)
      ? message.items.filter(item => typeof item === 'string' && item.trim().length > 0)
          .map(item => item.trim().slice(0, 120)).slice(0, 20)
      : [];
    session.parked_items = items;
    await saveSession(session);
    return { ok: true, parked_items: items };
  }

  if (type === 'fe:parking_add' || type === 'fe:parking_remove') {
    const session = await loadSession();
    if (!session?.active) return { ok: false, error: 'no active session' };
    const current = Array.isArray(session.parked_items) ? session.parked_items : [];
    if (type === 'fe:parking_add') {
      const item = typeof message.item === 'string' ? message.item.trim().slice(0, 120) : '';
      if (item && current.length < 20 && !current.includes(item)) current.push(item);
    } else if (typeof message.item === 'string') {
      session.parked_items = current.filter(item => item !== message.item);
    }
    if (type === 'fe:parking_add') session.parked_items = current;
    await saveSession(session);
    return { ok: true, parked_items: session.parked_items };
  }

  if (type === 'fe:allow_site') {
    const session = await loadSession();
    if (!session?.active) return { ok: false, error: 'no active session' };
    const tabs = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    const host = normalizeHost(message.host || tabs[0]?.url || '');
    if (!host || !isDistracting(host, session.distraction_list || [])) {
      return { ok: false, error: 'active tab is not a listed distraction site' };
    }
    await dispatch({ type: EV.ALLOW_SITE_FOR_SESSION, payload: { host } });
    return { ok: true, host };
  }

  if (type === 'fe:get_allow_site_state') {
    const session = await loadSession();
    const tabs = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    const host = normalizeHost(tabs[0]?.url || '');
    return { ok: true, host, listed: Boolean(session?.active && host && isDistracting(host, session.distraction_list || [])) };
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
    const sites = (distraction_list || []).map(h => normalizeHost(h)).filter(Boolean);
    await saveSessionSites(sites);
    await dispatch({
      type: EV.SESSION_STARTED,
      payload: {
        intention,
        distraction_list: sites,
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
    const credentials = await chrome.storage.local.get(['fe_auth_token', 'fe_user_id']);
    return { ok: true, session, distraction, cloud_ready: Boolean(credentials.fe_auth_token && credentials.fe_user_id), recent_events: q.slice(-10).map(e => e.event) };
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

