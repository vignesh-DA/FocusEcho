#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Opens Chrome with the FocusEcho extension loaded unpacked.
  Works with: regular Chrome (branded), Chrome for Testing, or Chromium.

.NOTES
  IMPORTANT: Regular branded Chrome (136+) disables --load-extension by policy
  in some OS/channel combinations. This script tries multiple strategies:
    1. Chrome for Testing (recommended — always supports --load-extension)
    2. Chrome Canary (usually supports it)
    3. Regular Chrome with the flag (works on most Windows installs)
    4. Fallback: manual instructions

.USAGE
  Right-click → Run with PowerShell  (or: pwsh .\test-phase1.ps1)
#>

param(
  [string]$DashboardOrigin = "https://focusecho-app.vercel.app"
)

$ExtPath = "E:\Project\FocusEcho\browser_extension"

# ---------------------------------------------------------------------------
# 1. Find a usable Chrome binary
# ---------------------------------------------------------------------------
$ChromeForTestingPaths = @(
  "$env:LOCALAPPDATA\Google\Chrome for Testing\Application\chrome.exe",
  "C:\Program Files\Google\Chrome for Testing\Application\chrome.exe",
  "$env:LOCALAPPDATA\chrome-for-testing\chrome-win64\chrome.exe"
)
$ChromeCanaryPaths = @(
  "$env:LOCALAPPDATA\Google\Chrome SxS\Application\chrome.exe"
)
$ChromeStablePaths = @(
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)

$CfT    = $ChromeForTestingPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
$Canary = $ChromeCanaryPaths     | Where-Object { Test-Path $_ } | Select-Object -First 1
$Stable = $ChromeStablePaths     | Where-Object { Test-Path $_ } | Select-Object -First 1

$Chrome     = $null
$ChromeType = $null

if ($CfT)    { $Chrome = $CfT;    $ChromeType = "Chrome for Testing (guaranteed support)" }
elseif ($Canary) { $Chrome = $Canary; $ChromeType = "Chrome Canary (usually supports --load-extension)" }
elseif ($Stable) { $Chrome = $Stable; $ChromeType = "Chrome stable (may require policy override — see fallback below)" }

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  FocusEcho Phase 1 — Extension Test Launcher  " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# 2. If no Chrome found, offer to download Chrome for Testing
# ---------------------------------------------------------------------------
if (-not $Chrome) {
  Write-Host "❌ No Chrome binary found." -ForegroundColor Red
  Write-Host ""
  Write-Host "Option A — Download Chrome for Testing (recommended):" -ForegroundColor Yellow
  Write-Host "  https://googlechromelabs.github.io/chrome-for-testing/" -ForegroundColor Gray
  Write-Host "  Download the 'chrome' zip for your platform, extract to a folder," -ForegroundColor Gray
  Write-Host "  then re-run this script." -ForegroundColor Gray
  Write-Host ""
  Write-Host "Option B — Manual load (always works):" -ForegroundColor Yellow
  _PrintManualInstructions
  exit 1
}

Write-Host "Chrome binary: $ChromeType" -ForegroundColor Green
Write-Host "Path:          $Chrome" -ForegroundColor Gray
Write-Host "Extension:     $ExtPath" -ForegroundColor Gray
Write-Host ""

# ---------------------------------------------------------------------------
# 3. Try launching Chrome with --load-extension
# ---------------------------------------------------------------------------
$ChromeArgs = @(
  "--load-extension=`"$ExtPath`"",
  "--no-first-run",
  "--no-default-browser-check"
)

Write-Host "Launching Chrome..." -ForegroundColor Green
try {
  Start-Process -FilePath $Chrome -ArgumentList $ChromeArgs -ErrorAction Stop
} catch {
  Write-Host ""
  Write-Host "⚠ Launch failed. If Chrome shows 'Extensions disabled' or ignores the flag:" -ForegroundColor Yellow
  Write-Host "  This is a policy restriction in branded Chrome builds." -ForegroundColor Gray
  Write-Host "  Use the manual load method below instead." -ForegroundColor Gray
  Write-Host ""
  _PrintManualInstructions
  exit 1
}

Start-Sleep -Seconds 2

# ---------------------------------------------------------------------------
# 4. Show the full test script
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "WHAT TO DO NEXT:" -ForegroundColor Yellow
Write-Host "  1. In Chrome → navigate to chrome://extensions" -ForegroundColor White
Write-Host "     If 'FocusEcho' is NOT listed, use manual load (see below)." -ForegroundColor Gray
Write-Host "  2. Click the 'Service Worker' link in the FocusEcho card." -ForegroundColor White
Write-Host "  3. In the SW DevTools Console tab, paste tests A–E below." -ForegroundColor White
Write-Host ""
Write-Host "═══════════════ TEST A — Start session ════════════════" -ForegroundColor Cyan
Write-Host @"
chrome.runtime.sendMessage({
  type: 'fe:debug_start_session',
  intention: 'SW restart test',
  distraction_list: ['twitter.com']
}).then(r => console.log('✅ start:', JSON.stringify(r)));
"@ -ForegroundColor White
Write-Host "Expected logs:" -ForegroundColor Gray
Write-Host "  [FE SM]  IDLE --[SESSION_STARTED]--> MONITORING" -ForegroundColor DarkCyan
Write-Host "  [FE ACT] session started | intention: `"SW restart test`"" -ForegroundColor DarkCyan
Write-Host ""

Write-Host "════════ TEST B — Glance <3s (SCENARIO 1 = ignored) ═══" -ForegroundColor Cyan
Write-Host @"
chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'TAB_ACTIVATED',
  payload:{host:'twitter.com',isDistracting:true,tabId:999}}).then(()=>{
  setTimeout(()=>{
    chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'TAB_ACTIVATED',
      payload:{host:'vscode.dev',isDistracting:false,tabId:998}})
      .then(()=>console.log('left after 1s'));
  }, 1000);
});
"@ -ForegroundColor White
Write-Host "Expected:" -ForegroundColor Gray
Write-Host "  [FE SM]  MONITORING --[TAB_ACTIVATED:twitter.com]--> COUNTING_GRACE" -ForegroundColor DarkCyan
Write-Host "  [FE SM]  COUNTING_GRACE --[TAB_ACTIVATED:vscode.dev]--> MONITORING" -ForegroundColor DarkCyan
Write-Host "  [FE ACT] grace ignored: visit < 3 000 ms | no count, no overlay" -ForegroundColor DarkCyan
Write-Host ""

