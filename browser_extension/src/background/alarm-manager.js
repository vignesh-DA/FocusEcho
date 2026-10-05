/**
 * @fileoverview chrome.alarms management.
 * Phase 1: heartbeat only (1-minute period). No sub-30s alarms.
 *
 * The heartbeat serves two roles:
 *   1. Keeps the SW alive / provides periodic wake-up.
 *   2. Drives grace-period confirmation when no other event fires within 3 s
 *      (Phase 1 fallback — Phase 2 content-script timers replace this for
 *      accuracy on the first distraction visit).
 */

import { ALARM } from '../shared/constants.js';

/**
 * Ensure the heartbeat alarm is running.
 * Safe to call multiple times — chrome.alarms.create with the same name
 * replaces the existing alarm.
 */
export async function ensureHeartbeat() {
  const existing = await chrome.alarms.get(ALARM.HEARTBEAT);
  if (!existing) {
    await chrome.alarms.create(ALARM.HEARTBEAT, {
      periodInMinutes: ALARM.HEARTBEAT_PERIOD_MIN,
    });
    console.log('[FocusEcho AM] heartbeat alarm created (period: 1 min)');
  }
}

/** Stop the heartbeat alarm. */
export async function clearHeartbeat() {
  await chrome.alarms.clear(ALARM.HEARTBEAT);
  console.log('[FocusEcho AM] heartbeat alarm cleared');
}
