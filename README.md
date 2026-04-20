# Stock Options Time Series Predictor

A Spring Boot microservice for stock options price prediction using time series analysis methods including Exponential Moving Average (EMA), Simple Moving Average (SMA), and Ordinary Least Squares Linear Regression.

## Prerequisites

- Java 17+
- Maven 3.9+
- Docker and Docker Compose
- Jenkins (for CI/CD pipeline)

## Running Locally

```bash
# Build the application
mvn clean package -DskipTests

# Run the application
java -jar target/stock-predictor-1.0.0.jar

# Or with Docker Compose (includes SonarQube)
docker-compose up -d
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/v1/predict/ema/{ticker} | EMA-14 price prediction |
| GET | /api/v1/predict/sma/{ticker} | SMA-20 price prediction |
| GET | /api/v1/predict/regression/{ticker} | OLS Linear Regression prediction |
| GET | /api/v1/stocks/tickers | List all available tickers |
| GET | /api/v1/stocks/{ticker} | Historical price data |
| POST | /api/v1/stocks | Add new price record |
| POST | /api/v1/stocks/batch | Bulk insert price records |

## Swagger UI

Access the API documentation at: http://localhost:8080/swagger-ui.html

## Running Tests

```bash
# Unit tests only
mvn test

# All tests with coverage report
mvn verify

# View coverage report
open target/site/jacoco/index.html
```

## CI/CD Pipeline

The Jenkins pipeline (`Jenkinsfile`) executes the following stages:
1. Checkout
2. Build
3. Unit Tests
4. Integration Tests
5. SonarQube Analysis
6. Quality Gate Check
7. Docker Image Build
8. Deploy

## Pre-loaded Tickers

The application seeds sample data for: AAPL, MSFT, GOOGL (60 days each).
