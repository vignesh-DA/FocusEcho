/**
 * @fileoverview Unit tests for the FocusEcho state machine.
 * Runs under Node.js (ES modules) — no Chrome, no browser, no mocks.
 *
 * Usage:
 *   node browser_extension/tests/state-machine.test.js
 *
 * Covers:
 *   T1  Glance < 3s              — no count, no overlay, ignored
 *   T2  20s visit                — count=1, L1, recovery event
 *   T3  Re-entry increments      — every MONITORING→COUNTING increments count
 *   T4  L2 expiry then 60s       — expiry→COUNTING, 60s→next level
 *   T5  L3 tab-leave             — RECOVERY + HIDE_OVERLAY
 *   T6  USER_END_SESSION         — honoured from every state → IDLE
 *   T7  WINDOW_BLURRED           — PAUSED; resume → restore state
 *   T8  RECOVERY classification  — classifyRecovery boundaries
 */

import { transition, levelForCount, classifyRecovery } from '../src/background/state-machine.js';
import { STATE, EV, ESC, GRACE, RECOVERY_ZONES } from '../src/shared/constants.js';

// ---------------------------------------------------------------------------
// Minimal test harness
// ---------------------------------------------------------------------------
let passed = 0, failed = 0;
const results = [];

function assert(label, condition, detail = '') {
  if (condition) {
    passed++;
    results.push(`  ✅  ${label}`);
  } else {
    failed++;
    results.push(`  ❌  ${label}${detail ? ' — ' + detail : ''}`);
  }
}

function group(name) {
  results.push(`\n── ${name} ──`);
}

/** Build a default context with all null/zero fields */
function ctx(overrides = {}) {
  return {
    distractionCount:     0,
    graceEnteredAt:       null,
    distractionStartedAt: null,
    postExpiryAt:         null,
    resumeToState:        null,
    graceConfirmed:       false,
    ...overrides,
  };
}

/** Shorthand event builders */
const ev = {
  start:         (payload = {}) => ({ type: EV.SESSION_STARTED, payload }),
  tabDistracting:(host = 'twitter.com') => ({ type: EV.TAB_ACTIVATED, payload: { host, isDistracting: true, tabId: 999 } }),
  tabClean:      (host = 'vscode.dev') => ({ type: EV.TAB_ACTIVATED, payload: { host, isDistracting: false, tabId: 998 } }),
  heartbeat:     () => ({ type: EV.HEARTBEAT, payload: {} }),
  countdownExp:  () => ({ type: EV.COUNTDOWN_EXPIRED, payload: {} }),
  endSession:    () => ({ type: EV.USER_END_SESSION, payload: {} }),
  backToFocus:   () => ({ type: EV.USER_BACK_TO_FOCUS, payload: {} }),
  windowBlur:    () => ({ type: EV.WINDOW_BLURRED, payload: {} }),
  windowFocus:   () => ({ type: EV.WINDOW_FOCUSED, payload: {} }),
  pauseSession:  () => ({ type: EV.USER_PAUSE_SESSION, payload: {} }),
  emergencyHold: () => ({ type: EV.USER_EMERGENCY_HOLD, payload: {} }),
};

const NOW = 1_728_000_000_000; // fixed reference epoch ms

// ---------------------------------------------------------------------------
// T0 — Helpers
// ---------------------------------------------------------------------------
group('T0 — Helper functions');

assert('levelForCount(1) === 1', levelForCount(1) === 1);
assert('levelForCount(2) === 2', levelForCount(2) === 2);
assert('levelForCount(3) === 2', levelForCount(3) === 2);
assert('levelForCount(4) === 3', levelForCount(4) === 3);
assert('levelForCount(99) === 3', levelForCount(99) === 3);

assert('classifyRecovery(0) === ignored',              classifyRecovery(0) === 'ignored');
assert('classifyRecovery(2999) === ignored',           classifyRecovery(2999) === 'ignored');
assert('classifyRecovery(3000) === intentional_switch',classifyRecovery(3000) === 'intentional_switch');
assert('classifyRecovery(14999) === intentional_switch',classifyRecovery(14999) === 'intentional_switch');
assert('classifyRecovery(15000) === recovery',         classifyRecovery(15000) === 'recovery');
assert('classifyRecovery(60000) === recovery',         classifyRecovery(60000) === 'recovery');

// ---------------------------------------------------------------------------
// T1 — Glance < 3 s (ignored, no count, no overlay)
// ---------------------------------------------------------------------------
group('T1 — Glance < 3 s → ignored');

