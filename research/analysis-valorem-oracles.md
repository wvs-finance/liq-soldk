# Valorem Oracles: Deep Analysis for LP Hedge Instrument Integration

**Date**: 2026-03-29
**Repo**: `lib/valorem-oracles` (github.com/valorem-labs-inc/valorem-oracles)
**Author**: Alcibiades / Valorem Labs
**Solidity version**: 0.8.13
**License**: BUSL 1.1 (core), AGPL-3.0 (Volatility lib from Aloe)

---

## Executive Summary

Valorem Oracles is a **partially-implemented** oracle suite designed to feed the Valorem option settlement engine with pricing inputs. It contains three functional oracle contracts and one interface-only placeholder:

| Component | Status | Methodology |
|---|---|---|
| IV Oracle (UniswapV3VolatilityOracle) | **Implemented, tested** | Aloe Blend fee-growth method (Lambert 2021) |
| Price Oracle (ChainlinkPriceOracle) | **Implemented, minimal** | Chainlink AggregatorV3 wrapper |
| Yield Oracle (CompoundV3YieldOracle) | **Implemented, tested** | Compound III supply rate TWAP |
| Black-Scholes Pricer | **Interface only, NO implementation** | N/A |
| Greeks computation | **Not present at all** | N/A |
| Realized Volatility | **Not implemented** | `revert("not implemented")` on L60 |

**Bottom line**: The repository delivers one genuinely useful component -- the Uni V3 fee-based implied volatility estimator derived from Aloe Blend. The BSM pricer and greeks, which would be the most valuable for our hedge construction, do not exist as code. The yield oracle provides a risk-free rate proxy via Compound III supply rates.

---

## 1. Component-by-Component Analysis

### 1.1 UniswapV3VolatilityOracle (IV Oracle)

**Files**:
- `src/UniswapV3VolatilityOracle.sol` (349 lines)
- `src/libraries/Volatility.sol` (192 lines) -- forked from Aloe Blend
- `src/libraries/Oracle.sol` (73 lines) -- forked from Aloe Blend
- `src/libraries/TickMath.sol`, `FullMath.sol`, `FixedPoint96.sol` -- standard Uni V3 math

**Methodology**: Guillaume Lambert's on-chain volatility estimation via Uniswap V3 fee growth differentials. The core paper: "On-chain Volatility and Uniswap V3" (Lambert, 2021).

**How it works, step by step**:

1. **Fee growth sampling**: The oracle stores a circular buffer of 25 `FeeGrowthGlobals` snapshots per pool (containing `feeGrowthGlobal0X128`, `feeGrowthGlobal1X128`, and `timestamp`). New snapshots are written at most once per hour.

2. **TWAP tick computation**: Uses `Oracle.consult()` to get the arithmetic mean tick and `secondsPerLiquidityX128` over a lookback window (capped between 1 hour and 1 day, with `maxSecondsAgo` scaled to 3/5 of the oldest available observation).

3. **Revenue estimation**: `Volatility.computeRevenueGamma()` computes per-token revenue from fee growth differentials, adjusting for protocol fee (gamma0/gamma1) and time-weighted liquidity:
   ```
   revenue = (feeGrowthB - feeGrowthA) * secondsAgo * gamma / (secondsPerLiquidityX128 * 1e6)
   ```

4. **Volume estimation**: Token0 revenue is converted to token1 terms using the geometric mean price, then summed to get `volumeGamma0Gamma1`.

5. **IV formula** (`Volatility.estimate24H`, line 96-98):
   ```
   IV = 2e18 * timeAdjustmentX32 * sqrt(volumeGamma0Gamma1) / sqrtTickTVLX32
   ```
   Where `timeAdjustmentX32 = sqrt(1 day / elapsed)` normalizes to 24-hour IV, and `tickTVL` is the value of liquidity at the current tick denominated in token1.

6. **Read selection**: `_loadIndicesAndSelectRead()` searches the 25-element buffer for the snapshot closest to 24 hours ago, minimizing the timing error `|age - 24h|`.

**Data sources**: Uni V3 pool `slot0()`, `feeGrowthGlobal0X128()`, `feeGrowthGlobal1X128()`, `liquidity()`, `observe()`.

**Keep3r integration**: A `work()` function callable by Keep3r keepers refreshes the cache for all registered token pairs. Admin can also manually trigger via `refreshVolatilityCache()`.

**Return value**: IV scaled by 1e18 (so 0.5 = 50% annualized vol = 5e17).

**Limitations**:
- Requires >= 1 hour of oracle observation history (line 303: `require(secondsAgo >= 1 hours)`)
- Only measures fee-implied volatility, not realized price volatility
- `getHistoricalVolatility()` explicitly reverts with "not implemented" (line 60-61)
- V3-only; no V4 hook/pool support
- Single-factory hardcoded to `0x1F98431c8aD98523631AE4a59f267346ea31F984` (Ethereum mainnet)

