# Synthesis: Pair x CFMM Primitive → Macro Variable Matrix

*Date: 2026-03-31*
*Project: liq-soldk-dev — Macro Risk Hedging via On-Chain Instruments*

---

## The Complete Matrix

Each cell: **Macro Variable Proxied** (Signal Strength: S=Strong, M=Moderate, W=Weak)

### PRICE Observables

| Pair Type | Spot Price | TWAP (30d) | Realized Vol | Parallel Market Premium | Implied Spread |
|---|---|---|---|---|---|
| **EM-stable/USD** (cNGN/USDC) | Currency Depreciation (S) | Depreciation Trend (S) | Currency Crisis (S) | **Currency Crisis + Capital Controls (S)** | Liquidity Crisis (M) |
| **EM-stable/Gold** (cNGN→PAXG) | Local Inflation (S) | Inflation Trend (S) | Inflation Volatility (M) | Real Purchasing Power Gap (M) | — |
| **EM-stable/Yield** (cNGN→wstETH) | Interest Rate Differential (S) | Rate Spread Trend (S) | Rate Shock Detection (M) | — | — |
| **EM-stable/Crypto** (cNGN→WETH) | Capital Flight/Risk Appetite (M) | Flight Trend (M) | Global Risk Sentiment (M) | — | — |
| **EM-stable/Commodity** (cNGN→Oil) | Terms of Trade (S) | ToT Trend (S) | Commodity Shock (M) | — | — |
| **EM-stable/AMPL** (cNGN/AMPL) | Real Exchange Rate (S) | Real Depreciation Trend (S) | Real FX Vol (M) | Real Parallel Premium (S) | — |
| **Cross-EM** (cCOP/BRZ) | Relative FX Performance (M) | Relative Trend (M) | Contagion Risk (M) | Cross-Country Premium Spread (M) | — |

### VOLUME Observables

| Pair Type | Directional Volume | Net Flow (7d) | Volume Acceleration | Time-of-Day Patterns | Turnover Ratio |
|---|---|---|---|---|---|
| **EM-stable/USD** | Capital Flight (S) | Capital Flight sustained (S) | Crisis Leading Indicator (M-S) | Remittance Cycle (M) | Crisis vs Growth (M) |
| **EM-stable/Gold** | Inflation Hedging Demand (M) | Gold Accumulation Signal (M) | Inflation Panic (M) | — | — |
| **EM-stable/Yield** | Carry Trade Flow (M) | Rate Arbitrage Direction (M) | Rate Shock Response (M) | — | — |
| **EM-stable/Crypto** | **Capital Flight (S)** — volume on EM-stable/USDC leg is key signal | Flight Acceleration (S) | Crisis Escalation (S) | Weekend Patterns (W) | Hot Money Detection (M) |
| **EM-stable/Commodity** | Export Revenue Proxy (M) | Trade Balance Signal (M) | Commodity Shock Response (M) | — | — |
| **EM-stable/AMPL** | Real Purchasing Power Flight (M) | — | — | — | — |
| **Cross-EM** | Relative Capital Movement (M) | Contagion Direction (M) | Synchronized Crisis (M) | — | — |

### LP INCOME Observables

| Pair Type | Fee Revenue (feeGrowthGlobal) | Fee Yield (fees/TVL) | Fee Revenue Volatility | Cross-Corridor Fee Comparison |
|---|---|---|---|---|
| **EM-stable/USD** | Economic Throughput / Shiller Income Claim (M) | **Monetary Policy Divergence (S)** | Income Risk = Hedging Target (M) | Terms of Trade, Relative Health (M) |
| **EM-stable/Gold** | Gold Market Activity (W) | Inflation Hedging Cost (M) | Inflation Regime Changes (M) | — |
| **EM-stable/Yield** | Rate Arbitrage Activity (M) | Carry Trade Profitability (M) | Rate Volatility (M) | — |
| **EM-stable/Crypto** | Crypto Adoption Activity (M) | Risk Premium for Crypto Exposure (M) | Sentiment Regime Changes (M) | — |
| **EM-stable/Commodity** | Trade Activity Proxy (M) | Commodity Market Access Cost (M) | ToT Stability (M) | — |
| **EM-stable/AMPL** | Real Economic Activity (W) | Real Rate Proxy (M) | — | — |
| **Cross-EM** | Relative Corridor Activity (M) | Relative Corridor Health (M) | Contagion Detection (M) | **Primary Use Case** (S) |

