import assert from 'node:assert/strict';

const calls = [];
let clickListener;
globalThis.chrome = {
  runtime: { getURL: (path) => `chrome-extension://test/${path}` },
  notifications: {
    create: async (id, options) => { calls.push(['create', id, options]); },
    clear: async (id) => { calls.push(['clear', id]); return true; },
    onClicked: { addListener: (listener) => { clickListener = listener; } },
  },
  alarms: {
    create: async (name, options) => { calls.push(['alarm-create', name, options]); },
    clear: async (name) => { calls.push(['alarm-clear', name]); return true; },
  },
  storage: { local: { get: async () => ({ fe_dashboard_tab_id: 7 }) } },
  tabs: {
    get: async (id) => ({ id, windowId: 9 }),
    update: async (...args) => { calls.push(['tab-update', ...args]); },
    create: async (...args) => { calls.push(['tab-create', ...args]); },
  },
  windows: { update: async (...args) => { calls.push(['window-update', ...args]); } },
};

const notifications = await import('../src/background/desktop-notifications.js');

await notifications.showDistractionNotification(
  { active: true, state: 'L1_TOAST', intention: 'private intention' },
  { host: 'reddit.com', level: 2 },
  2,
);
const first = calls.find(([kind]) => kind === 'create');
assert.equal(first[1], notifications.DISTRACTION_NOTIFICATION_ID);
assert.match(first[2].title, /reddit\.com/);
assert.doesNotMatch(JSON.stringify(first[2]), /private intention/);
assert.deepEqual(
  calls.find(([kind]) => kind === 'alarm-create').slice(1),
  ['fe-distraction-nudge', { delayInMinutes: 0.5, periodInMinutes: 0.5 }],
);

calls.length = 0;
const active = await notifications.repeatDistractionNotification(
  async () => ({ active: true, state: 'COUNTING' }),
  async () => ({ host: 'reddit.com', level: 3 }),
);
assert.equal(active, true);
assert.equal(calls.filter(([kind]) => kind === 'create').length, 1);

calls.length = 0;
const paused = await notifications.repeatDistractionNotification(
  async () => ({ active: true, state: 'PAUSED' }),
  async () => ({ host: 'reddit.com', level: 3 }),
);
assert.equal(paused, false);
assert.deepEqual(calls.map(([kind]) => kind), ['alarm-clear', 'clear']);

calls.length = 0;
assert.equal(await notifications.focusDashboardFromNotification('other'), false);
assert.equal(await notifications.focusDashboardFromNotification(
  notifications.DISTRACTION_NOTIFICATION_ID,
), true);
assert.deepEqual(calls.map(([kind]) => kind), ['tab-update', 'window-update']);

console.log('Desktop notification checks: 4 passed, 0 failed.');
