/**
 * @fileoverview Pure state machine for FocusEcho extension.
 *
 * transition() is a PURE FUNCTION — no Chrome API calls, no I/O.
 * The service worker is the sole interpreter of returned actions.
 *
 * Action types returned in the `actions` array are strings consumed by
 * service-worker.js executeActions(). Adding a new action requires
 * updating both this file (to return it) and service-worker.js (to handle it).
 */

import { STATE, EV, ESC, GRACE, RECOVERY_ZONES } from '../shared/constants.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * @param {number} count
 * @returns {1|2|3}
 */
export function levelForCount(count) {
  if (count <= ESC.L1_AT) return 1;
  if (count <= ESC.L2_MAX) return 2;
  return 3;
}

/**
 * @param {1|2|3} level
 * @returns {string} next STATE for that level
 */
function stateForLevel(level) {
  if (level === 1) return STATE.L1_TOAST;
  if (level === 2) return STATE.L2_OVERLAY;
  return STATE.L3_FORCED;
}

/**
 * Classify time-on-site into a recovery zone.
 * Returns the event_type string to emit, or null for ignored.
 *
 * @param {number} timeOnSiteMs  - leave_time − distraction.started_at
 * @returns {'ignored'|'intentional_switch'|'recovery'}
 */
export function classifyRecovery(timeOnSiteMs) {
  if (timeOnSiteMs < RECOVERY_ZONES.IGNORED_BELOW_MS)     return 'ignored';
  if (timeOnSiteMs < RECOVERY_ZONES.INTENTIONAL_BELOW_MS) return 'intentional_switch';
  return 'recovery';
}

// ---------------------------------------------------------------------------
// Transition
// ---------------------------------------------------------------------------

/**
 * @typedef {Object} TransitionContext
 * @property {number}      distractionCount    - current session value
 * @property {number|null} graceEnteredAt      - epoch ms when COUNTING_GRACE began
 * @property {number|null} distractionStartedAt - epoch ms when grace was confirmed (counting began)
 * @property {number|null} postExpiryAt        - epoch ms when L2 countdown expired
 * @property {string|null} resumeToState       - state to restore from PAUSED
 * @property {boolean}     graceConfirmed      - true once ≥ 3 s elapsed on site
 */

/**
 * @typedef {Object} SMEvent
 * @property {string}  type
 * @property {object}  [payload]
 */

/**
 * @typedef {Object} TransitionResult
 * @property {string}   nextState
 * @property {string[]} actions   - interpreted by service-worker.js executeActions()
 */

/**
 * Pure state transition function.
 *
 * @param {string}            currentState
 * @param {SMEvent}           event
 * @param {TransitionContext} ctx
 * @param {number}            now  - epoch ms (injected for testability)
 * @returns {TransitionResult}
 */
