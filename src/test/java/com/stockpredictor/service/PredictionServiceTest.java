package com.stockpredictor.service;

import com.stockpredictor.model.PredictionResult;
import com.stockpredictor.model.StockPrice;
import com.stockpredictor.repository.StockPriceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("PredictionService Unit Tests")
class PredictionServiceTest {

    @Mock
    private StockPriceRepository stockPriceRepository;

    @InjectMocks
    private PredictionService predictionService;

    private List<StockPrice> samplePrices;

    @BeforeEach
    void setUp() {
        samplePrices = generatePrices("AAPL", 30, 150.0);
    }

    @Test
    @DisplayName("EMA prediction returns valid result with correct ticker")
    void testEMAPredictionReturnsTicker() {
        when(stockPriceRepository.findByTickerOrderByTradeDateAsc("AAPL"))
                .thenReturn(samplePrices);

        PredictionResult result = predictionService.predictWithEMA("AAPL", 5);

        assertThat(result).isNotNull();
        assertThat(result.getTicker()).isEqualTo("AAPL");
        assertThat(result.getMethod()).contains("EMA");
        assertThat(result.getPredictedPrice()).isPositive();
    }

    @Test
    @DisplayName("EMA confidence interval: lower must be less than upper")
    void testEMAConfidenceInterval() {
        when(stockPriceRepository.findByTickerOrderByTradeDateAsc("AAPL"))
                .thenReturn(samplePrices);

        PredictionResult result = predictionService.predictWithEMA("AAPL", 5);

        assertThat(result.getConfidenceLower()).isLessThan(result.getConfidenceUpper());
    }

    @Test
    @DisplayName("EMA forecast contains requested number of days")
    void testEMAForecastSize() {
        when(stockPriceRepository.findByTickerOrderByTradeDateAsc("AAPL"))
                .thenReturn(samplePrices);

        PredictionResult result = predictionService.predictWithEMA("AAPL", 5);

        assertThat(result.getForecast()).hasSize(5);
    }

    @Test
    @DisplayName("SMA prediction returns valid result")
    void testSMAPrediction() {
        when(stockPriceRepository.findByTickerOrderByTradeDateAsc("MSFT"))
                .thenReturn(generatePrices("MSFT", 30, 300.0));

        PredictionResult result = predictionService.predictWithSMA("MSFT", 3);

        assertThat(result).isNotNull();
        assertThat(result.getMethod()).contains("SMA");
        assertThat(result.getPredictedPrice()).isPositive();
        assertThat(result.getForecast()).hasSize(3);
    }

    @Test
    @DisplayName("Linear regression prediction returns trend-based result")
    void testLinearRegressionPrediction() {
        when(stockPriceRepository.findByTickerOrderByTradeDateAsc("GOOGL"))
                .thenReturn(generatePrices("GOOGL", 30, 140.0));

        PredictionResult result = predictionService.predictWithLinearRegression("GOOGL", 5);

        assertThat(result).isNotNull();
        assertThat(result.getMethod()).contains("Regression");
        assertThat(result.getForecast()).hasSize(5);
    }

    @Test
    @DisplayName("EMA throws exception when insufficient data")
    void testEMAThrowsOnInsufficientData() {
        when(stockPriceRepository.findByTickerOrderByTradeDateAsc("TINY"))
                .thenReturn(generatePrices("TINY", 5, 50.0));

        assertThatThrownBy(() -> predictionService.predictWithEMA("TINY", 5))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Insufficient data");
    }

    @Test
    @DisplayName("SMA throws exception when insufficient data")
    void testSMAThrowsOnInsufficientData() {
        when(stockPriceRepository.findByTickerOrderByTradeDateAsc("TINY"))
                .thenReturn(generatePrices("TINY", 10, 50.0));

        assertThatThrownBy(() -> predictionService.predictWithSMA("TINY", 5))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Insufficient data");
    }

    @Test
    @DisplayName("EMA values list size is correct relative to period")
    void testEMAListSize() {
        List<BigDecimal> prices = new ArrayList<>();
        for (int i = 0; i < 20; i++) {
            prices.add(BigDecimal.valueOf(100 + i));
        }

        List<BigDecimal> ema = predictionService.calculateEMA(prices, 14);

        assertThat(ema).hasSize(7); // 20 - 14 + 1
    }

    @Test
    @DisplayName("SMA values are within expected price range")
    void testSMAWithinRange() {
        List<BigDecimal> prices = new ArrayList<>();
        for (int i = 0; i < 25; i++) {
            prices.add(BigDecimal.valueOf(100.0));
        }

        List<BigDecimal> sma = predictionService.calculateSMA(prices, 20);

        assertThat(sma).isNotEmpty();
        sma.forEach(v -> assertThat(v.doubleValue()).isEqualTo(100.0));
    }

    @Test
    @DisplayName("MAPE is a non-negative percentage")
    void testMAPEIsNonNegative() {
        when(stockPriceRepository.findByTickerOrderByTradeDateAsc("AAPL"))
                .thenReturn(samplePrices);

        PredictionResult result = predictionService.predictWithEMA("AAPL", 5);

        assertThat(result.getMape()).isGreaterThanOrEqualTo(0.0);
    }

    @Test
    @DisplayName("RMSE is a non-negative value")
    void testRMSEIsNonNegative() {
        when(stockPriceRepository.findByTickerOrderByTradeDateAsc("AAPL"))
                .thenReturn(samplePrices);

        PredictionResult result = predictionService.predictWithEMA("AAPL", 5);

        assertThat(result.getRmse()).isGreaterThanOrEqualTo(0.0);
    }

    @Test
    @DisplayName("Standard deviation is positive for varying prices")
    void testStdDevIsPositive() {
        List<BigDecimal> prices = List.of(
                BigDecimal.valueOf(100), BigDecimal.valueOf(105),
                BigDecimal.valueOf(98), BigDecimal.valueOf(110));

        BigDecimal stdDev = predictionService.calculateStdDev(prices);

        assertThat(stdDev.doubleValue()).isGreaterThan(0.0);
    }

    @Test
    @DisplayName("Prediction date is set to today")
    void testPredictionDateIsToday() {
        when(stockPriceRepository.findByTickerOrderByTradeDateAsc("AAPL"))
                .thenReturn(samplePrices);

        PredictionResult result = predictionService.predictWithEMA("AAPL", 5);

        assertThat(result.getPredictionDate()).isEqualTo(LocalDate.now());
    }

    // --- Helper ---
    private List<StockPrice> generatePrices(String ticker, int count, double startPrice) {
        List<StockPrice> prices = new ArrayList<>();
        double price = startPrice;
        for (int i = 0; i < count; i++) {
            price += (Math.random() - 0.5) * 2;
            prices.add(StockPrice.builder()
                    .ticker(ticker)
                    .tradeDate(LocalDate.now().minusDays(count - i))
                    .openPrice(BigDecimal.valueOf(price))
                    .highPrice(BigDecimal.valueOf(price + 1))
                    .lowPrice(BigDecimal.valueOf(price - 1))
                    .closePrice(BigDecimal.valueOf(price))
                    .volume(1000000L)
                    .build());
        }
        return prices;
    }
}
