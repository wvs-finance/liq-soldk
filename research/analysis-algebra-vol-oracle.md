# Algebra Integral: Volatility Oracle and Adaptive Fee Plugin Analysis

**Date**: 2026-03-29
**Analyst**: Papa Bear (Deep Analysis)
**Scope**: `/lib/Algebra/` (Algebra Integral v1.2.2 core) + cross-reference with `/lib/VolatilityHook-UniV4/`, `/lib/valorem-oracles/`, `/lib/voltaire/`
**Purpose**: Assess extractability of on-chain volatility computation for IL hedge sizing in the LP risk hedging project (Prop 3.5 decomposition, Panoptic settlement).

---

## Executive Summary

The Algebra Integral repository at `/lib/Algebra/` contains the **core pool contracts and plugin interface layer** but does NOT contain the actual volatility oracle or adaptive fee computation logic. Those live in a separate repository (`cryptoalgebra/integral-team-plugins`) that is not currently included as a submodule. However, the Algebra plugin architecture is fully documented in the core codebase and provides a clean hook-based pattern for injecting volatility-dependent logic.

This analysis reconstructs the complete volatility-to-fee pipeline from:
1. The Algebra core plugin interface (present in repo)
2. The Algebra Base Plugin architecture (documented, not present -- reconstructed from docs + audit artifacts)
3. Three alternative volatility oracle implementations present in the repo (`valorem-oracles`, `VolatilityHook-UniV4`, `voltaire`)

**Key finding**: The Aloe/Valorem implied volatility estimator (present at `/lib/valorem-oracles/src/libraries/Volatility.sol`) is the most immediately extractable on-chain vol computation in the repo, and maps directly to the IL hedge sizing use case. The Algebra adaptive fee sigmoid model provides a second, complementary approach.

---

## 1. Algebra Plugin Architecture (Present in Repo)

### 1.1 Hook System

The Algebra Integral plugin system uses an 8-bit config bitmap to enable/disable callbacks. Each bit corresponds to a hook point:

| Bit | Flag | Value | Hook |
|-----|------|-------|------|
| 0 | `BEFORE_SWAP_FLAG` | 1 | `beforeSwap()` |
| 1 | `AFTER_SWAP_FLAG` | 2 | `afterSwap()` |
| 2 | `BEFORE_POSITION_MODIFY_FLAG` | 4 | `beforeModifyPosition()` |
| 3 | `AFTER_POSITION_MODIFY_FLAG` | 8 | `afterModifyPosition()` |
| 4 | `BEFORE_FLASH_FLAG` | 16 | `beforeFlash()` |
| 5 | `AFTER_FLASH_FLAG` | 32 | `afterFlash()` |
| 6 | `AFTER_INIT_FLAG` | 64 | `afterInitialize()` |
| 7 | `DYNAMIC_FEE` | 128 | Enables fee override from plugin |

**Source**: `/lib/Algebra/src/core/contracts/libraries/Plugins.sol` (lines 19-27)

### 1.2 Plugin-Pool Interaction for Dynamic Fees

The critical path for dynamic fee injection:

1. **Pool calls `_beforeSwap()`** -- if `BEFORE_SWAP_FLAG` is set and caller is not the plugin itself, it invokes `IAlgebraPlugin(plugin).beforeSwap(...)`.
2. **Plugin returns `(selector, overrideFee, pluginFee)`** -- the `beforeSwap` hook returns both a fee override and a plugin fee.
3. **Fee application in `_calculateSwap()`** -- if `overrideFee != 0`, it replaces the pool's `lastFee`; `pluginFee` is added on top. Total fee must be < 1e6.
4. **Plugin fee accounting** -- plugin fees accumulate in `pluginFeePending0/1` and are transferred to the plugin via `handlePluginFee()`.

**Source**: `/lib/Algebra/src/core/contracts/AlgebraPool.sol` (lines 395-412, 253-298)

### 1.3 Dynamic Fee Querying

The pool's `fee()` view function delegates to `IAlgebraDynamicFeePlugin(plugin).getCurrentFee()` when `DYNAMIC_FEE` is set. This provides a read-only path for external contracts to query the current volatility-adjusted fee.

**Source**: `/lib/Algebra/src/core/contracts/base/AlgebraPoolBase.sol` (lines 146-150)

### 1.4 Plugin Attachment

