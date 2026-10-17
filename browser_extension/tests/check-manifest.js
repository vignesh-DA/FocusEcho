/**
 * @fileoverview Manifest integrity checker.
 * Walks manifest.json and verifies every referenced file exists on disk.
 * Fails with exit code 1 if any file is missing.
 *
 * Checks:
 *   background.service_worker
 *   action.default_popup
 *   action.default_icon  (all sizes)
 *   options_page
 *   content_scripts[].js[]
 *   content_scripts[].css[]
 *   web_accessible_resources[].resources[]  (skips wildcards)
 *
 * Usage:  node browser_extension/tests/check-manifest.js
 */

import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const EXT_ROOT  = join(__dirname, '..');
const MANIFEST  = join(EXT_ROOT, 'manifest.json');

// ---------------------------------------------------------------------------
// Load manifest (strip _comment keys — they are not valid JSON in MV3 but
// Chrome silently ignores them; JSON.parse handles them fine as regular keys)
// ---------------------------------------------------------------------------
const raw      = readFileSync(MANIFEST, 'utf8');
const manifest = JSON.parse(raw);

const missing  = [];
const checked  = [];

function check(relPath, context) {
  if (!relPath || typeof relPath !== 'string') return;
  // Skip globs / wildcards
  if (relPath.includes('*')) return;
  const abs = join(EXT_ROOT, relPath);
  const ok  = existsSync(abs);
  checked.push({ relPath, context, ok });
  if (!ok) missing.push({ relPath, context });
}

// ---------------------------------------------------------------------------
// Walk the manifest
// ---------------------------------------------------------------------------

// background.service_worker
if (manifest.background?.service_worker) {
  check(manifest.background.service_worker, 'background.service_worker');
}

// action icons and popup
if (manifest.action) {
  if (manifest.action.default_popup) {
    check(manifest.action.default_popup, 'action.default_popup');
  }
  if (manifest.action.default_icon) {
    for (const [size, path] of Object.entries(manifest.action.default_icon)) {
      check(path, `action.default_icon[${size}]`);
    }
  }
}

// options_page / options_ui
if (manifest.options_page) {
  check(manifest.options_page, 'options_page');
}
if (manifest.options_ui?.page) {
  check(manifest.options_ui.page, 'options_ui.page');
}

// content_scripts
for (const [i, cs] of (manifest.content_scripts ?? []).entries()) {
  for (const js of cs.js ?? []) {
    check(js, `content_scripts[${i}].js`);
  }
  for (const css of cs.css ?? []) {
    check(css, `content_scripts[${i}].css`);
  }
}

// web_accessible_resources (Phase 2+)
for (const [i, war] of (manifest.web_accessible_resources ?? []).entries()) {
  for (const res of war.resources ?? []) {
    check(res, `web_accessible_resources[${i}]`);
  }
}

// icons (top-level icons object, separate from action icons)
if (manifest.icons) {
  for (const [size, path] of Object.entries(manifest.icons)) {
    check(path, `icons[${size}]`);
  }
}

// Referenced HTML script tags
const htmlFiles = [manifest.action?.default_popup, manifest.options_page, manifest.options_ui?.page].filter(Boolean);
for (const htmlRel of htmlFiles) {
  const htmlAbs = join(EXT_ROOT, htmlRel);
  if (existsSync(htmlAbs)) {
    const htmlContent = readFileSync(htmlAbs, 'utf8');
    const scriptMatches = [...htmlContent.matchAll(/<script\s+[^>]*src=["']([^"']+)["']/gi)];
    for (const match of scriptMatches) {
      const scriptRel = join(dirname(htmlRel), match[1]).replace(/\\/g, '/');
      check(scriptRel, `${htmlRel} -> script src`);
    }
  }
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------
console.log('\n--- Manifest Integrity Check ---');
console.log(`Extension root: ${EXT_ROOT}`);
console.log(`Manifest:       ${MANIFEST}`);
console.log('');

for (const { relPath, context, ok } of checked) {
  console.log(`  ${ok ? '[OK]  ' : '[MISS]'} ${context.padEnd(36)} ${relPath}`);
}

console.log('');
console.log(`Checked: ${checked.length}  |  Missing: ${missing.length}`);

if (missing.length > 0) {
  console.log('');
  console.error('FAILED: the following manifest-referenced files do not exist:');
  for (const { relPath, context } of missing) {
    console.error(`  [MISS] ${context}: ${relPath}`);
  }
  process.exit(1);
} else {
  console.log('PASS: all manifest-referenced files exist.\n');
}
