#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Opens Chrome with the FocusEcho extension loaded unpacked and runs
  the Phase 1 SW restart test scenario. Paste the console commands
  manually into the SW DevTools that Chrome opens.

.USAGE
  Right-click → Run with PowerShell  (or: pwsh .\test-phase1.ps1)
#>

$ExtPath = "E:\Project\FocusEcho\browser_extension"

# Find Chrome executable
$ChromePaths = @(
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)
$Chrome = $ChromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $Chrome) {
  Write-Error "Chrome not found. Update the path in this script."
  exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  FocusEcho Phase 1 — Manual Test Guide  " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Launching Chrome with extension loaded..." -ForegroundColor Green
Write-Host "Extension path: $ExtPath" -ForegroundColor Gray
Write-Host ""

# Launch Chrome with the extension loaded via --load-extension
# --auto-open-devtools-for-tabs opens DevTools automatically.
$args = @(
  "--load-extension=`"$ExtPath`"",
  "--auto-open-devtools-for-tabs",
  "--no-first-run",
  "--no-default-browser-check"
)
Start-Process -FilePath $Chrome -ArgumentList $args

Start-Sleep -Seconds 2

Write-Host "STEP-BY-STEP TEST INSTRUCTIONS" -ForegroundColor Yellow
Write-Host "==============================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Chrome is open. Navigate to: chrome://extensions" -ForegroundColor White
Write-Host "   - Enable Developer Mode (top-right toggle)" -ForegroundColor Gray
Write-Host "   - Confirm 'FocusEcho' card appears with no errors" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Click 'Service Worker' link in the FocusEcho card" -ForegroundColor White
Write-Host "   - A DevTools window opens for the SW context" -ForegroundColor Gray
Write-Host "   - Open the Console tab" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Paste TEST A into the SW console:" -ForegroundColor White
Write-Host ""
Write-Host @"
// ── TEST A: Start session ──────────────────────────────────────
chrome.runtime.sendMessage({
  type: 'fe:debug_start_session',
  intention: 'SW restart test',
  distraction_list: ['twitter.com']
}).then(r => console.log('✅ start:', JSON.stringify(r)));
"@ -ForegroundColor Cyan
Write-Host ""
Write-Host "   Expected console output:" -ForegroundColor Gray
Write-Host "   [FE SM]  IDLE --[SESSION_STARTED]--> MONITORING" -ForegroundColor DarkCyan
Write-Host "   [FE ACT] session started | intention: `"SW restart test`"" -ForegroundColor DarkCyan
Write-Host ""

Write-Host "4. Paste TEST B (glance < 3 s — ignored):" -ForegroundColor White
Write-Host ""
Write-Host @"
// ── TEST B: Glance < 3 s ───────────────────────────────────────
chrome.runtime.sendMessage({
  type: 'fe:debug_dispatch', ev_type: 'TAB_ACTIVATED',
  payload: { host: 'twitter.com', isDistracting: true, tabId: 999 }
}).then(r => console.log('entered distraction site'));

// Wait ~1 s then paste the next line:
setTimeout(() => {
  chrome.runtime.sendMessage({
    type: 'fe:debug_dispatch', ev_type: 'TAB_ACTIVATED',
    payload: { host: 'vscode.dev', isDistracting: false, tabId: 998 }
  }).then(r => console.log('left site after ~1s'));
}, 1000);
"@ -ForegroundColor Cyan
Write-Host ""
Write-Host "   Expected: MONITORING → COUNTING_GRACE → MONITORING (grace ignored)" -ForegroundColor Gray
Write-Host "   [FE SM]  MONITORING --[TAB_ACTIVATED:twitter.com]--> COUNTING_GRACE" -ForegroundColor DarkCyan
Write-Host "   [FE SM]  COUNTING_GRACE --[TAB_ACTIVATED:vscode.dev]--> MONITORING" -ForegroundColor DarkCyan
Write-Host "   [FE ACT] grace ignored: visit < 3 000 ms | no count, no overlay" -ForegroundColor DarkCyan
Write-Host ""

Write-Host "5. Paste TEST C (20 s visit → recovery):" -ForegroundColor White
Write-Host ""
Write-Host @"
// ── TEST C: 20 s visit ─────────────────────────────────────────
chrome.runtime.sendMessage({
  type: 'fe:debug_dispatch', ev_type: 'TAB_ACTIVATED',
  payload: { host: 'twitter.com', isDistracting: true, tabId: 999 }
}).then(() => console.log('entered twitter'));

// Simulate grace elapsed (3.1 s):
setTimeout(() => {
  chrome.runtime.sendMessage({
    type: 'fe:debug_dispatch', ev_type: 'HEARTBEAT', payload: {}
  }).then(() => console.log('heartbeat fired — grace should confirm'));
}, 3100);

// Leave site after 20 s total:
setTimeout(() => {
  chrome.runtime.sendMessage({
    type: 'fe:debug_dispatch', ev_type: 'TAB_ACTIVATED',
    payload: { host: 'vscode.dev', isDistracting: false, tabId: 998 }
  }).then(() => console.log('left site after 20s'));
}, 20000);
"@ -ForegroundColor Cyan
Write-Host ""
Write-Host "   Expected over 20 s:" -ForegroundColor Gray
Write-Host "   [FE SM]  MONITORING --[TAB_ACTIVATED:twitter.com]--> COUNTING_GRACE" -ForegroundColor DarkCyan
Write-Host "   [FE SM]  COUNTING_GRACE --[HEARTBEAT]--> L1_TOAST  | actions: [INCREMENT_DISTRACTION_COUNT, CONFIRM_GRACE, SHOW_OVERLAY:1, EMIT_DISTRACTION_EVENT:1]" -ForegroundColor DarkCyan
Write-Host "   [FE ACT] distractionCount → 1" -ForegroundColor DarkCyan
Write-Host "   [FE ACT] ▶ SHOW_OVERLAY level 1" -ForegroundColor DarkCyan
Write-Host "   (20 s later)" -ForegroundColor DarkGray
Write-Host "   [FE SM]  L1_TOAST --[TAB_ACTIVATED:vscode.dev]--> MONITORING" -ForegroundColor DarkCyan
Write-Host "   [FE ACT] recovery event: recovery | time_on_site: ~20000 ms" -ForegroundColor DarkCyan
Write-Host ""

Write-Host "6. NOW STOP THE SERVICE WORKER:" -ForegroundColor Yellow
Write-Host "   Open a NEW tab → navigate to: chrome://serviceworker-internals" -ForegroundColor White
Write-Host "   Find 'FocusEcho' → click [Stop]" -ForegroundColor White
Write-Host "   The SW DevTools console will go silent." -ForegroundColor Gray
Write-Host ""

Write-Host "7. Paste TEST D in the SW console (will wake the SW):" -ForegroundColor White
Write-Host ""
Write-Host @"
// ── TEST D: Re-entry after SW restart ─────────────────────────
chrome.runtime.sendMessage({
  type: 'fe:debug_dispatch', ev_type: 'TAB_ACTIVATED',
  payload: { host: 'twitter.com', isDistracting: true, tabId: 999 }
}).then(r => console.log('post-restart result:', JSON.stringify(r)));
"@ -ForegroundColor Cyan
Write-Host ""
Write-Host "   Expected on SW restart:" -ForegroundColor Gray
Write-Host "   [FE SW]  activated — reconstructing state from storage" -ForegroundColor DarkCyan
Write-Host "   [FE SW]  state on wake: MONITORING | count: 1" -ForegroundColor DarkCyan
Write-Host "   [FE SM]  MONITORING --[TAB_ACTIVATED:twitter.com]--> COUNTING_GRACE" -ForegroundColor DarkCyan
Write-Host "   [FE ACT] distractionCount → 2  (count persisted across SW restart!)" -ForegroundColor DarkCyan
Write-Host "   [FE ACT] ▶ SHOW_OVERLAY level 2  (L2 because count=2)" -ForegroundColor DarkCyan
Write-Host ""

Write-Host "8. Paste TEST E (read final state):" -ForegroundColor White
Write-Host ""
Write-Host @"
// ── TEST E: Read state ─────────────────────────────────────────
chrome.runtime.sendMessage({ type: 'fe:debug_get_state' })
  .then(r => console.log(JSON.stringify(r, null, 2)));
"@ -ForegroundColor Cyan
Write-Host ""
Write-Host "   Expected: session.distraction_count = 2, state = L2_OVERLAY" -ForegroundColor Gray
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Copy the console output and share it.  " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
