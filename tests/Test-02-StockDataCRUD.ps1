# Test-02-StockDataCRUD.ps1
# Verifies the stock price CRUD endpoints:
#   GET  /api/v1/stocks/tickers
#   GET  /api/v1/stocks/{ticker}
#   POST /api/v1/stocks
#   GET  /api/v1/stocks/{ticker}/range
#   DELETE /api/v1/stocks/{id}

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
    if ($condition) {
        Write-Pass $label
        $script:passed++
    } else {
        Write-Fail $label
        $script:failed++
    }
}

function Assert-StatusCode {
    param($label, $expected, $uri, $method = "GET", $body = $null, $contentType = "application/json")
    try {
        $params = @{ Uri = $uri; Method = $method; UseBasicParsing = $true }
        if ($body) { $params.Body = $body; $params.ContentType = $contentType }
        $r = Invoke-WebRequest @params
        Assert-Equal $label $expected ([int]$r.StatusCode)
        return $r
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        Assert-Equal $label $expected $code
        return $null
    }
}

# ── Test body ─────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  TEST 02 - Stock Data CRUD Operations    " -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  Base URL : $BaseUrl"

# ── 2.1  List tickers ─────────────────────────────────────────────────────────
Write-Section "2.1  GET /api/v1/stocks/tickers - seeded tickers present"

$r = Assert-StatusCode "HTTP 200" 200 "$BaseUrl/api/v1/stocks/tickers"
if ($r) {
    $tickers = $r.Content | ConvertFrom-Json
    Assert-True "Response is an array"         ($tickers -is [array])
    Assert-True "AAPL is in seeded tickers"    ($tickers -contains "AAPL")
    Assert-True "MSFT is in seeded tickers"    ($tickers -contains "MSFT")
    Assert-True "GOOGL is in seeded tickers"   ($tickers -contains "GOOGL")
}

# ── 2.2  Get history for AAPL ─────────────────────────────────────────────────
Write-Section "2.2  GET /api/v1/stocks/AAPL - history has 60 records"

$r = Assert-StatusCode "HTTP 200" 200 "$BaseUrl/api/v1/stocks/AAPL"
if ($r) {
    $prices = $r.Content | ConvertFrom-Json
    Assert-True "Returns an array"             ($prices -is [array])
    Assert-True "At least 60 records seeded"   ($prices.Count -ge 60)
    Assert-Equal "Ticker is AAPL"  "AAPL"      $prices[0].ticker
    Assert-True "closePrice > 0"               ([double]$prices[0].closePrice -gt 0)
}

# ── 2.3  Create a new record ──────────────────────────────────────────────────
Write-Section "2.3  POST /api/v1/stocks - create TSLA record"

$today = (Get-Date).ToString("yyyy-MM-dd")
$newRecord = @{
    ticker     = "TSLA"
    tradeDate  = $today
    openPrice  = 220.50
    highPrice  = 228.75
    lowPrice   = 218.00
    closePrice = 225.30
    volume     = 38000000
} | ConvertTo-Json

$r = Assert-StatusCode "HTTP 201" 201 "$BaseUrl/api/v1/stocks" "POST" $newRecord
$createdId = $null
if ($r) {
    $created = $r.Content | ConvertFrom-Json
    Assert-Equal "Ticker saved as TSLA"    "TSLA"   $created.ticker
    Assert-Equal "closePrice persisted"    "225.3"  $created.closePrice
    Assert-True  "ID assigned by database" ($created.id -gt 0)
    $createdId = $created.id
}

# ── 2.4  Date range filter ────────────────────────────────────────────────────
Write-Section "2.4  GET /api/v1/stocks/AAPL/range - date range filter"

$from = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
$to   = (Get-Date).ToString("yyyy-MM-dd")
$uri  = "$BaseUrl/api/v1/stocks/AAPL/range?from=$from&to=$to"

$r = Assert-StatusCode "HTTP 200" 200 $uri
if ($r) {
    $ranged = $r.Content | ConvertFrom-Json
    Assert-True "Returns array for range"  ($ranged -is [array])
    Assert-True "At least 1 record found"  ($ranged.Count -ge 1)
    Assert-True "Max 30 records in window" ($ranged.Count -le 31)
}

# ── 2.5  Validation - missing required fields ─────────────────────────────────
Write-Section "2.5  POST /api/v1/stocks - validation rejects incomplete payload"

$badPayload = '{ "ticker": "INVALID" }'
try {
    Invoke-WebRequest -Uri "$BaseUrl/api/v1/stocks" -Method POST `
        -Body $badPayload -ContentType "application/json" -UseBasicParsing | Out-Null
    Write-Fail "HTTP 400 expected but 2xx returned"
    $script:failed++
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Assert-Equal "HTTP 400 for invalid payload" 400 $code
}

# ── 2.6  Delete the record created in 2.3 ────────────────────────────────────
Write-Section "2.6  DELETE /api/v1/stocks/{id} - remove created record"

if ($createdId) {
    $r = Assert-StatusCode "HTTP 204" 204 "$BaseUrl/api/v1/stocks/$createdId" "DELETE"
    Write-Pass "Record ID $createdId deleted successfully"
} else {
    Write-Host "  [SKIP] No ID to delete (creation failed in 2.3)" -ForegroundColor DarkYellow
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor Gray
Write-Host "  Results: $script:passed passed  |  $script:failed failed" -ForegroundColor $(if ($script:failed -eq 0) { "Green" } else { "Red" })
Write-Host "------------------------------------------" -ForegroundColor Gray

if ($script:failed -gt 0) { exit 1 } else { exit 0 }