{
  // MONITORING → COUNTING_GRACE
  const r1 = transition(STATE.MONITORING, ev.tabDistracting(), ctx(), NOW);
  assert('T1.1 MONITORING → COUNTING_GRACE', r1.nextState === STATE.COUNTING_GRACE);
  assert('T1.2 actions include RECORD_GRACE_ENTRY', r1.actions.includes('RECORD_GRACE_ENTRY'));

  // Leave 1 s later (< 3 s grace)
  const graceEnteredAt = NOW;
  const leaveNow = NOW + 1_000; // 1 s — under GRACE.THRESHOLD_MS (3000)
  const r2 = transition(
    STATE.COUNTING_GRACE,
    ev.tabClean(),
    ctx({ graceEnteredAt }),
    leaveNow,
  );
  assert('T1.3 COUNTING_GRACE + leave@1s → MONITORING', r2.nextState === STATE.MONITORING);
  assert('T1.4 actions include CLEAR_DISTRACTION',      r2.actions.includes('CLEAR_DISTRACTION'));
  assert('T1.5 actions include LOG_GRACE_IGNORED',      r2.actions.includes('LOG_GRACE_IGNORED'));
  assert('T1.6 no INCREMENT in actions',                !r2.actions.some(a => a.startsWith('INCREMENT')));
  assert('T1.7 no EMIT_DISTRACTION in actions',         !r2.actions.some(a => a.startsWith('EMIT_DISTRACTION')));
}

// ---------------------------------------------------------------------------
// T2 — 20 s visit → count=1, L1, recovery
// ---------------------------------------------------------------------------
group('T2 — 20 s visit → L1 → recovery');

{
  // Enter grace
  const r1 = transition(STATE.MONITORING, ev.tabDistracting(), ctx(), NOW);
  assert('T2.1 MONITORING → COUNTING_GRACE', r1.nextState === STATE.COUNTING_GRACE);

  // Grace confirmed via HEARTBEAT after 3.1 s → count=0+1=1 → L1_TOAST
  const graceEnteredAt = NOW;
  const heartbeatNow = NOW + 3_100;
  const r2 = transition(
    STATE.COUNTING_GRACE,
    ev.heartbeat(),
    ctx({ distractionCount: 0, graceEnteredAt }),
    heartbeatNow,
  );
  assert('T2.2 COUNTING_GRACE + HEARTBEAT@3.1s → L1_TOAST', r2.nextState === STATE.L1_TOAST);
  assert('T2.3 actions include INCREMENT_DISTRACTION_COUNT', r2.actions.includes('INCREMENT_DISTRACTION_COUNT'));
  assert('T2.4 actions include CONFIRM_GRACE',              r2.actions.includes('CONFIRM_GRACE'));
  assert('T2.5 actions include SHOW_OVERLAY:1',             r2.actions.includes('SHOW_OVERLAY:1'));
  assert('T2.6 actions include EMIT_DISTRACTION_EVENT:1',   r2.actions.includes('EMIT_DISTRACTION_EVENT:1'));

  // Leave after 20 s total from grace entry (time_on_site = 20000 ms ≥ 15000 → recovery)
  const leaveNow = NOW + 20_000;
  const r3 = transition(
    STATE.L1_TOAST,
    ev.tabClean(),
    ctx({ distractionCount: 1, graceEnteredAt, distractionStartedAt: heartbeatNow }),
    leaveNow,
  );
  assert('T2.7 L1_TOAST + leave@20s → MONITORING',              r3.nextState === STATE.MONITORING);
  assert('T2.8 actions include HIDE_OVERLAY',                    r3.actions.includes('HIDE_OVERLAY'));
  assert('T2.9 actions include EMIT_RECOVERY_EVENT:recovery',    r3.actions.includes('EMIT_RECOVERY_EVENT:recovery'));
  assert('T2.10 actions include CLEAR_DISTRACTION',              r3.actions.includes('CLEAR_DISTRACTION'));
}

// ---------------------------------------------------------------------------
// T3 — Re-entry from MONITORING always increments
// ---------------------------------------------------------------------------
group('T3 — Re-entry: MONITORING → COUNTING_GRACE always increments');

