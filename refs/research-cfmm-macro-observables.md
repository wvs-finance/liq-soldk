# CFMM Pool Observables as Macro Variable Proxies

*Research date: 2026-03-31*
*Project: liq-soldk-dev -- Macro Risk Hedging via On-Chain Instruments*

---

## Executive Summary

This report maps every observable produced by a Constant Function Market Maker (CFMM) pool -- specifically Uniswap v3, Algebra Integral, and Balancer weighted pools trading emerging-market stablecoin pairs (cNGN/USDC, cCOP/USDC, cKES/cUSD, MXNB/USDC, etc.) -- to the macro variable it can proxy. The analysis covers five observable categories (price, volume, LP income, liquidity, position structure) and ten macro variables (local inflation, currency depreciation, capital flight, remittance flows, interest rate shocks, terms of trade, currency crisis, labor market stress, liquidity crisis, monetary policy divergence).

The central finding is that CFMM pools produce a rich information surface. Price observables are the strongest proxies for FX depreciation and currency crisis; volume observables best capture capital flight and remittance flow changes; LP income observables proxy local economic health and interest rate dynamics; liquidity structure observables reveal market stress and confidence; and position-level data encodes informed LP expectations. Critically, the deviation between the on-chain price and the official central bank rate -- the "parallel market premium" -- is the single most powerful macro signal available from EM stablecoin pools, directly analogous to the black market premium studied extensively in the informal FX literature.

We also analyze AMPL as a real-value unit of account, cross-EM pairs, Balancer vs Uniswap v3 signal quality, and Algebra's adaptive fees as a macro observable in themselves. For each mapping, we provide theoretical justification, signal quality assessment, noise sources, academic references, and Solidity function signatures for extraction.

---

## Table of Contents

