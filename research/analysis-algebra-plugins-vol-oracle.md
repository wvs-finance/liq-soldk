# Algebra Integral Plugins: Volatility Oracle and Adaptive Fee -- Deep Analysis

**Date:** 2026-03-29
**Repo:** `lib/algebra-plugins` (cryptoalgebra/integral-team-plugins)
**Scope:** VolatilityOracle.sol, AdaptiveFee.sol, AlgebraBasePluginV1.sol, and full data flow
**Purpose:** Assess extractability of sigma (volatility estimate) for Hedge Builder position sizing

---

## Executive Summary

The Algebra Integral plugins implement a **production-grade on-chain volatility oracle** used by Camelot, THENA, QuickSwap, and other major DEXes. The system computes a cumulative volatility metric from tick observations stored in a 65,536-entry ring buffer, then maps this volatility to a dynamic swap fee via a dual-sigmoid formula. The volatility computation is mathematically distinct from standard realized volatility -- it measures the **integrated squared deviation of tick from its time-weighted average** (a "tracking error variance" rather than a return variance). This is a critical distinction for our Hedge Builder: the Algebra "volatility" is not directly annualized sigma in the Black-Scholes sense, but it can be converted with known scaling factors.

**Key findings for our project:**

1. The volatility metric is continuously accumulated on every swap (no keeper needed), making it highly available
2. It uses a 24-hour (WINDOW = 86400s) rolling average, normalized to 15-second intervals for fee computation
3. The mathematical formula measures `sum((tick(t) - avgTick(t))^2)` resampled to 1-second frequency -- a mean-reverting deviation measure, not a log-return variance
4. Extraction is feasible but requires a conversion factor to obtain annualized sigma
5. No sliding fee plugin exists in this repository (the 3 plugin variants -- stub, limit-order, brevis -- all share identical VolatilityOracle and AdaptiveFee code)

---

## 1. Repository Structure

The repo contains three plugin variants under `src/plugin/`:

```
src/plugin/
  stub/          -- Minimal "default" plugin (oracle + adaptive fee + farming)
  limit-order/   -- Adds limit order functionality
  brevis/        -- Adds Brevis ZK-proof integration
```

**All three variants share byte-identical VolatilityOracle.sol and AdaptiveFee.sol libraries.** The only differences are in the plugin-specific features layered on top.

### Core Files (using stub/ as canonical path)

| File | Purpose |
|------|---------|
| `libraries/VolatilityOracle.sol` | Ring buffer, tick accumulation, volatility computation |
| `libraries/AdaptiveFee.sol` | Dual-sigmoid fee formula |
| `base/AlgebraFeeConfiguration.sol` | Fee config struct (7 params) |
| `types/AlgebraFeeConfigurationU144.sol` | Bit-packed config for single-slot storage |
| `AlgebraBasePluginV1.sol` | Main plugin contract, hook callbacks |
| `BasePluginV1Factory.sol` | Factory for plugin deployment |
| `libraries/integration/OracleLibrary.sol` | TWAP helper for external consumers |
| `lens/AlgebraOracleV1TWAP.sol` | Read-only frontend contract |

---

## 2. Data Structures

### 2.1 Timepoint Struct (Ring Buffer Entry)

**File:** `libraries/VolatilityOracle.sol`, line 20-28

```solidity
struct Timepoint {
    bool initialized;          // 1 byte   -- whether slot is valid
    uint32 blockTimestamp;     // 4 bytes  -- when this observation was recorded
    int56 tickCumulative;      // 7 bytes  -- cumulative sum of (tick * dt)
    uint88 volatilityCumulative; // 11 bytes -- cumulative volatility accumulator
    int24 tick;                // 3 bytes  -- spot tick at this timestamp
    int24 averageTick;         // 3 bytes  -- TWAP tick over WINDOW at this timestamp
    uint16 windowStartIndex;   // 2 bytes  -- index of closest timepoint >= WINDOW ago
}
```

**Total:** 31 bytes, packed into a single 256-bit storage slot.

### 2.2 Ring Buffer