**Test quality**: `test/UniswapV3VolatilityOracle.t.sol` (303 lines) covers admin controls, pool lookups, token refresh lists, Keep3r integration, and a full 24-hour cache simulation with simulated swaps via Foundry fork tests. Reasonably thorough.


### 1.2 ChainlinkPriceOracle

**File**: `src/ChainlinkPriceOracle.sol` (70 lines)

**Methodology**: Trivial adapter wrapping Chainlink `AggregatorV3Interface.latestRoundData()` into a `getPriceUSD(IERC20)` call.

**Implementation details**:
- Maps ERC20 addresses to Chainlink price feed aggregators via admin-controlled `setPriceFeed()`
- Returns raw `latestRoundData()` price and the aggregator's `decimals()` as scale
- No staleness checks, no round completeness validation, no fallback logic
- Comment on line 49: `// todo: validate token and price feed`

**Assessment**: Bare-minimum wrapper. Missing critical production safeguards (staleness, sequencer uptime for L2, heartbeat checks). Functional but not production-grade.


### 1.3 CompoundV3YieldOracle (Risk-Free Rate Proxy)

**File**: `src/CompoundV3YieldOracle.sol` (238 lines)

**Methodology**: Time-weighted average of Compound III (Comet) supply rates, used as an approximation of the risk-free rate for BSM pricing.

**How it works**:
1. Periodically latches the Comet supply rate (from `comet.getSupplyRate(utilization)`) into a circular buffer of 5-15 `SupplyRateSnapshot` structs per token.
2. `getTokenYield()` computes a time-weighted average across all snapshots using trapezoidal integration: `yield = sum(avgRate_i * delta_t_i) / sum(delta_t_i)`.
3. Returns a per-second rate scaled by 1e18.

**Data source**: Compound III Comet contract, hardcoded USDC Comet at `0xc3d688B66703497DAA19211EEdff47f25384cdc3`.

**Keep3r integration**: Same pattern as the volatility oracle -- `work()` latches rates for all registered tokens.

**Limitations**:
- Only Compound III, only USDC on mainnet
- Circular buffer of 5-15 snapshots means the TWAP window depends on latch frequency
- Per-second rate requires annualization: `annualRate = rate * 365.25 * 86400`
- No fallback if Compound III is paused or has zero utilization


### 1.4 Black-Scholes Pricer

**File**: `src/interfaces/IBlackScholes.sol` (60 lines) -- **INTERFACE ONLY**

**What is declared**:
- `getLongCallPremium(uint256 optionId) -> uint256`
- `getShortCallPremium(uint256 optionId) -> uint256`
- `getLongCallPremiumEx(...)` / `getShortCallPremiumEx(...)` -- extended versions accepting explicit oracle references
- Setters for volatility oracle, price oracle, yield oracle, and Valorem engine

**What exists in code**: Zero implementation. No contract implements `IBlackScholes`. No BSM formula, no `d1`/`d2` computation, no cumulative normal distribution, no `exp()` or `ln()` functions anywhere in the codebase.

**Dependency**: The interface imports `IOptionSettlementEngine` from `valorem-core`, indicating the intended design was to price Valorem-style physically-settled options.


### 1.5 Greeks Computation

**Status**: Completely absent. No interface, no library, no stub. The word "delta" appears only as time-delta in the yield oracle. No gamma, vanna, vega, theta, or rho anywhere.


### 1.6 Realized Volatility

**Status**: Interface declared in `IVolatilityOracle.getHistoricalVolatility(address)`, implementation is:
```solidity
function getHistoricalVolatility(address) external pure returns (uint256) {
    revert("not implemented");
}
```
No EWMA, no Parkinson, no Yang-Zhang, no close-to-close estimator. Not implemented.

---

## 2. Integration Assessment for LP Hedge Instruments

### 2.1 Can the IV computation feed into hedge sizing? (vol -> expected IL -> positionSize)

**Partially yes, with significant caveats.**

The Lambert fee-based IV is a reasonable proxy for short-term realized volatility in Uni V3 pools. The mathematical relationship we need is:

```
E[IL] ~ sigma^2 * T / 2   (for concentrated LP, first-order)
```

So feeding `sigma = IV_oracle / 1e18` into the IL estimator for position sizing is conceptually sound. However:

- The Lambert method measures **fee-implied** volatility, which conflates trading volume with actual price movement. High volume in a tight range (e.g., stablecoin pools) can register high "IV" even with minimal price drift. This is an overestimate of IL-relevant volatility for stable pairs.
- The 24-hour normalization means this is a **short-horizon** estimate. For multi-day hedge horizons, you would need to either (a) accumulate and annualize, or (b) use a separate longer-horizon RV estimator.
- The fee-growth method is specific to Uni V3 pool architecture. For V4 hooks that modify fee structures, the gamma0/gamma1 parameters would need recalibration.

