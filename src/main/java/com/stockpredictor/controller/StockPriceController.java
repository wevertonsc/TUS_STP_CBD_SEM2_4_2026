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

import com.stockpredictor.model.StockPrice;
import com.stockpredictor.service.StockPriceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/v1/stocks")
@RequiredArgsConstructor
@Tag(name = "Stock Data API", description = "CRUD operations for historical stock price data")
public class StockPriceController {

    private final StockPriceService stockPriceService;

    @GetMapping("/tickers")
    @Operation(summary = "List all available tickers")
    public ResponseEntity<List<String>> getAllTickers() {
        return ResponseEntity.ok(stockPriceService.getAllTickers());
    }

    @GetMapping("/{ticker}")
    @Operation(summary = "Get all historical prices for a ticker")
    public ResponseEntity<List<StockPrice>> getPricesByTicker(@PathVariable String ticker) {
        return ResponseEntity.ok(stockPriceService.getAllPricesForTicker(ticker));
    }

    @GetMapping("/{ticker}/range")
    @Operation(summary = "Get prices for a ticker within a date range")
    public ResponseEntity<List<StockPrice>> getPricesInRange(
            @PathVariable String ticker,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(stockPriceService.getPricesInRange(ticker, from, to));
    }

    @PostMapping
    @Operation(summary = "Add a new stock price record")
    public ResponseEntity<StockPrice> createStockPrice(@Valid @RequestBody StockPrice stockPrice) {
        return ResponseEntity.status(HttpStatus.CREATED).body(stockPriceService.save(stockPrice));
    }

    @PostMapping("/batch")
    @Operation(summary = "Bulk insert stock price records")
    public ResponseEntity<List<StockPrice>> createBatch(@Valid @RequestBody List<StockPrice> prices) {
        return ResponseEntity.status(HttpStatus.CREATED).body(stockPriceService.saveAll(prices));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Delete a stock price record by ID")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        stockPriceService.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}
