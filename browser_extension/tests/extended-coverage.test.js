/**
 * @fileoverview Extended Unit Tests for FocusEcho Browser Extension.
 * 67 deterministic tests verifying state machine transitions, escalation rules,
 * recovery classifications, constants integrity, and storage schemas.
 */

import { transition, levelForCount, classifyRecovery } from '../src/background/state-machine.js';
import { STATE, EV, ESC, GRACE, RECOVERY_ZONES, SK, MSG, ALARM } from '../src/shared/constants.js';

let passed = 0;
let failed = 0;
const results = [];

function assert(label, condition) {
  if (condition) {
    passed++;
    results.push(`  ✅  ${label}`);
  } else {
    failed++;
    results.push(`  ❌  ${label}`);
  }
}

function ctx(overrides = {}) {
  return {
    distractionCount: 0,
    graceEnteredAt: null,
    distractionStartedAt: null,
    postExpiryAt: null,
    resumeToState: null,
    graceConfirmed: false,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// 1. Escalation Level Tests (15 tests)
// ---------------------------------------------------------------------------
assert('levelForCount: count 0 -> level 1', levelForCount(0) === 1);
assert('levelForCount: count 1 -> level 1', levelForCount(1) === 1);
assert('levelForCount: count 2 -> level 2', levelForCount(2) === 2);
assert('levelForCount: count 3 -> level 2', levelForCount(3) === 2);
assert('levelForCount: count 4 -> level 3', levelForCount(4) === 3);
assert('levelForCount: count 5 -> level 3', levelForCount(5) === 3);
assert('levelForCount: count 10 -> level 3', levelForCount(10) === 3);
assert('levelForCount: count 100 -> level 3', levelForCount(100) === 3);
assert('levelForCount: negative count -> level 1', levelForCount(-1) === 1);
assert('levelForCount: null count -> level 1', levelForCount(null) === 1);
assert('levelForCount: ESC.L1_AT is 1', ESC.L1_AT === 1);
assert('levelForCount: ESC.L2_MAX is 3', ESC.L2_MAX === 3);
assert('levelForCount: ESC.L3_MIN is 4', ESC.L3_MIN === 4);
assert('levelForCount: float 2.5 -> level 2', levelForCount(2.5) === 2);
assert('levelForCount: float 4.9 -> level 3', levelForCount(4.9) === 3);

// ---------------------------------------------------------------------------
// 2. Recovery Classification Tests (15 tests)
// ---------------------------------------------------------------------------
assert('classifyRecovery: 0ms -> ignored', classifyRecovery(0) === 'ignored');
assert('classifyRecovery: 1000ms -> ignored', classifyRecovery(1000) === 'ignored');
assert('classifyRecovery: 2999ms -> ignored', classifyRecovery(2999) === 'ignored');
assert('classifyRecovery: 3000ms -> intentional_switch', classifyRecovery(3000) === 'intentional_switch');
assert('classifyRecovery: 5000ms -> intentional_switch', classifyRecovery(5000) === 'intentional_switch');
assert('classifyRecovery: 10000ms -> intentional_switch', classifyRecovery(10000) === 'intentional_switch');
assert('classifyRecovery: 14999ms -> intentional_switch', classifyRecovery(14999) === 'intentional_switch');
assert('classifyRecovery: 15000ms -> recovery', classifyRecovery(15000) === 'recovery');
assert('classifyRecovery: 15001ms -> recovery', classifyRecovery(15001) === 'recovery');
assert('classifyRecovery: 30000ms -> recovery', classifyRecovery(30000) === 'recovery');
assert('classifyRecovery: 60000ms -> recovery', classifyRecovery(60000) === 'recovery');
assert('classifyRecovery: 300000ms -> recovery', classifyRecovery(300000) === 'recovery');
assert('classifyRecovery: negative ms -> ignored', classifyRecovery(-500) === 'ignored');
assert('classifyRecovery: null -> ignored', classifyRecovery(null) === 'ignored');
assert('classifyRecovery: 100ms -> ignored', classifyRecovery(100) === 'ignored');

// ---------------------------------------------------------------------------
// 3. State Machine Transition Edge Cases (20 tests)
// ---------------------------------------------------------------------------
const sIdle = transition(STATE.IDLE, { type: 'UNKNOWN_EVENT' }, ctx());
assert('transition: IDLE + unknown -> remains IDLE', sIdle.nextState === STATE.IDLE);

const sMonUnknown = transition(STATE.MONITORING, { type: 'UNKNOWN_EVENT' }, ctx());
assert('transition: MONITORING + unknown -> remains MONITORING', sMonUnknown.nextState === STATE.MONITORING);

const sEndFromMon = transition(STATE.MONITORING, { type: EV.USER_END_SESSION }, ctx());
assert('transition: MONITORING + USER_END_SESSION -> IDLE', sEndFromMon.nextState === STATE.IDLE);

const sEndFromL1 = transition(STATE.L1_TOAST, { type: EV.USER_END_SESSION }, ctx());
assert('transition: L1_TOAST + USER_END_SESSION -> IDLE', sEndFromL1.nextState === STATE.IDLE);

const sEndFromL2 = transition(STATE.L2_OVERLAY, { type: EV.USER_END_SESSION }, ctx());
assert('transition: L2_OVERLAY + USER_END_SESSION -> IDLE', sEndFromL2.nextState === STATE.IDLE);

const sEndFromL3 = transition(STATE.L3_FORCED, { type: EV.USER_END_SESSION }, ctx());
assert('transition: L3_FORCED + USER_END_SESSION -> IDLE', sEndFromL3.nextState === STATE.IDLE);

const sEndFromPaused = transition(STATE.PAUSED, { type: EV.USER_END_SESSION }, ctx());
assert('transition: PAUSED + USER_END_SESSION -> IDLE', sEndFromPaused.nextState === STATE.IDLE);

const sPauseFromL1 = transition(STATE.L1_TOAST, { type: EV.WINDOW_BLURRED }, ctx());
assert('transition: L1_TOAST + WINDOW_BLURRED -> PAUSED', sPauseFromL1.nextState === STATE.PAUSED);

const sPauseFromL2 = transition(STATE.L2_OVERLAY, { type: EV.WINDOW_BLURRED }, ctx());
assert('transition: L2_OVERLAY + WINDOW_BLURRED -> PAUSED', sPauseFromL2.nextState === STATE.PAUSED);

const sBackToFocusL1 = transition(STATE.L1_TOAST, { type: EV.USER_BACK_TO_FOCUS }, ctx());
assert('transition: L1_TOAST + USER_BACK_TO_FOCUS -> MONITORING', sBackToFocusL1.nextState === STATE.MONITORING);
assert('transition: L1_TOAST + USER_BACK_TO_FOCUS includes NAVIGATE_BACK_TO_FOCUS', sBackToFocusL1.actions.includes('NAVIGATE_BACK_TO_FOCUS'));
assert('transition: L1_TOAST + USER_BACK_TO_FOCUS includes HIDE_OVERLAY', sBackToFocusL1.actions.includes('HIDE_OVERLAY'));

const sBackToFocusL2 = transition(STATE.L2_OVERLAY, { type: EV.USER_BACK_TO_FOCUS }, ctx());
assert('transition: L2_OVERLAY + USER_BACK_TO_FOCUS -> MONITORING', sBackToFocusL2.nextState === STATE.MONITORING);
assert('transition: L2_OVERLAY + USER_BACK_TO_FOCUS includes NAVIGATE_BACK_TO_FOCUS', sBackToFocusL2.actions.includes('NAVIGATE_BACK_TO_FOCUS'));

const sBackToFocusL3 = transition(STATE.L3_FORCED, { type: EV.USER_BACK_TO_FOCUS }, ctx());
assert('transition: L3_FORCED + USER_BACK_TO_FOCUS -> MONITORING', sBackToFocusL3.nextState === STATE.MONITORING);
assert('transition: L3_FORCED + USER_BACK_TO_FOCUS includes NAVIGATE_BACK_TO_FOCUS', sBackToFocusL3.actions.includes('NAVIGATE_BACK_TO_FOCUS'));

const sDriftL1 = transition(STATE.L1_TOAST, { type: EV.USER_DRIFT_BUTTON }, ctx());
assert('transition: L1_TOAST + USER_DRIFT_BUTTON -> L2_OVERLAY', sDriftL1.nextState === STATE.L2_OVERLAY);

const sEmergencyL2 = transition(STATE.L2_OVERLAY, { type: EV.USER_EMERGENCY_HOLD }, ctx());
assert('transition: L2_OVERLAY + USER_EMERGENCY_HOLD -> COUNTING', sEmergencyL2.nextState === STATE.COUNTING);

const sEmergencyL3 = transition(STATE.L3_FORCED, { type: EV.USER_EMERGENCY_HOLD }, ctx());
assert('transition: L3_FORCED + USER_EMERGENCY_HOLD -> COUNTING', sEmergencyL3.nextState === STATE.COUNTING);

const sCountdownL2 = transition(STATE.L2_OVERLAY, { type: EV.COUNTDOWN_EXPIRED }, ctx());
assert('transition: L2_OVERLAY + COUNTDOWN_EXPIRED -> COUNTING', sCountdownL2.nextState === STATE.COUNTING);

// ---------------------------------------------------------------------------
// 4. Constants & Schema Verifications (17 tests)
// ---------------------------------------------------------------------------
assert('constants: STATE.IDLE exists', STATE.IDLE === 'IDLE');
assert('constants: STATE.MONITORING exists', STATE.MONITORING === 'MONITORING');
assert('constants: STATE.COUNTING_GRACE exists', STATE.COUNTING_GRACE === 'COUNTING_GRACE');
assert('constants: STATE.COUNTING exists', STATE.COUNTING === 'COUNTING');
assert('constants: STATE.L1_TOAST exists', STATE.L1_TOAST === 'L1_TOAST');
assert('constants: STATE.L2_OVERLAY exists', STATE.L2_OVERLAY === 'L2_OVERLAY');
assert('constants: STATE.L3_FORCED exists', STATE.L3_FORCED === 'L3_FORCED');
assert('constants: STATE.PAUSED exists', STATE.PAUSED === 'PAUSED');
assert('constants: STATE.SESSION_PAUSED exists', STATE.SESSION_PAUSED === 'SESSION_PAUSED');

assert('constants: GRACE.THRESHOLD_MS is 3000', GRACE.THRESHOLD_MS === 3000);
assert('constants: RECOVERY_ZONES.IGNORED_BELOW_MS is 3000', RECOVERY_ZONES.IGNORED_BELOW_MS === 3000);
assert('constants: RECOVERY_ZONES.INTENTIONAL_BELOW_MS is 15000', RECOVERY_ZONES.INTENTIONAL_BELOW_MS === 15000);

assert('constants: SK.SESSION exists', SK.SESSION === 'fe_session');
assert('constants: SK.CONFIG exists', SK.CONFIG === 'fe_config');
assert('constants: SK.DASHBOARD_TAB_ID exists', SK.DASHBOARD_TAB_ID === 'fe_dashboard_tab_id');

assert('constants: MSG.SHOW_OVERLAY exists', MSG.SHOW_OVERLAY === 'fe:show_overlay');
assert('constants: ALARM.HEARTBEAT exists', ALARM.HEARTBEAT === 'fe-heartbeat');

// ---------------------------------------------------------------------------
// Output summary
// ---------------------------------------------------------------------------
console.log('\n--- Extended Extension Coverage Tests ---');
if (failed > 0) {
  results.filter(r => r.includes('❌')).forEach(r => console.log(r));
}
console.log(`Results: ${passed} passed, ${failed} failed.\n`);

if (failed > 0) {
  process.exit(1);
}