{
  // First entry (count 0→1)
  const r1 = transition(STATE.MONITORING, ev.tabDistracting(), ctx({ distractionCount: 0 }), NOW);
  assert('T3.1 first entry → COUNTING_GRACE', r1.nextState === STATE.COUNTING_GRACE);
  assert('T3.2 RECORD_GRACE_ENTRY in actions', r1.actions.includes('RECORD_GRACE_ENTRY'));

  // Grace confirms (count 0 → 1 at this point)
  const grace = NOW;
  const r2 = transition(
    STATE.COUNTING_GRACE,
    ev.heartbeat(),
    ctx({ distractionCount: 0, graceEnteredAt: grace }),
    NOW + 3_100,
  );
  assert('T3.3 grace confirmed → L1_TOAST (count was 0, new = 1)', r2.nextState === STATE.L1_TOAST);

  // Leave → MONITORING (recovery)
  const r3 = transition(
    STATE.L1_TOAST,
    ev.tabClean(),
    ctx({ distractionCount: 1, graceEnteredAt: grace, distractionStartedAt: NOW + 3_100 }),
    NOW + 20_000,
  );
  assert('T3.4 leave → MONITORING', r3.nextState === STATE.MONITORING);

  // Second entry from MONITORING (same site) — count will go 1→2 → L2_OVERLAY
  const r4 = transition(STATE.MONITORING, ev.tabDistracting(), ctx({ distractionCount: 1 }), NOW + 25_000);
  assert('T3.5 re-entry from MONITORING → COUNTING_GRACE', r4.nextState === STATE.COUNTING_GRACE);

  const r5 = transition(
    STATE.COUNTING_GRACE,
    ev.heartbeat(),
    ctx({ distractionCount: 1, graceEnteredAt: NOW + 25_000 }),
    NOW + 28_100,
  );
  assert('T3.6 grace confirmed → L2_OVERLAY (count was 1, new = 2)', r5.nextState === STATE.L2_OVERLAY);
  assert('T3.7 SHOW_OVERLAY:2',             r5.actions.includes('SHOW_OVERLAY:2'));
  assert('T3.8 EMIT_DISTRACTION_EVENT:2',   r5.actions.includes('EMIT_DISTRACTION_EVENT:2'));
  assert('T3.9 INCREMENT_DISTRACTION_COUNT',r5.actions.includes('INCREMENT_DISTRACTION_COUNT'));

  // Third entry (count 2→3 → still L2)
  const r6 = transition(
    STATE.COUNTING_GRACE,
    ev.heartbeat(),
    ctx({ distractionCount: 2, graceEnteredAt: NOW + 30_000 }),
    NOW + 33_100,
  );
  assert('T3.10 count 3 → L2_OVERLAY (not L3 yet)', r6.nextState === STATE.L2_OVERLAY);
  assert('T3.11 SHOW_OVERLAY:2 (level 2 at count=3)', r6.actions.includes('SHOW_OVERLAY:2'));

  // Fourth entry (count 3→4 → L3)
  const r7 = transition(
    STATE.COUNTING_GRACE,
    ev.heartbeat(),
    ctx({ distractionCount: 3, graceEnteredAt: NOW + 40_000 }),
    NOW + 43_100,
  );
  assert('T3.12 count 4 → L3_FORCED', r7.nextState === STATE.L3_FORCED);
  assert('T3.13 SHOW_OVERLAY:3',       r7.actions.includes('SHOW_OVERLAY:3'));
}

// ---------------------------------------------------------------------------
// T4 — L2 countdown expiry → COUNTING; 60 s later → new distraction (next level)
// ---------------------------------------------------------------------------
group('T4 — L2 expiry → COUNTING; 60s heartbeat → new level');

