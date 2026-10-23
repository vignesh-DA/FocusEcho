/**
 * @fileoverview Unit tests for FocusEcho Extension Database Sync module.
 * Verifies mapping of distraction, recovery, and emergency events to Supabase schema.
 */

import {
  formatDistractionEventRow,
  getFriendlyAppLabel,
  DEFAULT_SUPABASE_URL,
  DEFAULT_SUPABASE_ANON_KEY,
} from '../src/background/database-sync.js';

console.log('\n--- FocusEcho Database Sync Tests ---\n');

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  ✅ ${message}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${message}`);
    failed++;
  }
}

// Test 1: Friendly label mapping
console.log('── Friendly Label Mapping ──');
assert(getFriendlyAppLabel('youtube.com') === 'YouTube', 'youtube.com maps to YouTube');
assert(getFriendlyAppLabel('www.reddit.com') === 'Reddit', 'www.reddit.com maps to Reddit');
assert(getFriendlyAppLabel('twitter.com') === 'X (Twitter)', 'twitter.com maps to X (Twitter)');
assert(getFriendlyAppLabel('github.com') === 'Github', 'github.com capitalizes to Github');

// Test 2: Formatting Distraction Event for Supabase
console.log('\n── Distraction Event Schema Validation ──');
const mockSession = {
  session_id: 'sess-1234-uuid',
  intention: 'Finish API Docs',
  started_at: Date.now() - 120000, // 2 minutes ago
  active: true,
  mode: 'focus',
};

const mockDistractionEvent = {
  event_type: 'distraction',
  domain: 'youtube.com',
  category: 'video',
  escalation_level: 2,
  session_id: 'sess-1234-uuid',
  timestamp: new Date().toISOString(),
  distraction_count: 2,
};

const rowL2 = formatDistractionEventRow(mockDistractionEvent, mockSession);

assert(rowL2.session_id === 'sess-1234-uuid', 'session_id matches active session');
assert(rowL2.package_name === 'youtube.com', 'package_name set to domain');
assert(rowL2.app_label === 'YouTube', 'app_label mapped to friendly label');
assert(rowL2.risk_score === 'medium', 'L2 distraction maps to medium risk');
assert(rowL2.risk_score_numeric === 0.6, 'L2 risk numeric is 0.6');
assert(rowL2.escalation_level === 2, 'escalation_level is 2');
assert(rowL2.is_recovered === false, 'distraction event is_recovered is false');
assert(rowL2.is_synced === 1, 'is_synced flag is set to 1');
assert(typeof rowL2.session_minute_when_occurred === 'number', 'session_minute is computed');

// Test 3: Formatting Recovery Event for Supabase
console.log('\n── Recovery Event Schema Validation ──');
const mockRecoveryEvent = {
  event_type: 'recovery',
  domain: 'youtube.com',
  time_on_site_ms: 22500,
  distraction_started_at: new Date(Date.now() - 22500).toISOString(),
  session_id: 'sess-1234-uuid',
  timestamp: new Date().toISOString(),
  from_level: 2,
};

const rowRec = formatDistractionEventRow(mockRecoveryEvent, mockSession);

assert(rowRec.is_recovered === true, 'recovery event is_recovered is true');
assert(rowRec.recovery_time_seconds === 23, 'recovery_time_seconds rounded from ms (23s)');
assert(rowRec.time_away_seconds === 23, 'time_away_seconds set to recovery seconds');
assert(rowRec.recovered_at !== null, 'recovered_at ISO string populated');

// Test 4: L3 Escalation Event Schema
console.log('\n── Level 3 Full Escalation Risk ──');
const mockL3Event = {
  event_type: 'distraction',
  domain: 'reddit.com',
  escalation_level: 3,
  session_id: 'sess-1234-uuid',
};
const rowL3 = formatDistractionEventRow(mockL3Event, mockSession);
assert(rowL3.risk_score === 'high', 'L3 maps to high risk score');
assert(rowL3.risk_score_numeric === 0.9, 'L3 risk numeric is 0.9');

// Test 5: Default Supabase Config sanity
console.log('\n── Config Sanity ──');
assert(DEFAULT_SUPABASE_URL.includes('supabase.co'), 'Default Supabase URL points to supabase.co');
assert(DEFAULT_SUPABASE_ANON_KEY.startsWith('eyJ'), 'Default anon key is a valid JWT format');

console.log(`\nResults: ${passed} passed, ${failed} failed.\n`);
if (failed > 0) process.exit(1);
