# Structural Econometric Method: CFMM Observables -> Macro Variables
## Starting Pair: USDC/DAI on QuickSwap (Algebra, Polygon)

*Date: 2026-03-31*
*Project: liq-soldk-dev -- Macro Risk Hedging via On-Chain Instruments*

---

## Research Strategy

Data-driven, pair-by-pair. Start with USDC/DAI on QuickSwap. Establish the full method on this one pair, then replicate for each subsequent pair progressively. Each pair adds macro dimensions; the Algebra adaptive fee is the connective thread across all.

---

## Why USDC/DAI First

Both tokens are USD-pegged but with fundamentally different backing:
- **USDC** -- fiat-backed (Circle), centralized, US-regulated, bank deposit risk
- **DAI** -- crypto-collateral + RWA-backed (Sky/Maker), decentralized, smart contract risk, increasingly exposed to T-bills via RWA vaults

The pool price should be 1.0. Every deviation is information. This makes it an econometric error-correction system by construction -- a clean laboratory for the method before introducing FX noise.

---

## On-Chain Observables (Algebra-Specific)

| Observable | Solidity Source | What It Encodes |
|---|---|---|
| `sqrtPriceX96` | `pool.globalState()` | USDC/DAI peg deviation |
| Adaptive fee level | `pool.globalState().fee` | Real-time micro-volatility of the peg |
| Fee change rate | `d(fee)/dt` from plugin | Volatility regime transitions |
| `feeGrowthGlobal0/1` | `pool.totalFeeGrowth0/1Token()` | Cumulative economic throughput |
| Directional volume | swap events `(amount0, amount1)` | Who is selling what -- flight direction |
| Net flow (rolling) | aggregated swap amounts | Sustained preference for USDC vs DAI |
| TVL / liquidity | `pool.liquidity()` + tick range | Market maker confidence in the peg |
| Tick distribution skew | position mint/burn events | LP beliefs about asymmetric depeg risk |
| Volatility accumulator | Algebra plugin `volatilityOracle` | On-chain realized vol, zero oracle dependency |

---

## Tentative Macro Questions

### Q1. DeFi Systemic / Collateral Stress
DAI collateral is ~50% crypto (ETH, WBTC), ~50% RWAs. When crypto crashes, DAI can temporarily depeg. The USDC/DAI spread is a DeFi systemic risk barometer.
- **Method**: Threshold regression -- does the spread widen non-linearly when ETH drops >15% in 24h?
- **Contrast variables**: ETH realized vol, DeFi TVL drawdown, liquidation volume on Aave/Maker

### Q2. US Monetary Policy Transmission into DeFi
DAI's backing increasingly includes T-bills. The DSR (DAI Savings Rate) tracks Fed policy with a lag. Fee yield on the pool reflects the carry trade.
- **Method**: Event study around FOMC decisions -- does USDC/DAI spread, volume, or Algebra fee respond?
- **Contrast variables**: Fed funds rate, DSR, T-bill yields, USDC yield on Coinbase/Aave

### Q3. Counterparty / Regulatory Risk Pricing
USDC = Circle = US-regulated = OFAC-compliant. DAI = decentralized = censorship-resistant. The spread prices differential regulatory exposure.
- **Method**: Granger causality -- do regulatory announcements (OFAC, SEC, MiCA) cause directional volume shifts?
- **Contrast variables**: USDC market cap changes, Circle/Coinbase equity, regulatory event timeline

### Q4. Flight-to-Safety Direction within Stablecoins
During stress, do agents flee USDC->DAI (regulatory fear) or DAI->USDC (collateral fear)?
- **Method**: Directional volume decomposition during identified stress events (SVB-type, Luna-type, regulatory-type)
- **Contrast variables**: Stablecoin market caps, DEX aggregate volume, CEX withdrawal data

### Q5. Credit Risk Differential
USDC = bank deposit + money market fund risk. DAI = smart contract + collateral + governance risk. The spread is a credit spread in traditional finance terms.
- **Method**: Merton-style structural credit model -- infer implied default probabilities from spread
- **Contrast variables**: CDS on US banks, Maker surplus buffer, USDC attestation reports

### Q6. Yield Differential / Carry Trade Activity
When DSR > USDC lending rate, capital flows DAI-ward. Fee revenue on the pool reflects this carry activity.
- **Method**: Regression of fee revenue on (DSR - USDC_lending_rate) spread
- **Contrast variables**: DSR, Aave/Compound USDC supply rates, sDAI TVL

### Q7. Algebra Adaptive Fee as Volatility Oracle
The Algebra fee plugin adjusts fees based on recent pool volatility. For a near-peg pair, fee spikes = stress detection with zero oracle dependency.
- **Method**: Compare Algebra fee time series against VIX, ETH IV (Deribit), and realized vol of BTC
- **Contrast variables**: TradFi volatility indices, crypto IV surfaces

---

## Econometric Methods

| Method | Why | Data Requirements |
|---|---|---|
| **Cointegration / VECM** | USDC and DAI are cointegrated by construction -- the error correction speed IS the signal | Price time series at block/hour granularity |
| **Markov regime-switching** (Hamilton 1989) | Normal regime (tight peg) vs. stress regime (wide spread) -- estimate transition probabilities | Price + volume + fee series |
| **Granger causality** | Does USDC/DAI spread predict ETH vol? Does ETH vol predict the spread? Bidirectional? | Aligned time series of spread + macro variables |
| **Event study** | Measure abnormal spread/volume/fee around FOMC, regulatory events, DeFi exploits | Event calendar + high-frequency pool data |
| **Threshold VAR** | Non-linear dynamics -- the pool may behave differently above/below some spread threshold | Sufficient observations in both regimes |
| **Realized volatility signatures** | Algebra fee history gives a free realized vol estimator -- compare against Deribit IV | Algebra plugin state history |

---

## Data Pipeline Required

### On-chain (QuickSwap USDC/DAI on Polygon)
1. Pool address identification
2. Historical `Swap` events (price, amounts, direction, fee at time of swap)
3. Historical `globalState` snapshots (sqrtPriceX96, fee, tick)
4. `feeGrowthGlobal0Token`, `feeGrowthGlobal1Token` over time
5. Mint/Burn events (LP positioning)
6. Algebra volatility oracle accumulator values (if plugin is active)

### Off-chain macro contrasts
1. Fed funds rate (FRED API)
2. DAI Savings Rate history (Maker governance)
3. USDC/DAI market cap time series (CoinGecko/DefiLlama)
4. ETH price + realized vol
5. DeFi TVL (DefiLlama)
6. Aave/Compound USDC and DAI supply/borrow rates
7. VIX (CBOE) and ETH implied vol (Deribit)
8. Regulatory event timeline (manual curation)

---

## Progressive Expansion (After USDC/DAI)

Each subsequent pair replicates this method and adds new macro dimensions:

| Step | Pair | New Macro Dimensions Added |
|---|---|---|
| 1 | **USDC/DAI** (this document) | USD peg dynamics, DeFi systemic risk, yield differential |
| 2 | USDC/USDT | Offshore-vs-onshore USD risk, Tether counterparty |
| 3 | ETH/USDC | Crypto risk premium, capital flight from/to USD |
| 4 | wstETH/ETH | Interest rate structure, staking yield as risk-free rate proxy |
| 5 | EM-stable/USDC (cNGN, BRZ, etc.) | FX depreciation, emerging market macro |
| 6 | PAXG/USDC | Inflation proxy, real asset pricing |

The method established here on USDC/DAI becomes the template for all subsequent pairs.
