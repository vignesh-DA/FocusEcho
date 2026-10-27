// Replays real-use browsing sequences against the actual service-worker.js using a fake chrome API.
// Run all:   node tests/replay-real-use.mjs
// Not a substitute for real Chrome (run the live test too), but it catches logic gaps the live harness missed
// (switching tabs, leaving to chrome:// pages, starting a session while already on a site, alt-tab during grace).
import { spawn } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const SCENARIOS = [
  'S1_switch_to_youtube', 'S2_leave_to_new_tab', 'S3_leave_to_own_page_is_ignored', 'S4_start_while_on_youtube',
  'S5_alt_tab_during_grace', 'S6_leave_to_real_site', 'S7_glance_then_new_tab', 'S8_start_on_productive_site',
  'S9_events_visible_in_debug_state',
];

if (!process.argv[2]) {
  const self = fileURLToPath(import.meta.url);
  const runs = SCENARIOS.map(s => new Promise(res => {
    let out = ''; const p = spawn(process.execPath, [self, s], { env: process.env });
    p.stdout.on('data', d => out += d); p.stderr.on('data', d => out += d);
    p.on('close', code => res({ s, code, out }));
  }));
  const results = await Promise.all(runs);
  let failed = 0;
  for (const r of results) { console.log(r.out.split('\n').filter(l => l.startsWith('==') || l.includes('PASS') || l.includes('FAIL')).join('\n')); if (r.code) failed++; }
  console.log(`\n${SCENARIOS.length - failed}/${SCENARIOS.length} scenarios passed`);
  process.exit(failed ? 1 : 0);
}

// ---------------- child: one scenario in a fresh process ----------------
const mkStore = () => { const d = {}; return {
  async get(k){ if(k==null) return {...d}; const keys=Array.isArray(k)?k:[k]; const o={}; for(const x of keys) if(x in d) o[x]=d[x]; return o; },
  async set(o){ Object.assign(d,o); }, async remove(k){ for(const x of (Array.isArray(k)?k:[k])) delete d[x]; } }; };
const L = {}; const ev = n => ({ addListener: f => (L[n] ??= []).push(f) });
const OWN = 'chrome-extension://abc/';
const tabs = {
  1: { id:1, url: OWN + 'src/options/options.html', windowId:1 },
  2: { id:2, url:'https://www.youtube.com/', windowId:1 },
  3: { id:3, url:'chrome://newtab/', windowId:1 },
  4: { id:4, url:'https://docs.google.com/document/d/x', windowId:1 },
};
let activeId = 1;
globalThis.self = globalThis;
self.addEventListener = () => {}; self.skipWaiting = () => {}; self.clients = { claim: async () => {} };
globalThis.chrome = {
  storage: { session: mkStore(), local: mkStore() },
  notifications: {
    create: async () => {}, clear: async () => true,
    onClicked: ev('notification-click'),
  },
  alarms: { get: async () => undefined, create: async () => {}, clear: async () => {}, onAlarm: ev('alarm') },
  idle: { setDetectionInterval(){}, onStateChanged: ev('idle') },
  windows: { WINDOW_ID_NONE: -1, onFocusChanged: ev('winfocus') },
  webNavigation: { onHistoryStateUpdated: ev('hist'), onCommitted: ev('commit') },
  tabs: { onActivated: ev('act'), onRemoved: ev('rem'), onUpdated: ev('upd'),
    async get(id){ return { ...tabs[id], active: id===activeId }; },
    async query(){ return [{ ...tabs[activeId], active:true }]; },
    async update(id){ activeId=id; }, async create(){ return {id:99}; } },
  runtime: { onMessage: ev('msg'), getURL: p => OWN + (p ?? '') },
};
const SW = process.env.SW_PATH ? pathToFileURL(process.env.SW_PATH).href : new URL('../src/background/service-worker.js', import.meta.url).href;
await import(SW);

const sleep = ms => new Promise(r => setTimeout(r, ms));
const send = msg => new Promise(res => L.msg[0](msg, {}, res));
const switchTo = async id => { activeId = id; for (const f of L.act) await f({ tabId:id, windowId:1 }); await sleep(40); };
const start = async () => { await send({ type:'fe:debug_start_session', intention:'study', distraction_list:['youtube.com'] }); await sleep(40); };
const sess = () => self.__fe.loadSession();
let bad = 0;
const check = async (label, want, extra) => {
  const s = await sess(); const got = `${s?.state}/${s?.distraction_count}`;
  const ok = got === want && (!extra || extra(s));
  if (!ok) bad++;
  console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${label}  (want ${want}, got ${got})`);
};
console.log(`== ${process.argv[2]}`);
const sc = process.argv[2];
if (sc === 'S1_switch_to_youtube') { await start(); await switchTo(2); await sleep(3600); await check('options tab -> YouTube, wait 3.6s', 'L1_TOAST/1'); }
if (sc === 'S2_leave_to_new_tab') { await start(); await switchTo(2); await sleep(3600); await switchTo(3); await check('L1 on YouTube, then open New Tab page', 'MONITORING/1'); }
if (sc === 'S3_leave_to_own_page_is_ignored') { await start(); await switchTo(2); await sleep(3600); await switchTo(1); await check('L1 on YouTube, then open the debug options page (ignored)', 'L1_TOAST/1'); }
if (sc === 'S4_start_while_on_youtube') { activeId = 2; await start(); await sleep(3600); await check('press Start while already on YouTube, wait 3.6s', 'L1_TOAST/1'); }
if (sc === 'S5_alt_tab_during_grace') { await start(); await switchTo(2); for (const f of L.winfocus) await f(-1); await sleep(40);
  await sleep(3600); for (const f of L.winfocus) await f(1); await sleep(3600); await check('alt-tab away for 3.6s mid-grace, return, wait 3.6s', 'L1_TOAST/1'); }
if (sc === 'S6_leave_to_real_site') { await start(); await switchTo(2); await sleep(3600); await switchTo(4); await check('L1 on YouTube, then Google Docs', 'MONITORING/1'); }
if (sc === 'S7_glance_then_new_tab') { await start(); await switchTo(2); await sleep(1000); await switchTo(3); await check('1s glance at YouTube, then New Tab (ignored)', 'MONITORING/0'); }
if (sc === 'S8_start_on_productive_site') { activeId = 4; await start(); await check('press Start on Google Docs', 'MONITORING/0', s => s.last_productive_tab_id === 4); }
if (sc === 'S9_events_visible_in_debug_state') { await start(); await switchTo(2); await sleep(3600);
  const r = await send({ type:'fe:debug_get_state' }); const e = (r.recent_events ?? []).find(x => x.event_type === 'distraction');
  const ok = !!e && e.domain === 'youtube.com' && !('url' in e); if (!ok) bad++;
  console.log(`  ${ok ? 'PASS' : 'FAIL'}  debug state lists the distraction event (domain only)  (got ${JSON.stringify(r.recent_events ?? null)})`); }
process.exit(bad ? 1 : 0);
