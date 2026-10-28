<#
FocusEcho backend API checks (security, authorization, validation, CORS, latency).
ASCII-only so it parses on Windows PowerShell 5.1 and PowerShell 7.

USAGE
  .\backend_checks.ps1 -Supa https://YOUR-PROJECT.supabase.co -Anon YOUR_ANON_KEY -Api http://localhost:8000 -Web https://YOUR-WEB-URL

SAFETY
  * Use a TEST Supabase project and a locally running or test backend. It creates two anonymous
    users plus a few rows. Delete them in the Supabase dashboard afterwards.
  * Never paste real keys into this file. Pass them as parameters.
  * Not executed by its author. If a line misbehaves, record the output as evidence and report it.
#>
param(
  [Parameter(Mandatory=$true)][string]$Supa,
  [Parameter(Mandatory=$true)][string]$Anon,
  [string]$Api = "http://localhost:8000",
  [string]$Web = "http://localhost:3000",
  [string]$OutCsv = "backend_check_results.csv"
)

function New-TestUser {
  Invoke-RestMethod -Method Post -Uri "$Supa/auth/v1/signup" -Headers @{ apikey = $Anon } -ContentType "application/json" -Body "{}"
}

function Call($m, $p, $t, $b) {
  $h = @{}
  if ($t) { $h["Authorization"] = "Bearer $t" }
  try {
    $r = Invoke-WebRequest -Method $m -Uri "$Api$p" -Headers $h -ContentType "application/json" -Body $b -UseBasicParsing
    return [int]$r.StatusCode
  } catch {
    if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
    return -1
  }
}

function Cors($origin) {
  try {
    $r = Invoke-WebRequest -Method Options -Uri "$Api/api/v1/sessions/" -UseBasicParsing -Headers @{
      Origin = $origin
      "Access-Control-Request-Method" = "POST"
      "Access-Control-Request-Headers" = "authorization,content-type"
    }
    return [string]$r.Headers["Access-Control-Allow-Origin"]
  } catch { return "" }
}

$script:rows = @()
function Check($id, $name, $want, $got) {
  $ok = ($want -contains $got)
  $script:rows += [pscustomobject]@{
    ID = $id; Check = $name; Want = ($want -join "/"); Got = $got
    Result = $(if ($ok) { "PASS" } else { "FAIL" })
  }
}

Write-Host "Creating two anonymous test users..."
$A = New-TestUser
$B = New-TestUser
$ta = $A.access_token; $ia = $A.user.id
$tb = $B.access_token; $ib = $B.user.id
if (-not $ta -or -not $tb) { Write-Host "Could not create test users. Is Anonymous Auth enabled on the TEST project?"; exit 2 }

$sid = [guid]::NewGuid().ToString()
$now = (Get-Date).ToUniversalTime().ToString("o")
$sess = @{ id = $sid; user_id = $ia; start_time = $now; productive_app = "Notion" } | ConvertTo-Json

function Ev($n) {
  1..$n | ForEach-Object {
    @{ id = [guid]::NewGuid().ToString(); session_id = $sid; package_name = "com.instagram.android"
       app_label = "Instagram"; triggered_at = $now; risk_score = "LOW"; is_recovered = $false }
  }
}

Check "B1"  "health is public"                 @(200)     (Call GET "/health")
Check "B2"  "no token is rejected"             @(401)     (Call GET "/api/v1/analytics/summary/$ia")
Check "B3"  "garbage token is rejected"        @(401)     (Call GET "/api/v1/analytics/summary/$ia" "not.a.jwt")
Check "B4"  "A creates own session"            @(200,201) (Call POST "/api/v1/sessions/" $ta $sess)
Check "B5"  "B reuses A's session id"          @(403)     (Call POST "/api/v1/sessions/" $tb ($sess -replace $ia, $ib))
$mismatch = @{ id = [guid]::NewGuid().ToString(); user_id = $ib; start_time = $now; productive_app = "x" } | ConvertTo-Json
Check "B6"  "token and body user mismatch"     @(403)     (Call POST "/api/v1/sessions/" $ta $mismatch)
Check "B7"  "B patches A's session"            @(403)     (Call PATCH "/api/v1/sessions/$sid" $tb '{"status":"completed"}')
Check "B8"  "A patches own session"            @(200)     (Call PATCH "/api/v1/sessions/$sid" $ta '{"status":"completed"}')
Check "B9"  "A posts events to own session"    @(200,201) (Call POST "/api/v1/events/batch" $ta (@{ user_id = $ia; events = @(Ev 2) } | ConvertTo-Json -Depth 5))
Check "B10" "B posts events to A's session"    @(403)     (Call POST "/api/v1/events/batch" $tb (@{ user_id = $ib; events = @(Ev 1) } | ConvertTo-Json -Depth 5))
Check "B11" "501 events are rejected"          @(422)     (Call POST "/api/v1/events/batch" $ta (@{ user_id = $ia; events = @(Ev 501) } | ConvertTo-Json -Depth 5))
Check "B12" "empty batch is rejected"          @(422)     (Call POST "/api/v1/events/batch" $ta (@{ user_id = $ia; events = @() } | ConvertTo-Json))
Check "B13" "malformed event is rejected"      @(422)     (Call POST "/api/v1/events/batch" $ta '{"user_id":"x","events":[{"id":"1"}]}')
Check "B14" "B reads A's analytics"            @(403)     (Call GET "/api/v1/analytics/summary/$ia" $tb)
Check "B15" "A reads own analytics"            @(200)     (Call GET "/api/v1/analytics/summary/$ia" $ta)
Check "B16" "B asks for debrief of A's session" @(403,404) (Call POST "/api/v1/coach/session-debrief" $tb (@{ session_id = $sid } | ConvertTo-Json))
Check "B17" "predictions accepts empty list"   @(200)     (Call POST "/api/v1/predictions/distraction-risk" $null "[]")
Check "B18a" "CORS echoes the allowed web origin" @($Web) (Cors $Web)
Check "B18b" "CORS refuses an unknown origin"  @("")      (Cors "https://evil.example")

$script:rows | Format-Table -AutoSize

Write-Host ""
Write-Host "B21 latency baseline for GET /health (50 calls, approximate percentiles)"
$ms = 1..50 | ForEach-Object {
  (Measure-Command { Invoke-WebRequest -Uri "$Api/health" -UseBasicParsing | Out-Null }).TotalMilliseconds
} | Sort-Object
Write-Host ("  p50={0}ms  p95={1}ms  max={2}ms" -f [math]::Round($ms[24],1), [math]::Round($ms[47],1), [math]::Round($ms[49],1))
Write-Host "  Time the first call after the server has been idle separately (cold start) and record it too."

$script:rows | Export-Csv -NoTypeInformation -Path $OutCsv
$fail = @($script:rows | Where-Object { $_.Result -eq "FAIL" }).Count
Write-Host ""
Write-Host ("{0} of {1} checks passed. Results saved to {2}" -f ($script:rows.Count - $fail), $script:rows.Count, $OutCsv)
if ($fail -gt 0) { exit 1 }