**Recommendation**: Use the Volatility.sol library as a starting point, but feed the output into a smoothing filter (e.g., EWMA with configurable halflife) before using it for hedge sizing. Also cross-check against actual price RV from TWAP differentials.

**Integration path**:
1. Deploy or fork UniswapV3VolatilityOracle for the target pair
2. Read `getImpliedVolatility(tokenA, tokenB, tier)`
3. Convert to annualized sigma: `sigma = IV / 1e18`
4. Feed into IL model: `expectedIL = sigma^2 * T / 2` (or the exact Deng-Zong-Wang decomposition)
5. Derive hedge notional from expected IL and desired coverage ratio


### 2.2 Can the BSM pricer help price Panoptic option legs?

**No. It does not exist.**

The `IBlackScholes` interface was designed for Valorem's physically-settled vanilla options (via `IOptionSettlementEngine`), not for Panoptic's perpetual streaming options. Even if implemented, it would need fundamental adaptation:

- Panoptic options are **perpetual** (no fixed expiry), so classical BSM with `T -> expiry` does not directly apply
- Panoptic uses **streaming premia** derived from fee accumulation, not upfront premium
- The strike mechanism in Panoptic is based on tick ranges, not discrete strike prices

**What we actually need**: A pricer that maps our K^{-3/2}-weighted strike grid into Panoptic `tokenId` positions and estimates the streaming premium cost per unit of gamma exposure. This is a custom computation, not classical BSM.


### 2.3 Can greeks computation help with hedge ratios?

**No. Greeks are not implemented.**

For our hedge construction, we need:
- **Delta** at each strike to compute the net delta of the hedge portfolio
- **Gamma** to verify the IL-replicating property (gamma of LP ~ sum of gammas of option legs)
- **Vanna** (cross-greek dS/dsigma) for vol-sensitivity of the hedge

None of this exists in Valorem oracles. The Panoptic codebase itself has some delta/gamma awareness in its collateral tracking, which is more relevant.


### 2.4 Uni V3/V4 TWAP dependencies

The Volatility and Oracle libraries are **hard-coded to Uni V3 pool interfaces**:
- `IUniswapV3Pool.slot0()` -- V4 uses `PoolManager.getSlot0()` via `StateLibrary`
- `IUniswapV3Pool.observe()` -- V4 oracle is opt-in via hooks
- `IUniswapV3Pool.feeGrowthGlobal0X128()` -- V4 uses `PoolManager.getFeeGrowthGlobals()`
- `IUniswapV3Pool.liquidity()` -- V4 uses `PoolManager.getLiquidity()`

**Porting effort**: The core `Volatility.estimate24H()` library function is pure and takes struct inputs. The V3-specific calls are isolated in `UniswapV3VolatilityOracle._estimate24H()` and `Oracle.consult()`. Adapting to V4 would require:
1. A new `UniswapV4VolatilityOracle` contract that reads pool state via `PoolManager` + `StateLibrary`
2. Implementing oracle observation via a hook (V4 does not have built-in oracle; see `OracleHook` patterns)
3. Rewriting `Oracle.consult()` to use the hook's observation array
4. The `Volatility` library itself can be reused as-is

---

## 3. Code Quality Assessment

### Strengths
- Clean separation of concerns: interfaces, libraries, contracts
- The Volatility library (from Aloe Blend) is well-tested and battle-hardened
- Keep3r integration for automated updates is production-minded
- Circular buffer design for fee growth globals is gas-efficient
- Tests use Foundry fork testing with real mainnet state

### Weaknesses
- **Incomplete implementation**: BSM and RV are declared but not built
- **No staleness protection** on Chainlink oracle
- **Hardcoded addresses**: Uni V3 factory, Comet USDC -- no multi-chain support
- **Pragma 0.8.13**: Outdated; Panoptic and our codebase use newer versions
- **No access control granularity**: Simple admin pattern with no timelocks or multisig integration
- **No events on critical state reads**: Only emissions on writes
- **BUSL 1.1 license**: Restrictive for commercial use; the Volatility lib is AGPL (copyleft)

### Code maturity
This looks like a **prototype/MVP** that was started alongside the Valorem options protocol (now known as "Valorem Clear") but development stalled before the BSM pricer was built. The working components (IV oracle, yield oracle) are functional but not production-hardened.

---

## 4. Salvageable Components for Our Project

### 4.1 Volatility.sol library -- HIGH VALUE

The `Volatility.estimate24H()` function and its helpers (`computeRevenueGamma`, `computeTickTVLX64`, `amount0ToAmount1`) implement Lambert's fee-based IV method correctly. This is the most complex and valuable piece.

