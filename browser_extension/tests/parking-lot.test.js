import assert from 'node:assert/strict';
import fs from 'node:fs';

const popup = fs.readFileSync(new URL('../src/popup/popup.js', import.meta.url), 'utf8');
const html = fs.readFileSync(new URL('../src/popup/popup.html', import.meta.url), 'utf8');
const worker = fs.readFileSync(new URL('../src/background/service-worker.js', import.meta.url), 'utf8');
const bridge = fs.readFileSync(new URL('../src/content/bridge.js', import.meta.url), 'utf8');

assert.match(html, /input-parking/);
assert.match(html, /parking-list/);
assert.match(popup, /fe:parking_add/);
assert.match(popup, /fe:parking_remove/);
assert.match(popup, /textContent = item/);
assert.match(worker, /fe:parking_set/);
assert.match(worker, /slice\(0, 20\)/);
assert.match(worker, /slice\(0, 120\)/);
assert.match(bridge, /fe:parking_items/);

console.log('PASS: parking lot popup, worker limits, safe rendering, and bridge wiring are present.');
