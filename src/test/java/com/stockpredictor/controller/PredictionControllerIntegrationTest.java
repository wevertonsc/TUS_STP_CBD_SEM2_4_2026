package com.stockpredictor.controller;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DisplayName("PredictionController Integration Tests")
class PredictionControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @DisplayName("GET /api/v1/predict/ema/AAPL - returns 200 with prediction result")
    void testEMAPredictionEndpoint() throws Exception {
        mockMvc.perform(get("/api/v1/predict/ema/AAPL")
                        .param("days", "5")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.ticker").value("AAPL"))
                .andExpect(jsonPath("$.predictedPrice").isNumber())
                .andExpect(jsonPath("$.forecast").isArray())
                .andExpect(jsonPath("$.forecast.length()").value(5));
    }

    @Test
    @DisplayName("GET /api/v1/predict/sma/MSFT - returns 200 with SMA result")
    void testSMAPredictionEndpoint() throws Exception {
        mockMvc.perform(get("/api/v1/predict/sma/MSFT")
                        .param("days", "3")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.method").value(org.hamcrest.Matchers.containsString("SMA")))
                .andExpect(jsonPath("$.confidenceLower").isNumber())
                .andExpect(jsonPath("$.confidenceUpper").isNumber());
    }

    @Test
    @DisplayName("GET /api/v1/predict/regression/GOOGL - returns 200 with regression result")
    void testRegressionPredictionEndpoint() throws Exception {
        mockMvc.perform(get("/api/v1/predict/regression/GOOGL")
                        .param("days", "5")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.method").value(org.hamcrest.Matchers.containsString("Regression")))
                .andExpect(jsonPath("$.mape").isNumber())
                .andExpect(jsonPath("$.rmse").isNumber());
    }

    @Test
    @DisplayName("GET /api/v1/predict/ema/UNKNOWN - returns 400 for insufficient data")
    void testEMAForUnknownTickerReturns400() throws Exception {
        mockMvc.perform(get("/api/v1/predict/ema/UNKNOWN")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").exists());
    }

    @Test
    @DisplayName("GET /api/v1/stocks/tickers - returns list of available tickers")
    void testGetAllTickers() throws Exception {
        mockMvc.perform(get("/api/v1/stocks/tickers")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray());
    }

    @Test
    @DisplayName("GET /api/v1/stocks/AAPL - returns stock price history")
    void testGetStockHistory() throws Exception {
        mockMvc.perform(get("/api/v1/stocks/AAPL")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$[0].ticker").value("AAPL"));
    }

    @Test
    @DisplayName("POST /api/v1/stocks - creates a new stock price record")
    void testCreateStockPrice() throws Exception {
        String body = """
                {
                  "ticker": "TSLA",
                  "tradeDate": "2024-01-15",
                  "openPrice": 220.50,
                  "highPrice": 225.00,
                  "lowPrice": 218.00,
                  "closePrice": 223.75,
                  "volume": 35000000
                }
                """;

        mockMvc.perform(post("/api/v1/stocks")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.ticker").value("TSLA"))
                .andExpect(jsonPath("$.closePrice").value(223.75));
    }

    @Test
    @DisplayName("POST /api/v1/stocks - returns 400 for missing required fields")
    void testCreateStockPriceValidationFailure() throws Exception {
        String invalidBody = """
                {
                  "ticker": "TSLA"
                }
                """;

        mockMvc.perform(post("/api/v1/stocks")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(invalidBody))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("GET /actuator/health - returns UP status")
    void testActuatorHealth() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }
}