- **Size:** `UINT16_MODULO = 65536` entries (line 18)
- **Type:** `Timepoint[65536] storage`
- **Overflow handling:** uint16 index wraps naturally. When `self[indexUpdated].initialized` is true, we know the buffer has wrapped and `oldestIndex = indexUpdated`.
- **Write frequency:** At most once per block (duplicate timestamps are silently skipped, line 56)
- **Prepayment:** `prepayTimepointsStorageSlots()` allows pre-warming storage slots to reduce future SSTORE costs from cold (~20k gas) to warm (~5k gas)

### 2.3 Fee Configuration (Packed)

**File:** `types/AlgebraFeeConfigurationU144.sol`

Seven parameters packed into uint144 (18 bytes, fits in single slot alongside other state):

| Field | Type | Offset | Default Value | Meaning |
|-------|------|--------|---------------|---------|
| alpha1 | uint16 | 0 | 2900 | Max contribution of sigmoid 1 (hundredths of bip) |
| alpha2 | uint16 | 16 | 12000 | Max contribution of sigmoid 2 |
| beta1 | uint32 | 32 | 360 | X-shift for sigmoid 1 |
| beta2 | uint32 | 64 | 60000 | X-shift for sigmoid 2 |
| gamma1 | uint16 | 96 | 59 | Stretch factor for sigmoid 1 |
| gamma2 | uint16 | 112 | 8500 | Stretch factor for sigmoid 2 |
| baseFee | uint16 | 128 | 100 (0.01%) | Minimum fee floor |

**Constraint:** `alpha1 + alpha2 + baseFee <= type(uint16).max` (65535, i.e., 6.5535%)

---

## 3. Complete Data Flow

### 3.1 Trigger: beforeSwap Hook

**File:** `AlgebraBasePluginV1.sol`, line 256-259

```
Pool.swap() -> plugin.beforeSwap() -> _writeTimepointAndUpdateFee()
```

The `beforeSwap` hook is the ONLY entry point that writes new timepoints. This means:
- Timepoints are written **before** the swap executes (capturing the pre-swap tick)
- No timepoints are written during periods of inactivity (no swaps = no observations)
- The oracle is purely swap-driven, no keeper infrastructure needed

### 3.2 _writeTimepointAndUpdateFee() -- The Core Update

**File:** `AlgebraBasePluginV1.sol`, line 297-319

Step-by-step:

1. **Load state** (single SLOAD due to packing): `timepointIndex`, `lastTimepointTimestamp`, `_feeConfig`, `isInitialized`
2. **Dedup check:** If `lastTimepointTimestamp == currentTimestamp`, return early (at most one write per block)
3. **Read pool state:** Get current `tick` from `IAlgebraPoolState.globalState()`
4. **Write timepoint:** `timepoints.write(lastIndex, currentTimestamp, tick)`
5. **Update fee:** Compute `getAverageVolatility()` then `AdaptiveFee.getFee()`, call `pool.setFee()` if changed

### 3.3 Timepoint Creation: _createNewTimepoint()

**File:** `VolatilityOracle.sol`, line 244-263

Given the previous timepoint `last` and new data:

```
delta = blockTimestamp - last.blockTimestamp

tickCumulative += tick * delta

volatilityCumulative += _volatilityOnRange(delta, tick, tick, last.averageTick, averageTick)

averageTick = TWAP over WINDOW
```

**Critical observation:** The `tick` parameter passed to `_createNewTimepoint` is the CURRENT tick. In the `write()` function (line 78), both `tick0` and `tick1` in `_volatilityOnRange` are the same value (the current tick). This means **within a single timepoint interval, the tick is treated as constant**. The volatility comes from the deviation of this constant tick from the changing average tick.

### 3.4 The Volatility Formula: _volatilityOnRange()

**File:** `VolatilityOracle.sol`, line 273-291

This is the mathematical core. The function computes the sum of `(tick(t) - avgTick(t))^2` for every second `t` in the interval `(0, dt]`, assuming both tick and avgTick change linearly during the interval.

**Mathematical derivation (from the comments, verified against code):**

Let:
- `tick(t) = k*t + b` (linear interpolation of tick)
- `avgTick(t) = p*t + q` (linear interpolation of average tick)

We want: `sum_{t=1}^{dt} (tick(t) - avgTick(t))^2`

