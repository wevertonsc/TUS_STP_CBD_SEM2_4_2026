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

import com.stockpredictor.model.StockPrice;
import com.stockpredictor.repository.StockPriceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class StockPriceService {

    private final StockPriceRepository repository;

    @Transactional(readOnly = true)
    public List<StockPrice> getAllPricesForTicker(String ticker) {
        log.info("Fetching all prices for ticker: {}", ticker);
        return repository.findByTickerOrderByTradeDateAsc(ticker.toUpperCase());
    }

    @Transactional(readOnly = true)
    public List<StockPrice> getPricesInRange(String ticker, LocalDate from, LocalDate to) {
        log.info("Fetching prices for ticker {} between {} and {}", ticker, from, to);
        return repository.findByTickerAndTradeDateBetweenOrderByTradeDateAsc(
                ticker.toUpperCase(), from, to);
    }

    @Transactional(readOnly = true)
    public List<String> getAllTickers() {
        return repository.findAllTickers();
    }

    @Transactional
    public StockPrice save(StockPrice stockPrice) {
        stockPrice.setTicker(stockPrice.getTicker().toUpperCase());
        log.info("Saving stock price for {} on {}", stockPrice.getTicker(), stockPrice.getTradeDate());
        return repository.save(stockPrice);
    }

    @Transactional
    public List<StockPrice> saveAll(List<StockPrice> stockPrices) {
        stockPrices.forEach(sp -> sp.setTicker(sp.getTicker().toUpperCase()));
        log.info("Bulk saving {} stock price records", stockPrices.size());
        return repository.saveAll(stockPrices);
    }

    @Transactional
    public void deleteById(Long id) {
        log.info("Deleting stock price record with id: {}", id);
        repository.deleteById(id);
    }

    @Transactional(readOnly = true)
    public boolean existsByTickerAndDate(String ticker, LocalDate date) {
        return repository.existsByTickerAndTradeDate(ticker.toUpperCase(), date);
    }
}