Plugins are set per-pool via `setPlugin(address)` (admin-permissioned). The plugin factory pattern (`IAlgebraPluginFactory`) auto-deploys plugins during pool creation. A plugin can also call `pool.setPluginConfig()` on itself to update its hook configuration dynamically.

---

## 2. Algebra Base Plugin: Volatility Oracle and Adaptive Fee (NOT in Repo)

The Algebra Base Plugin (package `@cryptoalgebra/integral-base-plugin`, repo `cryptoalgebra/integral-team-plugins`) implements three modules:
- **TWAP Oracle** (timepoints ring buffer)
- **Adaptive Fee** (sigmoid-based fee from volatility)
- **Farming Proxy**

### 2.1 TWAP Oracle -- Timepoints Ring Buffer

**Data Structure**: A ring buffer of `Timepoint` structs, indexed by a monotonically increasing counter. Each timepoint records:

```
struct Timepoint {
    bool initialized;
    uint32 blockTimestamp;
    int56 tickCumulative;         // cumulative tick for TWAP
    uint88 volatilityCumulative;  // cumulative volatility accumulator
    int24 averageTick;            // EMA of tick
    uint16 windowStartIndex;     // index of the oldest timepoint in the current averaging window
}
```

**Ring buffer size**: 65535 entries (uint16 index wrapping).

**Write trigger**: `beforeSwap` hook writes a new timepoint (at most once per block). The `afterInitialize` hook writes the first timepoint.

**Volatility accumulation**: The oracle computes tick variance over a sliding window. The `volatilityCumulative` field accumulates `(tick - averageTick)^2 * timeDelta`, giving an on-chain estimator of realized tick variance over time.

**TWAP computation**: Standard `tickCumulative` differencing over the window gives arithmetic mean tick, convertible to geometric mean price via `getSqrtRatioAtTick()`.

### 2.2 Adaptive Fee Sigmoid Model

The Algebra adaptive fee formula (from V1 audit code, confirmed in Integral docs):

```
fee = baseFee + sigmoid_vol(volatility) + sigmoid_volume(volumePerLiquidity)
```

Where each sigmoid is:

```
sigmoid(x, alpha, beta, gamma) = alpha / (1 + (gamma / x)^beta)
```

**Volatility sigmoid**: Uses `alpha1`, `beta1`, `gamma1` parameters. Input is the volatility estimate from the oracle (tick variance divided by 15, annualized).

**Volume sigmoid** (removed in Integral v2.0): Used `alpha2`, `beta2`, `gamma2`, `volumeBeta`, `volumeGamma`. This was deprecated in the Integral version -- the adaptive fee now depends only on volatility.

**Default parameters** (from AlgebraV1/QuickSwap audit):
- `baseFee`: 100 (0.01%)
- `alpha1`: 2900 (max volatility fee contribution ~0.29%)
- `alpha2`: 12000
- `beta1`: 360
- `beta2`: 60000
- `gamma1`: 59
- `gamma2`: 8500

### 2.3 Pipeline: Tick Observations --> Volatility Estimate --> Fee

```
[swap event]
    |
    v
beforeSwap() --> write timepoint(tick, timestamp)
    |
    v
compute volatility = sqrt(sum((tick_i - avgTick)^2 * dt_i) / totalTime)
    |
    v
scale: volatility_scaled = volatility / 15
    |
    v
apply sigmoid: fee_vol = alpha1 / (1 + (gamma1 / volatility_scaled)^beta1)
    |
    v
total fee = baseFee + fee_vol
    |
    v
return (overrideFee, pluginFee) to pool
```

---

## 3. Alternative Volatility Oracles in the Repo

### 3.1 Valorem/Aloe Implied Volatility Estimator (MOST RELEVANT)

**Location**: `/lib/valorem-oracles/src/libraries/Volatility.sol`

**Method**: Based on Guillaume Lambert's on-chain IV estimator (https://lambert-guillaume.medium.com/on-chain-volatility-and-uniswap-v3-d031b98143d1). Derives implied volatility from fee growth globals:

```
IV_24h = (2 * timeAdjustment * sqrt(volumeGamma0Gamma1)) / sqrtTickTVL
```