```
(tick(t) - avgTick(t))^2 = ((k-p)*t + (b-q))^2
                         = (k-p)^2 * t^2 + 2*(k-p)*(b-q)*t + (b-q)^2
```

Using summation formulas:
- `sum(t, 1..dt) = dt*(dt+1)/2`
- `sum(t^2, 1..dt) = dt*(dt+1)*(2*dt+1)/6`

The actual code computes:

```solidity
k = (tick1 - tick0) - (avgTick1 - avgTick0)  // This is (k-p)*dt
b = (tick0 - avgTick0) * dt                    // This is (b-q)*dt

sumOfSequence = dt * (dt + 1)                  // 2 * sum(t)
sumOfSquares = sumOfSequence * (2 * dt + 1)    // 6 * sum(t^2)

volatility = (k^2 * sumOfSquares + 6*b*k*sumOfSequence + 6*dt*b^2) / (6 * dt^2)
```

**This computes:** `sum_{t=1}^{dt} (tick(t) - avgTick(t))^2` -- the total squared tracking error between the instantaneous tick and the moving average tick, resampled to 1-second granularity.

**IMPORTANT INTERPRETATION:** This is NOT a log-return variance. It is a **mean-reversion tracking error**. The "volatility" accumulates faster when the tick deviates far from its 24-hour TWAP. This makes it more like a measure of "how much is the price oscillating around its mean" rather than "how much are returns varying."

### 3.5 Average Tick (TWAP) Computation

**File:** `VolatilityOracle.sol`, line 316-348

The average tick is a Time-Weighted Average Price (TWAP) over `WINDOW = 1 days = 86400 seconds`:

```
avgTick = (tickCumulative[now] - tickCumulative[now - WINDOW]) / WINDOW
```

Where `tickCumulative` is the running sum of `tick * elapsed_seconds`.

The `windowStartIndex` field on each timepoint provides a shortcut to efficiently locate the timepoint at `currentTime - WINDOW` without a full binary search from scratch -- it narrows the search window.

### 3.6 Average Volatility Computation

**File:** `VolatilityOracle.sol`, line 187-231

`getAverageVolatility()` returns the average per-second volatility over the WINDOW:

```
volatilityAverage = (volatilityCumulative[now] - volatilityCumulative[now - WINDOW]) / WINDOW
```

This is the average of the per-second squared tracking error over 24 hours.

**Bessel's correction:** When the sample window is shorter than WINDOW (pool is young), the denominator is reduced by 1 (line 227: `if (unbiasedDenominator > 1) unbiasedDenominator--`).

---

## 4. Adaptive Fee Formula

### 4.1 Normalization

**File:** `AdaptiveFee.sol`, line 41

```solidity
volatility /= 15; // normalize for 15 sec interval
```

The raw `volatilityAverage` (per-second squared tracking error, averaged over 24h) is divided by 15. This converts from a per-second measure to a per-15-second measure. The fee config parameters (beta1, beta2, gamma1, gamma2) are calibrated for this 15-second-normalized volatility scale.

### 4.2 Dual Sigmoid Formula

**File:** `AdaptiveFee.sol`, line 37-49

```
fee = baseFee + sigmoid1(vol) + sigmoid2(vol)
```

Where each sigmoid is:

```
sigmoid(x, gamma, alpha, beta) = alpha / (1 + e^((beta - x) / gamma))
```

**Fee range:** `[baseFee, baseFee + alpha1 + alpha2]`

With defaults:
- Minimum fee: baseFee = 100 (0.01%)
- Maximum fee: 100 + 2900 + 12000 = 15000 (1.5%)

### 4.3 Sigmoid Implementation

**File:** `AdaptiveFee.sol`, line 55-73

The sigmoid uses a lookup-table-accelerated Taylor series expansion of `e^(x/gamma)`:

1. Compute `floor(x/gamma)` and look up `e^0, e^1, ..., e^5` from a hardcoded table
2. If the remainder `>= gamma/2`, multiply by `e^0.5`
3. Compute the remaining Taylor series `1 + x/g + x^2/(2g^2) + x^3/(6g^3) + x^4/(24g^4)` for the fractional part
4. All computation is done in `g^4`-scaled arithmetic to avoid divisions

