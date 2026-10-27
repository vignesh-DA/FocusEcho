/**
 * @fileoverview Documented shape of every chrome.storage key.
 *
 * STORAGE SPLIT RATIONALE:
 *   chrome.storage.session  — volatile; cleared when the browser restarts.
 *                             Used for active session state. A session that
 *                             survives a browser restart would be confusing
 *                             and insecure. This is intentional.
 *   chrome.storage.local    — persistent; survives restarts.
 *                             Used for user config and the offline event queue.
 *
 * CONTENT SCRIPT ACCESS:
 *   Content scripts do NOT have direct storage access. They receive state via
 *   chrome.runtime.sendMessage (SW pushes SHOW_OVERLAY / SYNC_STATE).
 *   Justification: message passing is more secure — the SW validates every
 *   request and exposes only the minimum needed (level, endsAt, intention).
 *   chrome.storage.session.setAccessLevel is NOT called; session storage
 *   remains SW-only.
 */

// ---------------------------------------------------------------------------
// chrome.storage.session  (key: SK.SESSION)
// ---------------------------------------------------------------------------
/**
 * @typedef {Object} SessionState
 * @property {boolean}  active            - true while a session or habit mode is running
 * @property {'focus'|'habit'} mode
 * @property {string}   session_id        - UUID generated at session start
 * @property {string}   intention         - user's declared focus goal
 * @property {number}   started_at        - epoch ms
 * @property {string[]} distraction_list  - normalised hostnames
 * @property {number}   distraction_count - incremented once per confirmed site entry
 * @property {string[]} parked_items      - short notes to revisit after the session
 * @property {string}   state             - current STATE value
 * @property {string|null} resume_to_state  - state to restore after PAUSED
 * @property {number|null} last_productive_tab_id - for "Back to focus" navigation
 */

// ---------------------------------------------------------------------------
// chrome.storage.session  (key: SK.CURRENT_DISTRACTION)
// ---------------------------------------------------------------------------
/**
 * Non-null while the user is on (or recently left) a distraction site.
 * Reset to null on MONITORING re-entry.
 *
 * @typedef {Object} CurrentDistraction
 * @property {string}      host           - hostname of the distraction site
 * @property {string}      category       - SiteCategory
 * @property {number}      started_at     - epoch ms when site was entered (COUNTING_GRACE entry)
 * @property {boolean}     grace_confirmed - true once >= 3 000 ms have elapsed
 * @property {number|null} post_expiry_at - epoch ms when L2 countdown expired; null otherwise.
 *                                          If non-null and HEARTBEAT fires while still on site
 *                                          and (now − post_expiry_at) >= 60 000 ms, a new
 *                                          distraction is triggered.
 * @property {number}      active_ms      - accumulated active ms (for habit-mode limit; unused in focus-mode Phase 1)
 * @property {number|null} paused_at      - epoch ms of last pause; null when running
 * @property {number}      level          - EscalationLevel when grace was confirmed; 0 before
 */

// ---------------------------------------------------------------------------
// chrome.storage.session  (key: SK.TAB_STATES)
// ---------------------------------------------------------------------------
/**
 * @typedef {Object} TabState
 * @property {string}      host
 * @property {boolean}     is_distracting
 * @property {number|null} active_start  - epoch ms when this tab became the active tab in its window
 */

/**
 * @typedef {Object.<number, TabState>} TabStates  - keyed by tabId
 */

// ---------------------------------------------------------------------------
// chrome.storage.local  (key: SK.CONFIG)
// ---------------------------------------------------------------------------
/**
 * @typedef {Object} DistractionSite
 * @property {string}   hostname
 * @property {string}   category     - SiteCategory
 * @property {number}   limit_minutes - for habit mode; ignored in focus mode
 */

/**
 * @typedef {Object} ExtensionConfig
 * @property {DistractionSite[]} distraction_list
 * @property {object}  habit_mode
 * @property {boolean} habit_mode.enabled
 * @property {number}  habit_mode.limit_minutes   - default 60
 * @property {number}  habit_mode.break_minutes   - default 5
 * @property {object}  escalation
 * @property {number}  escalation.countdown_ms        - default 15 000
 * @property {number}  escalation.emergency_hold_ms   - default 2 000
 * @property {number}  escalation.post_expiry_ms      - default 60 000
 * @property {string[]} dashboard_origins - exact origins for the dashboard bridge content script
 */

/** @returns {ExtensionConfig} */
export function defaultConfig() {
  return {
    distraction_list: [],
    strict_focus_mode: false,
    habit_mode: { enabled: false, limit_minutes: 60, break_minutes: 5 },
    escalation: { countdown_ms: 15_000, emergency_hold_ms: 2_000, post_expiry_ms: 60_000 },
    dashboard_origins: [
      'https://focusecho-app.vercel.app',
      'http://localhost:3000',
      'http://localhost:5173',
    ],
  };
}

// ---------------------------------------------------------------------------
// chrome.storage.local  (key: SK.EVENT_QUEUE)
// ---------------------------------------------------------------------------
/**
 * Array of QueuedEvent objects (see event-schema.js).
 * Purge policy: remove only after (a) successful sync to backend, or
 * (b) queued_at older than QUEUE_TTL_MS (7 days). NOT purged on session end.
 */