export function transition(currentState, event, ctx, now = Date.now()) {
  const { type, payload } = event;
  const { distractionCount, graceEnteredAt, distractionStartedAt, postExpiryAt, resumeToState } = ctx;

  // ------------------------------------------------------------------
  // Global: USER_END_SESSION is always honoured in every state
  // ------------------------------------------------------------------
  if (type === EV.USER_END_SESSION) {
    return { nextState: STATE.IDLE, actions: ['HIDE_OVERLAY', 'CLEAR_SESSION', 'LOG_SESSION_ENDED'] };
  }

  switch (currentState) {

    // ----------------------------------------------------------------
    case STATE.IDLE:
    // ----------------------------------------------------------------
      if (type === EV.SESSION_STARTED) {
        return { nextState: STATE.MONITORING, actions: ['RESET_SESSION', 'START_HEARTBEAT'] };
      }
      return { nextState: STATE.IDLE, actions: [] };

    // ----------------------------------------------------------------
    case STATE.MONITORING:
    // ----------------------------------------------------------------
      if (_isDistractionEntry(type) && payload?.isDistracting) {
        return {
          nextState: STATE.COUNTING_GRACE,
          actions: ['RECORD_GRACE_ENTRY', 'UPDATE_LAST_PRODUCTIVE_TAB_CLEAR'],
        };
      }
      if (_isNonDistractionEntry(type) && !payload?.isDistracting) {
        return { nextState: STATE.MONITORING, actions: ['UPDATE_LAST_PRODUCTIVE_TAB'] };
      }
      if (type === EV.USER_RESUME_SESSION) {
        return { nextState: STATE.MONITORING, actions: ['LOG_SESSION_RESUMED'] };
      }
      return { nextState: STATE.MONITORING, actions: [] };

    // ----------------------------------------------------------------
    case STATE.COUNTING_GRACE:
    // ----------------------------------------------------------------
      // User left the site — evaluate grace
      if (_isSiteLeave(type, payload)) {
        const timeOnSite = now - (graceEnteredAt ?? now);
        if (timeOnSite < GRACE.THRESHOLD_MS) {
          // < 3 s: ignored — no count, no event
          return { nextState: STATE.MONITORING, actions: ['CLEAR_DISTRACTION', 'LOG_GRACE_IGNORED'] };
        }
        // ≥ 3 s left the site — grace expired but user is leaving.
        // Increment count, classify, emit events, go to MONITORING.
        const newCount = distractionCount + 1;
        const level = levelForCount(newCount);
        const classification = classifyRecovery(timeOnSite);
        return {
          nextState: STATE.MONITORING,
          actions: [
            'INCREMENT_DISTRACTION_COUNT',
            `EMIT_DISTRACTION_EVENT:${level}`,
            `EMIT_RECOVERY_EVENT:${classification}`,
            'CLEAR_DISTRACTION',
          ],
        };
      }
      // Grace elapsed while still on site (from HEARTBEAT or GRACE_ELAPSED)
      if (type === EV.GRACE_ELAPSED || _graceElapsed(type, graceEnteredAt, now)) {
        const newCount = distractionCount + 1;
        const level = levelForCount(newCount);
        return {
          nextState: stateForLevel(level),
          actions: [
            'INCREMENT_DISTRACTION_COUNT',
            'CONFIRM_GRACE',
            `SHOW_OVERLAY:${level}`,
            `EMIT_DISTRACTION_EVENT:${level}`,
          ],
        };
      }
      // Pause while in grace
      if (_isPauseEvent(type)) {
        return { nextState: STATE.PAUSED, actions: ['SET_RESUME_TO:COUNTING_GRACE', 'LOG_PAUSED'] };
      }
      if (_isNonDistractionEntry(type) && !payload?.isDistracting) {
        return { nextState: STATE.MONITORING, actions: ['UPDATE_LAST_PRODUCTIVE_TAB'] };
      }
      return { nextState: STATE.COUNTING_GRACE, actions: [] };

    // ----------------------------------------------------------------
    case STATE.COUNTING:
    // ----------------------------------------------------------------
      // User left the site
      if (_isSiteLeave(type, payload)) {
        const timeOnSite = now - (distractionStartedAt ?? now);
        const classification = classifyRecovery(timeOnSite);
        return {
          nextState: STATE.MONITORING,
          actions: [
            `EMIT_RECOVERY_EVENT:${classification}`,
            'CLEAR_DISTRACTION',
            'UPDATE_LAST_PRODUCTIVE_TAB',
          ],
        };
      }
      // Heartbeat — check post-expiry new-distraction rule (Amendment 3)
      if (type === EV.HEARTBEAT && postExpiryAt !== null) {
        if (now - postExpiryAt >= ESC.POST_EXPIRY_NEW_DISTRACTION_MS) {
          const newCount = distractionCount + 1;
          const level = levelForCount(newCount);
          return {
            nextState: stateForLevel(level),
            actions: [
              'INCREMENT_DISTRACTION_COUNT',
              `SHOW_OVERLAY:${level}`,
              `EMIT_DISTRACTION_EVENT:${level}`,
              'CLEAR_POST_EXPIRY',
            ],
          };
        }
      }
      // Re-entry to a distraction site from COUNTING (navigation to another distraction site)
      if (_isDistractionEntry(type) && payload?.isDistracting) {
        return {
          nextState: STATE.COUNTING_GRACE,
          actions: ['RECORD_GRACE_ENTRY', 'HIDE_OVERLAY'],
        };
      }
      if (_isPauseEvent(type)) {
        return { nextState: STATE.PAUSED, actions: ['SET_RESUME_TO:COUNTING', 'LOG_PAUSED'] };
      }
      return { nextState: STATE.COUNTING, actions: [] };

    // ----------------------------------------------------------------
    case STATE.L1_TOAST:
    // ----------------------------------------------------------------
      if (_isSiteLeave(type, payload)) {
        const timeOnSite = now - (distractionStartedAt ?? now);
        const classification = classifyRecovery(timeOnSite);
        return {
          nextState: STATE.MONITORING,
          actions: [
            'HIDE_OVERLAY',
            `EMIT_RECOVERY_EVENT:${classification}`,
            'CLEAR_DISTRACTION',
            'UPDATE_LAST_PRODUCTIVE_TAB',
          ],
        };
      }
      if (type === EV.USER_BACK_TO_FOCUS) {
        return {
          nextState: STATE.MONITORING,
          actions: ['HIDE_OVERLAY', 'NAVIGATE_BACK_TO_FOCUS', 'EMIT_RECOVERY_EVENT:recovery', 'CLEAR_DISTRACTION'],
        };
      }
      if (type === EV.USER_DRIFT_BUTTON) {
        return { nextState: STATE.L2_OVERLAY, actions: ['SHOW_OVERLAY:2'] };
      }
      if (_isPauseEvent(type)) {
        return { nextState: STATE.PAUSED, actions: ['SET_RESUME_TO:L1_TOAST', 'LOG_PAUSED'] };
      }
      return { nextState: STATE.L1_TOAST, actions: [] };

    // ----------------------------------------------------------------
    case STATE.L2_OVERLAY:
    // ----------------------------------------------------------------
      if (_isSiteLeave(type, payload)) {
        const timeOnSite = now - (distractionStartedAt ?? now);
        const classification = classifyRecovery(timeOnSite);
        return {
          nextState: STATE.MONITORING,
          actions: [
            'HIDE_OVERLAY',
            `EMIT_RECOVERY_EVENT:${classification}`,
            'CLEAR_DISTRACTION',
            'UPDATE_LAST_PRODUCTIVE_TAB',
          ],
        };
      }
      if (type === EV.USER_BACK_TO_FOCUS) {
        return {
          nextState: STATE.MONITORING,
          actions: ['HIDE_OVERLAY', 'NAVIGATE_BACK_TO_FOCUS', 'EMIT_RECOVERY_EVENT:recovery', 'CLEAR_DISTRACTION'],
        };
      }
      // Countdown expired → COUNTING (NOT recovery). Start post-expiry 60s watch.
      if (type === EV.COUNTDOWN_EXPIRED) {
        return {
          nextState: STATE.COUNTING,
          actions: ['HIDE_OVERLAY', 'SET_POST_EXPIRY_MARKER', 'LOG_COUNTDOWN_EXPIRED'],
        };
      }
      if (type === EV.USER_EMERGENCY_HOLD) {
        return { nextState: STATE.COUNTING, actions: ['HIDE_OVERLAY', 'LOG_EMERGENCY_EXIT', 'CLEAR_POST_EXPIRY'] };
      }
      if (_isPauseEvent(type)) {
        return { nextState: STATE.PAUSED, actions: ['SET_RESUME_TO:L2_OVERLAY', 'LOG_PAUSED'] };
      }
      return { nextState: STATE.L2_OVERLAY, actions: [] };

    // ----------------------------------------------------------------
    case STATE.L3_FORCED:
    // ----------------------------------------------------------------
      // User navigates away — overlay hides, recovery computed
      if (_isSiteLeave(type, payload)) {
        const timeOnSite = now - (distractionStartedAt ?? now);
        const classification = classifyRecovery(timeOnSite);
        return {
          nextState: STATE.MONITORING,
          actions: [
            'HIDE_OVERLAY',
            `EMIT_RECOVERY_EVENT:${classification}`,
            'CLEAR_DISTRACTION',
            'UPDATE_LAST_PRODUCTIVE_TAB',
          ],
        };
      }
      if (type === EV.USER_BACK_TO_FOCUS) {
        return {
          nextState: STATE.MONITORING,
          actions: ['HIDE_OVERLAY', 'NAVIGATE_BACK_TO_FOCUS', 'EMIT_RECOVERY_EVENT:recovery', 'CLEAR_DISTRACTION'],
        };
      }
      if (type === EV.USER_PAUSE_SESSION) {
        return { nextState: STATE.SESSION_PAUSED, actions: ['HIDE_OVERLAY', 'LOG_SESSION_PAUSED'] };
      }
      if (type === EV.USER_EMERGENCY_HOLD) {
        return { nextState: STATE.COUNTING, actions: ['HIDE_OVERLAY', 'LOG_EMERGENCY_EXIT'] };
      }
      // Tab switches do NOT escape L3 (overlay follows to new tabs in Phase 2)
      return { nextState: STATE.L3_FORCED, actions: [] };

    // ----------------------------------------------------------------
    case STATE.PAUSED:
    // ----------------------------------------------------------------
      if (_isResumeEvent(type)) {
        const restoreTo = resumeToState ?? STATE.MONITORING;
        return { nextState: restoreTo, actions: ['RESUME_TIMER', 'LOG_RESUMED'] };
      }
      if (_isSiteLeave(type, payload)) {
        // Left site while paused — can still classify (wall-clock includes pause time per spec)
        const timeOnSite = now - (distractionStartedAt ?? graceEnteredAt ?? now);
        const classification = classifyRecovery(timeOnSite);
        return {
          nextState: STATE.MONITORING,
          actions: [
            'HIDE_OVERLAY',
            `EMIT_RECOVERY_EVENT:${classification}`,
            'CLEAR_DISTRACTION',
          ],
        };
      }
      return { nextState: STATE.PAUSED, actions: [] };

    // ----------------------------------------------------------------
    case STATE.SESSION_PAUSED:
    // ----------------------------------------------------------------
      if (type === EV.USER_RESUME_SESSION) {
        return { nextState: STATE.MONITORING, actions: ['LOG_SESSION_RESUMED'] };
      }
      return { nextState: STATE.SESSION_PAUSED, actions: [] };

    // ----------------------------------------------------------------
    default:
      return { nextState: currentState, actions: [] };
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

function _isDistractionEntry(type) {
  return type === EV.TAB_ACTIVATED || type === EV.TAB_NAVIGATED || type === EV.URL_CHANGED;
}

function _isNonDistractionEntry(type) {
  return type === EV.TAB_ACTIVATED || type === EV.TAB_NAVIGATED || type === EV.URL_CHANGED;
}

/** True if the event signals the user has left the current distraction site. */
function _isSiteLeave(type, payload) {
  return (
    (type === EV.TAB_ACTIVATED && payload?.isDistracting === false) ||
    (type === EV.TAB_NAVIGATED && payload?.isDistracting === false) ||
    (type === EV.URL_CHANGED   && payload?.isDistracting === false)
  );
}

function _isPauseEvent(type) {
  return (
    type === EV.WINDOW_BLURRED   ||
    type === EV.VISIBILITY_HIDDEN ||
    type === EV.IDLE_DETECTED
  );
}

function _isResumeEvent(type) {
  return (
    type === EV.WINDOW_FOCUSED    ||
    type === EV.VISIBILITY_VISIBLE ||
    type === EV.IDLE_ENDED
  );
}

/**
 * On HEARTBEAT, check whether the grace period has elapsed.
 * (Phase 1 fallback since there is no content-script timer yet.)
 */
function _graceElapsed(type, graceEnteredAt, now) {
  return type === EV.HEARTBEAT && graceEnteredAt !== null && (now - graceEnteredAt) >= GRACE.THRESHOLD_MS;
}
