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
package com.stockpredictor.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PredictionResult {

    private String ticker;
    private String method;
    private LocalDate predictionDate;
    private BigDecimal predictedPrice;
    private BigDecimal confidenceLower;
    private BigDecimal confidenceUpper;
    private double mape;
    private double rmse;
    private List<ForecastPoint> forecast;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ForecastPoint {
        private LocalDate date;
        private BigDecimal price;
    }
}
