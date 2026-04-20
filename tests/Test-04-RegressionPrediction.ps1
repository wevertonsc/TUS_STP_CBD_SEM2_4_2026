# Test-04-RegressionPrediction.ps1
# Verifies the OLS Linear Regression prediction endpoint:
#   GET /api/v1/predict/regression/{ticker}?days=N

param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"

function Write-Pass   { param($msg) Write-Host "  [PASS] $msg" -ForegroundColor Green }
function Write-Fail   { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red   }
function Write-Info   { param($msg) Write-Host "    $msg"      -ForegroundColor Gray   }
function Write-Section{ param($msg) Write-Host "`n==> $msg"   -ForegroundColor Cyan   }

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

# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  TEST 04 - OLS Regression Prediction    " -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  Base URL : $BaseUrl"

# ── 4.1  Basic response structure for AAPL ───────────────────────────────────
Write-Section "4.1  GET /api/v1/predict/regression/AAPL?days=5 - response structure"

try {
    $reg = Invoke-Get ($BaseUrl + "/api/v1/predict/regression/AAPL?days=5")
    Assert-Equal "ticker is AAPL"                    "AAPL"  $reg.ticker
    Assert-True  "method contains Regression"        ($reg.method -like "*Regression*")
    Assert-True  "predictedPrice > 0"                ([double]$reg.predictedPrice -gt 0)
    Assert-True  "confidenceLower is present"        ($null -ne $reg.confidenceLower)
    Assert-True  "confidenceUpper is present"        ($null -ne $reg.confidenceUpper)
    Assert-True  "confidenceLower < confidenceUpper" ([double]$reg.confidenceLower -lt [double]$reg.confidenceUpper)
    Assert-True  "mape >= 0"                         ([double]$reg.mape -ge 0)
    Assert-True  "rmse >= 0"                         ([double]$reg.rmse -ge 0)
    Assert-Equal "forecast length = 5"               5 $reg.forecast.Count
    Write-Info ("predicted: {0}  MAPE: {1:N4}%  RMSE: {2:N4}" -f $reg.predictedPrice, [double]$reg.mape, [double]$reg.rmse)
} catch {
    Write-Fail "Regression AAPL request failed: $_"
    $script:failed++
}

# ── 4.2  Forecast dates are sequential ───────────────────────────────────────
Write-Section "4.2  GET /api/v1/predict/regression/MSFT?days=7 - dates sequential"

try {
    $reg7 = Invoke-Get ($BaseUrl + "/api/v1/predict/regression/MSFT?days=7")
    Assert-Equal "forecast length = 7" 7 $reg7.forecast.Count

    $dates = $reg7.forecast | ForEach-Object { [datetime]$_.date }
    $asc = $true
    for ($i = 1; $i -lt $dates.Count; $i++) {
        if ($dates[$i] -le $dates[$i-1]) { $asc = $false }
    }
    Assert-True "all forecast dates strictly ascending" $asc
    Assert-True "first forecast date is today or later" ($dates[0] -ge [datetime]::Today)
    Write-Info ("First: {0}  Last: {1}" -f $dates[0].ToString("yyyy-MM-dd"), $dates[-1].ToString("yyyy-MM-dd"))
} catch {
    Write-Fail "Regression MSFT date test failed: $_"
    $script:failed++
}

# ── 4.3  All three seeded tickers return valid predictions ────────────────────
# IMPORTANT: do NOT use $ticker as the loop variable — it shadows outer variables
# in PS 5.1 child processes. Use a fixed array index pattern instead.
Write-Section "4.3  Regression works for all three seeded tickers"

$seededTickers = @("AAPL", "MSFT", "GOOGL")
for ($idx = 0; $idx -lt $seededTickers.Length; $idx++) {
    $tkr  = $seededTickers[$idx]
    $rUrl = $BaseUrl + "/api/v1/predict/regression/" + $tkr + "?days=5"
    try {
        $rr = Invoke-Get $rUrl
        Assert-True  ("[$tkr] predictedPrice > 0")   ([double]$rr.predictedPrice -gt 0)
        Assert-Equal ("[$tkr] forecast length = 5") 5 $rr.forecast.Count
        Write-Info ("$tkr predicted: {0}" -f $rr.predictedPrice)
    } catch {
        Write-Fail "[$tkr] regression failed: $_"
        $script:failed++
    }
}

# ── 4.4  Regression vs EMA coexist for GOOGL ─────────────────────────────────
Write-Section "4.4  Regression and EMA coexist for GOOGL - compare metrics"

try {
    $regG = Invoke-Get ($BaseUrl + "/api/v1/predict/regression/GOOGL?days=1")
    $emaG = Invoke-Get ($BaseUrl + "/api/v1/predict/ema/GOOGL?days=1")

    Assert-True "Regression returns a price"       ([double]$regG.predictedPrice -gt 0)
    Assert-True "EMA also returns a price"         ([double]$emaG.predictedPrice -gt 0)
    Assert-True "Methods are labelled differently" ($regG.method -ne $emaG.method)

    Write-Info ("OLS: {0}  |  EMA: {1}" -f $regG.predictedPrice, $emaG.predictedPrice)
    Write-Info ("OLS MAPE: {0:N4}%  |  EMA MAPE: {1:N4}%" -f [double]$regG.mape, [double]$emaG.mape)
} catch {
    Write-Fail "Comparison test failed: $_"
    $script:failed++
}

# ── 4.5  Unknown ticker returns 400 ──────────────────────────────────────────
Write-Section "4.5  GET /api/v1/predict/regression/NODATA - returns HTTP 400"

try {
    Invoke-RestMethod -Uri ($BaseUrl + "/api/v1/predict/regression/NODATA?days=5") -Method GET | Out-Null
    Write-Fail "Expected HTTP 400 but got success"
    $script:failed++
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Assert-Equal "HTTP 400 for unknown ticker" 400 $code
}

# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor Gray
Write-Host ("  Results: {0} passed  |  {1} failed" -f $script:passed, $script:failed) `
    -ForegroundColor $(if ($script:failed -eq 0) { "Green" } else { "Red" })
Write-Host "------------------------------------------" -ForegroundColor Gray

if ($script:failed -gt 0) { exit 1 } else { exit 0 }
