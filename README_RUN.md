# Stock Options Time Series Predictor

A Spring Boot 3.2 microservice for stock options price prediction using time series analysis. Implements Exponential Moving Average (EMA-14), Simple Moving Average (SMA-20), and Ordinary Least Squares (OLS) Linear Regression, exposed as a REST API with OpenAPI documentation, a full CI/CD pipeline via Jenkins and GitHub Actions, static code analysis via SonarQube, containerisation via Docker, and automated deployment via Ansible.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Project Structure](#project-structure)
4. [Local Development](#local-development)
5. [Running Tests](#running-tests)
6. [Docker](#docker)
7. [SonarQube](#sonarqube)
8. [Jenkins CI/CD Pipeline](#jenkins-cicd-pipeline)
9. [Ansible Deployment](#ansible-deployment)
10. [API Reference](#api-reference)
11. [Sample Requests](#sample-requests)
12. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
HTTP Client / Swagger UI
        |
        v  REST (HTTP/JSON)
+---------------------------+
|   PredictionController    |  GET /api/v1/predict/{ema|sma|regression}/{ticker}
|   StockPriceController    |  GET|POST|DELETE /api/v1/stocks/**
+---------------------------+
        |  method calls
        v
+---------------------------+
|   PredictionService       |  EMA-14 | SMA-20 | OLS Regression
|   StockPriceService       |  CRUD + validation
+---------------------------+
        |  Spring Data JPA
        v
+---------------------------+
|   StockPriceRepository    |  JpaRepository<StockPrice, Long>
|   H2 In-Memory Database   |  Table: stock_prices (seeded on startup)
+---------------------------+
```

On startup, `DataInitializer` seeds 60 days of synthetic OHLCV data for three tickers: **AAPL**, **MSFT**, and **GOOGL**.

---

## Prerequisites

| Tool | Version   | Purpose |
|------|-----------|---------|
| Java (JDK) | 21+       | Runtime and compilation |
| Maven | 3.9+      | Build lifecycle and dependency management |
| Docker | 24+       | Container build and runtime |
| Docker Compose | v2+       | Local orchestration (app + SonarQube) |
| Jenkins | 2.440+ LTS | CI/CD pipeline execution |
| Ansible | 2.15+     | Automated deployment |
| Git | 2.x       | Version control |
| curl | any       | Health check and API testing |

Verify your environment:

```bash
java  -version
mvn   --version
docker --version
docker compose version
ansible --version
```

---

## Project Structure

```
stock-predictor/
├── src/
│   ├── main/java/com/stockpredictor/
│   │   ├── StockPredictorApplication.java
│   │   ├── config/
│   │   │   ├── DataInitializer.java        # Seeds 180 sample records on startup
│   │   │   └── GlobalExceptionHandler.java # HTTP error responses (400, 500)
│   │   ├── controller/
│   │   │   ├── PredictionController.java   # /api/v1/predict/**
│   │   │   └── StockPriceController.java   # /api/v1/stocks/**
│   │   ├── model/
│   │   │   ├── StockPrice.java             # JPA entity (@Entity)
│   │   │   └── PredictionResult.java       # Response DTO (+ ForecastPoint)
│   │   ├── repository/
│   │   │   └── StockPriceRepository.java   # Spring Data JPA interface
│   │   └── service/
│   │       ├── PredictionService.java      # EMA, SMA, OLS algorithms
│   │       └── StockPriceService.java      # CRUD operations
│   ├── main/resources/
│   │   └── application.properties
│   └── test/java/com/stockpredictor/
│       ├── controller/
│       │   └── PredictionControllerIntegrationTest.java  # 10 MockMvc tests
│       └── service/
│           └── PredictionServiceTest.java                # 10 Mockito unit tests
├── ansible/
│   └── deploy.yml                          # Ansible deployment playbook
├── sonar/
│   └── sonar-project.properties            # SonarQube configuration
├── .github/
│   └── workflows/
│       └── ci-cd.yml                       # GitHub Actions pipeline
├── docker-compose.yml                      # App + SonarQube local stack
├── Dockerfile                              # Multi-stage container build
├── Jenkinsfile                             # Declarative Jenkins pipeline
└── pom.xml
```

---

## Local Development

### 1. Clone the repository

```bash
git clone https://github.com/wevertoncastanho/stock-predictor.git
cd stock-predictor
```

### 2. Compile and package

```bash
mvn clean package -DskipTests
```

Expected output:

```
[INFO] BUILD SUCCESS
[INFO] Building jar: target/stock-predictor-1.0.0.jar
```

### 3. Run the application

```bash
java -jar target/stock-predictor-1.0.0.jar
```

The application starts on port **8080**. On first run, `DataInitializer` seeds 60 days of OHLCV data for AAPL, MSFT, and GOOGL automatically.

Verify the application is running:

```bash
curl http://localhost:8080/actuator/health
# {"status":"UP","components":{"db":{"status":"UP"},"diskSpace":{"status":"UP"}}}
```

### 4. Access Swagger UI

Open your browser at:

```
http://localhost:8080/swagger-ui.html
```

The OpenAPI specification is available at:

```
http://localhost:8080/api-docs
```

### 5. Access the H2 Console (development only)

```
http://localhost:8080/h2-console
JDBC URL:  jdbc:h2:mem:stockdb
Username:  sa
Password:  (leave blank)
```

---

## Running Tests

### Unit tests only

Runs `PredictionServiceTest` (10 tests) with Mockito-isolated mocks. No Spring context is loaded.

```bash
mvn test
```

Expected output:

```
Tests run: 10, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

### All tests with coverage enforcement

Runs unit tests and integration tests (`PredictionControllerIntegrationTest`, 10 tests). Loads the full Spring context against an H2 database. JaCoCo enforces a **minimum 70% line coverage** gate — the build fails if coverage falls below this threshold.

```bash
mvn verify
```

Expected output:

```
Tests run: 20, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

### View the coverage report

```bash
# On macOS
open target/site/jacoco/index.html

# On Linux
xdg-open target/site/jacoco/index.html

# Or serve it locally
python3 -m http.server 9090 --directory target/site/jacoco
# then open http://localhost:9090
```

### Run a specific test class

```bash
# Unit tests only
mvn test -Dtest=PredictionServiceTest

# Integration tests only
mvn verify -Dit.test=PredictionControllerIntegrationTest
```

---

## Docker

### Build the image manually

The Dockerfile uses a **multi-stage build**: stage 1 compiles the JAR using the Maven builder image, stage 2 copies only the JAR into a minimal Alpine JRE image. The application runs as a non-root user (`appuser`).

```bash
docker build -t stock-predictor:latest .
```

Verify the image:

```bash
docker images stock-predictor
# REPOSITORY        TAG       IMAGE ID       CREATED         SIZE
# stock-predictor   latest    a3f9b21c4d2e   2 minutes ago   ~180MB
```

### Run the container

```bash
docker run -d \
  --name stock-predictor \
  -p 8080:8080 \
  --restart unless-stopped \
  stock-predictor:latest
```

Check container status and logs:

```bash
# Container status
docker ps --filter name=stock-predictor

# Application logs (follow mode)
docker logs -f stock-predictor

# Health check status (shows HEALTHY after ~40s)
docker inspect --format='{{.State.Health.Status}}' stock-predictor
```

Wait for the HEALTHCHECK to pass (~40 seconds), then verify:

```bash
curl http://localhost:8080/actuator/health
```

### Stop and remove the container

```bash
docker stop stock-predictor
docker rm stock-predictor
```

### Docker Compose — full local stack (app + SonarQube)

The `docker-compose.yml` starts both the application and a SonarQube server with a single command.

```bash
# Start both services in the background
docker compose up -d

# View logs for all services
docker compose logs -f

# View logs for a specific service
docker compose logs -f stock-predictor
docker compose logs -f sonarqube

# Check service health
docker compose ps
```

Expected services after startup:

| Service | URL | Notes |
|---------|-----|-------|
| stock-predictor | http://localhost:8080 | Ready after ~40s |
| sonarqube | http://localhost:9000 | Ready after ~60s |

Stop and remove all containers and volumes:

```bash
docker compose down -v
```

### Inspect the running container

```bash
# Open a shell inside the container
docker exec -it stock-predictor sh

# Check the JVM process
docker exec stock-predictor ps aux

# Check real-time resource usage
docker stats stock-predictor --no-stream
```

---

## SonarQube

SonarQube performs static code analysis and enforces a quality gate before any Docker image is built or deployed.

### Quality Gate criteria

| Metric | Threshold | Configured in |
|--------|-----------|---------------|
| Line coverage | >= 70% | JaCoCo + sonar-project.properties |
| Blocker issues | 0 | Default SonarQube gate |
| Critical vulnerabilities | 0 | Default SonarQube gate |
| Code duplication | < 3% | Default SonarQube gate |

### Step 1 — Start SonarQube

Using Docker Compose (recommended):

```bash
docker compose up -d sonarqube
```

Or as a standalone container:

```bash
docker run -d \
  --name sonarqube \
  -p 9000:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  sonarqube:10.4-community
```

Wait for SonarQube to be ready (~60 seconds):

```bash
until curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; do
  echo "Waiting for SonarQube..."; sleep 5
done
echo "SonarQube is ready."
```

### Step 2 — First-time login and token generation

1. Open http://localhost:9000 in your browser.
2. Log in with the default credentials: **admin / admin**.
3. Change the password when prompted.
4. Navigate to: **My Account > Security > Generate Tokens**.
5. Create a token named `stock-predictor-ci` of type **Project Analysis Token**.
6. Copy the generated token — it is displayed only once.

### Step 3 — Create the project in SonarQube

1. Click **Create Project > Manually**.
2. Set **Project key**: `stock-predictor`
3. Set **Display name**: `Stock Options Time Series Predictor`
4. Click **Set Up**, then select **Use the global setting** for the quality gate.
5. Click **Create project**.

### Step 4 — Run analysis locally

Run `mvn verify` first to generate the JaCoCo coverage report, then run the analysis:

```bash
mvn verify -B

mvn sonar:sonar \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token=YOUR_TOKEN_HERE \
  -Dsonar.projectKey=stock-predictor \
  -Dsonar.projectName="Stock Options Time Series Predictor" \
  -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
```

Or using the properties file:

```bash
mvn sonar:sonar \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token=YOUR_TOKEN_HERE \
  -Dproject.settings=sonar/sonar-project.properties
```

### Step 5 — View results

Open http://localhost:9000/dashboard?id=stock-predictor to see:

- Overall quality gate status (PASSED / FAILED)
- Line and branch coverage breakdown per class
- Bugs, vulnerabilities, and code smells per file
- Duplication analysis

### Step 6 — Store the token for Jenkins

In Jenkins, go to **Manage Jenkins > Credentials > System > Global credentials > Add Credentials**:

- Kind: **Secret text**
- ID: `sonar-token`
- Secret: `YOUR_TOKEN_HERE`
- Description: `SonarQube analysis token for stock-predictor`

### Step 7 — Configure the SonarQube webhook for Quality Gate

The `waitForQualityGate` Jenkins step requires SonarQube to post a callback to Jenkins when analysis is complete.

1. In SonarQube go to **Administration > Configuration > Webhooks**.
2. Click **Create**.
3. Name: `Jenkins`
4. URL: `http://<JENKINS_HOST>:8090/sonarqube-webhook/`
5. Click **Create**.

---

## Jenkins CI/CD Pipeline

### Prerequisites — Jenkins plugins

Install these plugins via **Manage Jenkins > Plugins > Available plugins**:

| Plugin | Purpose |
|--------|---------|
| Pipeline | Declarative pipeline execution |
| Git | Source checkout from GitHub |
| Maven Integration | Maven tool configuration |
| SonarQube Scanner | `waitForQualityGate` step |
| JaCoCo | Coverage report publishing |
| Docker Pipeline | `docker build` and `docker run` in pipeline |
| GitHub | Webhook trigger |

### Step 1 — Configure global tools

Navigate to **Manage Jenkins > Tools**:

**JDK installation:**
- Name: `JDK-17`
- Install automatically: OpenJDK 17

**Maven installation:**
- Name: `Maven-3.9`
- Install automatically: Maven 3.9.6

### Step 2 — Configure the SonarQube server

Navigate to **Manage Jenkins > System > SonarQube servers**:

- Check **Environment variables**
- Name: `SonarQube`
- Server URL: `http://localhost:9000`
- Authentication token: select the `sonar-token` credential created above

### Step 3 — Create the pipeline job

1. Click **New Item**.
2. Name: `stock-predictor`, type: **Pipeline**.
3. Click **OK**.

In the configuration screen:

- **Build Triggers**: check **GitHub hook trigger for GITScm polling**
- **Pipeline**: select **Pipeline script from SCM**
  - SCM: **Git**
  - Repository URL: `https://github.com/wevertoncastanho/stock-predictor.git`
  - Credentials: your GitHub credential
  - Branch: `*/main`
  - Script Path: `Jenkinsfile`
- Click **Save**.

### Step 4 — Configure the GitHub webhook

In your GitHub repository go to **Settings > Webhooks > Add webhook**:

- Payload URL: `http://<JENKINS_HOST>:8090/github-webhook/`
- Content type: `application/json`
- Events: **Just the push event**
- Click **Add webhook**

A green tick appears in GitHub after the first successful delivery.

### Step 5 — First manual run

1. Open the `stock-predictor` job.
2. Click **Build Now**.
3. Click the build number and open **Console Output** to follow each stage.

### Step 6 — Pipeline stage reference

| Stage | Command | Failure condition |
|-------|---------|-------------------|
| Checkout | `git checkout <sha>` | SCM error |
| Build | `mvn clean package -DskipTests -B` | Compile error |
| Unit Tests | `mvn test -B` | Any test failure |
| Integration Tests | `mvn verify -B` | Test failure or coverage < 70% |
| Code Quality | `mvn sonar:sonar ...` | SonarQube unreachable |
| Quality Gate | `waitForQualityGate abortPipeline: true` | Gate returns ERROR |
| Docker Build | `docker build -t stock-predictor:$BUILD_NUMBER .` | Image build error |
| Deploy | `docker run ... && curl /actuator/health` | Health check fails |

### Step 7 — Trigger an automated build via code push

```bash
echo "# updated $(date)" >> README.md

git add README.md
git commit -m "ci: trigger pipeline build $(date +%Y%m%d-%H%M%S)"
git push origin main
```

Within a few seconds the webhook fires and Jenkins starts a new build. The **Pipeline Stage View** shows each stage turning green in sequence.

### Step 8 — Reading pipeline results

After a successful build:

- **Test Results**: build > **Test Result** — all 20 tests listed with timing
- **Coverage Report**: build > **Coverage Report** — JaCoCo line and branch data
- **Archived Artefact**: `target/stock-predictor-1.0.0.jar` is stored per build
- **SonarQube link**: appears in the left sidebar after analysis completes

If the Quality Gate fails the console shows:

```
[Pipeline] waitForQualityGate
[SonarQube] Pipeline aborted due to quality gate failure: ERROR
```

The Docker build and deploy stages are skipped. No broken image is ever produced.

### Step 9 — Run Jenkins in Docker (optional)

If running Jenkins itself in a container, mount the Docker socket so pipeline stages can call `docker`:

```bash
docker run -d \
  --name jenkins \
  -p 8090:8080 \
  -p 50000:50000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts

# Install Docker CLI inside the Jenkins container
docker exec -u root jenkins \
  sh -c "apt-get update && apt-get install -y docker.io"
```

---

## Ansible Deployment

Ansible provides idempotent, repeatable deployment to any Linux host with Docker installed. It is used after Jenkins has built the image, or as a standalone deployment mechanism.

### Step 1 — Install Ansible and the Docker collection

```bash
pip3 install ansible

ansible-galaxy collection install community.docker
```

### Step 2 — Create the inventory file

Create `ansible/inventory.ini` (add to `.gitignore` — do not commit):

```ini
[app_servers]
192.168.1.100 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

# For local deployment on the same machine:
# localhost ansible_connection=local
```

For a local deployment:

```ini
[app_servers]
localhost ansible_connection=local
```

### Step 3 — Playbook tasks overview

The playbook at `ansible/deploy.yml` executes these tasks in order:

| Task | Action |
|------|--------|
| Ensure Docker is installed | `package` module — installs `docker.io` |
| Ensure Docker service is running | `service` module — starts and enables Docker |
| Pull latest image | `docker_image` — pulls `stock-predictor:latest` |
| Remove existing container | `docker_container` — stops and removes old container |
| Start new container | `docker_container` — runs with port 8080 and restart policy |
| Wait for health check | `uri` module — polls `/actuator/health` up to 12 times |
| Print result | `debug` — logs `Deployment successful. Health: UP` |

### Step 4 — Dry-run (check mode)

Verify what will change without making any modifications:

```bash
ansible-playbook ansible/deploy.yml \
  -i ansible/inventory.ini \
  --check \
  --diff
```

### Step 5 — Execute the deployment

```bash
ansible-playbook ansible/deploy.yml \
  -i ansible/inventory.ini \
  -v
```

Expected output:

```
PLAY [Deploy Stock Predictor Microservice] ****

TASK [Ensure Docker is installed] *************
ok: [localhost]

TASK [Ensure Docker service is running] *******
ok: [localhost]

TASK [Pull latest Docker image] ***************
changed: [localhost]

TASK [Stop and remove existing container] *****
changed: [localhost]

TASK [Start new application container] ********
changed: [localhost]

TASK [Wait for application health check] ******
ok: [localhost]

TASK [Print deployment result] ****************
ok: [localhost] => {
    "msg": "Deployment successful. Health: UP"
}

PLAY RECAP ************************************
localhost : ok=7  changed=3  unreachable=0  failed=0
```

### Step 6 — Override variables at runtime

```bash
# Deploy a specific image version
ansible-playbook ansible/deploy.yml \
  -i ansible/inventory.ini \
  -e "docker_image=stock-predictor:42" \
  -e "app_port=8081"

# Target a specific host group only
ansible-playbook ansible/deploy.yml \
  -i ansible/inventory.ini \
  --limit staging_servers
```

### Step 7 — Verify the deployment via Ansible ad-hoc commands

```bash
# Check the container is running on the target host
ansible app_servers -i ansible/inventory.ini \
  -m shell -a "docker ps --filter name=stock-predictor --format '{{.Status}}'"

# Tail the last 50 lines of application logs
ansible app_servers -i ansible/inventory.ini \
  -m shell -a "docker logs --tail 50 stock-predictor"

# Confirm the health endpoint responds
ansible app_servers -i ansible/inventory.ini \
  -m uri -a "url=http://localhost:8080/actuator/health"
```

---

## API Reference

Base URL: `http://localhost:8080`

### Prediction endpoints

#### GET /api/v1/predict/ema/{ticker}

Returns a price prediction using the Exponential Moving Average (EMA-14) algorithm. Requires at least 14 historical records.

| Parameter | Type | Location | Required | Default | Description |
|-----------|------|----------|----------|---------|-------------|
| ticker | String | path | yes | — | Stock ticker symbol (e.g., AAPL) |
| days | int | query | no | 5 | Number of forecast days |

#### GET /api/v1/predict/sma/{ticker}

Returns a price prediction using the Simple Moving Average (SMA-20) algorithm. Requires at least 20 historical records.

| Parameter | Type | Location | Required | Default |
|-----------|------|----------|----------|---------|
| ticker | String | path | yes | — |
| days | int | query | no | 5 |

#### GET /api/v1/predict/regression/{ticker}

Returns a price forecast using OLS Linear Regression. Requires at least 10 historical records.

| Parameter | Type | Location | Required | Default |
|-----------|------|----------|----------|---------|
| ticker | String | path | yes | — |
| days | int | query | no | 5 |

**Prediction response body (all three endpoints):**

```json
{
  "ticker": "AAPL",
  "method": "Exponential Moving Average (EMA-14)",
  "predictionDate": "2025-04-20",
  "predictedPrice": 183.4521,
  "confidenceLower": 178.1204,
  "confidenceUpper": 188.7838,
  "mape": 1.23,
  "rmse": 2.45,
  "forecast": [
    { "date": "2025-04-21", "price": 183.4521 },
    { "date": "2025-04-22", "price": 183.4521 },
    { "date": "2025-04-23", "price": 183.4521 },
    { "date": "2025-04-24", "price": 183.4521 },
    { "date": "2025-04-25", "price": 183.4521 }
  ]
}
```

**Error response (HTTP 400):**

```json
{
  "timestamp": "2025-04-20T10:30:00",
  "status": 400,
  "error": "Bad Request",
  "message": "Insufficient data for ticker 'TINY'. Required: 14, Found: 5"
}
```

### Stock data endpoints

| Method | Endpoint | Description | Success status |
|--------|----------|-------------|----------------|
| GET | /api/v1/stocks/tickers | List all ticker symbols | 200 |
| GET | /api/v1/stocks/{ticker} | Full price history for a ticker | 200 |
| GET | /api/v1/stocks/{ticker}/range?from=&to= | Price history in date range (ISO 8601 dates) | 200 |
| POST | /api/v1/stocks | Add a single price record | 201 |
| POST | /api/v1/stocks/batch | Bulk insert price records | 201 |
| DELETE | /api/v1/stocks/{id} | Delete a price record by ID | 204 |

### Operational endpoints

| Endpoint | Description |
|----------|-------------|
| GET /actuator/health | Application and DB health status |
| GET /actuator/info | Application version and name |
| GET /actuator/metrics | JVM and HTTP metrics |
| GET /swagger-ui.html | Interactive API documentation |
| GET /api-docs | OpenAPI 3 specification (JSON) |
| GET /h2-console | H2 database web console (dev only) |

---

## Sample Requests

### List available tickers

```bash
curl -s http://localhost:8080/api/v1/stocks/tickers | python3 -m json.tool
# ["AAPL", "GOOGL", "MSFT"]
```

### Get full price history for AAPL

```bash
curl -s http://localhost:8080/api/v1/stocks/AAPL | python3 -m json.tool
```

### Get price history within a date range

```bash
curl -s "http://localhost:8080/api/v1/stocks/AAPL/range?from=2025-01-01&to=2025-03-31" \
  | python3 -m json.tool
```

### EMA prediction for AAPL — 5-day forecast

```bash
curl -s "http://localhost:8080/api/v1/predict/ema/AAPL?days=5" \
  | python3 -m json.tool
```

### SMA prediction for MSFT — 3-day forecast

```bash
curl -s "http://localhost:8080/api/v1/predict/sma/MSFT?days=3" \
  | python3 -m json.tool
```

### OLS regression forecast for GOOGL — 10-day horizon

```bash
curl -s "http://localhost:8080/api/v1/predict/regression/GOOGL?days=10" \
  | python3 -m json.tool
```

### Add a new stock price record

```bash
curl -s -X POST http://localhost:8080/api/v1/stocks \
  -H "Content-Type: application/json" \
  -d '{
    "ticker": "TSLA",
    "tradeDate": "2025-04-20",
    "openPrice": 220.50,
    "highPrice": 225.00,
    "lowPrice": 218.00,
    "closePrice": 223.75,
    "volume": 35000000
  }' | python3 -m json.tool
```

### Bulk insert price records

```bash
curl -s -X POST http://localhost:8080/api/v1/stocks/batch \
  -H "Content-Type: application/json" \
  -d '[
    {
      "ticker": "NVDA",
      "tradeDate": "2025-04-18",
      "openPrice": 870.00,
      "highPrice": 885.50,
      "lowPrice": 865.00,
      "closePrice": 880.25,
      "volume": 42000000
    },
    {
      "ticker": "NVDA",
      "tradeDate": "2025-04-19",
      "openPrice": 880.00,
      "highPrice": 895.00,
      "lowPrice": 878.00,
      "closePrice": 891.10,
      "volume": 39000000
    }
  ]' | python3 -m json.tool
```

### Delete a price record by ID

```bash
curl -s -X DELETE http://localhost:8080/api/v1/stocks/1 -w "%{http_code}\n"
# 204
```

### Health check

```bash
curl -s http://localhost:8080/actuator/health | python3 -m json.tool
```

---

## Troubleshooting

### Application fails to start — port 8080 already in use

```bash
# Find the process using port 8080
lsof -i :8080
# or on Linux
ss -tlnp | grep 8080

# Kill by PID
kill -9 <PID>
```

### Docker container exits immediately

```bash
# Check the exit code
docker inspect stock-predictor --format='{{.State.ExitCode}}'

# Read the last logs
docker logs stock-predictor
```

The most common cause is insufficient memory. Increase Docker Desktop memory allocation to at least **2 GB** in **Settings > Resources**.

### SonarQube fails to start — Elasticsearch bootstrap error

SonarQube requires a higher virtual memory limit on Linux:

```bash
# Temporary fix (lost on reboot)
sudo sysctl -w vm.max_map_count=262144

# Permanent fix
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

The `docker-compose.yml` sets `SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true` to bypass this in local development.

### Jenkins — `sonar-token` credential not found

Confirm the credential exists at: **Manage Jenkins > Credentials > System > Global credentials**.

- ID must be exactly `sonar-token`
- Kind must be **Secret text**

### Jenkins — Docker not found in pipeline shell

When running Jenkins inside a container, the Docker socket must be mounted and the CLI must be installed:

```bash
# Re-run Jenkins with Docker socket
docker run -d \
  --name jenkins \
  -p 8090:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts

# Install Docker CLI inside Jenkins
docker exec -u root jenkins \
  sh -c "apt-get update && apt-get install -y docker.io"
```

### Maven build fails — dependency download errors

If behind a corporate proxy, add proxy settings to the Maven invocation:

```bash
mvn clean package -DskipTests \
  -Dhttps.proxyHost=proxy.example.com \
  -Dhttps.proxyPort=8080
```

Or configure the proxy permanently in `~/.m2/settings.xml`.

### Ansible — `community.docker` module not found

```bash
ansible-galaxy collection install community.docker --force
```

### Coverage gate fails in Jenkins (< 70%)

Run `mvn verify` locally and open `target/site/jacoco/index.html` to identify which classes are below threshold. The `sonar/sonar-project.properties` file excludes `DataInitializer`, `StockPredictorApplication`, and all classes under `model/` and `config/` from the coverage requirement so enforcement targets only service and controller logic.

### Quality Gate stuck in PENDING state

If `waitForQualityGate` hangs indefinitely, the SonarQube webhook is not configured or the URL is unreachable from the SonarQube container. Verify the webhook in SonarQube at **Administration > Configuration > Webhooks** and check that Jenkins is reachable on the configured URL.

---

## Pre-loaded Tickers

The `DataInitializer` component seeds the following data on every application startup:

| Ticker | Days of data | Start price | Description |
|--------|-------------|-------------|-------------|
| AAPL | 60 | $180.00 | Apple Inc. (synthetic OHLCV) |
| MSFT | 60 | $310.00 | Microsoft Corp. (synthetic OHLCV) |
| GOOGL | 60 | $140.00 | Alphabet Inc. (synthetic OHLCV) |

Data is generated deterministically using a seeded random number generator, so the same values are produced on every startup. Add real data via `POST /api/v1/stocks/batch` for production use.