**How to use**: Fork `Volatility.sol` and `Oracle.sol`, adapt the data-fetching layer for V4, keep the pure math as-is.

**File**: `/home/jmsbpp/apps/liq-soldk-dev/lib/valorem-oracles/src/libraries/Volatility.sol`

### 4.2 CompoundV3YieldOracle -- MEDIUM VALUE

The time-weighted supply rate computation provides a reasonable on-chain risk-free rate proxy. This feeds into:
- BSM pricing (if we build our own pricer)
- Carry cost estimation for hedges held over time
- Opportunity cost of capital locked in Panoptic collateral

**File**: `/home/jmsbpp/apps/liq-soldk-dev/lib/valorem-oracles/src/CompoundV3YieldOracle.sol`

### 4.3 IBlackScholes interface -- LOW VALUE (design reference only)

The interface shows the intended architecture: volatility oracle + price oracle + yield oracle -> BSM premium. This modular oracle composition pattern is sound, even though we will price differently (streaming premia, not BSM lump-sum).

**File**: `/home/jmsbpp/apps/liq-soldk-dev/lib/valorem-oracles/src/interfaces/IBlackScholes.sol`

### 4.4 Keep3r automation pattern -- LOW VALUE

The Keep3r integration shows how to automate oracle refresh. We may want a similar pattern for periodic hedge rebalancing, though MEV-aware solutions (Flashbots Protect, etc.) would be more appropriate.

---

## 5. What Is Missing That We Need

| Need | Valorem Status | Alternative Source |
|---|---|---|
| Realized Volatility (close-to-close or Parkinson) | Not implemented | Build from TWAP snapshots; see VolatilityHook-UniV4 in our lib/ |
| BSM/option pricer | Interface only | Lyra's BlackScholes.sol, or custom streaming-premia model |
| Greeks (delta, gamma, vanna) | Absent | Panoptic's internal collateral tracking has partial delta; build gamma from IL decomposition |
| V4-compatible vol oracle | Absent | Adapt Volatility.sol with V4 StateLibrary reads |
| IV surface (vol-by-strike) | Absent | Would need implied vol at multiple tick ranges; research-grade problem |
| Streaming premium estimator | Absent (wrong model) | Derive from Panoptic's fee accumulation model |

---

## 6. Recommendations

1. **Fork Volatility.sol** into our `src/libraries/` and create a V4-compatible wrapper. This gives us on-chain sigma for the IL model's `expectedIL = f(sigma, tick_range)` computation. The pure math in `estimate24H` is reusable without modification.

2. **Do not depend on Valorem's BSM interface** for pricing. Panoptic options have fundamentally different economics (streaming vs. upfront premium). Build a custom `HedgePricer` that estimates the cost of a Panoptic position in terms of expected streaming premium outflow.

3. **Consider the yield oracle** for carry/opportunity cost, but evaluate whether Aave/Morpho rates are more representative than Compound III for the tokens we hedge.

4. **Build our own RV estimator** using V4 hook oracle observations (tick snapshots at regular intervals). The Deng-Zong-Wang IL decomposition needs actual realized sigma, not fee-implied IV which overestimates for low-drift pairs.

5. **License awareness**: Volatility.sol is AGPL-3.0 (from Aloe Blend). If our project uses BUSL or proprietary license, we need to either (a) accept AGPL copyleft, (b) rewrite the math independently, or (c) isolate it as a separate AGPL-licensed library.

---

## 7. File Reference

All paths relative to repo root `/home/jmsbpp/apps/liq-soldk-dev/lib/valorem-oracles/`:

| File | Lines | Purpose |
|---|---|---|
| `src/UniswapV3VolatilityOracle.sol` | 349 | Main IV oracle contract (V3-specific) |
| `src/libraries/Volatility.sol` | 192 | Core IV math (Aloe Blend fork) -- **most valuable** |
| `src/libraries/Oracle.sol` | 73 | V3 TWAP helper (Aloe Blend fork) |
| `src/ChainlinkPriceOracle.sol` | 70 | Minimal Chainlink wrapper |
| `src/CompoundV3YieldOracle.sol` | 238 | Risk-free rate via Compound III |
| `src/interfaces/IBlackScholes.sol` | 60 | BSM interface (no implementation) |
| `src/interfaces/IVolatilityOracle.sol` | 33 | IV/RV oracle interface |
| `src/interfaces/IYieldOracle.sol` | 25 | Yield oracle interface |
| `src/interfaces/IPriceOracle.sol` | 20 | Price oracle interface |
| `test/UniswapV3VolatilityOracle.t.sol` | 303 | Fork test with simulated swaps |
| `test/CompoundV3YieldOracle.t.sol` | -- | Yield oracle tests |
