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
package com.stockpredictor.repository;

import com.stockpredictor.model.StockPrice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface StockPriceRepository extends JpaRepository<StockPrice, Long> {

    List<StockPrice> findByTickerOrderByTradeDateAsc(String ticker);

    List<StockPrice> findByTickerAndTradeDateBetweenOrderByTradeDateAsc(
            String ticker, LocalDate startDate, LocalDate endDate);

    Optional<StockPrice> findByTickerAndTradeDate(String ticker, LocalDate tradeDate);

    @Query("SELECT DISTINCT s.ticker FROM StockPrice s ORDER BY s.ticker")
    List<String> findAllTickers();

    @Query("SELECT s FROM StockPrice s WHERE s.ticker = :ticker ORDER BY s.tradeDate DESC")
    List<StockPrice> findRecentByTicker(@Param("ticker") String ticker);

    boolean existsByTickerAndTradeDate(String ticker, LocalDate tradeDate);
}
