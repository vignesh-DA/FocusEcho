/**
 * @fileoverview Shared constants for the FocusEcho extension.
 * Used by the service worker (ES module). Content scripts receive state
 * via message passing — they do NOT import this file directly.
 * No Chrome API calls. Pure data.
 */

// ---------------------------------------------------------------------------
// State machine states
// ---------------------------------------------------------------------------
export const STATE = /** @type {const} */ ({
  IDLE:            'IDLE',
  MONITORING:      'MONITORING',
  /**
   * User just entered a distraction site. Grace period: no count increment,
   * no overlay until ≥ 3 000 ms have elapsed on the site (computed from
   * timestamps on the next event or via content-script GRACE_ELAPSED message
   * in Phase 2). Visits < 3 s exit directly to MONITORING with no event.
   */
  COUNTING_GRACE:  'COUNTING_GRACE',
  /**
   * Grace period passed. distractionCount already incremented. Overlay was
   * shown (L1/L2/L3). This state is the "between overlays" base state while
   * the user remains on the distraction site (e.g. after L2 countdown expiry).
   */
  COUNTING:        'COUNTING',
  /**
   * Timer paused (window blur, tab hidden, system idle).
   * session.resumeToState holds the state to restore.
   */
  PAUSED:          'PAUSED',
  L1_TOAST:        'L1_TOAST',
  L2_OVERLAY:      'L2_OVERLAY',
  L3_FORCED:       'L3_FORCED',
  SESSION_PAUSED:  'SESSION_PAUSED',
});

// ---------------------------------------------------------------------------
// State machine input event types
// ---------------------------------------------------------------------------
export const EV = /** @type {const} */ ({
  // Chrome-originated (service worker)
  TAB_ACTIVATED:      'TAB_ACTIVATED',
  TAB_NAVIGATED:      'TAB_NAVIGATED',       // webNavigation.onCommitted (main frame, non-SPA)
  URL_CHANGED:        'URL_CHANGED',          // webNavigation.onHistoryStateUpdated (SPA primary)
  WINDOW_FOCUSED:     'WINDOW_FOCUSED',
  WINDOW_BLURRED:     'WINDOW_BLURRED',
  IDLE_DETECTED:      'IDLE_DETECTED',
  IDLE_ENDED:         'IDLE_ENDED',
  HEARTBEAT:          'HEARTBEAT',            // alarm: fe-heartbeat (60 s)

  // Content-script-originated (via chrome.runtime.sendMessage → fe:cs_ev)
  VISIBILITY_HIDDEN:   'VISIBILITY_HIDDEN',
  VISIBILITY_VISIBLE:  'VISIBILITY_VISIBLE',
  GRACE_ELAPSED:       'GRACE_ELAPSED',       // Phase 2: CS timer fired after 3 s on site
  COUNTDOWN_EXPIRED:   'COUNTDOWN_EXPIRED',   // L2 countdown finished in content script

  // User actions
  USER_BACK_TO_FOCUS:   'USER_BACK_TO_FOCUS',
  USER_PAUSE_SESSION:   'USER_PAUSE_SESSION',
  USER_RESUME_SESSION:  'USER_RESUME_SESSION',
  USER_END_SESSION:     'USER_END_SESSION',
  USER_EMERGENCY_HOLD:  'USER_EMERGENCY_HOLD',
  USER_DRIFT_BUTTON:    'USER_DRIFT_BUTTON',
  ALLOW_SITE_FOR_SESSION: 'ALLOW_SITE_FOR_SESSION',
  SESSION_STARTED:      'SESSION_STARTED',
});

// ---------------------------------------------------------------------------
// SW → Content script message types
// ---------------------------------------------------------------------------
export const MSG = /** @type {const} */ ({
  SHOW_OVERLAY:   'fe:show_overlay',
  HIDE_OVERLAY:   'fe:hide_overlay',
  SYNC_STATE:     'fe:sync_state',

  // Content script → SW
  CS_READY:       'fe:cs_ready',
  CS_EV:          'fe:cs_ev',
});

// ---------------------------------------------------------------------------
// Alarm names  (no sub-30 s alarms)
// ---------------------------------------------------------------------------
export const ALARM = /** @type {const} */ ({
  HEARTBEAT:             'fe-heartbeat',
  HEARTBEAT_PERIOD_MIN:  1,
});

// ---------------------------------------------------------------------------
// Escalation
// ---------------------------------------------------------------------------
export const ESC = /** @type {const} */ ({
  /** distractionCount values that select each level */
  L1_AT:   1,
  L2_MIN:  2,
  L2_MAX:  3,
  L3_MIN:  4,

  /** Default L2 countdown (ms). Content script owns the visual timer. */
  COUNTDOWN_MS:  15_000,

  /** Hold-to-escape duration (ms) */
  EMERGENCY_HOLD_MS:  2_000,

  /**
   * After L2 countdown expiry, if the user is still on the distraction site
   * this many ms later, treat it as a fresh distraction (count +1, next level).
   */
  POST_EXPIRY_NEW_DISTRACTION_MS:  60_000,
});

// ---------------------------------------------------------------------------
// Entry grace period
// ---------------------------------------------------------------------------
export const GRACE = /** @type {const} */ ({
  /** Minimum ms on distraction site before count increments and overlay shows. */
  THRESHOLD_MS: 3_000,
});

// ---------------------------------------------------------------------------
// Recovery classification thresholds (wall-clock: leave_time − distractionStartedAt)
// ---------------------------------------------------------------------------
export const RECOVERY_ZONES = /** @type {const} */ ({
  IGNORED_BELOW_MS:      3_000,   // < 3 s   → ignored (no event emitted)
  INTENTIONAL_BELOW_MS:  15_000,  // 3–15 s  → intentional_switch
  // ≥ 15 s                        → recovery
});

// ---------------------------------------------------------------------------
// chrome.storage keys
// ---------------------------------------------------------------------------
export const SK = /** @type {const} */ ({
  // session storage — cleared on browser restart (intentional: sessions die with browser)
  SESSION:              'fe_session',
  CURRENT_DISTRACTION:  'fe_cur_distraction',
  TAB_STATES:           'fe_tab_states',

  // local storage — persists across restarts
  CONFIG:               'fe_config',
  EVENT_QUEUE:          'fe_event_queue',
  DASHBOARD_TAB_ID:     'fe_dashboard_tab_id',
});

// ---------------------------------------------------------------------------
// chrome.idle detection threshold
// ---------------------------------------------------------------------------
export const IDLE_THRESHOLD_SEC = 60;

// ---------------------------------------------------------------------------
// Offline event queue TTL (7 days in ms)
// ---------------------------------------------------------------------------
export const QUEUE_TTL_MS = 7 * 24 * 60 * 60 * 1_000;
