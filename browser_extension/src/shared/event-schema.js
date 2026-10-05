/**
 * @fileoverview Typed event schema shared between the extension and the backend.
 * Backend team: these types mirror the /events route payload.
 * All fields use snake_case to match the FastAPI Pydantic models.
 *
 * PRIVACY GUARANTEE: No field in any event type stores a full URL,
 * URL path, page title, page content, form data, or keystroke data.
 * Only hostname and pre-classified category are transmitted.
 */

/**
 * Valid event_type strings for distraction events.
 * @typedef {'distraction'} DistractionEventType
 */

/**
 * Valid event_type strings for recovery events.
 * @typedef {'recovery'|'intentional_switch'|'ignored'} RecoveryEventType
 */

/**
 * Valid event_type strings for special events.
 * @typedef {'emergency_exit'|'accessibility_exit'|'session_started'|'session_ended'|'session_paused'|'countdown_expired'} SpecialEventType
 */

/**
 * @typedef {'social_media'|'video'|'gaming'|'news'|'shopping'|'messaging'|'unknown'} SiteCategory
 */

/**
 * @typedef {1|2|3} EscalationLevel
 */

// ---------------------------------------------------------------------------

/**
 * Emitted when a distraction visit is confirmed (grace period passed).
 *
 * @typedef {Object} DistractionEvent
 * @property {'distraction'} event_type
 * @property {string}        domain           - hostname only e.g. "twitter.com"
 * @property {SiteCategory}  category
 * @property {EscalationLevel} escalation_level
 * @property {string}        session_id       - UUID
 * @property {string}        timestamp        - ISO 8601 UTC
 * @property {number}        distraction_count - session-cumulative count at this event
 */

/**
 * Emitted when the user leaves a distraction site.
 * event_type distinguishes the three recovery zones.
 *
 * @typedef {Object} RecoveryEvent
 * @property {RecoveryEventType} event_type
 * @property {string}            domain
 * @property {number}            time_on_site_ms  - wall-clock: leave_time − distraction.startedAt
 * @property {string}            distraction_started_at  - ISO 8601 UTC
 * @property {string}            session_id
 * @property {string}            timestamp        - ISO 8601 UTC (= leave time)
 * @property {EscalationLevel}   [from_level]     - level that was active when user left
 */

/**
 * Emitted when the user completes a hold-to-escape gesture.
 *
 * @typedef {Object} EmergencyExitEvent
 * @property {'emergency_exit'} event_type
 * @property {string}           domain
 * @property {EscalationLevel}  from_level
 * @property {string}           session_id
 * @property {string}           timestamp
 */

/**
 * Emitted when the user clicks the a11y "I need to use this site" exit.
 *
 * @typedef {Object} AccessibilityExitEvent
 * @property {'accessibility_exit'} event_type
 * @property {string}               domain
 * @property {number}               exit_count_this_session
 * @property {string}               session_id
 * @property {string}               timestamp
 */

/**
 * Emitted after L2 countdown expires and user remains on the site.
 *
 * @typedef {Object} CountdownExpiredEvent
 * @property {'countdown_expired'} event_type
 * @property {string}              domain
 * @property {string}              session_id
 * @property {string}              timestamp
 */

/**
 * Union of all event types stored in the offline queue.
 * @typedef {DistractionEvent|RecoveryEvent|EmergencyExitEvent|AccessibilityExitEvent|CountdownExpiredEvent} FocusEchoEvent
 */

/**
 * Wrap an event for the offline queue with a queue-level timestamp for TTL.
 *
 * @typedef {Object} QueuedEvent
 * @property {FocusEchoEvent} event
 * @property {number}         queued_at  - epoch ms; used for 7-day TTL pruning
 */

// ---------------------------------------------------------------------------
// Factory helpers (used by service-worker.js)
// ---------------------------------------------------------------------------

/**
 * @param {object} p
 * @param {string} p.domain
 * @param {SiteCategory} p.category
 * @param {EscalationLevel} p.escalation_level
 * @param {string} p.session_id
 * @param {number} p.distraction_count
 * @returns {DistractionEvent}
 */
export function mkDistractionEvent({ domain, category, escalation_level, session_id, distraction_count }) {
  return {
    event_type: 'distraction',
    domain,
    category,
    escalation_level,
    session_id,
    timestamp: new Date().toISOString(),
    distraction_count,
  };
}

/**
 * @param {object} p
 * @param {RecoveryEventType} p.event_type
 * @param {string} p.domain
 * @param {number} p.time_on_site_ms
 * @param {number} p.distraction_started_at  - epoch ms
 * @param {string} p.session_id
 * @param {EscalationLevel} [p.from_level]
 * @returns {RecoveryEvent}
 */
export function mkRecoveryEvent({ event_type, domain, time_on_site_ms, distraction_started_at, session_id, from_level }) {
  return {
    event_type,
    domain,
    time_on_site_ms,
    distraction_started_at: new Date(distraction_started_at).toISOString(),
    session_id,
    timestamp: new Date().toISOString(),
    ...(from_level !== undefined && { from_level }),
  };
}

/**
 * @param {object} p
 * @param {string} p.domain
 * @param {EscalationLevel} p.from_level
 * @param {string} p.session_id
 * @returns {EmergencyExitEvent}
 */
export function mkEmergencyExitEvent({ domain, from_level, session_id }) {
  return { event_type: 'emergency_exit', domain, from_level, session_id, timestamp: new Date().toISOString() };
}
