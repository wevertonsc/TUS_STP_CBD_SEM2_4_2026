# Test-05-BulkInsertAndPrediction.ps1
# End-to-end test: inserts 25 NVDA records via POST /batch,
# runs all three prediction algorithms, then cleans up.

param(
    [string]$BaseUrl  = "http://localhost:8080",
    [string]$Ticker   = "NVDA",
    [int]   $NumDays  = 25
)

$ErrorActionPreference = "Stop"

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Pass { param($msg) Write-Host "  [PASS] $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "    $msg"      -ForegroundColor Gray }
function Write-Section { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }

$script:passed = 0
$script:failed = 0

function Assert-Equal {
    param($label, $expected, $actual)
    if ("$actual" -eq "$expected") {
        Write-Pass "$label | expected: '$expected' | got: '$actual'"
        $script:passed++
    } else {
        Write-Fail "$label | expected: '$expected' | got: '$actual'"
        $script:failed++
    }
}

function Assert-True {
    param($label, $condition)
    if ($condition) { Write-Pass $label; $script:passed++ }
    else            { Write-Fail $label; $script:failed++ }
}

function Invoke-Get {
    param([string]$url)
    Write-Info "GET $url"
    return Invoke-RestMethod -Uri $url -Method GET
}

# ── Build batch payload ────────────────────────────────────────────────────────

function Build-BatchPayload {
    param([string]$t, [int]$days)
    $records = @()
    $price   = 870.0
    $rng     = [System.Random]::new(42)
    for ($i = $days; $i -ge 1; $i--) {
        $price += ($rng.NextDouble() - 0.48) * 6
        $price  = [Math]::Max(10.0, $price)
        $high   = $price + $rng.NextDouble() * 3
        $low    = [Math]::Max(1.0, $price - $rng.NextDouble() * 3)
        $open   = $low + $rng.NextDouble() * ($high - $low)
        $records += [ordered]@{
            ticker     = $t
            tradeDate  = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")
            openPrice  = [Math]::Round($open,  4)
            highPrice  = [Math]::Round($high,  4)
            lowPrice   = [Math]::Round($low,   4)
            closePrice = [Math]::Round($price, 4)
            volume     = $rng.Next(20000000, 60000000)
        }
    }
    return ($records | ConvertTo-Json -Depth 3)
}

# ── Test body ─────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  TEST 05 - Bulk Insert + E2E Prediction  " -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  Base URL : $BaseUrl"
Write-Host "  Ticker   : $Ticker"
Write-Host "  Records  : $NumDays"

$insertedIds = @()

# ── 5.1  Bulk insert ──────────────────────────────────────────────────────────
Write-Section "5.1  POST /api/v1/stocks/batch - insert $NumDays $Ticker records"

try {
    $payload  = Build-BatchPayload -t $Ticker -days $NumDays
    Write-Info "POST $BaseUrl/api/v1/stocks/batch ($NumDays records)"
    $response = Invoke-WebRequest -Uri "$BaseUrl/api/v1/stocks/batch" `
                    -Method POST -Body $payload `
                    -ContentType "application/json" -UseBasicParsing

    Assert-Equal "HTTP 201 Created" 201 ([int]$response.StatusCode)

    try   { $saved = $response.Content | ConvertFrom-Json -Depth 10 }
    catch { $saved = $response.Content | ConvertFrom-Json }

    Assert-True  "Returned array of records"   ($saved -is [array])
    Assert-Equal "All $NumDays records saved"  $NumDays $saved.Count
    Assert-True  "First record ticker correct" ($saved[0].ticker -eq $Ticker)

    $insertedIds = $saved | ForEach-Object { $_.id }
    Write-Info "Inserted IDs: $($insertedIds[0]) .. $($insertedIds[-1])"
} catch {
    Write-Fail "Batch insert failed: $_"
    $script:failed++
}

# ── 5.2  Ticker appears in list ───────────────────────────────────────────────
Write-Section "5.2  GET /api/v1/stocks/tickers - $Ticker now listed"

try {
    $tickers = Invoke-Get "$BaseUrl/api/v1/stocks/tickers"
    Assert-True "$Ticker present in ticker list" ($tickers -contains $Ticker)
    Write-Info "All tickers: $($tickers -join ', ')"
} catch {
    Write-Fail "Tickers request failed: $_"
    $script:failed++
}

# ── 5.3  EMA on new ticker ────────────────────────────────────────────────────
# EMA requires 14 records minimum. NumDays=25, so this must pass.
Write-Section "5.3  GET /api/v1/predict/ema/$Ticker?days=5 - EMA on freshly inserted data"

try {
    $emaUrl = "$BaseUrl/api/v1/predict/ema/$Ticker" + "?days=5"
    $ema = Invoke-Get $emaUrl
    Assert-Equal "ticker is $Ticker"           $Ticker $ema.ticker
    Assert-True  "method contains EMA"         ($ema.method -like "*EMA*")
    Assert-True  "predictedPrice > 0"          ([double]$ema.predictedPrice -gt 0)
    Assert-Equal "forecast length = 5"         5 $ema.forecast.Count
    Write-Info "EMA predicted: $($ema.predictedPrice)  CI [$($ema.confidenceLower) - $($ema.confidenceUpper)]"
} catch {
    Write-Fail "EMA on $Ticker failed: $_"
    $script:failed++
}

# ── 5.4  SMA and Regression on new ticker ────────────────────────────────────
# SMA requires 20 records minimum. NumDays=25, so this must pass.
Write-Section "5.4  SMA and OLS regression also succeed for $Ticker"

$smaUrl = "$BaseUrl/api/v1/predict/sma/$Ticker" + "?days=3"
try {
    $smaR = Invoke-Get $smaUrl
    Assert-True  "SMA predictedPrice > 0"    ([double]$smaR.predictedPrice -gt 0)
    Assert-Equal "SMA forecast length = 3"   3 $smaR.forecast.Count
    Write-Info "SMA predicted: $($smaR.predictedPrice)"
} catch {
    Write-Fail "SMA request for $Ticker failed: $_"
    $script:failed++
}

$regUrl = "$BaseUrl/api/v1/predict/regression/$Ticker" + "?days=3"
try {
    $regR = Invoke-Get $regUrl
    Assert-True  "OLS predictedPrice > 0"    ([double]$regR.predictedPrice -gt 0)
    Assert-Equal "OLS forecast length = 3"   3 $regR.forecast.Count
    Write-Info "OLS predicted: $($regR.predictedPrice)"
} catch {
    Write-Fail "Regression request for $Ticker failed: $_"
    $script:failed++
}

# ── 5.5  Cleanup ──────────────────────────────────────────────────────────────
Write-Section "5.5  DELETE all inserted $Ticker records and verify ticker removed"

$deleteErrors = 0
foreach ($rid in $insertedIds) {
    try {
        $del = Invoke-WebRequest -Uri "$BaseUrl/api/v1/stocks/$rid" `
                   -Method DELETE -UseBasicParsing
        if ([int]$del.StatusCode -ne 204) { $deleteErrors++ }
    } catch {
        $deleteErrors++
    }
}
Assert-Equal "All $($insertedIds.Count) records deleted" 0 $deleteErrors

try {
    $tickersAfter = Invoke-Get "$BaseUrl/api/v1/stocks/tickers"
    Assert-True "$Ticker no longer in list after deletion" (-not ($tickersAfter -contains $Ticker))
} catch {
    Write-Fail "Tickers check after deletion failed: $_"
    $script:failed++
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor Gray
Write-Host ("  Results: {0} passed  |  {1} failed" -f $script:passed, $script:failed) -ForegroundColor $(if ($script:failed -eq 0) { "Green" } else { "Red" })
Write-Host "------------------------------------------" -ForegroundColor Gray

if ($script:failed -gt 0) { exit 1 } else { exit 0 }
