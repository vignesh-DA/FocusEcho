<#
.SYNOPSIS
  Opens Chrome with the FocusEcho extension loaded unpacked.
  ASCII-only: safe on Windows PowerShell 5.1 (no BOM required).

.NOTES
  --load-extension is blocked in some branded Chrome builds (136+).
  Strategy: try Chrome for Testing first (always works), then Canary,
  then stable Chrome, then print manual load instructions.

.USAGE
  Right-click -> Run with PowerShell  (or: pwsh .\test-phase1.ps1)
#>

$ExtPath = "E:\Project\FocusEcho\browser_extension"

# ---------------------------------------------------------------------------
# Find a usable Chrome binary
# ---------------------------------------------------------------------------
$CfTPaths = @(
  "$env:LOCALAPPDATA\Google\Chrome for Testing\Application\chrome.exe",
  "C:\Program Files\Google\Chrome for Testing\Application\chrome.exe",
  "$env:LOCALAPPDATA\chrome-for-testing\chrome-win64\chrome.exe"
)
$CanaryPaths = @(
  "$env:LOCALAPPDATA\Google\Chrome SxS\Application\chrome.exe"
)
$StablePaths = @(
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)

$Chrome = $null
$ChromeType = $null

$c = $CfTPaths    | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($c) { $Chrome = $c; $ChromeType = "Chrome for Testing (guaranteed --load-extension support)" }

if (-not $Chrome) {
  $c = $CanaryPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($c) { $Chrome = $c; $ChromeType = "Chrome Canary" }
}

if (-not $Chrome) {
  $c = $StablePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($c) { $Chrome = $c; $ChromeType = "Chrome stable (may be blocked by policy -- see fallback below)" }
}

Write-Host ""
Write-Host "=============================================="
Write-Host "  FocusEcho Phase 1 -- Extension Test Guide"
Write-Host "=============================================="
Write-Host ""

if (-not $Chrome) {
  Write-Host "ERROR: No Chrome binary found."
  Write-Host ""
  Write-Host "Download Chrome for Testing (recommended):"
  Write-Host "  https://googlechromelabs.github.io/chrome-for-testing/"
  Write-Host "  Extract the chrome-win64 zip, then re-run this script."
  Write-Host ""
  Write-Host "Or use the manual load method:"
  Write-Host "  1. Open regular Chrome"
  Write-Host "  2. Go to chrome://extensions"
  Write-Host "  3. Enable Developer Mode (top-right toggle)"
  Write-Host "  4. Click 'Load unpacked' and select: $ExtPath"
  Write-Host "  5. Click 'Service Worker' in the FocusEcho card"
  exit 1
}

Write-Host "Chrome: $ChromeType"
Write-Host "Path:   $Chrome"
Write-Host "Ext:    $ExtPath"
Write-Host ""
Write-Host "Launching..."

Start-Process -FilePath $Chrome -ArgumentList @(
  "--load-extension=`"$ExtPath`"",
  "--no-first-run",
  "--no-default-browser-check"
)

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "--- NEXT STEPS ---"
Write-Host ""
Write-Host "1. In Chrome go to: chrome://extensions"
Write-Host "   Confirm 'FocusEcho' card appears with no errors."
Write-Host "   If the extension is not listed, use the manual load method below."
Write-Host ""
Write-Host "2. Click 'Service Worker' in the FocusEcho card to open SW DevTools."
Write-Host "   Switch to the Console tab."
Write-Host ""

Write-Host "--- TEST A: Start session ---"
Write-Host ""
Write-Host @'
chrome.runtime.sendMessage({
  type: 'fe:debug_start_session',
  intention: 'SW restart test',
  distraction_list: ['twitter.com']
}).then(r => console.log('start:', JSON.stringify(r)));
'@
Write-Host ""
Write-Host "Expected:"
Write-Host "  [FE SM]  IDLE --[SESSION_STARTED]--> MONITORING"
Write-Host "  [FE ACT] session started | intention: `"SW restart test`""
Write-Host ""

Write-Host "--- TEST B: Glance < 3s (should be ignored, no count) ---"
Write-Host ""
Write-Host @'
chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'TAB_ACTIVATED',
  payload:{host:'twitter.com',isDistracting:true,tabId:999}})
  .then(()=>{
    setTimeout(()=>{
      chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'TAB_ACTIVATED',
        payload:{host:'vscode.dev',isDistracting:false,tabId:998}})
        .then(()=>console.log('left after 1s'));
    }, 1000);
  });