{
  // L2 countdown expires — NOT recovery, → COUNTING + SET_POST_EXPIRY_MARKER
  const r1 = transition(
    STATE.L2_OVERLAY,
    ev.countdownExp(),
    ctx({ distractionCount: 2, distractionStartedAt: NOW }),
    NOW + 15_000,
  );
  assert('T4.1 L2_OVERLAY + COUNTDOWN_EXPIRED → COUNTING', r1.nextState === STATE.COUNTING);
  assert('T4.2 HIDE_OVERLAY',            r1.actions.includes('HIDE_OVERLAY'));
  assert('T4.3 SET_POST_EXPIRY_MARKER',  r1.actions.includes('SET_POST_EXPIRY_MARKER'));
  assert('T4.4 LOG_COUNTDOWN_EXPIRED',   r1.actions.includes('LOG_COUNTDOWN_EXPIRED'));
  assert('T4.5 no EMIT_RECOVERY in actions',
    !r1.actions.some(a => a.startsWith('EMIT_RECOVERY')),
    'L2 expiry must NOT emit recovery'
  );

  // Heartbeat fires 30 s after expiry (< 60 s) — no new distraction yet
  const postExpiryAt = NOW + 15_000;
  const r2 = transition(
    STATE.COUNTING,
    ev.heartbeat(),
    ctx({ distractionCount: 2, distractionStartedAt: NOW, postExpiryAt }),
    postExpiryAt + 30_000, // only 30 s elapsed
  );
  assert('T4.6 COUNTING + HEARTBEAT@30s (< 60s) → stays COUNTING', r2.nextState === STATE.COUNTING);
  assert('T4.7 no SHOW_OVERLAY (< 60s)',
    !r2.actions.some(a => a.startsWith('SHOW_OVERLAY')),
  );

  // Heartbeat fires 61 s after expiry — new distraction! count 2→3 → L2 again (count=3, level=2)
  const r3 = transition(
    STATE.COUNTING,
    ev.heartbeat(),
    ctx({ distractionCount: 2, distractionStartedAt: NOW, postExpiryAt }),
    postExpiryAt + 61_000, // 61 s elapsed → triggers
  );
  assert('T4.8 COUNTING + HEARTBEAT@61s → L2_OVERLAY (count 2→3, level=2)', r3.nextState === STATE.L2_OVERLAY);
  assert('T4.9 INCREMENT_DISTRACTION_COUNT',  r3.actions.includes('INCREMENT_DISTRACTION_COUNT'));
  assert('T4.10 SHOW_OVERLAY:2',              r3.actions.includes('SHOW_OVERLAY:2'));
  assert('T4.11 EMIT_DISTRACTION_EVENT:2',    r3.actions.includes('EMIT_DISTRACTION_EVENT:2'));
  assert('T4.12 CLEAR_POST_EXPIRY',           r3.actions.includes('CLEAR_POST_EXPIRY'));
}

// ---------------------------------------------------------------------------
// T5 — L3 tab-leave → MONITORING + HIDE_OVERLAY
// ---------------------------------------------------------------------------
group('T5 — L3 tab-leave → RECOVERY + HIDE_OVERLAY');

{
  // User navigates away from distraction site while L3 is showing
  const distractionStartedAt = NOW;
  const leaveNow = NOW + 25_000; // 25 s → recovery

  const r1 = transition(
    STATE.L3_FORCED,
    ev.tabClean(),
    ctx({ distractionCount: 4, distractionStartedAt }),
    leaveNow,
  );
  assert('T5.1 L3_FORCED + tab-leave → MONITORING',              r1.nextState === STATE.MONITORING);
  assert('T5.2 HIDE_OVERLAY',                                     r1.actions.includes('HIDE_OVERLAY'));
  assert('T5.3 EMIT_RECOVERY_EVENT:recovery (25s ≥ 15s)',         r1.actions.includes('EMIT_RECOVERY_EVENT:recovery'));
  assert('T5.4 CLEAR_DISTRACTION',                                r1.actions.includes('CLEAR_DISTRACTION'));

  // Tab-leave with short time (3-15 s → intentional_switch)
  const r2 = transition(
    STATE.L3_FORCED,
    ev.tabClean(),
    ctx({ distractionCount: 4, distractionStartedAt }),
    NOW + 8_000, // 8 s → intentional_switch
  );
  assert('T5.5 L3_FORCED + tab-leave@8s → intentional_switch',   r2.actions.includes('EMIT_RECOVERY_EVENT:intentional_switch'));

  // Tab-switch in L3 (another distracting tab) — L3 stays (no escape)
  const r3 = transition(
    STATE.L3_FORCED,
    { type: EV.TAB_ACTIVATED, payload: { host: 'youtube.com', isDistracting: true, tabId: 1001 } },
    ctx({ distractionCount: 4, distractionStartedAt }),
    NOW + 5_000,
  );
  assert('T5.6 L3_FORCED + tab-switch to another distracting site → stays L3_FORCED',
    r3.nextState === STATE.L3_FORCED);

  // USER_PAUSE_SESSION from L3 → SESSION_PAUSED
  const r4 = transition(
    STATE.L3_FORCED,
    ev.pauseSession(),
    ctx({ distractionCount: 4 }),
    NOW,
  );
  assert('T5.7 L3_FORCED + USER_PAUSE_SESSION → SESSION_PAUSED', r4.nextState === STATE.SESSION_PAUSED);
  assert('T5.8 HIDE_OVERLAY on pause',                           r4.actions.includes('HIDE_OVERLAY'));

  // USER_EMERGENCY_HOLD from L3 → COUNTING
  const r5 = transition(
    STATE.L3_FORCED,
    ev.emergencyHold(),
    ctx({ distractionCount: 4 }),
    NOW,
  );
  assert('T5.9 L3_FORCED + EMERGENCY_HOLD → COUNTING',           r5.nextState === STATE.COUNTING);
  assert('T5.10 LOG_EMERGENCY_EXIT',                              r5.actions.includes('LOG_EMERGENCY_EXIT'));
}

