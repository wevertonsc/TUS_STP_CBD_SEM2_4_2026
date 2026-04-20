# Run-AllTests.ps1
# Executes all five API test scripts in sequence and prints a consolidated summary.
# Usage:
#   .\Run-AllTests.ps1
#   .\Run-AllTests.ps1 -BaseUrl "http://localhost:9090"
#   .\Run-AllTests.ps1 -StopOnFirstFailure

param(
    [string]$BaseUrl           = "http://localhost:8080",
    [switch]$StopOnFirstFailure
)

$scripts = @(
    "Test-01-HealthCheck.ps1",
    "Test-02-StockDataCRUD.ps1",
    "Test-03-MovingAveragePredictions.ps1",
    "Test-04-RegressionPrediction.ps1",
    "Test-05-BulkInsertAndPrediction.ps1"
)

$root      = $PSScriptRoot
$totalPass = 0
$totalFail = 0
$results   = @()

Write-Host ""
Write-Host "########################################" -ForegroundColor Magenta
Write-Host "  Stock Predictor - Full Test Suite     " -ForegroundColor Magenta
Write-Host "########################################" -ForegroundColor Magenta
Write-Host "  Base URL : $BaseUrl"
Write-Host "  Scripts  : $($scripts.Count)"
Write-Host ""

# ── Wait for app to be ready ──────────────────────────────────────────────────
Write-Host "Waiting for application at $BaseUrl ..." -ForegroundColor Yellow
$retries = 12
$ready   = $false
for ($i = 1; $i -le $retries; $i++) {
    try {
        $h = Invoke-WebRequest "$BaseUrl/actuator/health" -UseBasicParsing -TimeoutSec 3
        if ([int]$h.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Write-Host "  Attempt $i/$retries - not ready, waiting 5s ..." -ForegroundColor DarkYellow
    Start-Sleep 5
}

if (-not $ready) {
    Write-Host ""
    Write-Host "[ERROR] Application did not respond after $($retries * 5)s. Aborting." -ForegroundColor Red
    exit 1
}
Write-Host "Application is UP. Starting tests ...`n" -ForegroundColor Green

# ── Run each script ───────────────────────────────────────────────────────────
foreach ($scriptName in $scripts) {
    $path = Join-Path $root $scriptName
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host "Running: $scriptName" -ForegroundColor White

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # FIX: Use Start-Process to get a reliable exit code.
    # The & operator in PS 5.1 does not propagate exit codes from child
    # scripts that call exit — $LASTEXITCODE stays 0 even on failure.
    $proc = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", `
                      "-File", "`"$path`"", "-BaseUrl", $BaseUrl `
        -Wait -PassThru -NoNewWindow

    $sw.Stop()
    $exitCode = $proc.ExitCode

    $status = if ($exitCode -eq 0) { "PASSED" } else { "FAILED" }
    $color  = if ($exitCode -eq 0) { "Green"  } else { "Red"    }

    Write-Host ("  => {0} : {1}  ({2}s)" -f $scriptName, $status, [Math]::Round($sw.Elapsed.TotalSeconds, 1)) -ForegroundColor $color

    $results += [PSCustomObject]@{
        Script   = $scriptName
        Status   = $status
        Duration = "$([Math]::Round($sw.Elapsed.TotalSeconds,1))s"
    }

    if ($exitCode -ne 0) { $totalFail++ } else { $totalPass++ }

    if ($StopOnFirstFailure -and $exitCode -ne 0) {
        Write-Host "`n[ABORTED] -StopOnFirstFailure set. Stopping." -ForegroundColor Red
        break
    }
}

# ── Consolidated summary ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "########################################" -ForegroundColor Magenta
Write-Host "  FINAL SUMMARY                        " -ForegroundColor Magenta
Write-Host "########################################" -ForegroundColor Magenta
Write-Host ""

$results | Format-Table -AutoSize

Write-Host ("  Test suites passed : {0}" -f $totalPass) -ForegroundColor Green
Write-Host ("  Test suites failed : {0}" -f $totalFail) -ForegroundColor $(if ($totalFail -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($totalFail -gt 0) {
    Write-Host "RESULT: FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "RESULT: ALL TESTS PASSED" -ForegroundColor Green
    exit 0
}
