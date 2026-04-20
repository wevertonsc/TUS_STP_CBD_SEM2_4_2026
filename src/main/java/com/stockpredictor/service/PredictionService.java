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
package com.stockpredictor.service;

import com.stockpredictor.model.PredictionResult;
import com.stockpredictor.model.StockPrice;
import com.stockpredictor.repository.StockPriceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class PredictionService {

    private static final int DEFAULT_FORECAST_DAYS = 5;
    private static final int EMA_PERIOD = 14;
    private static final int SMA_PERIOD = 20;
    private static final MathContext MC = new MathContext(10, RoundingMode.HALF_UP);

    private final StockPriceRepository stockPriceRepository;

    public PredictionResult predictWithEMA(String ticker, int forecastDays) {
        List<StockPrice> prices = stockPriceRepository.findByTickerOrderByTradeDateAsc(ticker);
        validateSufficientData(prices, EMA_PERIOD, ticker);

        List<BigDecimal> closePrices = extractClosePrices(prices);
        List<BigDecimal> emaValues = calculateEMA(closePrices, EMA_PERIOD);
        BigDecimal lastEMA = emaValues.get(emaValues.size() - 1);

        double[] errorMetrics = calculateErrorMetrics(closePrices, emaValues, EMA_PERIOD);
        BigDecimal stdDev = calculateStdDev(closePrices);

        List<PredictionResult.ForecastPoint> forecast = buildForecast(
                prices.get(prices.size() - 1).getTradeDate(), lastEMA, forecastDays);

        BigDecimal margin = stdDev.multiply(BigDecimal.valueOf(1.96), MC);

        return PredictionResult.builder()
                .ticker(ticker)
                .method("Exponential Moving Average (EMA-" + EMA_PERIOD + ")")
                .predictionDate(LocalDate.now())
                .predictedPrice(lastEMA.setScale(4, RoundingMode.HALF_UP))
                .confidenceLower(lastEMA.subtract(margin).setScale(4, RoundingMode.HALF_UP))
                .confidenceUpper(lastEMA.add(margin).setScale(4, RoundingMode.HALF_UP))
                .mape(errorMetrics[0])
                .rmse(errorMetrics[1])
                .forecast(forecast)
                .build();
    }

    public PredictionResult predictWithSMA(String ticker, int forecastDays) {
        List<StockPrice> prices = stockPriceRepository.findByTickerOrderByTradeDateAsc(ticker);
        validateSufficientData(prices, SMA_PERIOD, ticker);

        List<BigDecimal> closePrices = extractClosePrices(prices);
        List<BigDecimal> smaValues = calculateSMA(closePrices, SMA_PERIOD);
        BigDecimal lastSMA = smaValues.get(smaValues.size() - 1);

        double[] errorMetrics = calculateErrorMetrics(closePrices, smaValues, SMA_PERIOD);
        BigDecimal stdDev = calculateStdDev(closePrices);

        List<PredictionResult.ForecastPoint> forecast = buildForecast(
                prices.get(prices.size() - 1).getTradeDate(), lastSMA, forecastDays);

        BigDecimal margin = stdDev.multiply(BigDecimal.valueOf(1.96), MC);

        return PredictionResult.builder()
                .ticker(ticker)
                .method("Simple Moving Average (SMA-" + SMA_PERIOD + ")")
                .predictionDate(LocalDate.now())
                .predictedPrice(lastSMA.setScale(4, RoundingMode.HALF_UP))
                .confidenceLower(lastSMA.subtract(margin).setScale(4, RoundingMode.HALF_UP))
                .confidenceUpper(lastSMA.add(margin).setScale(4, RoundingMode.HALF_UP))
                .mape(errorMetrics[0])
                .rmse(errorMetrics[1])
                .forecast(forecast)
                .build();
    }

    public PredictionResult predictWithLinearRegression(String ticker, int forecastDays) {
        List<StockPrice> prices = stockPriceRepository.findByTickerOrderByTradeDateAsc(ticker);
        validateSufficientData(prices, 10, ticker);

        List<BigDecimal> closePrices = extractClosePrices(prices);
        int n = closePrices.size();

        double[] coefficients = fitLinearRegression(closePrices);
        double slope = coefficients[0];
        double intercept = coefficients[1];

        BigDecimal predictedNextPrice = BigDecimal.valueOf(slope * n + intercept)
                .setScale(4, RoundingMode.HALF_UP);

        BigDecimal stdDev = calculateResidualStdDev(closePrices, slope, intercept);
        BigDecimal margin = stdDev.multiply(BigDecimal.valueOf(1.96), MC);

        double[] errorMetrics = calculateRegressionError(closePrices, slope, intercept);

        List<PredictionResult.ForecastPoint> forecast = new ArrayList<>();
        LocalDate lastDate = prices.get(prices.size() - 1).getTradeDate();
        for (int i = 1; i <= forecastDays; i++) {
            double forecastValue = slope * (n + i) + intercept;
            forecast.add(PredictionResult.ForecastPoint.builder()
                    .date(lastDate.plusDays(i))
                    .price(BigDecimal.valueOf(forecastValue).setScale(4, RoundingMode.HALF_UP))
                    .build());
        }

        return PredictionResult.builder()
                .ticker(ticker)
                .method("Linear Regression (OLS)")
                .predictionDate(LocalDate.now())
                .predictedPrice(predictedNextPrice)
                .confidenceLower(predictedNextPrice.subtract(margin).setScale(4, RoundingMode.HALF_UP))
                .confidenceUpper(predictedNextPrice.add(margin).setScale(4, RoundingMode.HALF_UP))
                .mape(errorMetrics[0])
                .rmse(errorMetrics[1])
                .forecast(forecast)
                .build();
    }

    // --- Core Algorithms ---

    List<BigDecimal> calculateEMA(List<BigDecimal> prices, int period) {
        List<BigDecimal> ema = new ArrayList<>();
        BigDecimal multiplier = BigDecimal.valueOf(2.0 / (period + 1));

        BigDecimal initialSMA = prices.subList(0, period).stream()
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(period), MC);

        ema.add(initialSMA);

        for (int i = period; i < prices.size(); i++) {
            BigDecimal currentPrice = prices.get(i);
            BigDecimal previousEMA = ema.get(ema.size() - 1);
            BigDecimal currentEMA = currentPrice.subtract(previousEMA)
                    .multiply(multiplier, MC)
                    .add(previousEMA);
            ema.add(currentEMA);
        }
        return ema;
    }

    List<BigDecimal> calculateSMA(List<BigDecimal> prices, int period) {
        List<BigDecimal> sma = new ArrayList<>();
        for (int i = period; i <= prices.size(); i++) {
            BigDecimal sum = prices.subList(i - period, i).stream()
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            sma.add(sum.divide(BigDecimal.valueOf(period), MC));
        }
        return sma;
    }

    double[] fitLinearRegression(List<BigDecimal> prices) {
        int n = prices.size();
        double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

        for (int i = 0; i < n; i++) {
            double y = prices.get(i).doubleValue();
            sumX += i;
            sumY += y;
            sumXY += i * y;
            sumX2 += (double) i * i;
        }

        double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
        double intercept = (sumY - slope * sumX) / n;
        return new double[]{slope, intercept};
    }

    BigDecimal calculateStdDev(List<BigDecimal> prices) {
        int n = prices.size();
        BigDecimal mean = prices.stream()
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(n), MC);

        BigDecimal variance = prices.stream()
                .map(p -> p.subtract(mean).pow(2))
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(n), MC);

        return BigDecimal.valueOf(Math.sqrt(variance.doubleValue()));
    }

    private BigDecimal calculateResidualStdDev(List<BigDecimal> prices, double slope, double intercept) {
        int n = prices.size();
        double sumSquaredResiduals = 0;
        for (int i = 0; i < n; i++) {
            double predicted = slope * i + intercept;
            double residual = prices.get(i).doubleValue() - predicted;
            sumSquaredResiduals += residual * residual;
        }
        return BigDecimal.valueOf(Math.sqrt(sumSquaredResiduals / n));
    }

    private double[] calculateErrorMetrics(List<BigDecimal> actual, List<BigDecimal> predicted, int offset) {
        int n = Math.min(actual.size() - offset, predicted.size());
        double sumMAPE = 0, sumRMSE = 0;

        for (int i = 0; i < n; i++) {
            double a = actual.get(i + offset).doubleValue();
            double p = predicted.get(i).doubleValue();
            if (a != 0) {
                sumMAPE += Math.abs((a - p) / a);
            }
            sumRMSE += (a - p) * (a - p);
        }

        return new double[]{
                n > 0 ? (sumMAPE / n) * 100 : 0,
                n > 0 ? Math.sqrt(sumRMSE / n) : 0
        };
    }

    private double[] calculateRegressionError(List<BigDecimal> prices, double slope, double intercept) {
        int n = prices.size();
        double sumMAPE = 0, sumRMSE = 0;

        for (int i = 0; i < n; i++) {
            double actual = prices.get(i).doubleValue();
            double predicted = slope * i + intercept;
            if (actual != 0) {
                sumMAPE += Math.abs((actual - predicted) / actual);
            }
            sumRMSE += (actual - predicted) * (actual - predicted);
        }

        return new double[]{
                (sumMAPE / n) * 100,
                Math.sqrt(sumRMSE / n)
        };
    }

    private List<PredictionResult.ForecastPoint> buildForecast(LocalDate lastDate, BigDecimal basePrice, int days) {
        List<PredictionResult.ForecastPoint> forecast = new ArrayList<>();
        for (int i = 1; i <= days; i++) {
            forecast.add(PredictionResult.ForecastPoint.builder()
                    .date(lastDate.plusDays(i))
                    .price(basePrice.setScale(4, RoundingMode.HALF_UP))
                    .build());
        }
        return forecast;
    }

    private List<BigDecimal> extractClosePrices(List<StockPrice> prices) {
        return prices.stream()
                .map(StockPrice::getClosePrice)
                .collect(Collectors.toList());
    }

    private void validateSufficientData(List<StockPrice> prices, int minRequired, String ticker) {
        if (prices.size() < minRequired) {
            throw new IllegalArgumentException(
                    String.format("Insufficient data for ticker '%s'. Required: %d, Found: %d",
                            ticker, minRequired, prices.size()));
        }
    }
}
