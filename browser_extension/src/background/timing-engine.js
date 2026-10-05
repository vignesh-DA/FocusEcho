/**
 * @fileoverview Timing utilities — pure timestamp arithmetic. No Chrome APIs.
 *
 * Active-time accumulation is used for HABIT MODE (usage limit per site).
 * FOCUS SESSION MODE uses wall-clock time only for recovery classification.
 */

/**
 * Total active milliseconds on the distraction site, computed from timestamps.
 * If currently paused (paused_at is set), does not add more elapsed time.
 *
 * @param {{ started_at: number, paused_at: number|null, active_ms: number }} d
 * @param {number} [now]
 * @returns {number}
 */
export function computeActiveMs(d, now = Date.now()) {
  if (d.paused_at !== null) return d.active_ms;
  return d.active_ms + (now - d.started_at);
}

/**
 * Snapshot to use when pausing (window blur, idle, etc.).
 *
 * @param {{ started_at: number, paused_at: number|null, active_ms: number }} d
 * @param {number} [now]
 * @returns {{ paused_at: number, active_ms: number }}
 */
export function snapshotForPause(d, now = Date.now()) {
  return {
    paused_at: now,
    active_ms: computeActiveMs(d, now),
  };
}

/**
 * Snapshot to use when resuming from a pause.
 * Resets started_at to now; accumulated time is preserved in active_ms.
 *
 * @param {number} [now]
 * @returns {{ started_at: number, paused_at: null }}
 */
export function snapshotForResume(now = Date.now()) {
  return { started_at: now, paused_at: null };
}
