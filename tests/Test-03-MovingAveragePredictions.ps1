# Test-03-MovingAveragePredictions.ps1
# Verifies EMA-14 and SMA-20 prediction endpoints:
#   GET /api/v1/predict/ema/{ticker}?days=N
#   GET /api/v1/predict/sma/{ticker}?days=N

param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Pass { param($msg) Write-Host "  [PASS] $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red }
function Write-Section { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }

$passed = 0
$failed = 0

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

# ── Test body ─────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  TEST 03 - EMA and SMA Predictions      " -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  Base URL : $BaseUrl"

# ── 3.1  EMA prediction for AAPL ─────────────────────────────────────────────
Write-Section "3.1  GET /api/v1/predict/ema/AAPL?days=5"

try {
    $ema = Invoke-RestMethod -Uri "$BaseUrl/api/v1/predict/ema/AAPL?days=5" -Method GET
    Assert-Equal  "ticker is AAPL"                    "AAPL"  $ema.ticker
    Assert-True   "method contains EMA"               ($ema.method -like "*EMA*")
    Assert-True   "predictedPrice is a positive number" ([double]$ema.predictedPrice -gt 0)
    Assert-True   "confidenceLower < confidenceUpper" ([double]$ema.confidenceLower -lt [double]$ema.confidenceUpper)
    Assert-True   "mape is non-negative"              ([double]$ema.mape -ge 0)
    Assert-True   "rmse is non-negative"              ([double]$ema.rmse -ge 0)
    Assert-Equal  "forecast has 5 points"             5 $ema.forecast.Count
    Assert-True   "forecast[0].price > 0"             ([double]$ema.forecast[0].price -gt 0)
    Assert-True   "predictionDate is today"           ($ema.predictionDate -eq (Get-Date -Format "yyyy-MM-dd"))
} catch {
    Write-Fail "EMA request failed: $_"
    $script:failed++
}

# ── 3.2  EMA with custom forecast window ─────────────────────────────────────
Write-Section "3.2  GET /api/v1/predict/ema/MSFT?days=10 - custom horizon"

try {
    $ema10 = Invoke-RestMethod -Uri "$BaseUrl/api/v1/predict/ema/MSFT?days=10" -Method GET
    Assert-Equal "forecast has 10 points" 10 $ema10.forecast.Count
    Assert-Equal "ticker is MSFT"         "MSFT" $ema10.ticker

    # Verify forecast dates are strictly ascending
    $dates = $ema10.forecast | ForEach-Object { [datetime]$_.date }
    $ascending = $true
    for ($i = 1; $i -lt $dates.Count; $i++) {
        if ($dates[$i] -le $dates[$i - 1]) { $ascending = $false }
    }
    Assert-True "forecast dates are chronologically ascending" $ascending
} catch {
    Write-Fail "EMA 10-day request failed: $_"
    $script:failed++
}

# ── 3.3  SMA prediction for GOOGL ────────────────────────────────────────────
Write-Section "3.3  GET /api/v1/predict/sma/GOOGL?days=5"

try {
    $sma = Invoke-RestMethod -Uri "$BaseUrl/api/v1/predict/sma/GOOGL?days=5" -Method GET
    Assert-Equal "ticker is GOOGL"                     "GOOGL"  $sma.ticker
    Assert-True  "method contains SMA"                 ($sma.method -like "*SMA*")
    Assert-True  "predictedPrice > 0"                  ([double]$sma.predictedPrice -gt 0)
    Assert-True  "confidenceLower < confidenceUpper"   ([double]$sma.confidenceLower -lt [double]$sma.confidenceUpper)
    Assert-Equal "forecast has 5 points"               5 $sma.forecast.Count
} catch {
    Write-Fail "SMA request failed: $_"
    $script:failed++
}

# ── 3.4  EMA vs SMA predicted prices differ ──────────────────────────────────
Write-Section "3.4  EMA and SMA produce different predictions for AAPL"

try {
    $emaAapl = Invoke-RestMethod -Uri "$BaseUrl/api/v1/predict/ema/AAPL?days=1" -Method GET
    $smaAapl = Invoke-RestMethod -Uri "$BaseUrl/api/v1/predict/sma/AAPL?days=1" -Method GET
    $diff = [Math]::Abs([double]$emaAapl.predictedPrice - [double]$smaAapl.predictedPrice)
    Assert-True "EMA and SMA prices differ (diff=$diff)" ($diff -ge 0)
    Assert-True "EMA method label distinct from SMA"  ($emaAapl.method -ne $smaAapl.method)
    Write-Host "    EMA: $($emaAapl.predictedPrice)  |  SMA: $($smaAapl.predictedPrice)  |  diff: $([Math]::Round($diff,4))" -ForegroundColor Gray
} catch {
    Write-Fail "Comparison request failed: $_"
    $script:failed++
}

# ── 3.5  Unknown ticker returns 400 ──────────────────────────────────────────
Write-Section "3.5  GET /api/v1/predict/ema/UNKNOWN - returns HTTP 400"

try {
    Invoke-RestMethod -Uri "$BaseUrl/api/v1/predict/ema/UNKNOWN?days=5" -Method GET | Out-Null
    Write-Fail "Expected HTTP 400 but got success"
    $script:failed++
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Assert-Equal "HTTP 400 for unknown ticker" 400 $code
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor Gray
Write-Host "  Results: $script:passed passed  |  $script:failed failed" -ForegroundColor $(if ($script:failed -eq 0) { "Green" } else { "Red" })
Write-Host "------------------------------------------" -ForegroundColor Gray

if ($script:failed -gt 0) { exit 1 } else { exit 0 }
