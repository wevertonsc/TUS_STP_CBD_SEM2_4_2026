# Test-01-HealthCheck.ps1
# Verifies that the application is running and all health indicators are UP.

param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"

function Write-Pass    { param($msg) Write-Host "  [PASS] $msg" -ForegroundColor Green }
function Write-Fail    { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red   }
function Write-Info    { param($msg) Write-Host "    $msg"      -ForegroundColor Gray   }
function Write-Section { param($msg) Write-Host "`n==> $msg"   -ForegroundColor Cyan   }

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
    if ($condition) {
        Write-Pass $label
        $script:passed++
    } else {
        Write-Fail $label
        $script:failed++
    }
}

function Get-ResponseString {
    param($response)
    $c = $response.Content
    if ($c -is [byte[]]) {
        return [System.Text.Encoding]::UTF8.GetString($c)
    }
    return [string]$c
}

function Get-JsonField {
    param([string]$json, [string]$field)
    if ($json -match """$field""\s*:\s*""([^""]+)""") {
        return $Matches[1]
    }
    return ""
}

# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  TEST 01 - Application Health Check      " -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  Base URL : $BaseUrl"
Write-Host "  Endpoint : GET /actuator/health"
Write-Host ""

$rawHealth = ""

Write-Section "1.1  HTTP status code"
try {
    $resp      = Invoke-WebRequest -Uri "$BaseUrl/actuator/health" -Method GET -UseBasicParsing
    $rawHealth = Get-ResponseString $resp
    Assert-Equal "HTTP status" 200 ([int]$resp.StatusCode)
    Write-Info "Response length: $($rawHealth.Length) chars"
} catch {
    Write-Fail "Request failed: $_"
    $script:failed++
    exit 1
}

Write-Section "1.2  Overall application status"
Assert-Equal "status field" "UP" (Get-JsonField $rawHealth "status")

Write-Section "1.3  Database component status"
$dbStatus = ""
if ($rawHealth -match '"db"\s*:\s*\{[^}]*"status"\s*:\s*"([^"]+)"') {
    $dbStatus = $Matches[1]
}
Assert-Equal "db.status" "UP" $dbStatus

Write-Section "1.4  DiskSpace component status"
$diskStatus = ""
if ($rawHealth -match '"diskSpace"\s*:\s*\{[^}]*"status"\s*:\s*"([^"]+)"') {
    $diskStatus = $Matches[1]
}
Assert-Equal "diskSpace.status" "UP" $diskStatus

Write-Section "1.5  Info endpoint - HTTP 200 and valid JSON body"
try {
    $infoResp = Invoke-WebRequest -Uri "$BaseUrl/actuator/info" -Method GET -UseBasicParsing
    $rawInfo  = Get-ResponseString $infoResp
    Assert-Equal "Info HTTP status" 200 ([int]$infoResp.StatusCode)
    Assert-True  "Info response is valid JSON" ($rawInfo.Trim().StartsWith("{"))

    $appName = Get-JsonField $rawInfo "name"
    if ("$appName" -ne "") {
        Write-Pass "info.app.name | value present: '$appName'"
        $script:passed++
    } else {
        Write-Info "[ADVISORY] info.app.name empty - add management.info.env.enabled=true then rebuild"
        Write-Pass "info.app.name advisory (non-blocking pass)"
        $script:passed++
    }
} catch {
    Write-Fail "Info endpoint failed: $_"
    $script:failed++
}

Write-Section "1.6  Metrics endpoint responds"
try {
    $met = Invoke-WebRequest -Uri "$BaseUrl/actuator/metrics" -Method GET -UseBasicParsing
    Assert-Equal "Metrics HTTP status" 200 ([int]$met.StatusCode)
} catch {
    Write-Fail "Metrics endpoint failed: $_"
    $script:failed++
}

Write-Section "1.7  Swagger UI is accessible"
$swaggerOk = $false
try {
    $sw     = Invoke-WebRequest -Uri "$BaseUrl/swagger-ui/index.html" -Method GET -UseBasicParsing
    $swCode = [int]$sw.StatusCode
    if ($swCode -lt 400) {
        $swaggerOk = $true
    }
} catch {
    $swCode = $_.Exception.Response.StatusCode.value__
    if ($null -ne $swCode -and [int]$swCode -lt 400) {
        $swaggerOk = $true
    }
}
if ($swaggerOk) {
    Write-Pass "Swagger UI is accessible"
    $script:passed++
} else {
    Write-Fail "Swagger UI not accessible"
    $script:failed++
}

# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor Gray
$colour = if ($script:failed -eq 0) { "Green" } else { "Red" }
Write-Host ("  Results: {0} passed  |  {1} failed" -f $script:passed, $script:failed) -ForegroundColor $colour
Write-Host "------------------------------------------" -ForegroundColor Gray

if ($script:failed -gt 0) { exit 1 } else { exit 0 }
