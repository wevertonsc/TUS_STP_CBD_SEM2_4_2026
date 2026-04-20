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

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "stock_prices")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StockPrice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(nullable = false, length = 10)
    private String ticker;

    @NotNull
    @Column(nullable = false)
    private LocalDate tradeDate;

    @NotNull
    @Positive
    @Column(nullable = false, precision = 12, scale = 4)
    private BigDecimal openPrice;

    @NotNull
    @Positive
    @Column(nullable = false, precision = 12, scale = 4)
    private BigDecimal highPrice;

    @NotNull
    @Positive
    @Column(nullable = false, precision = 12, scale = 4)
    private BigDecimal lowPrice;

    @NotNull
    @Positive
    @Column(nullable = false, precision = 12, scale = 4)
    private BigDecimal closePrice;

    @NotNull
    @Positive
    @Column(nullable = false)
    private Long volume;
}