Where:
- `volumeGamma0Gamma1` = total trading volume (in token1 terms) over the measurement period, derived from `feeGrowthGlobal` deltas and `secondsPerLiquidity`
- `sqrtTickTVL` = sqrt of the TVL at the current tick
- `timeAdjustment` = sqrt(1 day / measurement_period) to annualize to 24h

**Data structures**:
- `FeeGrowthGlobals[25]` ring buffer per pool (25 hourly snapshots)
- `Indices { read, write }` for circular buffer management
- `PoolMetadata` caching `maxSecondsAgo`, `gamma0`, `gamma1`, `tickSpacing`

**Source**: `/lib/valorem-oracles/src/libraries/Volatility.sol` (lines 57-99)
**Oracle wrapper**: `/lib/valorem-oracles/src/UniswapV3VolatilityOracle.sol`

**Key advantage for IL hedging**: This estimator is ALREADY expressed as implied volatility in 1e18 scale, which maps directly to sigma in the IL formula. No additional transformation needed.

### 3.2 VolatilityHook-UniV4: SNARK-Verified Realized Volatility

**Location**: `/lib/VolatilityHook-UniV4/src/SnarkBasedVolatilityOracle.sol`

**Method**: Off-chain computation of realized volatility from Uniswap V3 tick data, verified on-chain via SP1 zero-knowledge proof. The oracle stores:
- `s`: standard deviation of tick returns (fixed-point, 40 fractional bits)
- `rv`: realized volatility = `s * ln(1.0001)` (converted from tick-log-base to natural-log-base)

**Fee computation**: `/lib/VolatilityHook-UniV4/src/Calc/CalcFeeLib.sol`
```
fee_per_lot = MIN_FEE + 2 * scaled_volume * (rv / LONG_ETH_VOL)^2
```
Fee is proportional to volume and quadratic in realized volatility, then converted to bips relative to price.

**Key advantage**: SNARK verification means the vol computation can be arbitrarily sophisticated off-chain (e.g., GARCH, stochastic vol models) while remaining trustless.

### 3.3 Voltaire: Cross-Chain Reactive Volatility Oracle

**Location**: `/lib/voltaire/src/VolatilityOracle.sol`

**Method**: Externally pushed annualized volatility (WAD format) from Reactive Network, aggregating TWAP prices across Ethereum, Arbitrum, Base, and BSC.

**Data structures**:
- `volatility`: current annualized vol in WAD (0.8e18 = 80%)
- `history[48]`: ring buffer of 48 historical observations
- `chainsMask`: bitmask of contributing chains
- `stalenessThreshold`: max acceptable data age (default 1 hour)

**Key advantage**: Multi-chain aggregation provides a more robust vol estimate for cross-chain pairs.

---

## 4. Extractability Assessment for IL Hedge Sizing

### 4.1 The Core Need

The IL hedge sizing algorithm needs:

```
sigma_est --> E[IL] --> hedge_ratio --> option legs at strike grid (K^{-3/2} weighting)
```

Where `sigma_est` is an annualized volatility estimate for the token pair.

### 4.2 Ranking of Available Vol Sources

| Source | On-chain? | Format | Update Freq | Extractability | Quality |
|--------|-----------|--------|-------------|----------------|---------|
| Valorem/Aloe IV | Yes (V3 only) | 1e18 IV | ~hourly | HIGH | Good (fee-based IV) |
| VolatilityHook SNARK | Hybrid | Fixed-point RV | Per-proof | MEDIUM | High (but needs off-chain prover) |
| Voltaire | External push | WAD annualized | ~hourly | HIGH | Good (multi-chain) |
| Algebra Adaptive Fee | Not in repo | Tick variance | Per-swap | LOW (not present) | Good (native to pool) |

### 4.3 Recommended Integration Path

**Primary**: Extract the Valorem `Volatility.estimate24H()` library and adapt it for use with Algebra pools or Uni V4 pools. The math is:

1. Read `feeGrowthGlobal0X128` and `feeGrowthGlobal1X128` from the target pool
2. Compute `revenue = delta(feeGrowthGlobal) * secondsAgo / secondsPerLiquidity`
3. Convert to volume using fee tier
4. Derive IV: `sigma = 2 * sqrt(volume / TVL) * sqrt(1 day / dt)`
5. Feed `sigma` into the Prop 3.5 decomposition:
   - `E[UIL_R]` (call-replicable component) depends on sigma
   - `E[UIL_L]` (put-replicable component) depends on sigma
   - Hedge ratio = sum of delta-weighted option legs