**Accuracy:** Good for `x/gamma < 6` (explicitly checked; beyond 6, the function saturates at alpha or 0).

### 4.4 Default Fee Curve Behavior

With default parameters:

| Volatility (normalized) | Approximate Fee |
|------------------------|----------------|
| 0 | 100 (0.01%) |
| ~360 | ~1550 (inflection of sigmoid1) |
| ~5000 | ~5000 (mid-range) |
| ~60000 | ~14500 (near sigmoid2 inflection) |
| Very high | 15000 (1.5% cap) |

Sigmoid 1 (alpha1=2900, beta1=360, gamma1=59) responds to **low-to-moderate** volatility changes with fine granularity. Sigmoid 2 (alpha2=12000, beta2=60000, gamma2=8500) responds to **extreme** volatility spikes.

---

## 5. Hook Callback Architecture

| Hook | Active | Purpose |
|------|--------|---------|
| `beforeInitialize` | Yes | Sets plugin config in pool |
| `afterInitialize` | Yes (AFTER_INIT_FLAG) | Initializes oracle, sets initial fee |
| `beforeSwap` | Yes (BEFORE_SWAP_FLAG) | **Primary driver:** writes timepoint, updates fee |
| `afterSwap` | Conditional (AFTER_SWAP_FLAG) | Only active when farming incentive is connected |
| `beforeModifyPosition` | No (reset if called) | Unused |
| `afterModifyPosition` | No (reset if called) | Unused |
| `beforeFlash` / `afterFlash` | No (reset if called) | Unused |

The `DYNAMIC_FEE` flag is always set in `defaultPluginConfig`, which tells the pool to call `getCurrentFee()` or accept `setFee()` calls.

---

## 6. Converting Algebra "Volatility" to Annualized Sigma

### 6.1 What Algebra's Metric Actually Measures

The `volatilityAverage` from `getAverageVolatility()` is:

```
V_avg = (1/WINDOW) * sum_{all intervals in WINDOW} sum_{t=1}^{dt_i} (tick(t) - avgTick(t))^2
```

This is the **average per-second squared deviation of tick from its 24h TWAP**, measured in tick^2 units.

### 6.2 Conversion to Annualized Sigma

Since `tick = log_{1.0001}(price)` and 1 tick ~= 1 basis point of price change:

```
V_avg is in units of tick^2 / second (after WINDOW averaging)
```

To get annualized volatility:

```
sigma_annual_ticks = sqrt(V_avg * SECONDS_PER_YEAR)
```

To convert to percentage:

```
sigma_annual_pct = sigma_annual_ticks * ln(1.0001)  [~= 0.00009999 per tick]
```

Or in basis points:

```
sigma_annual_bps = sigma_annual_ticks * 1  [since 1 tick ~= 1 bps]
```

**HOWEVER:** This is tracking-error volatility (deviation from mean), not return volatility. For a random walk, the tracking error over a window T equals approximately `sqrt(T/3)` times the diffusion coefficient. So for mean-reverting assets, this will **underestimate** true return vol, and for trending assets, it may **overestimate**.

The more precise relationship: if tick follows `dS = sigma * dW`, then the average squared deviation from the T-window mean is approximately `sigma^2 * T / 12` for a continuous Brownian motion. Therefore:

```
sigma^2 ~= 12 * V_avg / WINDOW * SECONDS_PER_YEAR
sigma_annual ~= sqrt(12 * V_avg * SECONDS_PER_YEAR / WINDOW)
```

But after the `/15` normalization in AdaptiveFee:

```
V_normalized = V_avg / 15
sigma_annual ~= sqrt(12 * 15 * V_normalized * SECONDS_PER_YEAR / WINDOW)
             = sqrt(180 * V_normalized * 31557600 / 86400)
             = sqrt(180 * V_normalized * 365.25)
             = sqrt(65745 * V_normalized)
```

### 6.3 Practical Extraction Path

For our Hedge Builder, the simplest approach:

