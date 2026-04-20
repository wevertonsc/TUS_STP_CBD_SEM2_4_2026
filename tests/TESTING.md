# API Test Scripts — Stock Options Time Series Predictor

PowerShell scripts for functional testing of the REST API.  
Each script runs independently against a live application instance and prints colour-coded PASS/FAIL results.

---

## Prerequisites

- PowerShell 5.1+ (Windows built-in) or PowerShell 7+ (cross-platform)
- Application running at `http://localhost:8080` (see [Running the application](#running-the-application))
- No additional modules required — all scripts use built-in `Invoke-WebRequest` / `Invoke-RestMethod`

### Allow script execution (run once in PowerShell as Administrator)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Running the Application

```powershell
# From the project root
mvn clean package -DskipTests
java -jar target/stock-predictor-1.0.0.jar
```

Wait for the log line:

```
Started StockPredictorApplication in X.XXX seconds
```

---

## Quick Start — Run All Tests

```powershell
cd scripts
.\Run-AllTests.ps1
```

Run against a different port:

```powershell
.\Run-AllTests.ps1 -BaseUrl "http://localhost:9090"
```

Stop on the first failing test suite:

```powershell
.\Run-AllTests.ps1 -StopOnFirstFailure
```

---

## Test Scripts

| Script | Coverage | Assertions |
|--------|----------|------------|
| [Test-01-HealthCheck.ps1](#test-01---health-check) | Actuator health and info | 5 |
| [Test-02-StockDataCRUD.ps1](#test-02---stock-data-crud) | Tickers, history, create, range, delete | 14 |
| [Test-03-MovingAveragePredictions.ps1](#test-03---moving-average-predictions) | EMA-14 and SMA-20 endpoints | 15 |
| [Test-04-RegressionPrediction.ps1](#test-04---ols-regression-prediction) | OLS Linear Regression endpoint | 16 |
| [Test-05-BulkInsertAndPrediction.ps1](#test-05---bulk-insert-and-end-to-end-prediction) | Batch insert + full E2E flow + cleanup | 14 |

---

## Test-01 - Health Check

**File:** `Test-01-HealthCheck.ps1`  
**Endpoint:** `GET /actuator/health`, `GET /actuator/info`

Verifies that the application and all its health indicators are operational before any other test runs.

### Assertions

| # | Endpoint | Check | Expected |
|---|----------|-------|---------|
| 1.1 | `/actuator/health` | HTTP status code | 200 |
| 1.2 | `/actuator/health` | `status` field | `UP` |
| 1.3 | `/actuator/health` | `components.db.status` | `UP` |
| 1.4 | `/actuator/health` | `components.diskSpace.status` | `UP` |
| 1.5 | `/actuator/info` | `app.name` field is present | non-null |

### Run

```powershell
.\Test-01-HealthCheck.ps1
# Custom URL:
.\Test-01-HealthCheck.ps1 -BaseUrl "http://localhost:9090"
```

### Expected output

```
==========================================
  TEST 01 - Application Health Check
==========================================
  Base URL : http://localhost:8080
  Endpoint : GET /actuator/health

==> 1.1  HTTP status code
  [PASS] HTTP status | expected: '200' | got: '200'

==> 1.2  Overall application status
  [PASS] status field | expected: 'UP' | got: 'UP'

==> 1.3  Database component status
  [PASS] db.status | expected: 'UP' | got: 'UP'

==> 1.4  DiskSpace component status
  [PASS] diskSpace.status | expected: 'UP' | got: 'UP'

==> 1.5  Info endpoint responds
  [PASS] info.app.name | value present: 'Stock Options Predictor'

------------------------------------------
  Results: 5 passed  |  0 failed
------------------------------------------
```

---

## Test-02 - Stock Data CRUD

**File:** `Test-02-StockDataCRUD.ps1`  
**Endpoints:** `GET /api/v1/stocks/tickers`, `GET /api/v1/stocks/{ticker}`, `POST /api/v1/stocks`, `GET /api/v1/stocks/{ticker}/range`, `DELETE /api/v1/stocks/{id}`

Covers the complete lifecycle of a stock price record: list, read, create, filter by range, validation rejection, and delete.

### Assertions

| # | Endpoint | Check | Expected |
|---|----------|-------|---------|
| 2.1 | `GET /tickers` | HTTP status | 200 |
| 2.1 | `GET /tickers` | Response is an array | true |
| 2.1 | `GET /tickers` | AAPL, MSFT, GOOGL present | true |
| 2.2 | `GET /AAPL` | HTTP status | 200 |
| 2.2 | `GET /AAPL` | At least 60 records | true |
| 2.2 | `GET /AAPL` | `ticker` field | `AAPL` |
| 2.2 | `GET /AAPL` | `closePrice > 0` | true |
| 2.3 | `POST /stocks` | HTTP status | 201 |
| 2.3 | `POST /stocks` | `ticker` persisted | `TSLA` |
| 2.3 | `POST /stocks` | `closePrice` persisted | `225.3` |
| 2.3 | `POST /stocks` | Database ID assigned | `> 0` |
| 2.4 | `GET /AAPL/range` | HTTP status | 200 |
| 2.4 | `GET /AAPL/range` | Count within 30-day window | `<= 31` |
| 2.5 | `POST /stocks` | Incomplete payload rejected | HTTP 400 |
| 2.6 | `DELETE /{id}` | Record deleted | HTTP 204 |

### Run

```powershell
.\Test-02-StockDataCRUD.ps1
```

---

## Test-03 - Moving Average Predictions

**File:** `Test-03-MovingAveragePredictions.ps1`  
**Endpoints:** `GET /api/v1/predict/ema/{ticker}`, `GET /api/v1/predict/sma/{ticker}`

Validates EMA-14 and SMA-20 prediction responses including structure, confidence intervals, forecast horizon, date ordering, and error handling.

### Assertions

| # | Endpoint | Check | Expected |
|---|----------|-------|---------|
| 3.1 | `EMA AAPL?days=5` | ticker | `AAPL` |
| 3.1 | `EMA AAPL?days=5` | method label contains EMA | true |
| 3.1 | `EMA AAPL?days=5` | `predictedPrice > 0` | true |
| 3.1 | `EMA AAPL?days=5` | `confidenceLower < confidenceUpper` | true |
| 3.1 | `EMA AAPL?days=5` | `mape >= 0` and `rmse >= 0` | true |
| 3.1 | `EMA AAPL?days=5` | forecast array length | 5 |
| 3.1 | `EMA AAPL?days=5` | `predictionDate` is today | true |
| 3.2 | `EMA MSFT?days=10` | forecast length | 10 |
| 3.2 | `EMA MSFT?days=10` | forecast dates ascending | true |
| 3.3 | `SMA GOOGL?days=5` | ticker | `GOOGL` |
| 3.3 | `SMA GOOGL?days=5` | method label contains SMA | true |
| 3.3 | `SMA GOOGL?days=5` | `predictedPrice > 0` | true |
| 3.3 | `SMA GOOGL?days=5` | forecast length | 5 |
| 3.4 | EMA vs SMA | method labels are distinct | true |
| 3.5 | `EMA UNKNOWN` | insufficient data rejected | HTTP 400 |

### Run

```powershell
.\Test-03-MovingAveragePredictions.ps1
```

---

## Test-04 - OLS Regression Prediction

**File:** `Test-04-RegressionPrediction.ps1`  
**Endpoint:** `GET /api/v1/predict/regression/{ticker}`

Validates the Ordinary Least Squares linear regression forecast including response structure, sequential forecast dates, cross-ticker coverage, and error handling.

### Assertions

| # | Endpoint | Check | Expected |
|---|----------|-------|---------|
| 4.1 | `regression AAPL?days=5` | ticker | `AAPL` |
| 4.1 | `regression AAPL?days=5` | method contains Regression | true |
| 4.1 | `regression AAPL?days=5` | `predictedPrice > 0` | true |
| 4.1 | `regression AAPL?days=5` | confidence bounds present | true |
| 4.1 | `regression AAPL?days=5` | `confidenceLower < confidenceUpper` | true |
| 4.1 | `regression AAPL?days=5` | `mape >= 0` and `rmse >= 0` | true |
| 4.1 | `regression AAPL?days=5` | forecast length | 5 |
| 4.2 | `regression MSFT?days=7` | forecast length | 7 |
| 4.2 | `regression MSFT?days=7` | dates strictly ascending | true |
| 4.2 | `regression MSFT?days=7` | first date in the future | true |
| 4.3 | AAPL, MSFT, GOOGL | all return `predictedPrice > 0` | true |
| 4.3 | AAPL, MSFT, GOOGL | all return 3-point forecast | true |
| 4.4 | OLS vs EMA GOOGL | both return prices | true |
| 4.4 | OLS vs EMA GOOGL | method labels differ | true |
| 4.5 | `regression NODATA` | unknown ticker rejected | HTTP 400 |

### Run

```powershell
.\Test-04-RegressionPrediction.ps1
```

---

## Test-05 - Bulk Insert and End-to-End Prediction

**File:** `Test-05-BulkInsertAndPrediction.ps1`  
**Endpoints:** `POST /api/v1/stocks/batch`, all three prediction endpoints, `DELETE /api/v1/stocks/{id}`

End-to-end scenario: generates 25 synthetic NVDA records, inserts them via batch API, runs all three prediction algorithms against the new ticker, then deletes all records and confirms the ticker is removed.

### Test flow

```
[Build 25 NVDA records in PowerShell]
        |
        v
POST /api/v1/stocks/batch  → 201 Created (25 records)
        |
        v
GET /api/v1/stocks/tickers → NVDA now listed
        |
        v
GET /api/v1/predict/ema/NVDA       → valid prediction
GET /api/v1/predict/sma/NVDA       → valid prediction
GET /api/v1/predict/regression/NVDA → valid prediction
        |
        v
DELETE /api/v1/stocks/{id} × 25   → 204 No Content each
        |
        v
GET /api/v1/stocks/tickers → NVDA no longer present
```

### Assertions

| # | Endpoint | Check | Expected |
|---|----------|-------|---------|
| 5.1 | `POST /batch` | HTTP status | 201 |
| 5.1 | `POST /batch` | Returns array | true |
| 5.1 | `POST /batch` | Saved count | 25 |
| 5.1 | `POST /batch` | First record ticker | `NVDA` |
| 5.2 | `GET /tickers` | NVDA in list after insert | true |
| 5.3 | `EMA NVDA?days=5` | method contains EMA | true |
| 5.3 | `EMA NVDA?days=5` | `predictedPrice > 0` | true |
| 5.3 | `EMA NVDA?days=5` | forecast length | 5 |
| 5.4 | `SMA NVDA?days=3` | `predictedPrice > 0` | true |
| 5.4 | `SMA NVDA?days=3` | forecast length | 3 |
| 5.4 | `regression NVDA?days=3` | `predictedPrice > 0` | true |
| 5.4 | `regression NVDA?days=3` | forecast length | 3 |
| 5.5 | `DELETE` × 25 | All deletions succeed | 0 errors |
| 5.5 | `GET /tickers` | NVDA removed after cleanup | true |

### Run

```powershell
.\Test-05-BulkInsertAndPrediction.ps1

# Custom ticker and record count:
.\Test-05-BulkInsertAndPrediction.ps1 -Ticker "AMD" -NumDays 30
```

---

## Run-AllTests.ps1 — Master Runner

Executes all five scripts in sequence, waits for the application to be ready before starting, and prints a consolidated summary table.

```powershell
.\Run-AllTests.ps1
```

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BaseUrl` | `http://localhost:8080` | Application base URL |
| `-StopOnFirstFailure` | (off) | Abort suite after the first failing script |

### Example output

```
########################################
  Stock Predictor - Full Test Suite
########################################
  Base URL : http://localhost:8080
  Scripts  : 5

Waiting for application at http://localhost:8080 ...
Application is UP. Starting tests ...

----------------------------------------
Running: Test-01-HealthCheck.ps1
  ...
  => Test-01-HealthCheck.ps1 : PASSED  (0.8s)

----------------------------------------
Running: Test-02-StockDataCRUD.ps1
  ...
  => Test-02-StockDataCRUD.ps1 : PASSED  (1.2s)

----------------------------------------
Running: Test-03-MovingAveragePredictions.ps1
  ...
  => Test-03-MovingAveragePredictions.ps1 : PASSED  (1.5s)

----------------------------------------
Running: Test-04-RegressionPrediction.ps1
  ...
  => Test-04-RegressionPrediction.ps1 : PASSED  (1.4s)

----------------------------------------
Running: Test-05-BulkInsertAndPrediction.ps1
  ...
  => Test-05-BulkInsertAndPrediction.ps1 : PASSED  (2.1s)

########################################
  FINAL SUMMARY
########################################

Script                                Status  Duration
------                                ------  --------
Test-01-HealthCheck.ps1               PASSED  0.8s
Test-02-StockDataCRUD.ps1             PASSED  1.2s
Test-03-MovingAveragePredictions.ps1  PASSED  1.5s
Test-04-RegressionPrediction.ps1      PASSED  1.4s
Test-05-BulkInsertAndPrediction.ps1   PASSED  2.1s

  Test suites passed : 5
  Test suites failed : 0

RESULT: ALL TESTS PASSED
```

---

## Troubleshooting

### "Execution of scripts is disabled on this system"

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Unable to connect to the remote server"

The application is not running. Start it first:

```powershell
java -jar target\stock-predictor-1.0.0.jar
```

### Test-05 fails at SMA assertion

SMA-20 requires 20 records. The script inserts 25 by default (`-NumDays 25`). If you reduce this below 20, SMA will return HTTP 400. Keep `-NumDays` at 25 or above.

### Tests leave data behind after a crash

If Test-05 crashes before cleanup, NVDA records remain in the H2 database. Since H2 is in-memory, a simple application restart clears all data and re-seeds the default tickers.
