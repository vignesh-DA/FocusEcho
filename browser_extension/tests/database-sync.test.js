/**
 * @fileoverview Unit tests for FocusEcho Extension Database Sync module.
 * Verifies mapping of distraction, recovery, and emergency events to Supabase schema.
 */

import {
  formatDistractionEventRow,
  formatQueuedEventRows,
  getFriendlyAppLabel,
  DEFAULT_SUPABASE_URL,
  DEFAULT_SUPABASE_ANON_KEY,
  refreshAuthSession,
  syncEventQueue,
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
  id: 'stable-event-uuid',
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
assert(rowL2.id === 'stable-event-uuid', 'extension event ID is preserved for cross-surface deduplication');
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
  related_event_id: 'stable-event-uuid',
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
assert(rowRec.id === 'stable-event-uuid', 'recovery updates the original distraction row');
assert(rowRec.event_type === 'distraction', 'recovered event keeps the distraction row type');
assert(rowRec.recovery_time_seconds === 23, 'recovery_time_seconds rounded from ms (23s)');
assert(rowRec.time_away_seconds === 23, 'time_away_seconds set to recovery seconds');
assert(rowRec.recovered_at !== null, 'recovered_at ISO string populated');
const coalescedLifecycleRows = formatQueuedEventRows([
  { event: mockDistractionEvent },
  { event: mockRecoveryEvent },
], mockSession);
assert(coalescedLifecycleRows.length === 1, 'queued distraction and recovery coalesce into one upsert row');
assert(coalescedLifecycleRows[0].is_recovered, 'coalesced row retains the recovery update');

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
assert(typeof refreshAuthSession === 'function', 'refresh-token helper is exported');

let savedCredentials = null;
globalThis.chrome = { storage: { local: { set: async (updates) => { savedCredentials = updates; } } } };
const originalFetch = globalThis.fetch;
globalThis.fetch = async (url, options) => ({
  ok: url.includes('/auth/v1/token?grant_type=refresh_token') && options.method === 'POST',
  json: async () => ({ access_token: 'fresh-access-token', refresh_token: 'fresh-refresh-token', user: { id: 'user-1' } }),
});
const refreshed = await refreshAuthSession({
  supabaseUrl: DEFAULT_SUPABASE_URL,
  supabaseAnonKey: DEFAULT_SUPABASE_ANON_KEY,
  authToken: 'expired-token',
  refreshToken: 'old-refresh-token',
  userId: 'user-1',
});
assert(refreshed?.authToken === 'fresh-access-token', 'refresh helper returns a fresh access token');
assert(savedCredentials?.fe_refresh_token === 'fresh-refresh-token', 'refresh helper persists rotated refresh token');
globalThis.fetch = originalFetch;

const queueStorage = {
  fe_event_queue: [{
    event: {
      event_type: 'recovery',
      domain: 'youtube.com',
      time_on_site_ms: 20000,
      session_id: 'session-auth-test',
      timestamp: new Date().toISOString(),
    },
    queued_at: Date.now(),
  }],
  fe_supabase_url: DEFAULT_SUPABASE_URL,
  fe_supabase_anon_key: DEFAULT_SUPABASE_ANON_KEY,
  fe_backend_url: '',
  fe_user_id: null,
};
globalThis.chrome = { storage: { local: {
  get: async (keys) => {
    const requested = Array.isArray(keys) ? keys : [keys];
    return Object.fromEntries(requested.filter(key => key in queueStorage).map(key => [key, queueStorage[key]]));
  },
  set: async (updates) => Object.assign(queueStorage, updates),
} } };
let writeRequests = 0;
globalThis.fetch = async () => { writeRequests += 1; throw new Error('write should not happen without auth'); };
const noAuth = await syncEventQueue();
assert(noAuth.remaining === 1 && writeRequests === 0, 'no user token keeps queued data local without any write');

queueStorage.fe_user_id = 'user-1';
queueStorage.fe_auth_token = 'expired-access-token';
queueStorage.fe_refresh_token = 'refresh-secret-test-value';
let refreshRequests = 0;
let eventRequests = 0;
const eventAuthorization = [];
const apiKeyHeaders = [];
const emittedInfoLogs = [];
const originalConsoleInfo = console.info;
console.info = (...args) => emittedInfoLogs.push(args.join(' '));
globalThis.fetch = async (url, options) => {
  if (url.includes('/auth/v1/token?grant_type=refresh_token')) {
    refreshRequests += 1;
    return {
      status: 200,
      ok: true,
      json: async () => ({ access_token: 'new-access-token', refresh_token: 'new-refresh-token', user: { id: 'user-1' } }),
    };
  }
  apiKeyHeaders.push(options.headers.apikey);
  if (url.endsWith('/focus_sessions')) return { status: 201, ok: true };
  if (url.endsWith('/distraction_events')) {
    eventRequests += 1;
    eventAuthorization.push(options.headers.Authorization);
    return eventRequests === 1
      ? { status: 401, ok: false, text: async () => 'expired' }
      : { status: 201, ok: true };
  }
  throw new Error('unexpected request');
};
const retried = await syncEventQueue();
console.info = originalConsoleInfo;
assert(retried.synced === 1, 'expired access token is refreshed and the failed write succeeds');
assert(eventRequests === 2 && refreshRequests === 1, '401 causes one refresh and exactly one request retry');
assert(eventAuthorization[0] === 'Bearer expired-access-token' && eventAuthorization[1] === 'Bearer new-access-token', 'retry uses refreshed bearer token');
assert(apiKeyHeaders.every(value => value === DEFAULT_SUPABASE_ANON_KEY), 'anon key remains only in apikey header');
assert(queueStorage.fe_refresh_token === 'new-refresh-token', 'rotated refresh token is persisted');
assert(!emittedInfoLogs.join(' ').includes('refresh-secret-test-value'), 'refresh token never appears in logs');
globalThis.fetch = originalFetch;
delete globalThis.chrome;

console.log(`\nResults: ${passed} passed, ${failed} failed.\n`);
if (failed > 0) process.exit(1);