```solidity
// Read from any Algebra-based pool (Camelot, THENA, QuickSwap)
IVolatilityOracle oracle = IVolatilityOracle(pluginAddress);
(, uint88 volCumNow) = oracle.getSingleTimepoint(0);
(, uint88 volCumAgo) = oracle.getSingleTimepoint(WINDOW);

uint88 avgVol = (volCumNow - volCumAgo) / WINDOW;

// Convert to annualized sigma in ticks (approximately bps)
// Using the sqrt(12/T * V_avg * SECONDS_PER_YEAR) formula
uint256 sigmaAnnualBps = sqrt(12 * uint256(avgVol) * 31557600 / 86400);
```

Or use the plugin's `getCurrentFee()` view function and back out an implied volatility from the known sigmoid parameters.

---

## 7. Comparison: Algebra vs Tempest

| Dimension | Algebra (VolatilityOracle) | Tempest (VolatilityEngine) |
|-----------|---------------------------|---------------------------|
| **Architecture** | Algebra V2 plugin (Plugins framework) | Uni V4 hook |
| **Observation trigger** | beforeSwap (pre-swap tick) | afterSwap (post-swap tick) |
| **Buffer** | 65,536 entries, 1 slot each | 1,024 entries, 4-packed per slot |
| **Vol metric** | Tracking error variance (tick vs 24h TWAP) | Standard return variance (tick deltas) |
| **Accumulation** | Cumulative (on-chain running sum) | Batch recomputation by keeper |
| **Window** | Fixed 24 hours | Variable (up to 256 most recent observations) |
| **Update model** | Every swap, fully on-chain | Observation per swap, vol computed by external keeper |
| **Fee formula** | Dual sigmoid (smooth, continuous) | Piecewise linear (6 control points) |
| **Fee range** | 0.01% to ~1.5% (default) | 0.05% to 5.00% (default) |
| **Annualization** | Implicit in normalization (/15) | Explicit (variance_per_second * SECONDS_PER_YEAR) |
| **EMA smoothing** | None (raw 24h window average) | 7-day and 30-day EMAs |
| **Regime detection** | None (continuous sigmoid mapping) | 5 discrete regimes (VeryLow to Extreme) |
| **Keeper dependency** | None | Required for vol computation |
| **Gas per update** | ~30-50k (write + binary search + fee calc) | ~5.2k per observation write, ~150k keeper update |
| **Staleness protection** | None (last known fee persists) | Escalates to max fee after 1 hour stale |
| **Momentum** | None | Fee boosted up to 50% when vol > EMA |

### 7.1 Mathematical Differences

**Algebra** computes:
```
vol = avg over 24h of: sum_{t=1}^{dt} (tick(t) - TWAP(t))^2
```
This is a **mean-reversion distance metric**. It measures how much the instantaneous tick oscillates around its 24-hour moving average.

**Tempest** computes:
```
vol = sqrt(avg(delta_tick^2 / dt) * SECONDS_PER_YEAR)
```
This is a standard **realized return volatility** (tick log-returns, time-weighted, annualized).

**For our Hedge Builder**, Tempest's metric is more directly usable because:
- It is already in annualized sigma form
- It measures the same quantity needed for Black-Scholes position sizing
- The Algebra metric requires a conversion factor that depends on assumptions about the price process

### 7.2 Advantages of Each

**Algebra advantages:**
- No keeper dependency (self-updating on every swap)
- Battle-tested in production across 4+ major DEXes
- 65k-entry buffer provides massive history depth
- Cumulative accumulator design is extremely gas-efficient for reads
- Binary search with window heuristic is well-optimized

**Tempest advantages:**
- Directly computes realized volatility (no conversion needed)
- EMA smoothing provides trend awareness
- Regime classification directly maps to hedge sizing
- Momentum adjustment captures vol acceleration
- Staleness protection prevents stale fee persistence
- Piecewise linear fee is more transparent and configurable

---

## 8. Extractability Assessment for Hedge Builder

### 8.1 Direct On-Chain Reading (Recommended)

The simplest integration path is to read from existing Algebra-based pool deployments:

```solidity
interface IAlgebraVolReader {
    function getSingleTimepoint(uint32 secondsAgo)
        external view returns (int56 tickCumulative, uint88 volatilityCumulative);
    function getTimepoints(uint32[] memory secondsAgos)
        external view returns (int56[] memory, uint88[] memory);
}
```

**Available on:** Every Camelot pool (Arbitrum), every THENA pool (BSC), every QuickSwap pool (Polygon).

