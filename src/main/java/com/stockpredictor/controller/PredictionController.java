/*
+- - - - - - - - - - - - - - - - - - - - - - - - - - - -+
| TUS - Technology University Shannon - Athlone         |
| Continuous Build and Delivery - (AL_KCNCM_9_1)       	|
+- - - - - - - - - - - - - - - - - - - - - - - - - - - -+
| Student: Weverton de Souza Castanho		            |
| Email: wevertonsc@gmail.com				            |
| Data: 20.APRIL.2026					                |
+- - - - - - - - - - - - - - - - - - - - - - - - - - - -+
*/
package com.stockpredictor.controller;

import com.stockpredictor.model.PredictionResult;
import com.stockpredictor.service.PredictionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/predict")
@RequiredArgsConstructor
@Tag(name = "Prediction API", description = "Stock options price prediction using time series methods")
public class PredictionController {

    private final PredictionService predictionService;

    @GetMapping("/ema/{ticker}")
    @Operation(summary = "Predict using Exponential Moving Average",
               description = "Returns next-day price prediction and confidence interval using EMA-14")
    public ResponseEntity<PredictionResult> predictWithEMA(
            @PathVariable @Parameter(description = "Stock ticker symbol (e.g., AAPL)") String ticker,
            @RequestParam(defaultValue = "5") @Parameter(description = "Number of days to forecast") int days) {
        return ResponseEntity.ok(predictionService.predictWithEMA(ticker.toUpperCase(), days));
    }

    @GetMapping("/sma/{ticker}")
    @Operation(summary = "Predict using Simple Moving Average",
               description = "Returns next-day price prediction and confidence interval using SMA-20")
    public ResponseEntity<PredictionResult> predictWithSMA(
            @PathVariable String ticker,
            @RequestParam(defaultValue = "5") int days) {
        return ResponseEntity.ok(predictionService.predictWithSMA(ticker.toUpperCase(), days));
    }

    @GetMapping("/regression/{ticker}")
    @Operation(summary = "Predict using Ordinary Least Squares Linear Regression",
               description = "Returns price forecast using OLS regression trend line")
    public ResponseEntity<PredictionResult> predictWithRegression(
            @PathVariable String ticker,
            @RequestParam(defaultValue = "5") int days) {
        return ResponseEntity.ok(predictionService.predictWithLinearRegression(ticker.toUpperCase(), days));
    }
}