1. [Theoretical Framework](#1-theoretical-framework)
2. [Price Observables](#2-price-observables)
3. [Volume Observables](#3-volume-observables)
4. [LP Income Observables](#4-lp-income-observables)
5. [Liquidity Observables](#5-liquidity-observables)
6. [Position Observables](#6-position-observables)
7. [Cross-Cutting Analysis: AMPL, Cross-EM Pairs, AMM Architecture](#7-cross-cutting-analysis)
8. [Composite Macro Indices](#8-composite-macro-indices)
9. [Solidity Implementation Reference](#9-solidity-implementation-reference)
10. [Academic References](#10-academic-references)

---

## 1. Theoretical Framework

### 1.1 Why CFMM Pools Encode Macro Information

A CFMM pool trading a local-currency stablecoin against a hard-currency stablecoin (e.g., cNGN/USDC) is, in economic terms, an informal FX market with the following properties:

- **Continuous price discovery**: The pool's `sqrtPriceX96` updates on every swap, producing a real-time exchange rate.
- **Incentive-compatible information revelation**: Arbitrageurs who trade the pool to align it with external markets reveal their private information about the "true" exchange rate (Kyle, 1985; Angeris et al., 2020 "Improved Price Oracles").
- **Skin-in-the-game liquidity provision**: LPs who provide capital at specific price ranges reveal their beliefs about the probability distribution of future exchange rates (Shiller, 1993; Milionis et al., 2022 "LVR").
- **Observable income streams**: Fee accrual (feeGrowthGlobal) is a direct, manipulation-resistant measure of economic activity flowing through the pair -- a Shillerian "income claim" observable.

This makes CFMM pools a natural extension of the informal/parallel FX markets that have been studied extensively in emerging-market macroeconomics (Reinhart & Rogoff, 2004; Kiguel & O'Connell, 1995). The key difference is that CFMM observables are (a) on-chain and thus verifiable, (b) timestamped at block granularity, (c) decomposable into price, volume, income, and structural components, and (d) composable with derivative instruments.

### 1.2 Shiller's Macro Markets Framework Applied to CFMMs

Robert Shiller's "Macro Markets" (1993) proposed perpetual claims on national income indices as instruments for managing society's largest economic risks. The framework requires:

1. An **observable index** that proxies the risk to be hedged
2. A **settlement mechanism** that pays out based on that index
3. A **cash market** whose price reveals collective expectations about the index

A CFMM pool simultaneously produces (1) -- the observables enumerated below -- and (3) -- the pool IS the cash market. What remains is (2), which is the contract layer we are building in this project.

### 1.3 Information Theory of Pool Observables

Following Shannon's information theory and the signal processing pipeline from the project's MACRO_RISKS notes:

```
Raw Observable  -->  Filter  -->  Signal  -->  Index  -->  Settlement
     |                |             |            |             |
  sqrtPriceX96      TWAP/EMA    Denoised     Composite      Payoff
  feeGrowth         Kalman      series       macro          function
  volume            outlier                  stress
                    removal                  score
```

Each pool observable has a **signal-to-noise ratio** for each macro variable. Our task is to characterize this SNR across all observable-variable pairs.

---

## 2. Price Observables

### 2.1 Spot Price (sqrtPriceX96)

**Macro Variable: Currency Depreciation (PRIMARY), Currency Crisis**

The spot price of a cNGN/USDC pool IS the informal exchange rate of the Nigerian naira against the US dollar. When this price moves, it directly reflects:

- **Currency depreciation**: A falling cNGN/USDC price (more cNGN needed per USDC) is definitionally naira depreciation in the on-chain market.
- **Currency crisis**: Rapid, discontinuous price moves indicate a crisis regime. The speed and magnitude of the move encode the severity.

**Theoretical Justification**: The fundamental theorem of asset pricing holds in CFMMs under reasonable conditions (Angeris, Chitra, Evans, 2020). Arbitrageurs ensure that the pool price converges to the external market price. For EM stablecoins, the "external market" IS the informal/parallel FX market, since the official rate is often controlled. Therefore, the pool price reveals the market-clearing rate that incorporates private information about FX fundamentals.

**Signal Quality**: STRONG proxy for currency depreciation. The pool price is the single most direct observable for this variable. It is identical in economic function to the black market rate observed at Bureau de Change in Lagos or at money changers in Manila.

**Noise Sources**:
- Low liquidity causing price impact from individual swaps (filter: use TWAP)
- Arbitrage latency between on-chain and off-chain markets (typically seconds to minutes)
- Smart contract exploit or manipulation (filter: outlier removal, multi-source confirmation)
- Stablecoin depeg of the reference asset (USDC depegging from $1)

**Academic References**:
- Angeris, Chitra, Evans (2020), "Improved Price Oracles: Constant Function Market Makers," arxiv:2003.10001
- Reinhart & Rogoff (2004), "The Modern History of Exchange Rate Arrangements"
- Alexander (2025), "Price Discovery and Efficiency in Uniswap Liquidity Pools," Journal of Futures Markets

**Solidity Extraction**:
```solidity
// Uniswap v4 / v3
(uint160 sqrtPriceX96, int24 tick, , ) = pool.slot0();
// Convert to human-readable price:
// price = (sqrtPriceX96 / 2^96)^2 = sqrtPriceX96^2 / 2^192

// Algebra Integral
(uint160 sqrtPrice, int24 tick, , , , ) = IAlgebraPool(pool).globalState();
```

---

### 2.2 Time-Weighted Average Price (TWAP)

**Macro Variable: Currency Depreciation (filtered), Monetary Policy Divergence**

TWAP over windows of 1h, 4h, 1d, 7d, 30d filters microstructure noise and provides a smoothed exchange rate signal. The 30-day TWAP is analogous to the monthly average rate reported by central banks.

**Theoretical Justification**: The TWAP oracle is provably manipulation-resistant for multi-block windows (Angeris et al., 2020). For macro analysis, the TWAP slope (d(TWAP)/dt) over 30-day windows directly measures the depreciation rate, analogous to the annualized depreciation rate used in macro models. Divergence between short-window and long-window TWAPs indicates regime change.

**Signal Quality**: STRONG. TWAP is the workhorse signal for all price-derived macro variables. The 30-day TWAP is the most natural settlement index for perpetual income claims.

**Noise Sources**:
- Liquidity regime changes within the window
- TWAP can lag sudden regime shifts (use shorter windows for crisis detection)

**Macro Variable Mapping**:
| TWAP Window | Best Macro Proxy | Rationale |
|---|---|---|
| 1h | Currency crisis detection | Captures intraday panic |
| 1d | Short-term capital flow signals | Daily FX market rhythm |
| 7d | Remittance cycle patterns | Weekly diaspora sending rhythm |
| 30d | Currency depreciation trend | Monthly macro reporting cycle |
| 90d | Monetary policy stance divergence | Aligns with central bank meeting cycles |

**Solidity Extraction**:
```solidity
// Uniswap v3 / Algebra: oracle.consult(window) returns arithmetic mean tick
int24 twapTick = OracleLibrary.consult(oracleAddress, secondsAgo);
uint160 twapSqrtPrice = TickMath.getSqrtRatioAtTick(twapTick);

// From AlgebraVolatilityLens.sol in this project:
int24 strikeTick = getStrikeByAvg(pair, factory, window);
```

---

### 2.3 Price Volatility (Realized Vol)

**Macro Variable: Currency Crisis (PRIMARY), Capital Flight, Interest Rate Shock**

Realized volatility of the pool price over rolling windows captures the uncertainty in the exchange rate. Spikes in realized vol are the canonical early warning signal for currency crises.

**Theoretical Justification**: The empirical finance literature (Reinhart, 2000; Kaminsky, Lizondo, Reinhart, 1998 "Leading Indicators of Currency Crises") identifies exchange rate volatility as one of the strongest leading indicators of currency crises. In the KLR framework, a spike in FX vol that exceeds 2 standard deviations from the historical mean triggers a crisis signal. The same logic applies to pool price vol.

Additionally, realized vol scales with the square root of time and is directly linked to LP income via the fee-to-LVR relationship (Milionis et al., 2022): fees ~ vol^2. This means that vol is embedded in the pool's income structure.

**Signal Quality**: STRONG for currency crisis detection. MODERATE for capital flight (vol spikes precede or accompany capital flight). MODERATE for interest rate shock (rate changes cause FX vol spikes with a lag).

**Noise Sources**:
- Low-liquidity pools have structurally higher vol (normalize by liquidity)
- Intraday patterns (deseasonalize)
- Outlier swaps from MEV or errors

**Academic References**:
- Kaminsky, Lizondo, Reinhart (1998), "Leading Indicators of Currency Crises," IMF Staff Papers
- Milionis, Moallemi, Roughgarden, Zhang (2022), "Automated Market Making and Loss-Versus-Rebalancing," arxiv:2208.06046
- Lambert (2021), "On-Chain Volatility and Uniswap v3" (fee-vol relationship)
- This project: `AlgebraVolatilityLens.sol` computes variance directly from Algebra's `volatilityCumulative` accumulator

**Solidity Extraction**:
```solidity
// Algebra: volatilityCumulative accumulator gives sigma^2 * T directly
(, uint88 volCumNow)  = oracle.getSingleTimepoint(0);
(, uint88 volCumThen) = oracle.getSingleTimepoint(window);
uint256 varianceOverWindow = uint256(volCumNow - volCumThen);
// sigma_ticks = sqrt(varianceOverWindow)

// Valorem/Aloe approach: implied vol from fee revenue
// See lib/valorem-oracles/src/libraries/Volatility.sol
uint256 iv24h = Volatility.estimate24H(metadata, data, feeGrowthA, feeGrowthB);

// Voltaire: cross-chain realized vol from ring buffer
uint256 vol = VolatilityOracle(oracle).getVolatility(); // WAD, annualized
```

---

### 2.4 Price Deviation from Official Rate (Parallel Market Premium)

**Macro Variable: Currency Crisis (PRIMARY), Capital Flight (PRIMARY), Capital Controls**

The spread between the on-chain CFMM price and the official central bank rate (obtained via Chainlink oracle or other off-chain feed) is the **parallel market premium**. This is the single most information-rich macro signal available from EM stablecoin pools.

**Theoretical Justification**: The parallel market premium has been studied extensively as a macro indicator (Kiguel & O'Connell, 1995; Reinhart & Rogoff, 2004). Key findings from the literature:

- A sustained premium > 20% signals severe capital controls and/or currency crisis
- The premium Granger-causes official devaluation (i.e., it predicts future policy action)
- Premium volatility signals policy uncertainty
- Premium mean-reversion speed signals central bank credibility

In Nigeria specifically, the naira black market premium has ranged from 0% (during convergence periods, e.g., March 2024 when official and parallel rates converged near N1,500/$) to over 100% (during severe control periods). The on-chain cNGN/USDC rate vs. the CBN official rate directly replicates this premium in a verifiable, timestamped manner.

**Signal Quality**: STRONG -- this is arguably the most powerful macro signal in the entire observable set. It is a direct, market-based measure of capital control severity and currency misalignment.

**Noise Sources**:
- Stale oracle feeds for the official rate (Chainlink feed update frequency)
- Differences in convention (mid-rate vs. bid/ask)
- cNGN-specific basis risk (the stablecoin may trade at a premium/discount to the naira itself)

**Academic References**:
- Kiguel & O'Connell (1995), "Parallel Exchange Rates in Developing Countries," World Bank Research Observer
- Reinhart & Rogoff (2004), "The Modern History of Exchange Rate Arrangements: A Reinterpretation"
- BIS Working Paper No. 1265, "DeFiying Gravity: Cross-Border Crypto Flows" (2024)
- Nairametrics / Bloomberg (2024), reporting on NGN official-parallel rate convergence

**Solidity Extraction**:
```solidity
// Premium = (onChainRate - officialRate) / officialRate
function parallelMarketPremium(
    address pool,
    address chainlinkFeed,
    uint32 twapWindow
) external view returns (int256 premiumBps) {
    int24 twapTick = OracleLibrary.consult(pool, twapWindow);
    uint256 onChainRate = _tickToPrice(twapTick); // cNGN per USDC

    (, int256 officialRate, , , ) = AggregatorV3Interface(chainlinkFeed).latestRoundData();

    premiumBps = int256((onChainRate - uint256(officialRate)) * 10000 / uint256(officialRate));
}
```

---

### 2.5 Bid-Ask Spread Implied by Liquidity Distribution

**Macro Variable: Liquidity Crisis, Currency Crisis (early warning)**

In a Uniswap v3 / Algebra pool, the effective bid-ask spread is determined by the density of liquidity around the current tick. Thin liquidity implies a wide spread, meaning high transaction costs for FX conversion.

**Theoretical Justification**: Market microstructure theory (Glosten & Milgrom, 1985; Kyle, 1985) establishes that bid-ask spreads widen when adverse selection risk increases -- i.e., when informed traders dominate. In an EM stablecoin pool, widening spreads indicate that LPs are retreating from providing liquidity because they fear large directional moves (currency crisis) or because informed capital flight is intensifying.

**Signal Quality**: MODERATE for liquidity crisis. MODERATE as an early warning for currency crisis (spreads widen before the price moves, as LPs pull liquidity in anticipation).

**Solidity Extraction**:
```solidity
// Effective spread = price impact of a reference trade size
// Approximate from liquidity at current tick
function impliedSpread(address pool, uint256 refAmountIn) external view returns (uint256 spreadBps) {
    uint128 currentLiquidity = IUniswapV3Pool(pool).liquidity();
    // Price impact ~ refAmountIn / (currentLiquidity * tickSpacing_value)
    // Convert to basis points
}
```

---

### 2.6 Price Impact for Given Trade Sizes

**Macro Variable: Liquidity Crisis (PRIMARY), Capital Flight**

The price impact of a standardized trade size (e.g., $10,000 equivalent) measures market depth. Rising price impact for the same notional signals deteriorating liquidity.

**Theoretical Justification**: Kyle's lambda (Kyle, 1985) -- the price impact coefficient -- measures the informativeness of order flow. In an EM stablecoin pool, lambda increasing over time means that each marginal dollar of flow moves the price more, indicating that liquidity providers are either exiting or concentrating their capital in narrow ranges far from the current price. This is a direct measure of FX market fragility.

**Signal Quality**: STRONG for liquidity crisis. MODERATE for capital flight (large one-directional flows increase impact).

---

## 3. Volume Observables

### 3.1 Swap Volume (Directional: Buy vs Sell)

**Macro Variable: Capital Flight (PRIMARY), Remittance Flow Changes**

Decomposing swap volume into buy-side (buying USDC with cNGN = capital outflow) and sell-side (selling USDC for cNGN = capital inflow or remittance arrival) produces a directional flow signal.

**Theoretical Justification**: In balance-of-payments accounting, net capital outflows = current account deficit + reserve drawdown. An EM stablecoin pool captures a slice of these flows. Persistent buy-side dominance (cNGN --> USDC) indicates capital flight. Periodic sell-side spikes (USDC --> cNGN) with weekly or monthly patterns indicate remittance inflows.

The IMF's 2025 working paper "How to Estimate International Stablecoin Flows" establishes methodology for using on-chain flow data as balance-of-payments proxies: "Tether's USDT is more popular in regions with more emerging economies -- Africa and the Middle East, Asia and the Pacific, and Latin America and the Caribbean." This validates the premise that on-chain stablecoin flows encode real cross-border capital movements.

**Signal Quality**: STRONG for capital flight (directional dominance). STRONG for remittance flow changes (periodic patterns in sell-side volume).

**Noise Sources**:
- Arbitrage volume (two-sided, noise) vs. directional flow (one-sided, signal)
- MEV and sandwich attacks inflate raw volume
- Wash trading (less common in EM stablecoin pairs due to low liquidity)

**Filter**: Net flow = SUM(sell_volume) - SUM(buy_volume) over rolling windows. Positive = net inflow (remittances dominating). Negative = net outflow (capital flight dominating).

**Academic References**:
- IMF Working Paper WP/2025/141, "How to Estimate International Stablecoin Flows"
- BIS Working Paper No. 1265, "DeFiying Gravity: Cross-Border Crypto Flows"
- Pressacademia (2025), "Evidence from Multinational Stablecoin Adoption"

**Solidity Extraction**:
```solidity
// Volume must be tracked off-chain via event indexing or via hooks
// Uniswap v4 hook approach:
function afterSwap(
    address sender,
    PoolKey calldata key,
    IPoolManager.SwapParams calldata params,
    BalanceDelta delta,
    bytes calldata hookData
) external override returns (bytes4, int128) {
    // params.zeroForOne: true = selling token0, false = selling token1
    // delta.amount0() / delta.amount1(): signed amounts
    if (params.zeroForOne) {
        sellVolume0 += uint256(int256(-delta.amount0()));
    } else {
        buyVolume0 += uint256(int256(delta.amount0()));
    }
    return (this.afterSwap.selector, 0);
}
```

---

### 3.2 Net Flow Direction

**Macro Variable: Capital Flight (PRIMARY), Remittance Flow Changes**

The net flow over rolling windows (1d, 7d, 30d) provides a smoothed directional signal. This is the on-chain equivalent of the balance of payments current account.

**Signal Quality**: STRONG. Net flow direction is the single best proxy for capital flight when sustained over 7d+ windows. A reversal in net flow direction after a sustained outflow period signals either capital controls taking effect, currency stabilization, or increased remittance inflows.

**Macro Variable Mapping**:
| Net Flow Pattern | Macro Interpretation |
|---|---|
| Sustained negative (cNGN --> USDC), accelerating | Capital flight, crisis intensifying |
| Sustained negative, decelerating | Capital flight peaking, stabilization possible |
| Periodic positive spikes (weekly/monthly) | Remittance inflows arriving on schedule |
| Positive spikes diminishing over time | Labor market stress in host country (diaspora earning less) |
| Sudden shift from negative to positive | Central bank intervention or capital control enforcement |

---

### 3.3 Volume Acceleration / Deceleration

**Macro Variable: Currency Crisis (leading indicator), Capital Flight**

The second derivative of volume (dV/dt) captures whether capital movement is accelerating. Volume acceleration precedes price moves in market microstructure theory.

**Theoretical Justification**: Easley & O'Hara (1992) show that trade intensity carries information. In the EM context, accelerating outflow volume signals that informed agents are front-running an expected devaluation. This is analogous to the "bank run" dynamics modeled in Diamond & Dybvig (1983), applied to currency instead of deposits.

**Signal Quality**: MODERATE-STRONG as a leading indicator. Volume acceleration often precedes the price move by hours to days.

---

### 3.4 Volume by Time-of-Day Patterns

**Macro Variable: Remittance Flow Changes, Labor Market Stress**

Remittance flows have characteristic time patterns:
- Weekend spikes (diaspora sends money after receiving weekly wages)
- Month-end spikes (monthly salary cycles)
- Holiday spikes (Eid, Christmas, Ramadan for different corridors)

Deviations from these patterns signal changes in the underlying labor market conditions.

**Theoretical Justification**: The IMF's "Propensity to Remit" working paper (2022) identifies macro and micro factors driving remittance flows to Central America and the Caribbean, including labor market conditions, wage levels, and seasonal employment patterns. Time-of-day and time-of-week volume patterns in an on-chain FX pool directly capture these cyclical flows.

**Signal Quality**: MODERATE for remittance flow changes. WEAK-MODERATE for labor market stress (requires long time series to establish baseline patterns).

---

### 3.5 Turnover Ratio (Volume / TVL)

**Macro Variable: Currency Crisis, Capital Flight, Liquidity Crisis**

The turnover ratio normalizes volume by the pool's total value locked, producing a capital velocity measure. High turnover means each dollar of liquidity is being traded through many times -- indicating urgency.

**Theoretical Justification**: In monetary economics, the velocity of money (V = PY/M) is a key macro indicator. The pool turnover ratio is an analogous measure for the on-chain FX market. Rising turnover with stable or falling TVL indicates hot money cycling through the pool -- a crisis signal. Rising turnover with rising TVL indicates healthy market growth.

**Signal Quality**: MODERATE for currency crisis. STRONG for distinguishing crisis (high turnover, falling TVL) from growth (high turnover, rising TVL).

| Turnover Pattern | TVL Trend | Macro Interpretation |
|---|---|---|
| Rising | Falling | Crisis: hot money, capital flight |
| Rising | Rising | Healthy growth: market deepening |
| Falling | Falling | Liquidity crisis: market drying up |
| Falling | Rising | Low activity: stable period, possible controls |

---

## 4. LP Income Observables

### 4.1 Cumulative Fee Revenue (feeGrowthGlobal0X128 / feeGrowthGlobal1X128)

**Macro Variable: Currency Depreciation (lagged), Remittance Flow Changes, Local Economic Health (composite)**

The feeGrowthGlobal accumulators record the total fees earned per unit of liquidity since pool inception. The rate of change of this accumulator (dfeeGrowth/dt) is the instantaneous fee revenue rate.

**Theoretical Justification**: Fee revenue = fee_rate * volume. Volume in an EM stablecoin pool reflects real economic activity (remittances, trade settlement, capital flows). Therefore, fee revenue is a weighted measure of economic throughput. This is precisely Shiller's "income claim" -- a perpetual stream of cash flows that reflects the health of the underlying economic activity.

The key insight from the project's MACRO_RISKS notes: "The beautiful thing is that on-chain, fee_revenue(t-1, t) is not estimated or reported -- it's exactly computable from feeGrowthGlobal. The dividend is a mathematical fact, not an accounting opinion."

**Signal Quality**: MODERATE for currency depreciation (fee revenue rises during crisis periods because vol and volume spike, then collapses as liquidity exits). STRONG for measuring real economic throughput of the corridor.

**Solidity Extraction**:
```solidity
// Uniswap v3 / v4
uint256 feeGrowth0 = pool.feeGrowthGlobal0X128();
uint256 feeGrowth1 = pool.feeGrowthGlobal1X128();

// Delta over period:
uint256 feeRevenue0 = feeGrowth0_now - feeGrowth0_then; // Q128.128 per unit liquidity
uint256 feeRevenue1 = feeGrowth1_now - feeGrowth1_then;

// Convert to absolute amounts:
// revenue_token0 = feeRevenue0 * activeLiquidity / 2^128
```

---

### 4.2 Fee Revenue per Epoch

**Macro Variable: Currency Depreciation, Interest Rate Shock, Remittance Flow Changes**

Fee revenue per epoch (block, hour, day) is the flow measure of pool income. It combines volume (activity) with fee rate (spread), making it a measure of both the quantity and cost of FX transactions.

**Theoretical Justification**: In traditional FX markets, the bid-ask spread and transaction volume together determine dealer revenue. This revenue is a function of both market conditions (volatility, flow imbalance) and market structure (competition, capital). For an EM stablecoin pool, fee revenue per epoch captures both dimensions.

Rising fee revenue can signal:
- Increasing economic activity (positive, healthy market)
- Increasing volatility/crisis (negative, but hedgeable)
- Interest rate shock causing portfolio rebalancing

**Signal Quality**: MODERATE across multiple variables. Best used as a component in composite indices rather than as a standalone proxy.

---

### 4.3 Fee Revenue Volatility

**Macro Variable: Interest Rate Shock, Currency Crisis**

The volatility of fee revenue itself (as opposed to price volatility) captures uncertainty in economic throughput. Stable fee revenue indicates steady-state flows; volatile fee revenue indicates regime instability.

**Theoretical Justification**: Income volatility is a direct measure of economic risk in the Shillerian framework. If the income claim on a corridor (perpetual claim on cNGN/USDC fees) has rising volatility, this means the underlying economic activity in that corridor is becoming less predictable -- exactly the risk we want to hedge.

**Signal Quality**: MODERATE for interest rate shock (rate changes cause sudden volume shifts, which cause fee revenue spikes). MODERATE for currency crisis (fee revenue spikes then collapses).

---

### 4.4 Fee Revenue Yield (Fee Revenue / TVL)

**Macro Variable: Interest Rate Shock (PRIMARY), Monetary Policy Divergence**

Fee yield = annualized fee revenue / TVL. This is the on-chain "interest rate" for providing FX liquidity. It is directly comparable to:
- The central bank policy rate
- The stETH yield (US dollar risk-free proxy)
- The local government bond yield

**Theoretical Justification**: The spread between the on-chain fee yield and the local risk-free rate reflects the risk premium demanded by LPs for bearing FX risk. This spread is analogous to the term premium in bond markets. When the local central bank raises rates, capital should flow from on-chain pools to local fixed income, reducing pool TVL and raising fee yield -- creating a measurable "interest rate transmission" channel.

The spread between fee yield on a cNGN/USDC pool and the stETH yield (or USDC lending rate on Aave) directly measures monetary policy divergence: it captures the difference between dollar rates and the effective rate in the naira corridor.

**Signal Quality**: STRONG for monetary policy divergence. MODERATE for interest rate shock.

**Solidity Extraction**:
```solidity
function feeYieldAnnualized(
    address pool,
    uint32 lookbackSeconds
) external view returns (uint256 yieldWad) {
    uint256 feeGrowth0_now = IUniswapV3Pool(pool).feeGrowthGlobal0X128();
    // ... get feeGrowth0_then from oracle or stored snapshot
    uint256 deltaFee = feeGrowth0_now - feeGrowth0_then;
    uint128 liquidity = IUniswapV3Pool(pool).liquidity();

    // Annualize
    uint256 periodsPerYear = 365 days / lookbackSeconds;
    uint256 revenuePerLiquidity = (deltaFee * liquidity) >> 128;
    yieldWad = revenuePerLiquidity * periodsPerYear * 1e18 / tvl;
}
```

---

### 4.5 Fee Revenue Across Corridors (Cross-Country Income Spread)

**Macro Variable: Terms of Trade, Relative Economic Health**

Comparing fee revenue on cNGN/USDC vs cCOP/USDC vs MXNB/USDC pools reveals relative economic activity across corridors. This is the on-chain equivalent of comparing trade volumes across bilateral FX pairs.

**Theoretical Justification**: The terms of trade (export price / import price) for commodity-exporting EMs shifts when global commodity prices change. Nigeria (oil), Colombia (oil, coffee), Mexico (manufacturing, remittances), Philippines (remittances) have different commodity exposures. Fee revenue shifts across corridors reflect these relative shifts. From the project's MACRO_RISKS notes: "CrossCountrySpread: underlying = income(cNGN_pools) / income(PUSO_pools), analog = macro relative value trade."

**Signal Quality**: MODERATE for terms of trade. Requires normalization by pool size and market maturity.

---

## 5. Liquidity Observables

### 5.1 Total Liquidity (TVL)

**Macro Variable: Capital Flight (lagged), Liquidity Crisis (PRIMARY), Market Confidence**

TVL in an EM stablecoin pool measures the total capital committed by LPs to provide FX liquidity. Declining TVL indicates LPs are exiting -- either because returns are insufficient or because risk is too high.

**Theoretical Justification**: LP capital in an FX pool is analogous to foreign exchange reserves held by market makers. When reserves decline, the market becomes fragile. Persistent TVL decline in an EM pool is a measure of declining confidence in the currency or the corridor.

**Signal Quality**: STRONG for liquidity crisis. MODERATE for capital flight (TVL decline is a consequence, not a leading indicator, of capital flight).

---

### 5.2 Liquidity Distribution Across Ticks

**Macro Variable: Currency Crisis (early warning), Market Expectations**

In Uniswap v3 / Algebra, LPs choose specific price ranges. The distribution of liquidity across ticks reveals:

- **Concentration around current price**: Market consensus that the rate is stable
- **Liquidity skewed below current price**: LPs expect depreciation (they position to earn fees in a declining market)
- **Liquidity pulled far from current price**: Fear of large moves (crisis signal)
- **Bimodal distribution**: Market is split between two scenarios (e.g., devaluation vs. peg defense)

**Theoretical Justification**: LP positioning in concentrated liquidity is informationally equivalent to limit orders in a central limit order book (CLOB). The "liquidity surface" (Arxiv 2509.05013, "Dynamics of Liquidity Surfaces in Uniswap v3") encodes the aggregate probability distribution that LPs assign to future prices. Skewness in this distribution is a direct measure of directional expectations -- analogous to the risk-neutral density extracted from options markets.

**Signal Quality**: STRONG as an early warning for currency crisis. The liquidity distribution shifts BEFORE the price moves, because LPs reposition in anticipation of informed flow.

**Solidity Extraction**:
```solidity
// Read liquidity at specific ticks via pool.ticks(tick)
// Or use pool.tickBitmap to find initialized ticks and iterate
function liquidityDistribution(
    address pool,
    int24 tickLower,
    int24 tickUpper,
    int24 tickSpacing
) external view returns (int128[] memory netLiquidity) {
    uint256 numTicks = uint256(int256((tickUpper - tickLower) / tickSpacing));
    netLiquidity = new int128[](numTicks);
    for (uint256 i = 0; i < numTicks; i++) {
        int24 tick = tickLower + int24(int256(i)) * tickSpacing;
        (, int128 liquidityNet, , , , , , ) = IUniswapV3Pool(pool).ticks(tick);
        netLiquidity[i] = liquidityNet;
    }
}
```

---

### 5.3 Liquidity Additions vs Removals (LP Sentiment)

**Macro Variable: Market Confidence, Capital Flight (leading indicator)**

The ratio of liquidity additions (mints) to removals (burns) over rolling windows is an LP sentiment indicator. Net additions = confidence. Net removals = fear or better opportunities elsewhere.

**Theoretical Justification**: LP entry/exit decisions incorporate forward-looking information about expected returns and risks. LPs who observe deteriorating macro conditions (via private information or simply reading the news) will remove liquidity before the crisis manifests in the price. This makes LP flow a leading indicator.

**Signal Quality**: MODERATE as a leading indicator for currency crisis and capital flight. Requires event-log indexing (Mint/Burn events).

---

### 5.4 Active Liquidity Ratio (In-Range / Total)

**Macro Variable: Liquidity Crisis, Currency Crisis**

The ratio of active (in-range) liquidity to total liquidity measures market depth at the current price. A falling ratio means more capital is sitting out-of-range -- LPs have been "left behind" by a price move and haven't repositioned.

**Theoretical Justification**: After a large price move (e.g., a devaluation), much of the concentrated liquidity will be out of range. The speed at which LPs reposition into the new range indicates market health. Slow repositioning = liquidity crisis. Fast repositioning = resilient market.

**Signal Quality**: STRONG for liquidity crisis assessment post-shock. MODERATE as a standalone indicator.

---

### 5.5 Number of Active Positions

**Macro Variable: Market Confidence, Market Maturity**

The total number of unique LP positions is a breadth indicator. A pool dominated by a single large LP is fragile; a pool with many small LPs is more resilient.

**Signal Quality**: WEAK as a macro proxy. Better used as a structural health metric.

---

## 6. Position Observables

### 6.1 Position Range Distribution (LP Clustering)

**Macro Variable: Market Expectations, Currency Crisis (early warning)**

Where do LPs cluster their ranges? This reveals consensus expectations:

- **Tight clustering around peg/official rate**: Market believes in rate stability
- **Clustering well below current rate**: Market expects depreciation
- **Wide dispersion**: High uncertainty
- **Asymmetric: more liquidity below than above**: Bearish skew (depreciation expected)

**Theoretical Justification**: This is equivalent to the implied probability distribution from options markets (Breeden & Litzenberger, 1978). In options markets, the risk-neutral density is extracted from option prices across strikes. In concentrated liquidity pools, the "implied density" is extracted from LP positioning across ticks. The key academic reference is the arxiv paper on "Dynamics of Liquidity Surfaces in Uniswap v3" (2509.05013) which uses functional principal component analysis to model this surface.

**Signal Quality**: STRONG for directional expectations. This is one of the most information-rich observables, but requires sophisticated analysis.

---

### 6.2 Position Duration

**Macro Variable: Market Confidence, Interest Rate Expectations**

How long do LPs hold their positions? Short durations indicate:
- High uncertainty (LPs constantly repositioning)
- Active management (sophisticated LPs)
- Regime change expectations

Long durations indicate:
- Stable expectations
- Passive LPs (possibly less informed)

**Theoretical Justification**: Position holding period is inversely related to expected regime change frequency. In stable macro environments, LPs can afford to be passive. In crisis periods, the optimal LP strategy requires frequent repositioning (as shown in JIT liquidity research, arxiv:2509.16157).

**Signal Quality**: WEAK-MODERATE. Requires position-level tracking which is complex.

---

### 6.3 Large Position Entries/Exits

**Macro Variable: Capital Flight (strong signal), Currency Crisis (leading indicator)**

Large LP position changes (mints/burns above a threshold) by a single address or a small number of addresses are whale signals. A large LP exiting the pool entirely is a strong crisis warning.

**Theoretical Justification**: In Kyle's (1985) model, large informed traders split their orders to minimize price impact. In the LP context, a large informed LP who expects a crisis will remove liquidity in advance. The size distribution of LP entries/exits follows a power law, with the largest entries/exits carrying the most information.

**Signal Quality**: MODERATE-STRONG for capital flight and crisis when combined with other signals. Standalone, it can produce false positives (an LP may exit for idiosyncratic reasons).

---

## 7. Cross-Cutting Analysis

### 7.1 AMPL as Unit of Measure: Real vs Nominal Effects

**Question**: How does an AMPL/EM-stablecoin pair behave differently from a USDC/EM-stablecoin pair?

AMPL rebases to a CPI-adjusted 2019 US dollar target. This means:

| Observable | USDC/cNGN Pair | AMPL/cNGN Pair |
|---|---|---|
| Spot price | Nominal FX rate (NGN per USD) | Real FX rate (NGN per CPI-adjusted USD) |
| TWAP trend | Nominal depreciation | Real depreciation (inflation-adjusted) |
| Price deviation from official rate | Nominal parallel premium | Real parallel premium |
| Vol | Nominal FX vol | Real FX vol (noisier due to AMPL rebase mechanics) |

**Macro Implication**: The AMPL/cNGN pair separates **local inflation** from **currency depreciation**:

```
Nominal Depreciation (USDC/cNGN) = Real Depreciation (AMPL/cNGN) + US Inflation (AMPL rebase)

Therefore:
Real Depreciation = Nominal Depreciation - US Inflation
Local Inflation Effect = AMPL/cNGN price change - USDC/cNGN price change + AMPL rebase adjustment
```

If the AMPL/cNGN price is falling FASTER than the USDC/cNGN price, it means US inflation is eroding the real value of the dollar itself -- the naira's real depreciation is worse than its nominal depreciation.

**Signal Quality for Local Inflation**: MODERATE. The AMPL rebase mechanism introduces noise (supply changes affect price independently of CPI tracking). Also, AMPL tracks US CPI, not Nigerian CPI. However, the differential between AMPL-denominated and USDC-denominated EM stablecoin prices does isolate the US inflation component, which is useful for measuring real (inflation-adjusted) exchange rate dynamics.

**Practical Limitation**: AMPL has very low on-chain liquidity. Creating a deep AMPL/cNGN pool is not realistic in the near term. The approach is more theoretically interesting than immediately implementable. A more practical alternative: use a Chainlink CPI-U oracle to adjust the USDC/cNGN rate off-chain.

---

### 7.2 Cross-EM Pairs (cCOP/MXN): Unique Macro Signals

A pool trading cCOP against MXNB (Colombian peso stablecoin vs Mexican peso stablecoin) produces signals that are ABSENT from either pair's USD pool:

**7.2.1 Terms of Trade Signal**

Colombia and Mexico have different export baskets (Colombia: oil, coffee, coal; Mexico: manufacturing, oil, remittances). The cCOP/MXNB rate captures the relative terms of trade between the two economies. When oil prices rise but manufacturing demand falls, cCOP should appreciate vs MXNB.

**7.2.2 Dollar-Neutral Macro Risk**

The cCOP/MXNB pair removes the common factor of dollar strength. Both cCOP/USDC and MXNB/USDC contain a "USD factor" (Fed policy, global risk appetite). The cross-EM pair cancels this common factor, isolating the RELATIVE health of the two economies. This is analogous to a "spread trade" in macro hedge fund strategies.

**7.2.3 Corridor-Specific Remittance Flow**

If a Colombian worker in Mexico sends money home via a cCOP/MXNB swap, this flow appears in the cross-EM pair but NOT in either USD pair. This is a direct capture of intra-EM remittance corridors, which are growing but underserved.

**Signal Quality**: MODERATE-STRONG for terms of trade. STRONG for dollar-neutral relative value. WEAK for intra-EM remittances (very low current volume). These pairs are currently the least liquid in the ecosystem (Mento's cross-stablecoin pairs have de minimis volume), but they produce the most interesting theoretical signals.

---

### 7.3 Balancer Weighted Pools vs Uniswap v3 Concentrated Liquidity

**Which produces cleaner macro signals?**

| Dimension | Balancer Weighted Pool | Uniswap v3 / Algebra CL |
|---|---|---|
| Price signal | Continuous, smooth (x^w * y^(1-w) = k) | Continuous but with tick granularity |
| Price discovery efficiency | Lower -- wider effective spread, slower convergence | Higher -- concentrated liquidity narrows spread |
| Liquidity distribution info | None -- liquidity is uniform by construction | Rich -- LP positioning encodes expectations |
| Fee yield signal | Available but less decomposable | Highly decomposable (per-tick, per-position) |
| Vol estimation | From price only | From price + Algebra volatilityCumulative accumulator |
| Manipulation resistance | Higher for TWAP (continuous curve) | Moderate (tick-based, but multi-block TWAP is robust) |
| Capital efficiency | Lower (50/50 weight = Uniswap v2 equivalent) | Higher (concentrated around current price) |

**Verdict**: Uniswap v3 / Algebra concentrated liquidity pools produce RICHER macro signals due to the information content of the liquidity distribution itself. Balancer pools produce CLEANER price signals because the continuous curve is less susceptible to tick-boundary artifacts, but they lose the structural information.

For macro hedging instruments, we recommend:
- **Primary signal source**: Uniswap v3 / Algebra pools (richer information surface)
- **Validation/smoothing**: Cross-reference with Balancer pool prices when available
- **Volatility oracle**: Use Algebra's native volatilityCumulative accumulator (already implemented in our `AlgebraVolatilityLens.sol`) as the primary vol source; cross-validate with Valorem/Aloe fee-implied vol approach

**Academic Reference**: Alexander (2025), "Price Discovery and Efficiency in Uniswap Liquidity Pools" (Journal of Futures Markets), finds that Uniswap v3 shows "much improved efficiency relative to v2, with some v3 pools approaching or even exceeding Bitstamp in terms of price discovery ability."

---

### 7.4 Algebra Adaptive Fees as a Macro Observable

**Can the dynamic fee itself become a macro signal?**

Yes. Algebra Integral implements two fee adjustment mechanisms:

1. **Adaptive Fee Plugin**: Adjusts fees based on 24-hour realized volatility. When vol rises, fees rise automatically.
2. **Sliding Fee Plugin**: Adjusts fees per-swap based on the price change of the last block and swap direction.

**The fee level IS a macro observable because**:

- The adaptive fee encodes the pool's recent volatility history in a single, easily readable uint16 value
- The sliding fee encodes directional pressure: if the fee is elevated for cNGN-to-USDC swaps (capital outflow direction), it means recent swaps have been predominantly in that direction
- Fee changes are on-chain events that can be tracked as a time series
- Rising fees indicate rising volatility/stress; falling fees indicate calming markets

**Macro Variable Mapping**:
| Fee Observable | Macro Proxy |
|---|---|
| Adaptive fee level | Currency crisis / volatility regime |
| Adaptive fee trend (rising) | Deteriorating FX stability |
| Sliding fee asymmetry (directional) | Capital flight direction |
| Fee level vs. competing pool fees | Relative corridor stress |

**Signal Quality**: MODERATE. The fee is a derivative of vol, which is itself a derivative of price. It is a second-order signal, but it has the advantage of being a single, on-chain-readable number that compresses complex market dynamics.

**Solidity Extraction**:
```solidity
// Algebra: read current fee directly
uint16 currentFee = IAlgebraPool(pool).fee();
// Or via plugin:
// IAlgebraPool(pool).plugin() -> plugin.fee()
```

---

## 8. Composite Macro Indices

### 8.1 Currency Crisis Index (CCI)

Combines the strongest crisis signals into a single score:

```
CCI(t) = w1 * parallelMarketPremium(30d TWAP)
       + w2 * realizedVol(7d) / historicalMeanVol
       + w3 * (1 - activeLiquidityRatio)
       + w4 * netFlowDirection(7d) [negative = crisis]
       + w5 * volumeAcceleration(1d)
       + w6 * feeRevenueVol(7d) / historicalFeeRevenueMean
```

Default weights: w1=0.30, w2=0.20, w3=0.15, w4=0.15, w5=0.10, w6=0.10

**Settlement**: This index can settle a binary option: "Does CCI exceed threshold T in period [t, t+30d]?"

---

### 8.2 Remittance Health Index (RHI)

```
RHI(t) = w1 * sellSideVolume(30d) / historicalMean(sellSideVolume)
        + w2 * weeklyVolumePattern_correlation_with_baseline
        + w3 * feeRevenue(30d) / historicalMean(feeRevenue)
        - w4 * buySideVolume(30d) / historicalMean(buySideVolume)
```

Falling RHI indicates deteriorating remittance flows (labor market stress in host country).

---

### 8.3 Monetary Policy Divergence Index (MPDI)

```
MPDI(t) = feeYield(cNGN_USDC_pool, 30d) - stETH_yield(30d)

// Or more precisely:
MPDI(t) = feeYield(pool) - riskFreeRate(USD) - historicalMean(feeYield - riskFreeRate)
```

Positive MPDI = pool yields are elevated relative to dollar rates = local monetary conditions are tighter or risk premium is higher.

---

## 9. Solidity Implementation Reference

### 9.1 Existing Project Infrastructure

The project already has the following relevant contracts:

| Contract | Location | Function |
|---|---|---|
| `AlgebraVolatilityLens.sol` | `src/libraries/AlgebraVolatilityLens.sol` | Reads Algebra volatilityCumulative, computes TWAP and symmetric tick ranges |
| `VolatilityOracle.sol` | `lib/voltaire/src/VolatilityOracle.sol` | Cross-chain realized vol oracle via Reactive Network |
| `Volatility.sol` | `lib/valorem-oracles/src/libraries/Volatility.sol` | Fee-implied vol estimation (Aloe/Lambert method) |
| `VolatilityOracle (Algebra)` | `lib/algebra-plugins/src/plugin/stub/contracts/libraries/VolatilityOracle.sol` | Algebra native vol accumulator |

### 9.2 Proposed New Contracts for Macro Observable Extraction

```solidity
// MacroObservableLens.sol -- read all macro-relevant observables from a pool
interface IMacroObservableLens {

    struct PriceObservables {
        uint160 sqrtPriceX96;        // Current spot
        int24 twapTick;              // TWAP over configurable window
        uint256 realizedVolWad;      // Annualized realized vol (WAD)
        int256 parallelPremiumBps;   // On-chain vs official rate (bps)
        uint256 priceImpactBps;      // Impact of reference trade (bps)
    }

    struct VolumeObservables {
        uint256 buyVolume;           // Cumulative over period
        uint256 sellVolume;          // Cumulative over period
        int256 netFlow;              // sell - buy (positive = inflow)
        uint256 turnoverRatioBps;    // volume / TVL in bps
    }

    struct IncomeObservables {
        uint256 feeGrowthDelta0;     // feeGrowthGlobal0X128 delta
        uint256 feeGrowthDelta1;     // feeGrowthGlobal1X128 delta
        uint256 feeYieldAnnualizedWad; // Annualized yield (WAD)
        uint256 feeRevenueVolWad;    // Fee revenue volatility (WAD)
    }

    struct LiquidityObservables {
        uint256 tvlToken0;           // TVL in token0 terms
        uint256 tvlToken1;           // TVL in token1 terms
        uint256 activeLiquidityRatio; // in-range / total (WAD)
        int256 lpSentiment;          // net mints - net burns (signed)
    }

    function getPoolObservables(
        address pool,
        uint32 window,
        address officialRateOracle
    ) external view returns (
        PriceObservables memory price,
        IncomeObservables memory income,
        LiquidityObservables memory liquidity
    );

    function getCurrencyCrisisIndex(
        address pool,
        uint32 window,
        address officialRateOracle
    ) external view returns (uint256 cci);

    function getRemittanceHealthIndex(
        address pool,
        uint32 window
    ) external view returns (uint256 rhi);

    function getMonetaryPolicyDivergence(
        address pool,
        uint32 window,
        address riskFreeRateOracle
    ) external view returns (int256 mpdi);
}
```

---

## 10. Observable-to-Macro-Variable Master Matrix

For quick reference, the complete mapping with signal quality ratings:

| Observable | Inflation | Depreciation | Capital Flight | Remittances | Rate Shock | Terms of Trade | Currency Crisis | Labor Stress | Liquidity Crisis | Policy Divergence |
|---|---|---|---|---|---|---|---|---|---|---|
| **Spot price** | - | STRONG | - | - | - | - | STRONG | - | - | - |
| **TWAP (30d)** | - | STRONG | - | - | - | - | MOD | - | - | MOD |
| **Realized vol** | - | MOD | MOD | - | MOD | - | STRONG | - | - | - |
| **Parallel premium** | - | STRONG | STRONG | - | MOD | - | STRONG | - | - | - |
| **Bid-ask spread** | - | - | - | - | - | - | MOD | - | STRONG | - |
| **Price impact** | - | - | MOD | - | - | - | - | - | STRONG | - |
| **Buy/sell volume** | - | - | STRONG | STRONG | - | - | - | - | - | - |
| **Net flow** | - | - | STRONG | STRONG | - | - | MOD | MOD | - | - |
| **Volume accel.** | - | - | MOD | - | - | - | STRONG | - | - | - |
| **Time-of-day vol** | - | - | - | STRONG | - | - | - | MOD | - | - |
| **Turnover ratio** | - | - | MOD | - | - | - | STRONG | - | STRONG | - |
| **feeGrowthGlobal** | - | MOD | - | MOD | - | - | - | - | - | - |
| **Fee per epoch** | - | MOD | - | MOD | MOD | - | - | - | - | - |
| **Fee revenue vol** | - | - | - | - | STRONG | - | MOD | - | - | - |
| **Fee yield** | - | - | - | - | STRONG | - | - | - | - | STRONG |
| **Cross-corridor fees** | - | - | - | - | - | MOD | - | - | - | - |
| **TVL** | - | - | MOD | - | - | - | - | - | STRONG | - |
| **Liquidity distrib.** | - | - | - | - | - | - | STRONG | - | MOD | - |
| **LP adds/removes** | - | - | MOD | - | - | - | MOD | - | - | - |
| **Active liq ratio** | - | - | - | - | - | - | MOD | - | STRONG | - |
| **Position ranges** | - | - | - | - | - | - | STRONG | - | - | - |
| **Large LP exits** | - | - | STRONG | - | - | - | MOD | - | - | - |
| **Algebra fee level** | - | - | - | - | - | - | MOD | - | - | - |
| **AMPL/EM price** | MOD | - | - | - | - | - | - | - | - | - |
| **Cross-EM pair** | - | - | - | MOD | - | STRONG | - | - | - | - |

Legend: STRONG = high confidence proxy, MOD = moderate/requires filtering, WEAK = low confidence, - = not applicable

---

## 11. Academic References

### Market Microstructure and AMMs
1. Kyle, A.S. (1985). "Continuous Auctions and Insider Trading." Econometrica, 53(6), 1315-1335.
2. Glosten, L.R. & Milgrom, P.R. (1985). "Bid, Ask, and Transaction Prices in a Specialist Market with Heterogeneously Informed Traders." Journal of Financial Economics, 14(1), 71-100.
3. Angeris, G., Chitra, T., & Evans, A. (2020). "Improved Price Oracles: Constant Function Market Makers." arxiv:2003.10001.
4. Angeris, G. & Chitra, T. (2023). "The Geometry of Constant Function Market Makers." arxiv:2308.08066.
5. Milionis, J., Moallemi, C.C., Roughgarden, T., & Zhang, A.L. (2022). "Automated Market Making and Loss-Versus-Rebalancing." arxiv:2208.06046.
6. Alexander (2025). "Price Discovery and Efficiency in Uniswap Liquidity Pools." Journal of Futures Markets.
7. Cartea, A., Drissi, F., & Monga, M. (2025). "Impermanent Loss and Loss-vs-Rebalancing II." arxiv:2502.04097.
8. (2025). "The Price of Liquidity: Implied Volatility of Automated Market Maker Fees." arxiv:2509.23222.
9. (2025). "Dynamics of Liquidity Surfaces in Uniswap v3." arxiv:2509.05013.

### Macro Markets and Perpetual Instruments
10. Shiller, R.J. (1993). "Measuring Asset Values for Cash Settlement in Derivative Markets: Hedonic Repeated Measures Indices and Perpetual Futures." Journal of Finance, 48(3), 911-931.
11. Shiller, R.J. (1993). Macro Markets: Creating Institutions for Managing Society's Largest Economic Risks. Oxford University Press.
12. Ackerer, D., Hugonnier, J., & Jermann, U. "Perpetual Futures Pricing." Working paper.

### Currency Crises and Parallel Markets
13. Kaminsky, G., Lizondo, S., & Reinhart, C.M. (1998). "Leading Indicators of Currency Crises." IMF Staff Papers, 45(1), 1-48.
14. Kiguel, M. & O'Connell, S.A. (1995). "Parallel Exchange Rates in Developing Countries." World Bank Research Observer, 10(1), 21-52.
15. Reinhart, C.M. & Rogoff, K.S. (2004). "The Modern History of Exchange Rate Arrangements: A Reinterpretation." Quarterly Journal of Economics, 119(1), 1-48.

### Stablecoins and On-Chain Macro
16. BIS Working Papers No. 1265. "DeFiying Gravity: Cross-Border Crypto Flows."
17. BIS Working Papers No. 1270. "Stablecoins and Safe Asset Prices."
18. IMF Working Paper WP/2025/141. "How to Estimate International Stablecoin Flows."
19. (2025). "Stablecoin Devaluation Risk." European Journal of Finance.
20. (2025). "Stablecoin Depegging Risk Prediction." ScienceDirect.
21. IMF (2025). "Understanding Stablecoins." Monetary and Capital Markets Department.
22. (2025). "Cryptocurrencies in Emerging Markets: A Stablecoin Solution?" Journal of International Money and Finance.
23. NBER Working Paper No. 34475. "Stablecoins."

### Remittances and Labor Markets
24. IMF (2022). "The Propensity to Remit: Macro and Micro Factors Driving Remittances to Central America and the Caribbean."
25. NBER (2025). "International Migration, Remittances, and Economic Development." NBER Reporter.
26. (2024). "Informal Foreign Currency Market Rate Coordination and Remittance Flows." Applied Economics.

### AMM Fee Mechanisms and Volatility
27. Lambert, G. (2021). "On-Chain Volatility and Uniswap v3." Medium.
28. Algebra. "Dynamic Fees vs. Sliding Fee Mechanism in Algebra-powered AMMs."
29. OpenGradient (2025). "Mitigating Risk and Loss in AMM Liquidity Pools: A Dynamic Fee System Based on Risk Prediction."
30. (2025). "Optimal Dynamic Fees in Automated Market Makers." arxiv:2506.02869.

### Ampleforth
31. Ampleforth. "AMPL as an Inflation Hedge."
32. Chainlink. "Decentralizing Ampleforth's Rebasing Mechanism."

### Information Theory
33. Shannon, C.E. (1948). "A Mathematical Theory of Communication." Bell System Technical Journal.
34. Easley, D. & O'Hara, M. (1992). "Time and the Process of Security Price Adjustment." Journal of Finance, 47(2), 577-605.

---

## 12. Next Steps and Implementation Priority

### Phase 1: Core Observable Extraction (Immediate)
1. Extend `AlgebraVolatilityLens.sol` to compute parallel market premium given a Chainlink feed
2. Build `MacroObservableLens.sol` with the interface proposed in Section 9.2
3. Implement Currency Crisis Index as a pure view function

### Phase 2: Volume and Flow Tracking (Requires Hooks)
4. Deploy Uniswap v4 hook to capture directional volume and compute net flow
5. Build Remittance Health Index from time-series of directional volume

### Phase 3: Composite Indices and Settlement
6. Implement composite indices (CCI, RHI, MPDI) as on-chain oracles
7. Connect to Panoptic / perpetual claim settlement layer
8. Backtest indices against historical cNGN, BRZ, cKES price data

### Phase 4: Cross-EM and Advanced Signals
9. Deploy cross-EM pair monitoring (cCOP/MXNB)
10. Implement liquidity distribution analysis for position-level signals
11. Integrate Algebra adaptive fee tracking as a macro signal

---

*This report was prepared as part of the liq-soldk-dev project's macro risk hedging research. All Solidity references are to contracts in the project repository or its library dependencies. The analysis synthesizes academic literature on market microstructure, currency crises, macro markets, and DeFi AMM design to provide a rigorous mapping between on-chain CFMM observables and macroeconomic variables.*