To get sigma for position sizing:

1. Call `getTimepoints([86400, 0])` to get 24h cumulative values
2. Compute `avgVol = (volCum[1] - volCum[0]) / 86400`
3. Apply conversion: `sigma = sqrt(12 * avgVol * 31557600 / 86400)` (in tick units, ~= bps)
4. Convert bps to decimal: `sigma_decimal = sigma_bps / 10000`

### 8.2 Library Extraction (For V4 Hook Integration)

The `VolatilityOracle` library is self-contained and could be adapted for a Uni V4 hook:

**Dependencies:**
- Only depends on Solidity primitives (no external imports)
- The `Timepoint` struct and ring buffer are the core data structures
- `_volatilityOnRange()`, `_getAverageTick()`, `getAverageVolatility()` are the key functions

**Modifications needed:**
1. Change storage pattern from `Timepoint[65536] storage` to hook-compatible transient or ERC-7201 namespaced storage
2. The `write()` function needs to be called from the hook's `beforeSwap` or `afterSwap`
3. The 24h window constant may need tuning (shorter for more responsive sigma, longer for stability)

### 8.3 Hybrid Approach (Recommended for Our Project)

For our IL oracle and hedge builder, the optimal approach:

1. **Use Algebra oracle as a cross-chain sigma source** for pools deployed on Camelot/THENA/QuickSwap
2. **Use Tempest's VolatilityEngine** (already in V4 hook form) as the primary sigma provider for our V4-native pools
3. **Build an adapter interface** `ISigmaProvider` that abstracts both:

```solidity
interface ISigmaProvider {
    /// @return sigma Annualized volatility in WAD (1e18 = 100%)
    function getSigma(bytes32 poolId) external view returns (uint256 sigma);
}
```

### 8.4 Gas Considerations

| Operation | Approximate Gas |
|-----------|----------------|
| `write()` (new timepoint) | ~25-35k (cold slot write + avg tick computation) |
| `write()` (warm slot, same block) | ~2k (early return) |
| `getAverageVolatility()` | ~10-25k (binary search + interpolation) |
| `getSingleTimepoint(0)` | ~5k (just reads last entry) |
| `getSingleTimepoint(86400)` | ~10-20k (binary search for 24h ago) |
| `getFee()` | ~2-5k (pure sigmoid math) |

The `prepayTimepointsStorageSlots()` function can reduce `write()` to ~8-10k by pre-warming slots. This is a significant optimization for high-frequency pools.

---

## 9. Notable Implementation Details

### 9.1 Overflow Safety

- Ring buffer index uses `uint16` with intentional overflow wrapping (line 59-61)
- `volatilityCumulative` uses `uint88` -- overflow after ~34,800 years at maximum volatility (per comment)
- `tickCumulative` uses `int56` -- sufficient for `int24 tick * uint32 time`
- Timestamp comparisons use `_lteConsideringOverflow()` which handles 1-overflow of uint32 timestamps (safe until ~2106)

### 9.2 Interpolation Between Timepoints

When querying a timestamp that falls between two stored timepoints, the library linearly interpolates both `tickCumulative` and `volatilityCumulative` (lines 127-134). This means:
- TWAP queries between timepoints are approximate (linear interpolation of cumulative = step function in rate)
- Volatility queries between timepoints are similarly approximated

The comments explicitly warn: **"volatilityCumulative values for timestamps after the last timepoint should not be compared because they may differ due to interpolation errors."**

### 9.3 Window Start Index Optimization

Each timepoint stores `windowStartIndex` -- the index of the closest timepoint at or before `currentTime - WINDOW`. This acts as a "bookmark" that narrows binary search when looking up the start of the 24h window. Combined with the heuristic in `_binarySearchInternal` (which first guesses near the left boundary for window-start queries), this significantly reduces the number of storage reads for the common case.

### 9.4 No Sliding Fee Plugin

Despite claims of a "15% efficiency improvement," no sliding fee plugin variant exists in this repository. All three variants (stub, limit-order, brevis) use identical VolatilityOracle and AdaptiveFee code (verified by diff).

---

## 10. Risks and Limitations

### 10.1 Oracle Manipulation