// ---------------------------------------------------------------------------
// T6 — USER_END_SESSION from EVERY state → IDLE
// ---------------------------------------------------------------------------
group('T6 — USER_END_SESSION honoured from every state');

const allStates = Object.values(STATE);
for (const s of allStates) {
  const r = transition(s, ev.endSession(), ctx({ distractionCount: 1 }), NOW);
  assert(`T6 ${s} + END_SESSION → IDLE`, r.nextState === STATE.IDLE, `got ${r.nextState}`);
}

// ---------------------------------------------------------------------------
// T7 — WINDOW_BLURRED → PAUSED; resume → restore
// ---------------------------------------------------------------------------
group('T7 — PAUSED → resume restores previous state');

{
  for (const [fromState, resumeTo] of [
    [STATE.COUNTING,    STATE.COUNTING],
    [STATE.L1_TOAST,    STATE.L1_TOAST],
    [STATE.L2_OVERLAY,  STATE.L2_OVERLAY],
    [STATE.COUNTING_GRACE, STATE.COUNTING_GRACE],
  ]) {
    const r1 = transition(fromState, ev.windowBlur(), ctx({ distractionCount: 1, distractionStartedAt: NOW }), NOW);
    assert(`T7 ${fromState} + WINDOW_BLURRED → PAUSED`, r1.nextState === STATE.PAUSED);
    assert(`T7 ${fromState} SET_RESUME_TO:${resumeTo}`, r1.actions.some(a => a === `SET_RESUME_TO:${resumeTo}`));
  }

  // Resume
  const r2 = transition(STATE.PAUSED, ev.windowFocus(), ctx({ resumeToState: STATE.L2_OVERLAY }), NOW);
  assert('T7 PAUSED + WINDOW_FOCUSED → L2_OVERLAY (restored)', r2.nextState === STATE.L2_OVERLAY);
  assert('T7 RESUME_TIMER in actions', r2.actions.includes('RESUME_TIMER'));
}

// ---------------------------------------------------------------------------
// T8 — Back-to-focus navigates (actions include NAVIGATE_BACK_TO_FOCUS)
// ---------------------------------------------------------------------------
group('T8 — USER_BACK_TO_FOCUS triggers navigation action');

{
  for (const s of [STATE.L1_TOAST, STATE.L2_OVERLAY, STATE.L3_FORCED]) {
    const r = transition(s, ev.backToFocus(), ctx({ distractionCount: 1, distractionStartedAt: NOW }), NOW + 20_000);
    assert(`T8 ${s} + USER_BACK_TO_FOCUS → MONITORING`,           r.nextState === STATE.MONITORING, `got ${r.nextState}`);
    assert(`T8 ${s} NAVIGATE_BACK_TO_FOCUS in actions`,           r.actions.includes('NAVIGATE_BACK_TO_FOCUS'));
    assert(`T8 ${s} EMIT_RECOVERY_EVENT:recovery in actions`,     r.actions.includes('EMIT_RECOVERY_EVENT:recovery'));
    assert(`T8 ${s} HIDE_OVERLAY in actions`,                     r.actions.includes('HIDE_OVERLAY'));
  }
}

// ---------------------------------------------------------------------------
// T9 — SESSION_PAUSED resume → MONITORING
// ---------------------------------------------------------------------------
group('T9 — SESSION_PAUSED → resume → MONITORING');

{
  const r1 = transition(STATE.SESSION_PAUSED, { type: EV.USER_RESUME_SESSION }, ctx(), NOW);
  assert('T9 SESSION_PAUSED + RESUME → MONITORING', r1.nextState === STATE.MONITORING);
  assert('T9 LOG_SESSION_RESUMED in actions',       r1.actions.includes('LOG_SESSION_RESUMED'));
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------
console.log('\n╔══════════════════════════════════════════╗');
console.log('║  FocusEcho SM Unit Tests — Phase 1      ║');
console.log('╚══════════════════════════════════════════╝');
console.log(results.join('\n'));
console.log(`\n${'─'.repeat(44)}`);
console.log(`  Total:  ${passed + failed}  |  ✅ Passed: ${passed}  |  ❌ Failed: ${failed}`);
console.log(`${'─'.repeat(44)}`);
if (failed > 0) {
  process.exit(1);
}
