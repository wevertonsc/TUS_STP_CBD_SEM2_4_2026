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
package com.stockpredictor.config;

import com.stockpredictor.model.StockPrice;
import com.stockpredictor.repository.StockPriceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

@Slf4j
@Component
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {

    private final StockPriceRepository repository;

    @Override
    public void run(String... args) {
        if (repository.count() == 0) {
            log.info("Seeding sample stock data...");
            repository.saveAll(generateSampleData("AAPL", 180.0, 60));
            repository.saveAll(generateSampleData("MSFT", 310.0, 60));
            repository.saveAll(generateSampleData("GOOGL", 140.0, 60));
            log.info("Sample data seeded successfully.");
        }
    }

    private List<StockPrice> generateSampleData(String ticker, double startPrice, int days) {
        List<StockPrice> prices = new ArrayList<>();
        Random rng = new Random(ticker.hashCode());
        double price = startPrice;
        LocalDate date = LocalDate.now().minusDays(days);

        for (int i = 0; i < days; i++) {
            double change = (rng.nextDouble() - 0.48) * 3.0;
            price = Math.max(1.0, price + change);

            double high = price + rng.nextDouble() * 2;
            double low = price - rng.nextDouble() * 2;
            double open = low + rng.nextDouble() * (high - low);

            prices.add(StockPrice.builder()
                    .ticker(ticker)
                    .tradeDate(date.plusDays(i))
                    .openPrice(BigDecimal.valueOf(open).setScale(4, java.math.RoundingMode.HALF_UP))
                    .highPrice(BigDecimal.valueOf(high).setScale(4, java.math.RoundingMode.HALF_UP))
                    .lowPrice(BigDecimal.valueOf(low).setScale(4, java.math.RoundingMode.HALF_UP))
                    .closePrice(BigDecimal.valueOf(price).setScale(4, java.math.RoundingMode.HALF_UP))
                    .volume((long) (rng.nextInt(50000000) + 10000000))
                    .build());
        }
        return prices;
    }
}