'@
Write-Host ""
Write-Host "Expected:"
Write-Host "  [FE SM]  MONITORING --[TAB_ACTIVATED:twitter.com]--> COUNTING_GRACE"
Write-Host "  [FE SM]  COUNTING_GRACE --[TAB_ACTIVATED:vscode.dev]--> MONITORING"
Write-Host "  [FE ACT] grace ignored: visit < 3 000 ms | no count, no overlay"
Write-Host ""

Write-Host "--- TEST C: 20s visit -> L1 -> recovery ---"
Write-Host ""
Write-Host @'
chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'TAB_ACTIVATED',
  payload:{host:'twitter.com',isDistracting:true,tabId:999}})
  .then(()=>console.log('entered twitter.com'));

setTimeout(()=>{
  chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'HEARTBEAT',payload:{}})
    .then(()=>console.log('heartbeat -- grace confirmed, count=1, L1 expected'));
}, 3100);

setTimeout(()=>{
  chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'TAB_ACTIVATED',
    payload:{host:'vscode.dev',isDistracting:false,tabId:998}})
    .then(()=>console.log('left at 20s -- recovery expected'));
}, 20000);
'@
Write-Host ""
Write-Host "Expected at 3.1s:"
Write-Host "  [FE SM]  COUNTING_GRACE --[HEARTBEAT]--> L1_TOAST"
Write-Host "  [FE ACT] distractionCount -> 1"
Write-Host "  [FE ACT] SHOW_OVERLAY level 1"
Write-Host "Expected at 20s:"
Write-Host "  [FE SM]  L1_TOAST --[TAB_ACTIVATED:vscode.dev]--> MONITORING"
Write-Host "  [FE ACT] recovery event: recovery | time_on_site: ~16900 ms"
Write-Host ""

Write-Host "--- TEST D: Re-entry -> count=2 -> L2 ---"
Write-Host ""
Write-Host @'
chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'TAB_ACTIVATED',
  payload:{host:'twitter.com',isDistracting:true,tabId:999}})
  .then(()=>console.log('re-entered twitter.com'));

setTimeout(()=>{
  chrome.runtime.sendMessage({type:'fe:debug_dispatch',ev_type:'HEARTBEAT',payload:{}})
    .then(()=>console.log('heartbeat -- count=2, L2 expected'));
}, 3100);
'@
Write-Host ""
Write-Host "Expected: count=2 -> L2_OVERLAY, SHOW_OVERLAY:2"
Write-Host ""

Write-Host "--- TEST E: SW Stop + Restart ---"
Write-Host ""
Write-Host "  Step 1: Open a new tab -> chrome://serviceworker-internals"
Write-Host "  Step 2: Find 'FocusEcho' -> click [Stop]"
Write-Host "  Step 3: Back in SW DevTools console, paste:"
Write-Host ""
Write-Host @'
chrome.runtime.sendMessage({type:'fe:debug_get_state'})
  .then(r=>console.log('state after restart:', JSON.stringify(r, null, 2)));
'@
Write-Host ""
Write-Host "Expected on SW restart:"
Write-Host "  [FE SW]  activated -- reconstructing state from storage"
Write-Host "  [FE SW]  state on wake: L2_OVERLAY | count: 2"
Write-Host "  session.distraction_count === 2  (persisted across SW death)"
Write-Host ""

Write-Host "=============================================="
Write-Host "  Share the console output when done."
Write-Host "=============================================="
Write-Host ""
Write-Host "--- MANUAL LOAD FALLBACK (if --load-extension is blocked) ---"
Write-Host "  1. Open Chrome -> chrome://extensions"
Write-Host "  2. Enable Developer Mode (top-right toggle)"
Write-Host "  3. Click 'Load unpacked'"
Write-Host "  4. Select: $ExtPath"
Write-Host "  5. Click 'Service Worker' in the FocusEcho card -> Console tab"
Write-Host "-------------------------------------------------------------"