**Secondary**: For Uni V4 hooks, use `SnarkBasedVolatilityOracle` as it provides a more manipilation-resistant vol estimate (off-chain computation, on-chain verification).

**Fallback**: `voltaire/VolatilityOracle` for a simple, immediately available vol feed that can be used in testing.

### 4.4 Specific Code Reuse Opportunities

1. **`Volatility.sol` library** (`/lib/valorem-oracles/src/libraries/Volatility.sol`):
   - `estimate24H()` -- core IV estimator, ~40 lines of math
   - `computeRevenueGamma()` -- revenue from fee growth accumulators
   - `computeTickTVLX64()` -- TVL at current tick for normalization
   - These are pure functions, directly importable

2. **`Oracle.sol` library** (`/lib/valorem-oracles/src/libraries/Oracle.sol`):
   - `consult()` -- TWAP tick and secondsPerLiquidity from V3 oracle
   - `getMaxSecondsAgo()` -- available observation window depth

3. **Ring buffer pattern** from `UniswapV3VolatilityOracle.sol`:
   - `FeeGrowthGlobals[25]` with read/write indices
   - `_timingError()` for selecting the optimal 24h-ago snapshot
   - Directly applicable as vol state storage in a V4 hook

### 4.5 Adaptation for Algebra Pools

To use the Valorem IV estimator with Algebra pools instead of Uni V3:

| Uni V3 Source | Algebra Equivalent |
|---------------|-------------------|
| `pool.slot0()` -> `sqrtPriceX96, tick` | `pool.globalState()` -> `price, tick` |
| `pool.feeGrowthGlobal0X128()` | `pool.totalFeeGrowth0Token()` |
| `pool.feeGrowthGlobal1X128()` | `pool.totalFeeGrowth1Token()` |
| `pool.observe(secondsAgos)` | Not native; requires plugin TWAP oracle |
| `pool.liquidity()` | `pool.liquidity()` |
| `pool.fee()` | `pool.fee()` (delegates to plugin if dynamic) |

**Gap**: Algebra Integral removed the native TWAP oracle from the core pool. The `tickCumulative` and `secondsPerLiquidity` accumulators must come from the Base Plugin's timepoints array. If using Algebra pools, you need either:
- The Base Plugin deployed (provides `getTimepoints()`)
- A custom plugin that maintains its own TWAP accumulator
- An alternative approach that uses only fee growth globals (the Valorem method works with just fee growth deltas + current liquidity, no TWAP needed for the core estimator)

---

## 5. The Algebra Plugin Hook Architecture -- Integration Pattern

### 5.1 For a Custom IL Hedge Plugin on Algebra

A plugin implementing both vol oracle and hedge signaling:

```solidity
// Hooks needed:
uint8 constant CONFIG =
    BEFORE_SWAP_FLAG |       // write timepoint, compute vol
    AFTER_SWAP_FLAG |        // update fee growth snapshot
    AFTER_INIT_FLAG |        // initialize timepoint array
    DYNAMIC_FEE;             // return vol-adjusted fee

function beforeSwap(...) external returns (bytes4, uint24 overrideFee, uint24 pluginFee) {
    _writeTimepoint(tick, blockTimestamp);
    uint256 sigma = _estimateVolatility();
    uint24 fee = _adaptiveFee(sigma);
    // Could also emit sigma for off-chain hedge executor
    return (IAlgebraPlugin.beforeSwap.selector, fee, 0);
}
```

### 5.2 For a Uni V4 Hook (Primary Target)

Since the project targets Uni V4 hooks, the Algebra plugin pattern translates as:

| Algebra Plugin | Uni V4 Hook |
|----------------|-------------|
| `beforeSwap()` returns `(selector, overrideFee, pluginFee)` | `beforeSwap()` returns `(selector, BeforeSwapDelta, uint24)` + `poolManager.updateDynamicLPFee()` |
| `afterSwap()` | `afterSwap()` |
| `afterInitialize()` | `afterInitialize()` |
| `setPluginConfig()` on pool | Hook permissions set at deployment via address mining |
| `plugin` address stored in pool state | Hook address encoded in pool key |

---

## 6. Sliding Fee Plugin (Newer Algebra Approach)