### LIQUIDITY Observables

| Pair Type | TVL Trend | Tick Distribution Skew | Mint/Burn Ratio | Active Liquidity Ratio |
|---|---|---|---|---|
| **EM-stable/USD** | Market Confidence (S) | **Crisis Early Warning (S)** — LPs reposition BEFORE price moves | Leading Indicator (M) | Post-Shock Health (S) |
| **EM-stable/Gold** | Gold Market Depth (M) | Inflation Expectations (M) | — | — |
| **EM-stable/Yield** | Rate Market Depth (M) | Rate Expectations (M) | — | — |
| **EM-stable/Crypto** | Crypto Market Confidence (M) | Flight Expectations (M) | — | — |
| **EM-stable/Commodity** | — | — | — | — |
| **EM-stable/AMPL** | — | — | — | — |
| **Cross-EM** | Cross-Country Confidence (M) | Relative Crisis Expectations (M) | — | — |

### ALGEBRA-SPECIFIC: Dynamic Fee as Observable

| Pair Type | Adaptive Fee Level | Fee Change Rate | Fee Spikes |
|---|---|---|---|
| **EM-stable/USD** | **Real-Time FX Volatility (S)** | Volatility Regime Change (S) | Crisis Detection (S) |
| **EM-stable/Gold** | Gold/FX Composite Vol (M) | Inflation Regime Change (M) | Inflation Panic (M) |
| **EM-stable/Yield** | Rate Spread Vol (M) | Rate Shock Detection (M) | Policy Surprise (M) |
| **EM-stable/Crypto** | Crypto/FX Composite Vol (M) | Sentiment Shift (M) | Market Panic (M) |

---

## Signal Strength Summary: Best Observable per Macro Variable

| Macro Variable | Best Pair | Best Observable | Signal |
|---|---|---|---|
| **Currency Depreciation** | EM-stable/USD | TWAP (30d) | S |
| **Currency Crisis** | EM-stable/USD | Parallel Market Premium + Realized Vol + Algebra Adaptive Fee | S |
| **Capital Flight** | EM-stable/USD (volume leg) | Net Flow Direction (7d+) | S |
| **Local Inflation** | EM-stable/Gold (PAXG) | Spot Price composite | S |
| **Interest Rate Shock** | EM-stable/Yield (wstETH) | Protocol rate vs TWAP depreciation | S |
| **Monetary Policy Divergence** | EM-stable/USD | Fee Yield vs stETH Yield | S |
| **Terms of Trade** | EM-stable/Commodity (Chainlink oil) | Oracle composite price trend | S |
| **Remittance Flow Changes** | EM-stable/USD | Time-of-day volume patterns + sell-side volume trend | M |
| **Labor Market Stress** | EM-stable/USD | Sell-side volume diminishing over time | M |
| **Liquidity Crisis** | EM-stable/USD | TVL trend + Active Liquidity Ratio + Turnover Ratio | S |
| **Real Exchange Rate** | EM-stable/AMPL (or CPI oracle) | Real vs Nominal depreciation spread | S (theory) / W (practice — AMPL illiquid) |
| **Contagion** | Cross-EM (cCOP/BRZ) | Correlation of vol spikes across corridors | M |

---

## Composite Indices (from research-cfmm-macro-observables.md)

### Currency Crisis Index (CCI)
```
CCI(t) = 0.30 × parallelMarketPremium(30d TWAP)
       + 0.20 × realizedVol(7d) / historicalMeanVol
       + 0.15 × (1 - activeLiquidityRatio)
       + 0.15 × netFlowDirection(7d) [negative = crisis]
       + 0.10 × volumeAcceleration(1d)
       + 0.10 × feeRevenueVol(7d) / historicalFeeRevenueMean
```

