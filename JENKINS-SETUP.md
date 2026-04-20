# Jenkins Setup Guide — Stock Options Time Series Predictor

Complete guide to start Jenkins in Docker and run the CI/CD pipeline.

---

## Stack overview

| Service | URL | Credentials |
|---------|-----|-------------|
| Jenkins | http://localhost:8090 | admin / admin123 |
| SonarQube | http://localhost:9000 | admin / admin |
| Stock Predictor | http://localhost:8080 | — |

---

## Step 1 — Start all services

From the project root (where `docker-compose.yml` is):

```powershell
docker compose up -d --build
```

This builds the custom Jenkins image (installs Maven, Docker CLI, and all
plugins) and starts all three services. The first build takes 3-5 minutes
because Jenkins downloads all plugins.

Monitor progress:

```powershell
# Follow all logs
docker compose logs -f

# Follow only Jenkins
docker compose logs -f jenkins

# Wait for Jenkins to be ready
docker compose logs -f jenkins | Select-String "Jenkins is fully up"
```

Jenkins is ready when you see:

```
jenkins  | INFO: Jenkins is fully up and running
```

---

## Step 2 — Unlock Jenkins (first run only)

Although the setup wizard is skipped, Jenkins generates an initial admin
password. The admin user is pre-configured via JCasC with password `admin123`.

Open http://localhost:8090 and log in:

- Username: `admin`
- Password: `admin123`

---

## Step 3 — Add credentials

Jenkins needs two credentials to run the pipeline.

### 3a. SonarQube token

First generate a token in SonarQube:

1. Open http://localhost:9000
2. Log in as `admin` / `admin` (change password when prompted)
3. Go to **My Account > Security > Generate Tokens**
4. Name: `stock-predictor-ci`, Type: **Project Analysis Token**
5. Copy the generated token

Then add it to Jenkins:

1. Open http://localhost:8090
2. Go to **Manage Jenkins > Credentials > System > Global credentials**
3. Click **Add Credentials**
4. Kind: **Secret text**
5. ID: `sonar-token`
6. Secret: paste the SonarQube token
7. Click **Create**

### 3b. GitHub credentials (for SCM checkout)

1. In the same **Global credentials** screen click **Add Credentials**
2. Kind: **Username with password**
3. ID: `github-credentials`
4. Username: your GitHub username
5. Password: your GitHub personal access token
   (GitHub > Settings > Developer settings > Personal access tokens > Generate new token)
   Required scopes: `repo`
6. Click **Create**

---

## Step 4 — Configure SonarQube project

1. Open http://localhost:9000
2. Click **Create Project > Manually**
3. Project key: `stock-predictor`
4. Display name: `Stock Options Time Series Predictor`
5. Click **Set Up > Use the global setting > Create project**

### Configure the SonarQube webhook (required for Quality Gate)

Jenkins' `waitForQualityGate` step requires SonarQube to POST back to Jenkins
when analysis completes.

1. In SonarQube go to **Administration > Configuration > Webhooks**
2. Click **Create**
3. Name: `Jenkins`
4. URL: `http://jenkins:8090/sonarqube-webhook/`
   (uses the Docker service name, not localhost)
5. Click **Create**

---

## Step 5 — Run the pipeline

The `stock-predictor` pipeline job is pre-created by JCasC. To trigger it:

1. Open http://localhost:8090
2. Click on the **stock-predictor** job
3. Click **Build Now**

Or push a commit to your GitHub repository — the webhook will trigger the
pipeline automatically.

### Pipeline stages

```
Checkout → Build → Unit Tests → Integration Tests
       → SonarQube → Quality Gate → Docker Build → Deploy
```

Watch progress in **Stage View** on the job page.

---

## Step 6 — Verify a successful run

After the pipeline completes:

```powershell
# Application health
curl http://localhost:8080/actuator/health

# Application API
curl http://localhost:8080/api/v1/predict/ema/AAPL?days=5
```

---

## Day-to-day commands

```powershell
# Start everything
docker compose up -d

# Start only Jenkins and SonarQube (build tools only)
docker compose up -d jenkins sonarqube

# Stop everything (data is preserved in volumes)
docker compose down

# Stop everything AND delete all data (full reset)
docker compose down -v

# Rebuild only the Jenkins image (after changing jenkins/Dockerfile or plugins.txt)
docker compose build jenkins
docker compose up -d jenkins

# View Jenkins logs
docker compose logs -f jenkins

# Open a shell inside Jenkins
docker exec -it jenkins bash

# Check Jenkins admin password (if locked out)
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

---

## Troubleshooting

### Jenkins cannot connect to Docker

The Jenkins container accesses Docker via the host socket mounted at
`/var/run/docker.sock`. If `docker build` fails inside a pipeline stage:

```powershell
# Check the socket is mounted
docker exec jenkins ls -la /var/run/docker.sock

# Check the jenkins user has access
docker exec jenkins docker ps
```

If permission is denied, the `DOCKER_GID` build argument needs to match
your host Docker group GID. On Linux/macOS:

```bash
getent group docker | cut -d: -f3
```

Then rebuild with the correct GID:

```powershell
docker compose build --build-arg DOCKER_GID=<YOUR_GID> jenkins
```

### SonarQube takes too long to start

SonarQube needs ~60-90 seconds to initialise Elasticsearch. Jenkins waits
for SonarQube to be healthy (`depends_on: condition: service_healthy`)
before starting. If Jenkins starts before SonarQube is ready, the Quality
Gate stage will fail.

Check SonarQube status:

```powershell
docker compose logs sonarqube | Select-String "SonarQube is up"
```

### Pipeline fails at Quality Gate - PENDING forever

The SonarQube webhook is not configured or the URL is wrong. Verify:

1. In SonarQube: **Administration > Configuration > Webhooks**
2. URL must be `http://jenkins:8090/sonarqube-webhook/` (not localhost)

### Port conflicts

If ports 8080, 8090, or 9000 are already in use:

```powershell
# Find what is using port 8090
netstat -ano | findstr :8090
```

Change the ports in `docker-compose.yml`:

```yaml
ports:
  - "8091:8080"   # Change 8090 to 8091
```

### Full reset (start from scratch)

```powershell
docker compose down -v          # Remove containers and volumes
docker compose up -d --build    # Rebuild images and start fresh
```

---

## Architecture inside Docker

```
┌─────────────────────────────────────────────────┐
│  Docker network: cicd (bridge)                  │
│                                                 │
│  ┌─────────────┐    ┌──────────────┐           │
│  │   Jenkins   │    │  SonarQube   │           │
│  │  :8090      │───>│  :9000       │           │
│  │             │    │              │           │
│  │  Maven 3.9  │    │  Quality     │           │
│  │  JDK 21     │    │  Gate        │           │
│  │  Docker CLI │    └──────────────┘           │
│  └──────┬──────┘                               │
│         │ docker build/run                      │
│         v                                       │
│  ┌──────────────────┐                          │
│  │  stock-predictor │                          │
│  │  :8080           │                          │
│  └──────────────────┘                          │
│                                                 │
└─────────────────────────────────────────────────┘
         │
         │ /var/run/docker.sock
         v
    Host Docker Engine
```