The oracle accumulates on every swap, making it resistant to single-block manipulation (similar to Uniswap TWAP). However:
- A sustained attack over many blocks within the 24h window could bias the TWAP
- The volatility metric would increase during an attack (deviation from mean increases), which actually serves as a natural defense (fees go up)

### 10.2 Inactive Pool Problem

If no swaps occur for extended periods:
- No new timepoints are written
- The oracle returns the last known values
- `getAverageVolatility()` extrapolates from whatever data exists
- Unlike Tempest, there is no staleness detection or failsafe

### 10.3 Mean-Reversion Bias

The tracking-error-based volatility will:
- **Underestimate** sigma for strongly trending assets (the tick moves WITH the average, reducing tracking error)
- **Overestimate** sigma for mean-reverting assets (oscillations around mean amplify the metric)
- For our position sizing formula `positionSize = f(|UIL|, L, sigma)`, this bias matters

---

## 11. Recommendations for Our Project

### 11.1 Sigma Provider Strategy

**Priority 1:** Use Tempest's VolatilityEngine for V4-native pools (direct realized vol, already in hook form).

**Priority 2:** Build an `AlgebraSigmaAdapter` that reads from Algebra-based pools and converts:

```solidity
contract AlgebraSigmaAdapter is ISigmaProvider {
    // Read Algebra volatilityAverage, convert to annualized sigma
    // sigma_wad = sqrt(12 * volAvg * 31557600 / 86400) * 1e14
    // (1e14 converts from tick-bps-ish to WAD where 1e18 = 100%)
}
```

**Priority 3:** Consider extracting `VolatilityOracle.sol` as a library for our own V4 hook, using it as a secondary data source alongside Tempest. The cumulative accumulator design is more gas-efficient for reads than Tempest's batch-recompute model.

### 11.2 For Position Sizing

The formula `positionSize = f(|UIL|, L, sigma)` needs true annualized sigma. Given the conversion uncertainty with Algebra's tracking-error metric, I recommend:

1. Use Tempest sigma as the primary input (it is already return volatility)
2. Cross-check against Algebra's metric (if significantly different, the difference itself is informative -- it indicates trending vs mean-reverting market conditions)
3. Consider using `max(tempest_sigma, algebra_converted_sigma)` as a conservative estimate

### 11.3 Key Files for Integration

- **Read Algebra volatility:** Call `IVolatilityOracle(pluginAddress).getTimepoints()` or `getSingleTimepoint()`
- **Read Algebra fee:** Call `IAlgebraDynamicFeePlugin(pluginAddress).getCurrentFee()`
- **Adapt for V4:** Extract `VolatilityOracle._volatilityOnRange()` and `_createNewTimepoint()` as library functions

---

## Appendix A: File Reference Index

| File (absolute path) | Key Contents |
|---|---|
| `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/libraries/VolatilityOracle.sol` | Ring buffer, timepoint struct, cumulative volatility, binary search, avg tick TWAP |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/libraries/AdaptiveFee.sol` | Dual sigmoid fee formula, Taylor series exp approximation |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/AlgebraBasePluginV1.sol` | Hook callbacks, _writeTimepointAndUpdateFee, getCurrentFee |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/base/AlgebraFeeConfiguration.sol` | Fee config struct definition |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/types/AlgebraFeeConfigurationU144.sol` | Bit-packed fee config (single-slot storage) |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/BasePluginV1Factory.sol` | Plugin deployment, default config |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/libraries/integration/OracleLibrary.sol` | TWAP helper, consult(), getQuoteAtTick() |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/lens/AlgebraOracleV1TWAP.sol` | Read-only frontend for oracle queries |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/test/SimulationAdaptiveFee.sol` | Simulation harness with init/getFee |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/test/VolatilityOracleTest.sol` | Test harness with batchUpdate, gas measurement |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/src/libraries/VolatilityEngine.sol` | Tempest: standard realized vol, EMA, regime detection |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/src/libraries/FeeCurve.sol` | Tempest: piecewise linear fee curve |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/src/libraries/TickObserver.sol` | Tempest: 4-packed observation buffer |
| `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/src/TempestHook.sol` | Tempest: V4 hook with keeper-based vol updates |
