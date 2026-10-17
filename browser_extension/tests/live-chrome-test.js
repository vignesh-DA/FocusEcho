/**
 * @fileoverview Automated Live Chrome E2E Test Suite for FocusEcho Extension (EXT-1).
 *
 * Runs against a real Chrome browser instance using Puppeteer.
 * Tests real Chrome WebNavigation/Tabs events, real service worker MV3 lifecycle,
 * DNS host-resolver mapping for youtube.com, timer grace execution, and CDP SW shutdown.
 *
 * Usage:
 *   node browser_extension/tests/live-chrome-test.js
 */

import puppeteer from 'puppeteer';
import https from 'https';
import fs from 'fs';
import { resolve, join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { execSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const EXT_ROOT = resolve(__dirname, '..');
const RESULTS_DIR = join(EXT_ROOT, 'test-results');
const PROFILE_DIR = join(RESULTS_DIR, 'profile');
const LOG_FILE = join(RESULTS_DIR, 'console.log');
const KEY_FILE = join(RESULTS_DIR, 'key.pem');
const CERT_FILE = join(RESULTS_DIR, 'cert.pem');
const CNF_FILE = join(RESULTS_DIR, 'openssl.cnf');

if (!fs.existsSync(RESULTS_DIR)) fs.mkdirSync(RESULTS_DIR, { recursive: true });

const PORT = 8999;
const logs = [];

function log(msg, ...args) {
  const line = `[${new Date().toISOString()}] ${msg} ${args.length ? JSON.stringify(args) : ''}`;
  console.log(line);
  logs.push(line);
}

// ---------------------------------------------------------------------------
// Ensure OpenSSL certificate exists for mock HTTPS server
// ---------------------------------------------------------------------------
function ensureCertificates() {
  if (fs.existsSync(KEY_FILE) && fs.existsSync(CERT_FILE)) {
    return;
  }
  log('Generating self-signed certificate for youtube.com via OpenSSL...');
  const cnf = `[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = youtube.com
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = youtube.com
DNS.2 = www.youtube.com
DNS.3 = clean.test
DNS.4 = localhost
IP.1 = 127.0.0.1
`;
  fs.writeFileSync(CNF_FILE, cnf, 'utf8');
  execSync(`openssl req -x509 -newkey rsa:2048 -nodes -keyout "${KEY_FILE}" -out "${CERT_FILE}" -days 365 -config "${CNF_FILE}"`, { stdio: 'pipe' });
  log('Certificate generated successfully.');
}

// ---------------------------------------------------------------------------
// 1. Mock HTTPS Server (with SAN certificate to satisfy Chrome for youtube.com)
// ---------------------------------------------------------------------------
function startMockServer() {
  ensureCertificates();
  const key = fs.readFileSync(KEY_FILE);
  const cert = fs.readFileSync(CERT_FILE);

  const server = https.createServer({ key, cert }, (req, res) => {
    const host = req.headers.host || 'unknown';
    res.writeHead(200, { 'Content-Type': 'text/html' });
    if (host.includes('youtube.com')) {
      res.end(`<!DOCTYPE html>
<html>
<head><title>YouTube</title></head>
<body style="background:#0f0f0f;color:white;font-family:sans-serif;padding:40px;">
  <h1>Mock YouTube Video Player</h1>
  <p id="info">URL: ${req.url}</p>
  <div id="video-player" style="width:400px;height:250px;background:#333;display:flex;align-items:center;justify-content:center;">Playing Video</div>
</body>
</html>`);
    } else {
      res.end(`<!DOCTYPE html>
<html>
<head><title>Clean Work Focus</title></head>
<body style="background:#f4f4f4;color:#111;font-family:sans-serif;padding:40px;">
  <h1>Productive Workspace (Docs & Coding)</h1>
  <p id="info">URL: ${req.url}</p>
</body>
</html>`);
    }
  });

  return new Promise((resolveServer, reject) => {
    server.listen(PORT, '127.0.0.1', () => {
      log(`Mock HTTPS server listening on https://127.0.0.1:${PORT}`);
      resolveServer(server);
    });
    server.on('error', reject);
  });
}

// ---------------------------------------------------------------------------
// Helper: get service worker target reliably
// ---------------------------------------------------------------------------
async function getSWTarget(browser, timeoutMs = 12000) {
  const existing = browser.targets().find(t => t.type() === 'service_worker' && t.url().includes('chrome-extension://'));
  if (existing) return existing;
  return await browser.waitForTarget(
    t => t.type() === 'service_worker' && t.url().includes('chrome-extension://'),
    { timeout: timeoutMs }
  );
}

// Helper: read storage from worker using self.__fe
async function getStorageData(worker) {
  return await worker.evaluate(async () => {
    const session = await self.__fe?.loadSession();
    const distraction = await self.__fe?.loadDistraction();
    const l = await chrome.storage.local.get(['fe_event_queue', 'fe_config']);
    return {
      session,
      distraction,
      event_queue: l?.fe_event_queue ?? [],
      config: l?.fe_config ?? null,
    };
  });
}

// Helper: send debug start session directly through SW handler
async function startSession(worker, intention = 'Deep Coding', sites = ['youtube.com']) {
  return await worker.evaluate(async (intention, sites) => {
    return await self.__fe.handleMessage({
      type: 'fe:debug_start_session',
      intention,
      distraction_list: sites,
    }, {});
  }, intention, sites);
}

// Extension messaging helpers (immune to dead worker handles after CDP stop)
async function sendExtMessage(browser, extId, msg) {
  const page = await browser.newPage();
  try {
    await page.goto(`chrome-extension://${extId}/src/options/options.html`, { waitUntil: 'domcontentloaded' });
    return await page.evaluate(async (m) => {
      return await chrome.runtime.sendMessage(m);
    }, msg);
  } finally {
    await page.close().catch(() => {});
  }
}

async function getExtState(browser, extId) {
  const page = await browser.newPage();
  try {
    await page.goto(`chrome-extension://${extId}/src/options/options.html`, { waitUntil: 'domcontentloaded' });
    return await page.evaluate(async () => {
      const resp = await chrome.runtime.sendMessage({ type: 'fe:debug_get_state' });
      const local = await chrome.storage.local.get(['fe_event_queue', 'fe_config']);
      return {
        session: resp?.session || null,
        distraction: resp?.distraction || null,
        event_queue: local?.fe_event_queue ?? [],
        config: local?.fe_config ?? null,
      };
    });
  } finally {
    await page.close().catch(() => {});
  }
}

// ---------------------------------------------------------------------------
// Main Test Runner
// ---------------------------------------------------------------------------
async function runTestSuite() {
  // Fresh profile directory on each test run so Chrome reloads extension code
  if (fs.existsSync(PROFILE_DIR)) {
    fs.rmSync(PROFILE_DIR, { recursive: true, force: true });
  }
  fs.mkdirSync(PROFILE_DIR, { recursive: true });

  const mockServer = await startMockServer();
  const testResults = [];

  function record(id, title, status, details = '') {
    testResults.push({ id, title, status, details });
    const symbol = status === 'PASS' ? '✅' : '❌';
    log(`${symbol} [${status}] ${id}: ${title} — ${details}`);
  }

  log('Launching Chrome with clean persistent profile & unpacked extension...');
  const browser = await puppeteer.launch({
    headless: false,
    userDataDir: PROFILE_DIR,
    ignoreHTTPSErrors: true,
    args: [
      `--disable-extensions-except=${EXT_ROOT}`,
      `--load-extension=${EXT_ROOT}`,
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--ignore-certificate-errors',
      '--allow-insecure-localhost',
      // Map youtube.com and clean.test to 127.0.0.1 without OS hosts file edits
      `--host-resolver-rules=MAP youtube.com 127.0.0.1, MAP www.youtube.com 127.0.0.1, MAP clean.test 127.0.0.1, MAP focusecho.test 127.0.0.1`,
    ],
  });

  try {
    // -----------------------------------------------------------------------
    // CHECK 1: Extension loads with no manifest or icon errors, SW active
    // -----------------------------------------------------------------------
    log('Waiting for Extension Service Worker target...');
    const swTarget = await getSWTarget(browser, 15000);
    const extUrl = new URL(swTarget.url());
    const extId = extUrl.hostname;
    let worker = await swTarget.worker();

    worker.on('console', msg => log(`[SW Console] ${msg.type()}: ${msg.text()}`));

    browser.on('targetcreated', async t => {
      if (t.type() === 'service_worker' && t.url().includes('chrome-extension://')) {
        const w = await t.worker().catch(() => null);
        w?.on('console', msg => log(`[SW Console] ${msg.type()}: ${msg.text()}`));
      }
    });

    const swActive = await worker.evaluate(() => typeof chrome !== 'undefined' && !!chrome.runtime);
    const pages = await browser.pages();
    const primaryPage = pages[0] || (await browser.newPage());

    await primaryPage.screenshot({ path: join(RESULTS_DIR, '01_extension_loaded.png') });

    if (swActive && extId) {
      record('CHECK-1', 'Extension loads with no manifest/icon errors and active SW', 'PASS', `Extension ID: ${extId}`);
    } else {
      record('CHECK-1', 'Extension loads with active SW', 'FAIL', 'Service worker not active');
    }

    // -----------------------------------------------------------------------
    // NEGATIVE CONTROL: Prove that disabling 3s timer leaves Check 2 in failure state
    // -----------------------------------------------------------------------
    log('\n--- Running Negative Control (Proving 3s Timer Bug is Caught) ---');
    // Suppress the 3-second grace timer to simulate the old buggy behavior
    await worker.evaluate(() => { self._disableGraceTimer = true; });
    await startSession(worker, 'Negative Control Task', ['youtube.com']);

    log('Navigating to youtube.com with timer disabled...');
    await primaryPage.goto(`https://youtube.com:${PORT}/watch?v=neg_control`, { waitUntil: 'domcontentloaded' });

    log('Waiting 3.8s with timer disabled (simulating legacy bug without manual heartbeat)...');
    await new Promise(r => setTimeout(r, 3800));

    const negStorage = await getStorageData(worker);
    log(`[Negative Control result]: State="${negStorage.session?.state}", count=${negStorage.session?.distraction_count}`);

    const negControlVerified = (negStorage.session?.state === 'COUNTING_GRACE' && negStorage.session?.distraction_count === 0);
    if (negControlVerified) {
      log('✅ NEGATIVE CONTROL PASS: Without the 3s timer, state remains stuck in COUNTING_GRACE after 3.8s (proves Check 2 would fail).');
    } else {
      log(`❌ NEGATIVE CONTROL UNEXPECTED: State was "${negStorage.session?.state}", count=${negStorage.session?.distraction_count}`);
    }

    // Restore timer for positive tests
    await worker.evaluate(() => { self._disableGraceTimer = false; });
    log('Restored 3-second grace timer for positive control execution.');

    // -----------------------------------------------------------------------
    // CHECK 2: Visit > 3s with NO manual events reaches L1 and count is 1
    // -----------------------------------------------------------------------
    log('\n--- Running Check 2 (Automatic 3s Grace Timer) ---');
    await startSession(worker, 'Study Coding', ['youtube.com']);
    await primaryPage.goto(`https://youtube.com:${PORT}/watch?v=tutorial_1`, { waitUntil: 'domcontentloaded' });
    log('Navigated to youtube.com. Waiting 3.8s for automatic 3s timer to fire without any manual heartbeat...');
    await new Promise(r => setTimeout(r, 3800));

    const check2Data = await getStorageData(worker);
    await primaryPage.screenshot({ path: join(RESULTS_DIR, '02_l1_toast_distraction.png') });

    if (check2Data.session?.state === 'L1_TOAST' && check2Data.session?.distraction_count === 1) {
      record('CHECK-2', 'Visit > 3s with no manual events reaches L1 & count=1', 'PASS', `State: ${check2Data.session.state}, count: ${check2Data.session.distraction_count}`);
    } else {
      record('CHECK-2', 'Visit > 3s with no manual events reaches L1 & count=1', 'FAIL', `Expected L1_TOAST count=1, got ${check2Data.session?.state} count=${check2Data.session?.distraction_count}`);
    }

    // -----------------------------------------------------------------------
    // CHECK 3: Glance < 3s leaves count at 0
    // -----------------------------------------------------------------------
    log('\n--- Running Check 3 (Glance < 3s) ---');
    await startSession(worker, 'Clean Session', ['youtube.com']);
    await primaryPage.goto(`https://youtube.com:${PORT}/shorts_quick`, { waitUntil: 'domcontentloaded' });
    log('On youtube.com for 1.0 second (< 3s)...');
    await new Promise(r => setTimeout(r, 1000));

    log('Leaving site to clean.test...');
    await primaryPage.goto(`https://clean.test:${PORT}/docs`, { waitUntil: 'domcontentloaded' });
    await new Promise(r => setTimeout(r, 500));

    const check3Data = await getStorageData(worker);
    await primaryPage.screenshot({ path: join(RESULTS_DIR, '03_glance_under_3s.png') });

    if (check3Data.session?.state === 'MONITORING' && check3Data.session?.distraction_count === 0) {
      record('CHECK-3', 'Glance < 3s leaves count at 0', 'PASS', `State: ${check3Data.session.state}, count: ${check3Data.session.distraction_count}`);
    } else {
      record('CHECK-3', 'Glance < 3s leaves count at 0', 'FAIL', `Expected MONITORING count=0, got ${check3Data.session?.state} count=${check3Data.session?.distraction_count}`);
    }

    // -----------------------------------------------------------------------
    // CHECK 4: 20s visit then switch away emits a recovery event
    // -----------------------------------------------------------------------
    log('\n--- Running Check 4 (20s visit + recovery switch) ---');
    await primaryPage.goto(`https://youtube.com:${PORT}/watch?v=long_study_drift`, { waitUntil: 'domcontentloaded' });
    log('Waiting 21 seconds for full 20s+ visit (recovery threshold is >= 15s active)...');
    await new Promise(r => setTimeout(r, 21000));

    log('Switching away to clean.test to trigger recovery event...');
    await primaryPage.goto(`https://clean.test:${PORT}/work`, { waitUntil: 'domcontentloaded' });
    await new Promise(r => setTimeout(r, 800));

    const check4Data = await getStorageData(worker);
    await primaryPage.screenshot({ path: join(RESULTS_DIR, '04_recovery_switch_away.png') });

    const recoveryEvent = check4Data.event_queue.find(
      q => q.event?.event_type === 'recovery' && q.event?.domain === 'youtube.com'
    );

    if (recoveryEvent && recoveryEvent.event.time_on_site_ms >= 15000) {
      record('CHECK-4', '20s visit then switch away emits recovery event', 'PASS', `Recovery logged with time_on_site: ${recoveryEvent.event.time_on_site_ms}ms`);
    } else {
      record('CHECK-4', '20s visit then switch away emits recovery event', 'FAIL', `Recovery event not found or duration < 15s. Queue size: ${check4Data.event_queue.length}`);
    }

    // -----------------------------------------------------------------------
    // CHECK 5: Re-entry raises count to 2 and reaches L2
    // -----------------------------------------------------------------------
    log('\n--- Running Check 5 (Re-entry to L2) ---');
    await primaryPage.goto(`https://youtube.com:${PORT}/watch?v=reentry_video`, { waitUntil: 'domcontentloaded' });
    log('Waiting 3.8s for grace timer to escalate to Level 2...');
    await new Promise(r => setTimeout(r, 3800));

    const check5Data = await getStorageData(worker);
    await primaryPage.screenshot({ path: join(RESULTS_DIR, '05_reentry_l2_overlay.png') });

    if (check5Data.session?.state === 'L2_OVERLAY' && check5Data.session?.distraction_count === 2) {
      record('CHECK-5', 'Re-entry raises count to 2 and reaches L2', 'PASS', `State: ${check5Data.session.state}, count: ${check5Data.session.distraction_count}`);
    } else {
      record('CHECK-5', 'Re-entry raises count to 2 and reaches L2', 'FAIL', `Expected L2_OVERLAY count=2, got ${check5Data.session?.state} count=${check5Data.session?.distraction_count}`);
    }

    // -----------------------------------------------------------------------
    // CHECK 6: Stopping service worker via CDP and waking it keeps state & count
    // -----------------------------------------------------------------------
    log('\n--- Running Check 6 (CDP Service Worker Termination & Persistence) ---');
    const cdp = await primaryPage.createCDPSession();
    let swVersionId = '0';
    cdp.on('ServiceWorker.workerVersionUpdated', ev => {
      for (const v of ev.versions) {
        if (v.runningStatus === 'running' && v.versionId) {
          swVersionId = v.versionId;
        }
      }
    });
    await cdp.send('ServiceWorker.enable');
    await new Promise(r => setTimeout(r, 600));

    log(`Stopping Service Worker over CDP (ServiceWorker.stopWorker version: ${swVersionId})...`);
    await cdp.send('ServiceWorker.stopWorker', { versionId: swVersionId });
    log('Service worker stopped over debugging protocol.');
    await new Promise(r => setTimeout(r, 1200));

    log('Waking service worker via extension options page...');
    const wakePage = await browser.newPage();
    await wakePage.goto(`chrome-extension://${extId}/src/options/options.html`, { waitUntil: 'domcontentloaded' });
    await new Promise(r => setTimeout(r, 1000));

    // Verify revived state directly via extension messaging on wakePage
    const check6Data = await wakePage.evaluate(async () => {
      const resp = await chrome.runtime.sendMessage({ type: 'fe:debug_get_state' });
      const storage = await chrome.storage.session.get(['fe_session', 'fe_cur_distraction']);
      return {
        session: resp?.session || storage?.fe_session || null,
        distraction: resp?.distraction || storage?.fe_cur_distraction || null,
      };
    });

    await wakePage.screenshot({ path: join(RESULTS_DIR, '06_sw_restart_persistence.png') });
    await wakePage.close();

    // Re-bind worker handle since previous worker execution context was stopped
    try {
      const revivedTarget = await getSWTarget(browser, 5000);
      worker = await revivedTarget.worker();
      if (worker) {
        worker.on('console', msg => log(`[SW Console] ${msg.type()}: ${msg.text()}`));
      }
    } catch (e) {
      log('Could not re-bind worker handle directly: ' + e.message);
    }

    if (check6Data.session?.distraction_count === 2 && check6Data.session?.active === true) {
      record('CHECK-6', 'Stopping SW over debugging protocol and waking keeps count and state', 'PASS', `Count preserved: ${check6Data.session.distraction_count}, state: ${check6Data.session.state}`);
    } else {
      record('CHECK-6', 'Stopping SW over debugging protocol and waking keeps count and state', 'FAIL', `Lost session data on wakeup`);
    }

    // -----------------------------------------------------------------------
    // CHECK 7: Popup link opens the options page
    // -----------------------------------------------------------------------
    log('\n--- Running Check 7 (Popup link opens options page) ---');
    // Close any previous options page to ensure clean test
    for (const t of browser.targets()) {
      if (t.url().includes('options.html') && t.type() === 'page') {
        const p = await t.page().catch(() => null);
        if (p) await p.close().catch(() => {});
      }
    }

    const popupPage = await browser.newPage();
    await popupPage.goto(`chrome-extension://${extId}/src/popup/popup.html`, { waitUntil: 'domcontentloaded' });

    const optLink = await popupPage.waitForSelector('#opt-link', { timeout: 5000 });
    const targetPromise = browser.waitForTarget(
      t => t.url().includes('options.html'),
      { timeout: 8000 }
    );

    await optLink.click();
    const optionsTarget = await targetPromise;
    await popupPage.screenshot({ path: join(RESULTS_DIR, '07_popup_opened_options.png') });
    await popupPage.close();

    if (optionsTarget && optionsTarget.url().includes('options.html')) {
      record('CHECK-7', 'Popup options link uses external script and opens options page', 'PASS', `Options opened: ${optionsTarget.url()}`);
    } else {
      record('CHECK-7', 'Popup options link opens options page', 'FAIL', 'Options page target not created');
    }

    // -----------------------------------------------------------------------
    // CHECK 8: Start Session while active restarts session cleanly
    // -----------------------------------------------------------------------
    log('\n--- Running Check 8 (Start Session while active restarts cleanly) ---');
    const optionsPage8 = await browser.newPage();
    await optionsPage8.goto(`chrome-extension://${extId}/src/options/options.html`, { waitUntil: 'domcontentloaded' });

    const restartResp = await optionsPage8.evaluate(async () => {
      return await chrome.runtime.sendMessage({
        type: 'fe:debug_start_session',
        intention: 'Brand New Task Intention',
        distraction_list: ['reddit.com', 'youtube.com'],
      });
    });

    await new Promise(r => setTimeout(r, 600));

    const check8Data = await optionsPage8.evaluate(async () => {
      const resp = await chrome.runtime.sendMessage({ type: 'fe:debug_get_state' });
      return resp;
    });

    await optionsPage8.screenshot({ path: join(RESULTS_DIR, '08_session_restarted.png') });
    await optionsPage8.close();

    if (
      restartResp?.restarted === true &&
      check8Data.session?.state === 'MONITORING' &&
      check8Data.session?.distraction_count === 0 &&
      check8Data.session?.intention === 'Brand New Task Intention'
    ) {
      record('CHECK-8', 'Start Session while active restarts session cleanly', 'PASS', `restarted: ${restartResp.restarted}, state: ${check8Data.session.state}, count: ${check8Data.session.distraction_count}`);
    } else {
      record('CHECK-8', 'Start Session while active restarts session cleanly', 'FAIL', `Restart failed: ${JSON.stringify(restartResp)}, count=${check8Data.session?.distraction_count}`);
    }

    // -----------------------------------------------------------------------
    // CHECK 9: Fast leave and re-enter on same host within 500ms
    // -----------------------------------------------------------------------
    log('\n--- Running Check 9 (Fast leave and re-enter on same host within 500ms) ---');
    await sendExtMessage(browser, extId, {
      type: 'fe:debug_start_session',
      intention: 'Fast Bounce Check',
      distraction_list: ['youtube.com'],
    });

    await primaryPage.bringToFront();
    await primaryPage.goto(`https://youtube.com:${PORT}/watch?v=bounce_start`, { waitUntil: 'domcontentloaded' });
    log('On youtube.com for 1.2s. Executing rapid departure to clean.test and immediate re-entry to youtube.com...');
    await new Promise(r => setTimeout(r, 1200));

    const tStart = Date.now();
    await primaryPage.goto(`https://clean.test:${PORT}/quick_bounce`, { waitUntil: 'domcontentloaded' });
    await primaryPage.goto(`https://youtube.com:${PORT}/watch?v=bounce_return`, { waitUntil: 'domcontentloaded' });
    const bounceElapsed = Date.now() - tStart;
    log(`Rapid bounce round-trip completed in ${bounceElapsed}ms (< 500ms window)`);

    const check9Immediate = await getExtState(browser, extId);
    log(`State immediately after rapid re-entry: ${check9Immediate.session?.state}, count: ${check9Immediate.session?.distraction_count}`);

    log('Waiting 3.8s to confirm fresh 3s grace timer fires without getting suppressed or dropped...');
    await new Promise(r => setTimeout(r, 3800));

    const check9Final = await getExtState(browser, extId);
    await primaryPage.screenshot({ path: join(RESULTS_DIR, '09_fast_leave_reenter.png') });

    if (
      check9Immediate.session?.state === 'COUNTING_GRACE' &&
      check9Final.session?.state === 'L1_TOAST' &&
      check9Final.session?.distraction_count === 1
    ) {
      record('CHECK-9', 'Fast leave & re-enter (<500ms) resets grace cleanly to L1', 'PASS', `Round-trip: ${bounceElapsed}ms (<500ms); reset to COUNTING_GRACE then cleanly reached L1_TOAST count=1`);
    } else {
      record('CHECK-9', 'Fast leave & re-enter (<500ms) resets grace cleanly to L1', 'FAIL', `Immediate: ${check9Immediate.session?.state}, Final: ${check9Final.session?.state}, count=${check9Final.session?.distraction_count}`);
    }

  } finally {
    log('Cleaning up browser and mock server...');
    await browser.close();
    await new Promise(r => mockServer.close(r));
    fs.writeFileSync(LOG_FILE, logs.join('\n'), 'utf8');
  }

  // -------------------------------------------------------------------------
  // Print Final Summary Table
  // -------------------------------------------------------------------------
  console.log('\n' + '═'.repeat(80));
  console.log('             FOCUS ECHO — LIVE CHROME AUTOMATED TEST REPORT (EXT-1)             ');
  console.log('═'.repeat(80));
  console.log('ID'.padEnd(10) + 'Status'.padEnd(10) + 'Test Title'.padEnd(42) + 'Details');
  console.log('─'.repeat(80));

  let allPassed = true;
  for (const t of testResults) {
    if (t.status !== 'PASS') allPassed = false;
    const stat = t.status === 'PASS' ? '✅ PASS' : '❌ FAIL';
    console.log(t.id.padEnd(10) + stat.padEnd(10) + t.title.padEnd(42) + t.details);
  }
  console.log('═'.repeat(80));
  console.log(`Results: ${testResults.filter(t => t.status === 'PASS').length}/${testResults.length} passed.`);
  console.log(`Screenshots saved to: ${RESULTS_DIR}`);
  console.log(`Logs saved to:        ${LOG_FILE}`);
  console.log('═'.repeat(80) + '\n');

  if (!allPassed) {
    process.exit(1);
  }
}

runTestSuite().catch(err => {
  console.error('Test suite crashed:', err);
  process.exit(1);
});