### Remittance Health Index (RHI)
```
RHI(t) = w1 × sellSideVolume(30d) / historicalMean
       + w2 × weeklyVolumePattern_correlation_with_baseline
       + w3 × feeRevenue(30d) / historicalMean
       - w4 × buySideVolume(30d) / historicalMean
```

### Monetary Policy Divergence Index (MPDI)
```
MPDI(t) = feeYield(pool, 30d) - stETH_yield(30d) - historicalSpreadMean
```

---

## Practical Signal Construction Paths

### Direct (pool exists):
- cKES/cUSD on Uniswap v3 Celo → All price/volume/LP income observables
- BRZ/USDT on Uniswap v4 Polygon → All price/volume/LP income observables
- eXOF/cEUR on Uniswap v3 Celo → Near-stable FX pair (CFA pegged to EUR)

### Two-hop composite (no direct pool):
- cNGN → USDC (Mento) → PAXG (Uniswap v2 ETH) = Gold/Naira inflation proxy
- cNGN → USDC (Mento) → wstETH (Balancer/Lido) = Interest rate differential
- BRZ → USDC (Stabull) → WETH (Uniswap v3) = Capital flight signal

### Oracle composite (no pool needed):
- Mento cNGN/cUSD TWAP × Chainlink XAU/USD = Gold price in Naira
- Mento cNGN/cUSD TWAP × Chainlink WTI/USD = Oil price in Naira (terms of trade)
- Mento cNGN/cUSD TWAP vs Chainlink NGN/USD (if available) = Parallel market premium
- wstETH.stEthPerToken() vs cNGN/USDC depreciation rate = Interest rate differential

### Algebra-native (deploy new pool):
- Deploy BRZ/USDC on QuickSwap (Polygon, Algebra) → get adaptive fee + vol accumulator for free
- Deploy cKES/cUSD on an Algebra DEX on Celo (if one exists) → full plugin suite

---

## Existing Pool Liquidity Summary (from research-em-stablecoin-cfmm-pools.md)

| Pool | Chain | DEX | TVL | Daily Volume | Macro Signal Utility |
|---|---|---|---|---|---|
| cKES/USDT | Celo | Uniswap v3 | ~$35K | ~$124K | Kenyan FX + remittance |
| eXOF/cEUR | Celo | Uniswap v3 | ~$27K | ~$31K | CFA/EUR peg stability |
| cGHS/USDT | Celo | Uniswap v3 | ~$23K | ~$26K | Ghanaian FX |
| cCOP/USDT | Celo | Uniswap v3 | ~$15K | ~$7K | Colombian FX |
| BRZ/USDT | Polygon | Uniswap v4 | ~$42K | ~$16K | Brazilian FX |
| PAXG/WETH | Ethereum | Uniswap v2 | **$15.8M** | **$1.8M** | Gold price (inflation proxy) |
| WETH/USDC | Ethereum | Uniswap v3 | **$200M+** | **$500M+** | Crypto routing layer |
| wstETH/WETH | Ethereum | Balancer | **$50M+** | High | ETH staking yield |

---

## Key Gaps Identified

1. **No EM stablecoin pools on Algebra DEXes** — missing adaptive fee as macro signal
2. **No cross-EM pairs** (cCOP/BRZ, cNGN/MXN) — missing contagion/relative value signals
3. **AMPL too illiquid** for real exchange rate construction — use CPI oracle instead
4. **Commodity RWA tokens have no DEX liquidity** — LITRO (oil) launches 2027; use Chainlink feeds
5. **MEV/toxic flow** contaminates volume signals — need CoW AMM, Angstrom, or Algebra sliding fees
6. **Chainlink lacks EM FX feeds** (NGN/USD, PHP/USD not confirmed) — binding constraint for parallel market premium