Write-Host "════════ TEST C — 20s visit (SCENARIO 2) ══════════════" -ForegroundColor Cyan
Write-Host @"
// Enter distraction site, wait 3.1s, send heartbeat (confirms grace), leave at 20s
chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'TAB_ACTIVATED',
  payload:{host:'twitter.com',isDistracting:true,tabId:999}})
  .then(()=>console.log('entered twitter.com'));

setTimeout(()=>{
  chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'HEARTBEAT',payload:{}})
    .then(()=>console.log('heartbeat — grace confirmed, count=1, L1 expected'));
}, 3100);

setTimeout(()=>{
  chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'TAB_ACTIVATED',
    payload:{host:'vscode.dev',isDistracting:false,tabId:998}})
    .then(()=>console.log('left at 20s — recovery expected'));
}, 20000);
"@ -ForegroundColor White
Write-Host "Expected at 3.1s:" -ForegroundColor Gray
Write-Host "  [FE SM]  COUNTING_GRACE --[HEARTBEAT]--> L1_TOAST" -ForegroundColor DarkCyan
Write-Host "  [FE ACT] distractionCount → 1" -ForegroundColor DarkCyan
Write-Host "  [FE ACT] ▶ SHOW_OVERLAY level 1" -ForegroundColor DarkCyan
Write-Host "Expected at 20s:" -ForegroundColor Gray
Write-Host "  [FE SM]  L1_TOAST --[TAB_ACTIVATED:vscode.dev]--> MONITORING" -ForegroundColor DarkCyan
Write-Host "  [FE ACT] recovery event: recovery | time_on_site: ~16900 ms" -ForegroundColor DarkCyan
Write-Host ""

Write-Host "════════ TEST D — Re-entry (SCENARIO 3 = count+1, L2) =" -ForegroundColor Cyan
Write-Host @"
chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'TAB_ACTIVATED',
  payload:{host:'twitter.com',isDistracting:true,tabId:999}})
  .then(()=>console.log('re-entered twitter.com'));

setTimeout(()=>{
  chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'HEARTBEAT',payload:{}})
    .then(()=>console.log('heartbeat — count=2, L2 expected'));
}, 3100);
"@ -ForegroundColor White
Write-Host "Expected: count=2 → L2_OVERLAY" -ForegroundColor DarkCyan
Write-Host ""

Write-Host "════════ TEST E — SW STOP + RESTART ═══════════════════" -ForegroundColor Cyan
Write-Host "  1. Open a new tab → chrome://serviceworker-internals" -ForegroundColor White
Write-Host "  2. Find 'FocusEcho' → click [Stop]" -ForegroundColor White
Write-Host "  3. Come back to the SW DevTools console and paste:" -ForegroundColor White
Write-Host @"
chrome.runtime.sendMessage({type:'fe:debug_get_state'})
  .then(r=>console.log('state after restart:', JSON.stringify(r, null, 2)));
"@ -ForegroundColor White
Write-Host "Expected on restart:" -ForegroundColor Gray
Write-Host "  [FE SW]  activated — reconstructing state from storage" -ForegroundColor DarkCyan
Write-Host "  [FE SW]  state on wake: L2_OVERLAY | count: 2" -ForegroundColor DarkCyan
Write-Host "  state.session.distraction_count === 2 (persisted across SW death)" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Share the console output above when done." -ForegroundColor Yellow
Write-Host ""

# ---------------------------------------------------------------------------
# 5. Manual fallback — always shown at the bottom
# ---------------------------------------------------------------------------
Write-Host "─── MANUAL LOAD FALLBACK ───────────────────────────────" -ForegroundColor DarkGray
Write-Host "If --load-extension is blocked by Chrome policy:" -ForegroundColor Gray
Write-Host "  1. Open Chrome → chrome://extensions" -ForegroundColor Gray
Write-Host "  2. Enable Developer Mode (toggle, top-right)" -ForegroundColor Gray
Write-Host "  3. Click 'Load unpacked'" -ForegroundColor Gray
Write-Host "  4. Select folder: $ExtPath" -ForegroundColor Gray
Write-Host "  5. Click 'Service Worker' in the FocusEcho card to open SW DevTools" -ForegroundColor Gray
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray

function _PrintManualInstructions {
  Write-Host ""
  Write-Host "MANUAL LOAD:" -ForegroundColor Yellow
  Write-Host "  1. Open Chrome" -ForegroundColor White
  Write-Host "  2. Navigate to: chrome://extensions" -ForegroundColor White
  Write-Host "  3. Enable Developer Mode (toggle top-right)" -ForegroundColor White
  Write-Host "  4. Click 'Load unpacked'" -ForegroundColor White
  Write-Host "  5. Select: $ExtPath" -ForegroundColor White
  Write-Host "  6. Click the 'Service Worker' link to open SW DevTools" -ForegroundColor White
}