Per Algebra documentation, a "Sliding Fee" plugin was introduced as an alternative to the adaptive fee. Key differences:

- **No sigmoid**: Uses a simpler directional fee model
- **Asymmetric fees**: Different fees for zeroToOne vs oneToZero swaps
- **Price-impact based**: Fee scales with how far price moves from a reference point
- **15% efficiency improvement** claimed over adaptive fee

The sliding fee plugin is relevant because it shows Algebra moving toward simpler, more gas-efficient fee models. For IL hedging purposes, the sliding fee approach is less useful because it does not directly expose a volatility estimate -- it is reactive to instantaneous price impact rather than historical volatility.

---

## 7. Data Structures Summary

### 7.1 Algebra Core (in repo)

```
GlobalState (1 slot):
    uint160 price          // sqrtPriceX96
    int24   tick
    uint16  lastFee        // current fee in 1e-6
    uint8   pluginConfig   // hook bitmap
    uint16  communityFee
    bool    unlocked

Per-tick:
    TickManagement.Tick:
        uint256 liquidityTotal
        int128  liquidityDelta
        int24   prevTick, nextTick
        uint256 outerFeeGrowth0Token, outerFeeGrowth1Token

Pool-level accumulators:
    uint256 totalFeeGrowth0Token  // Q128.128 cumulative fee/liquidity
    uint256 totalFeeGrowth1Token
    uint128 liquidity             // active liquidity at current tick
```

### 7.2 Algebra Base Plugin (not in repo, reconstructed)

```
Timepoint (ring buffer, 65535 entries):
    bool    initialized
    uint32  blockTimestamp
    int56   tickCumulative
    uint88  volatilityCumulative    // KEY: sum((tick-avgTick)^2 * dt)
    int24   averageTick             // EMA of tick
    uint16  windowStartIndex

AdaptiveFee.Configuration:
    uint16 alpha1, alpha2           // sigmoid amplitudes
    uint32 beta1, beta2             // sigmoid steepness
    uint16 gamma1, gamma2           // sigmoid midpoints
    uint16 baseFee
```

### 7.3 Valorem/Aloe (in repo, most useful)

```
Volatility.FeeGrowthGlobals (ring buffer, 25 entries per pool):
    uint256 feeGrowthGlobal0X128
    uint256 feeGrowthGlobal1X128
    uint32  timestamp

Volatility.PoolMetadata (cached per pool):
    uint32 maxSecondsAgo
    uint24 gamma0, gamma1          // fee net of protocol fee
    int24  tickSpacing

Indices { uint8 read, uint8 write }
```

---

## 8. Recommendations and Next Steps

### 8.1 Immediate Actions

1. **Import the Valorem `Volatility.sol` and `Oracle.sol` libraries** into the project as utility libraries. These provide a production-tested, audit-reviewed IV estimator that works with Uniswap V3 fee growth globals.

2. **Build a V4 hook adapter** that maintains a `FeeGrowthGlobals[25]` ring buffer (mirroring the Valorem pattern) and exposes `getImpliedVolatility()` as a view function consumable by the Hedge Builder.

3. **Wire vol output to hedge sizing**: The vol estimate (in 1e18 annualized) feeds directly into:
   ```
   sigma = getImpliedVolatility(pool)
   E[IL] = f(sigma, tickLower, tickUpper, dt)   // from Prop 3.5
   hedgeLegs = discretize(E[IL], strikeGrid, K^{-3/2})
   ```

### 8.2 Medium-Term

4. **Consider the SNARK oracle** (`VolatilityHook-UniV4/SnarkBasedVolatilityOracle.sol`) for manipulation resistance. The Valorem approach is based on fee growth which can be manipulated via targeted swaps. The SNARK approach computes vol off-chain from a larger dataset and verifies on-chain.

5. **Add the Algebra Base Plugin** as a submodule (`cryptoalgebra/integral-team-plugins`) if Algebra pool integration is needed. The timepoints-based volatility accumulator provides a different (complementary) vol signal.

6. **Evaluate the Voltaire cross-chain oracle** for multi-venue vol aggregation, particularly for major pairs where single-pool vol estimates may be noisy.

### 8.3 Mathematical Connection: Vol --> IL --> Hedge

For a concentrated LP position [tickLower, tickUpper] with current tick t0:

```
sigma_annual = getImpliedVolatility(pool)    // from Valorem estimator
sigma_dt = sigma_annual * sqrt(dt / 365.25)  // scale to holding period

// Prop 3.5 (Deng-Zong-Wang) decomposition:
UIL_R(K) = -integral_{K_lower}^{K_upper} Call(S, K) * K^{-3/2} dK   // call-replicable
UIL_L(K) = -integral_{K_lower}^{K_upper} Put(S, K) * K^{-3/2} dK    // put-replicable

// Discretized hedge at strike grid {K_i}:
leg_i = weight(K_i) * sigma_dt * f(S/K_i)   // option quantity at strike K_i
```

The vol estimate is the critical input that determines BOTH the expected IL magnitude AND the Black-Scholes-style delta/gamma of each hedge leg.

---

## 9. Key File References

| File | Purpose | Relevance |
|------|---------|-----------|
| `/lib/Algebra/src/core/contracts/libraries/Plugins.sol` | Hook flag constants | Plugin architecture |
| `/lib/Algebra/src/core/contracts/interfaces/plugin/IAlgebraPlugin.sol` | Full plugin interface | Hook signatures |
| `/lib/Algebra/src/core/contracts/interfaces/plugin/IAlgebraDynamicFeePlugin.sol` | Dynamic fee query | Fee delegation |
| `/lib/Algebra/src/core/contracts/AlgebraPool.sol` | Pool with plugin calls | Fee injection path |
| `/lib/Algebra/src/core/contracts/base/SwapCalculation.sol` | Swap math with fee | How overrideFee is applied |
| `/lib/Algebra/src/core/contracts/base/AlgebraPoolBase.sol` | GlobalState struct, fee() | State layout |
| `/lib/valorem-oracles/src/libraries/Volatility.sol` | Aloe IV estimator | **PRIMARY vol source** |
| `/lib/valorem-oracles/src/libraries/Oracle.sol` | TWAP helper | Supports vol estimator |
| `/lib/valorem-oracles/src/UniswapV3VolatilityOracle.sol` | Full oracle with ring buffer | Reference implementation |
| `/lib/VolatilityHook-UniV4/src/SnarkBasedVolatilityOracle.sol` | ZK-verified RV | Manipulation-resistant alt |
| `/lib/VolatilityHook-UniV4/src/Calc/CalcFeeLib.sol` | Vol-to-fee math | Fee computation pattern |
| `/lib/voltaire/src/VolatilityOracle.sol` | Cross-chain vol oracle | Multi-venue aggregation |

---

## 10. Sources

- [Algebra Adaptive Fee Documentation](https://docs.algebra.finance/algebra-integral-documentation/algebra-integral-technical-reference/plugins/adaptive-fee)
- [Algebra Plugin Overview](https://docs.algebra.finance/algebra-integral-documentation/algebra-integral-technical-reference/plugins/overview)
- [Algebra Plugin Development Guide](https://docs.algebra.finance/algebra-integral-documentation/algebra-integral-technical-reference/guides/plugin-development)
- [cryptoalgebra/integral-team-plugins (Base Plugin source)](https://github.com/cryptoalgebra/integral-team-plugins)
- [cryptoalgebra/IntegralFeeSimulation](https://github.com/cryptoalgebra/IntegralFeeSimulation)
- [Algebra Integral Plugins Technical Overview (Medium)](https://medium.com/@crypto_algebra/algebra-integral-plugins-technical-overview-315e6e7bc72f)
- [Dynamic Fees vs. Sliding Fee Mechanism (Medium)](https://medium.com/@crypto_algebra/dynamic-fees-vs-sliding-fee-mechanism-in-algebra-powered-amms-26b65b8249aa)
- [The Sliding Fee Plugin (Medium)](https://medium.com/@crypto_algebra/the-sliding-fee-plugin-for-algebra-integral-new-calculation-approach-with-15-efficiency-3b350fc7c0db)
- [Guillaume Lambert: On-chain Volatility and Uniswap V3](https://lambert-guillaume.medium.com/on-chain-volatility-and-uniswap-v3-d031b98143d1)
- [QuickSwap/Algebra V1 Code4rena Audit](https://github.com/code-423n4/2022-09-quickswap)
- [MixBytes Base Plugin Audit](https://github.com/mixbytes/audits_public/blob/master/Algebra%20Finance/Plugins/README.md)
