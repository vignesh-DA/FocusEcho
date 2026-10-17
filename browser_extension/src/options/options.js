/**
 * @fileoverview Debug options page logic — Phase 1 only.
 * Communicates with the SW via chrome.runtime.sendMessage.
 * All scenario simulations send fe:debug_dispatch to trigger real SM transitions.
 */

const $ = id => document.getElementById(id);
const stateBox = $('state-box');
const logBox   = $('log-box');

// ---------------------------------------------------------------------------
// State refresh
// ---------------------------------------------------------------------------
async function refreshState() {
  const resp = await chrome.runtime.sendMessage({ type: 'fe:debug_get_state' });
  if (resp?.ok) {
    stateBox.textContent = JSON.stringify({ session: resp.session, distraction: resp.distraction }, null, 2);
  } else {
    stateBox.textContent = 'Error: ' + (resp?.error ?? 'unknown');
  }
}

function addLog(text, cls = '') {
  const div = document.createElement('div');
  div.className = `log-entry ${cls}`;
  div.textContent = `[${new Date().toISOString().substring(11, 23)}] ${text}`;
  logBox.prepend(div);
}

// ---------------------------------------------------------------------------
// Session controls
// ---------------------------------------------------------------------------
$('btn-start').addEventListener('click', async () => {
  const intention = $('intention-input').value.trim() || 'Test session';
  const sites = $('sites-input').value.split(',').map(s => s.trim()).filter(Boolean);
  const resp = await chrome.runtime.sendMessage({
    type: 'fe:debug_start_session',
    intention,
    distraction_list: sites,
  });
  if (resp?.restarted) {
    addLog(`RESTARTED ACTIVE SESSION | new intention: "${intention}" | sites: [${sites.join(', ')}]`, 'warn');
  } else {
    addLog(`START SESSION | intention: "${intention}" | sites: [${sites.join(', ')}]`, 'act');
  }
  await refreshState();
});

$('btn-stop').addEventListener('click', async () => {
  await chrome.runtime.sendMessage({ type: 'fe:debug_stop_session' });
  addLog('END SESSION', 'warn');
  await refreshState();
});

$('btn-refresh').addEventListener('click', refreshState);

// ---------------------------------------------------------------------------
// Scenario simulation helpers
// ---------------------------------------------------------------------------
async function dispatch(ev_type, payload = {}) {
  const resp = await chrome.runtime.sendMessage({ type: 'fe:debug_dispatch', ev_type, payload });
  if (!resp?.ok) addLog(`dispatch failed: ${resp?.error}`, 'warn');
  return resp;
}

/**
 * SCENARIO 1 — Glance < 3 s
 * Enter distraction site → wait 1 s → leave.
 * Expected: COUNTING_GRACE → MONITORING (ignored, no count).
 */
$('btn-glance').addEventListener('click', async () => {
  addLog('--- SCENARIO: Glance < 3 s ---', 'sm');
  const host = 'twitter.com';
  await dispatch('TAB_ACTIVATED', { host, isDistracting: true, tabId: 999 });
  addLog(`  → entered ${host}`, '');
  await sleep(1000); // 1 s — under 3 s grace
  await dispatch('TAB_ACTIVATED', { host: 'vscode.dev', isDistracting: false, tabId: 998 });
  addLog(`  → left ${host} after ~1 s`, '');
  await refreshState();
});

/**
 * SCENARIO 2 — 20 s visit → recovery
 * Enter → wait 3.1 s (grace passes on next event) → force heartbeat to confirm
 * grace → wait → leave. Expected: count=1, L1 level, recovery event.
 */
$('btn-visit20').addEventListener('click', async () => {
  addLog('--- SCENARIO: 20 s visit → recovery ---', 'sm');
  const host = 'twitter.com';
  await dispatch('TAB_ACTIVATED', { host, isDistracting: true, tabId: 999 });
  addLog(`  → entered ${host}`, '');

  // Simulate grace period passing: send HEARTBEAT after 3.1 s
  addLog('  → waiting 3.1 s for grace to expire…', '');
  await sleep(3100);
  await dispatch('HEARTBEAT', {});
  addLog('  → HEARTBEAT fired (grace elapsed — count should increment, L1 shown)', '');

  // Stay on site for ~17 s total from entry (>15 s → recovery)
  await sleep(16900);
  await dispatch('TAB_ACTIVATED', { host: 'vscode.dev', isDistracting: false, tabId: 998 });
  addLog('  → left site (total time ≥ 15 s → recovery event expected)', '');
  await refreshState();
});

/**
 * SCENARIO 3 — Re-entry (after recovery → count increments again)
 * Expected: count=2, L2 overlay.
 */
$('btn-reentry').addEventListener('click', async () => {
  addLog('--- SCENARIO: Re-entry ---', 'sm');
  const host = 'twitter.com';
  await dispatch('TAB_ACTIVATED', { host, isDistracting: true, tabId: 999 });
  addLog(`  → re-entered ${host} from MONITORING (count should increment)`, '');
  await sleep(3100);
  await dispatch('HEARTBEAT', {});
  addLog('  → grace elapsed → L2 expected (count was ≥ 2 from previous scenario)', '');
  await refreshState();
});

$('btn-countdown-expire').addEventListener('click', async () => {
  addLog('--- SCENARIO: L2 countdown expired ---', 'sm');
  await dispatch('COUNTDOWN_EXPIRED', {});
  addLog('  → L2_OVERLAY → COUNTING | post_expiry_at set', '');
  await refreshState();
});

$('btn-drift').addEventListener('click', async () => {
  await dispatch('USER_DRIFT_BUTTON', {});
  addLog('"I\'m drifting" → manual L2', 'act');
  await refreshState();
});

$('btn-heartbeat').addEventListener('click', async () => {
  await dispatch('HEARTBEAT', {});
  addLog('force HEARTBEAT', '');
  await refreshState();
});

$('btn-clear-log').addEventListener('click', () => { logBox.innerHTML = ''; });

// ---------------------------------------------------------------------------
// Util
// ---------------------------------------------------------------------------
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------
refreshState();
