# Tempest Library Analysis

**Date:** 2026-03-29
**Repository:** `lib/tempest` (submodule, by Fabrknt)
**Purpose:** Assess Tempest's volatility-responsive dynamic fee hook for reusable components in our LP risk hedging project (IL Oracle, Hedge Builder, dynamic fee infrastructure).

---

## Executive Summary

Tempest is a well-structured Uniswap V4 dynamic fee hook that computes **annualized realized volatility from tick observations** and maps it to swap fees via piecewise linear interpolation. Its architecture cleanly separates three concerns into independent libraries -- tick observation storage, volatility computation, and fee curve mapping -- making selective extraction feasible.

**Key finding:** The `VolatilityEngine` library is directly extractable for IL oracle use. Its realized-vol computation from tick deltas is precisely the sigma input needed for Prop 3.5's IL decomposition into calls/puts. The EWMA smoothing (7d, 30d half-lives) and regime classification provide the volatility regime signal the Hedge Builder needs for strike grid discretization.

**Overall assessment:** High-quality production code with comprehensive tests (7 test files, ~50 test cases, fuzz tests, gas benchmarks, full lifecycle scenarios). The three-library architecture is modular enough for selective integration.

---

## 1. Repository Structure

```
lib/tempest/
  contracts/
    src/
      TempestHook.sol              -- Main hook contract (IHooks implementation)
      libraries/
        TickObserver.sol           -- Circular buffer for tick observations
        VolatilityEngine.sol       -- Realized vol computation + regime detection
        FeeCurve.sol               -- Piecewise linear vol-to-fee mapping
    test/
      TempestHook.t.sol            -- Unit tests for hook
      Integration.t.sol            -- Full lifecycle integration tests
      Scenario.t.sol               -- Multi-phase scenario tests
      Failsafe.t.sol               -- Staleness, dust filter, momentum tests
      VolatilityEngine.t.sol       -- Vol computation unit tests + fuzz
      TickObserver.t.sol           -- Ring buffer unit tests + fuzz
      FeeCurve.t.sol               -- Fee interpolation unit tests
      utils/TempestTestBase.sol    -- Shared test harness
    script/
      DeployTempest.s.sol          -- CREATE2 deployment script
  apps/
    keeper/                        -- TypeScript keeper service
    dashboard/                     -- Next.js monitoring dashboard
  packages/
    core/                          -- Chain-agnostic SDK types
    evm/                           -- EVM adapter (viem-based)
    solana/                        -- Solana adapter
    qn-addon/                      -- QuickNode add-on integration
```

---

## 2. Volatility Computation Methodology

**File:** `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/src/libraries/VolatilityEngine.sol`

### 2.1 Core Insight

Tempest exploits the fact that Uniswap V4 ticks are `log_1.0001(price)`, which means **tick differences are already log returns**. This eliminates all division for return computation -- a significant gas optimization.

### 2.2 Realized Vol Algorithm (`computeRealizedVol`, lines 59-100)

The algorithm computes **time-weighted annualized realized volatility**:

1. For each consecutive pair of observations (tick_i, t_i) and (tick_{i-1}, t_{i-1}):
   - delta = tick_i - tick_{i-1} (this IS the log return in bps)
   - dt = t_i - t_{i-1}
   - Skip zero-time intervals
   - Accumulate: `sumSq += (delta^2 * 1e18) / dt` (per-second variance, scaled by 1e18)

2. Average per-second variance: `variancePerSecond = sumSq / validPairs`

3. Annualize: `varianceAnnual = variancePerSecond * SECONDS_PER_YEAR` (365.25 days)

4. Convert to bps: `volBps = sqrt(varianceAnnual) / 1e9`

The 1e18 scaling factor preserves precision through the integer division by dt, and is removed via dividing by sqrt(1e18) = 1e9 after the square root.

### 2.3 EWMA Smoothing (`updateEMA`, lines 119-138)

Two exponential moving averages smooth the raw realized vol:

- **7-day EMA** (half-life: 604800s) -- used for momentum detection
- **30-day EMA** (half-life: 2592000s) -- used for elevation/depression detection

The alpha approximation uses: `weight = min(elapsed * 693 / halfLife, 1000)` where 693 approximates ln(2) * 1000. This is a first-order Taylor approximation of `1 - 0.5^(elapsed/halfLife)` that works well for `elapsed << halfLife` and clamps to full weight for `elapsed >= 1.44 * halfLife`.

### 2.4 Regime Classification (`classifyRegime`, lines 105-111)

Five discrete regimes based on annualized vol in bps:

| Regime   | Threshold (bps) | Annualized |
|----------|----------------|------------|
| VeryLow  | 0-2000         | < 20%      |
| Low      | 2001-3500      | 20-35%     |
| Normal   | 3501-5000      | 35-50%     |
| High     | 5001-7500      | 50-75%     |
| Extreme  | > 7500         | > 75%      |

### 2.5 Auxiliary Functions

- `isElevated(state)`: returns true when `currentVol > 1.5 * ema30d`
- `isDepressed(state)`: returns true when `currentVol < 0.5 * ema30d`
- `sqrt(x)`: Babylonian integer square root (lines 186-194)

---

## 3. Hook Callbacks and Uni V4 Integration Pattern

**File:** `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/src/TempestHook.sol`

### 3.1 Hook Permissions (constructor, lines 91-109)

Three callbacks are enabled:

| Callback          | Bit Flag               | Purpose                                    |
|-------------------|------------------------|--------------------------------------------|
| `afterInitialize` | bit 12 (0x1000)        | Register pool, seed observation buffer      |
| `beforeSwap`      | bit 7 (0x0080)         | Return dynamic fee (vol-based + momentum)  |
| `afterSwap`       | bit 6 (0x0040)         | Record tick observation (with dust filter) |

No liquidity hooks or return-delta hooks are used. The hook does NOT intercept liquidity operations.

### 3.2 afterInitialize (lines 126-145)

- Validates pool uses `DYNAMIC_FEE_FLAG`
- Initializes `PoolState` with default `FeeConfig`
- Seeds the observation buffer with the initial tick
- Emits `PoolRegistered`

### 3.3 beforeSwap (lines 147-180)

Fee determination logic:

1. If no vol state yet: return default 30 bps
2. If keeper is stale (`elapsed > staleFeeThreshold`): return cap fee (500 bps) -- **fail-safe**
3. Otherwise: `FeeCurve.getFee(config, currentVol)` + momentum boost
4. Returns fee with `OVERRIDE_FEE_FLAG` set (overrides pool's base fee)

### 3.4 afterSwap (lines 182-210)

- **Dust filter**: if `minSwapSize[poolId] > 0`, skips observation when `abs(delta.amount0) < minSwapSize`
- Reads current tick via `manager.getSlot0(poolId)`
- Records `(tick, timestamp)` into the circular buffer

### 3.5 Keeper-Driven Architecture

The `updateVolatility(PoolId)` function (lines 216-256) is callable by anyone (permissionless keeper):

1. Enforces `minUpdateInterval` (default 300s) between updates
2. Reads up to 256 most recent observations from the buffer
3. Calls `VolatilityEngine.updateVolState(...)` which computes vol, classifies regime, updates EMAs
4. Writes the new `VolState` to storage
5. Pays the caller a dynamic ETH reward: `base + gasOverhead * gasprice * (1 + premiumBps/10000)`

---

## 4. Fee Adjustment Algorithm (Vol to Fee Mapping)

**File:** `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/src/libraries/FeeCurve.sol`

### 4.1 Piecewise Linear Interpolation

The `FeeConfig` struct defines 6 control points `(vol_bps, fee_bps)` with strictly increasing vol values. `getFee` performs linear interpolation between adjacent points.

Default configuration:

| Vol (bps) | Fee (bps) | Meaning                  |
|-----------|-----------|--------------------------|
| 0         | 5         | Floor: 0.05%             |
| 2000      | 10        | At 20% vol: 0.10%       |
| 3500      | 30        | At 35% vol: 0.30%       |
| 5000      | 60        | At 50% vol: 0.60%       |
| 7500      | 150       | At 75% vol: 1.50%       |
| 15000     | 500       | Cap at 150% vol: 5.00%  |

Below vol0: floor fee. Above vol5: cap fee. Between any two points: linear interpolation.

### 4.2 Momentum Boost (`_applyMomentum`, TempestHook.sol lines 348-364)

When `currentVol > ema7d`, the fee is boosted:

```
ratio = min(currentVol * 100 / ema7d, 200)
boost = baseFee * (ratio - 100) / 200
fee = min(baseFee + boost, maxFee)
```

At 2x the 7-day EMA, the fee is boosted by 50%. Capped at `fee5` (500 bps).

### 4.3 Fail-Safe Escalation

If `block.timestamp - lastUpdate > staleFeeThreshold` (default 3600s), `beforeSwap` returns `feeConfig.fee5` (cap fee) regardless of stored vol. This protects LPs when the keeper is offline.

---

## 5. Extractability Assessment for IL Oracle

### 5.1 VolatilityEngine -- DIRECTLY EXTRACTABLE

The `VolatilityEngine` library is a pure library with no external dependencies beyond its own types. It can be imported and used as-is.

**What it provides for our IL Oracle:**

- **`computeRealizedVol(ticks, timestamps, count)`**: This is the sigma input for Prop 3.5. The annualized realized vol in bps is exactly what we need for the Black-Scholes-style IL decomposition.

- **`updateEMA(currentEma, newValue, elapsed, halfLife)`**: The 7d and 30d EMAs provide mean-reversion signals. For IL hedging, comparing instantaneous vol to the EMA tells us whether we're in a vol spike (hedges are more expensive but more needed) or a lull.

- **`classifyRegime(volBps)`**: Regime classification maps directly to hedge aggressiveness. In the Hedge Builder, the regime could determine:
  - Strike grid density (tighter spacing in Normal/High regimes)
  - Hedge ratio (delta coverage percentage)
  - Rebalance urgency

- **`isElevated(state)` / `isDepressed(state)`**: These are ready-made signals for the Hedge Builder to decide when to increase/decrease hedge coverage.

### 5.2 TickObserver -- EXTRACTABLE WITH MODIFICATIONS

The circular buffer is well-optimized (4 observations per storage slot, 1024 capacity) but has a fixed size. For the IL Oracle, we may want:

- Different buffer sizes per pool (configurable)
- Longer observation windows (1024 at 15s intervals = ~4.3 hours; for 7-day vol we need historical data)
- Possibly sampling at fixed intervals rather than per-swap

**However**, the `getRange()` function is immediately useful for feeding tick history to the vol engine.

### 5.3 FeeCurve -- PATTERN EXTRACTABLE

The piecewise linear interpolation pattern is useful as a template for mapping vol to hedge parameters (strike width, notional sizing) but the specific fee control points are Tempest-specific.

### 5.4 Integration Pattern

The keeper-driven architecture (accumulate observations on-chain, compute vol off-chain/on-chain periodically) is the same pattern our IL Oracle needs:

1. `afterSwap` records ticks (Tempest does this)
2. Keeper calls `updateVolatility` periodically (reusable pattern)
3. Our IL Oracle would additionally compute per-position UIL^R and UIL^L using the vol output

**Key difference**: Tempest computes pool-level vol. Our IL Oracle needs per-position IL, which requires the position's tick range (tickLower, tickUpper) in addition to the pool's current tick and vol.

---

## 6. Novel Patterns and Techniques

### 6.1 Packed Circular Ring Buffer (TickObserver)

**File:** `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/src/libraries/TickObserver.sol`

The observation buffer packs **4 observations per 256-bit storage slot**:

- Each observation: 56 bits = 24-bit tick (int24 stored as uint24) + 32-bit timestamp
- 4 observations x 56 bits = 224 bits per slot (32 bits spare)
- 1024 observations / 4 per slot = 256 storage slots
- Circular with saturating count

Write operation (lines 30-52):
1. Compute slot index and observation index within slot
2. Load slot, clear target 56-bit segment via bitmask, write new packed value
3. Advance head pointer modulo 1024
4. Increment count (saturates at BUFFER_SIZE)

This is a gas-efficient pattern: warm-slot writes for 3 out of every 4 observations (~5,200 gas per write per README).

### 6.2 Time-Weighted Variance (VolatilityEngine)

Rather than computing simple variance of tick deltas (which would be biased by observation frequency), Tempest normalizes each squared return by its time interval:

```
per_second_variance_contribution = delta^2 / dt
```

Then averages across all pairs and annualizes. This correctly handles irregular observation spacing, which is critical since swaps arrive at random times.

### 6.3 EMA Approximation

The `updateEMA` function (VolatilityEngine lines 119-138) approximates exponential decay using a first-order linear approximation:

```
alpha = min(elapsed * ln(2) / halfLife, 1.0)
```

Where `ln(2) * 1000 = 693` is used as a fixed-point constant. This avoids exponentiation on-chain while providing reasonable accuracy for typical update frequencies (minutes to hours vs. days of half-life).

### 6.4 Momentum Fee Adjustment

The `_applyMomentum` function (TempestHook lines 348-364) adds a forward-looking component to the backward-looking realized vol by comparing instantaneous vol to its 7-day EMA. This partially addresses the lag inherent in realized vol measurement -- a technique directly applicable to IL hedge sizing.

### 6.5 Permissionless Keeper with Dynamic Rewards

The keeper reward formula `base + gasOverhead * gasprice * (1 + premium)` ensures keeper profitability at any gas price level. This pattern is reusable for our IL Oracle's keeper.

---

## 7. Code Quality and Test Coverage

### 7.1 Source Code Quality

**Strengths:**
- Clean library separation (TickObserver, VolatilityEngine, FeeCurve are fully independent)
- All libraries are `internal pure` or `internal view` -- no external calls, no reentrancy surface
- Comprehensive NatSpec documentation on all public/external functions
- Explicit error types (no generic reverts)
- Gas-conscious design (packed storage, pure computations, minimal storage reads in hot path)
- Fail-safe defaults (30 bps default fee, cap fee on staleness)

**Concerns:**
- The `sqrt` function (Babylonian method) is not optimized -- could use Solmate's or PRB Math's version
- The EMA approximation diverges from true exponential for large `elapsed/halfLife` ratios, though it clamps to prevent overflow
- Buffer size (1024) is hardcoded -- not configurable per pool
- The `getRange` function copies observations to memory in a loop, which is O(n) gas for large ranges; the 256-sample cap in `updateVolatility` mitigates this

### 7.2 Test Coverage

**7 test files, approximately 50+ test cases:**

| File                    | Focus                                      | Notable Tests                              |
|-------------------------|--------------------------------------------|--------------------------------------------|
| `VolatilityEngine.t.sol`| Vol computation, EMA, regime, sqrt         | Fuzz test on sqrt, convergence test on EMA |
| `TickObserver.t.sol`    | Ring buffer CRUD, wrapping, packing        | Fuzz on record/retrieve, gas benchmarks    |
| `FeeCurve.t.sol`        | Interpolation, boundaries, monotonicity    | Monotonicity sweep, gas benchmark          |
| `TempestHook.t.sol`     | Deployment, governance, access control     | Flag validation, ACL tests                 |
| `Integration.t.sol`     | Full lifecycle, pool registration, vol     | Keeper reward payout, fee after vol update |
| `Scenario.t.sol`        | Multi-phase scenarios                      | Keeper failure/recovery, gas price scaling |
| `Failsafe.t.sol`        | Staleness, dust filter, momentum           | Dust attack mitigation, stale recovery     |

**Quality indicators:**
- Edge cases tested (zero movement, zero time intervals, buffer wrap-around, min/max int24)
- Fuzz tests present (sqrt, tick round-trip)
- Gas benchmarks (TickObserver record, FeeCurve getFee)
- Multi-phase scenario tests simulate real operational conditions
- Access control tested for all governance functions

**Missing coverage:**
- No invariant/stateful fuzz tests
- No tests for negative tick encoding edge cases beyond min/max
- No formal verification annotations
- The `_applyMomentum` function is tested indirectly through Failsafe.t.sol but lacks isolated unit tests

---

## 8. Recommendations for Integration

### 8.1 Immediate Reuse (Copy or Import)

1. **`VolatilityEngine.sol`** -- Import directly. Use `computeRealizedVol` as the sigma oracle for Prop 3.5 IL decomposition. The library has zero dependencies.

2. **`VolatilityEngine.VolState` struct** -- Use as the basis for our per-pool vol state. Extend with position-level IL fields.

3. **EWMA and regime classification** -- Use directly for Hedge Builder's strike grid density and hedge ratio decisions.

### 8.2 Adapt and Extend

1. **`TickObserver.sol`** -- Use as a template but consider:
   - Making buffer size configurable (template parameter or constructor arg)
   - Adding a `getLatestN()` function that returns the N most recent observations without computing logical offsets (optimization for the common case)
   - For 7-day vol windows at 15s observation rate, we need ~40,320 observations; the current 1024 buffer is insufficient. Either increase the buffer or compute vol off-chain from events.

2. **`FeeCurve.sol`** -- Adapt the piecewise linear pattern for a **vol-to-hedge-parameter curve** that maps realized vol to:
   - Strike grid spacing (in ticks)
   - Hedge notional as fraction of position value
   - Rebalance threshold

3. **Keeper pattern** -- Reuse the `minUpdateInterval` + dynamic reward pattern for our IL Oracle's keeper. Add: triggering hedge rebalances when vol regime changes.

### 8.3 What Tempest Does NOT Provide

1. **Per-position IL computation** -- Tempest is pool-level only. Our IL Oracle must extend with position-specific `(tickLower, tickUpper)` and compute UIL^R and UIL^L per-position.

2. **Options integration** -- No Panoptic awareness. The fee output is a swap fee, not a hedge parameter.

3. **Tick accumulator integration** -- Tempest records raw ticks, not Uni V4's built-in tick accumulators. For longer observation windows, we may want to leverage V4's native oracle infrastructure rather than maintaining a separate buffer.

4. **Cross-pool correlation** -- Tempest treats each pool independently. For hedging a portfolio of LP positions, we would need cross-pool vol correlation, which is out of scope for Tempest.

### 8.4 Architecture Sketch: Tempest Components in Our System

```
                    Tempest Components (reuse)         Our Extensions
                    -------------------------         ---------------
afterSwap -------> TickObserver.record()
                        |
                        v
keeper ----------> VolatilityEngine.computeRealizedVol()
                        |
                        v
                   VolatilityEngine.updateEMA()  --> ILOracle.computeUIL(vol, tickLower, tickUpper)
                   VolatilityEngine.classifyRegime()      |
                        |                                  v
                        v                          HedgeBuilder.discretize(uil, regime)
                   FeeCurve.getFee() [for fees]            |
                                                           v
                                                    Panoptic settlement
```

---

## 9. Specific File References

| Component | File | Key Lines | Extractable? |
|-----------|------|-----------|--------------|
| Vol computation | `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/src/libraries/VolatilityEngine.sol` | 59-100 | Yes, as-is |
| EWMA update | Same file | 119-138 | Yes, as-is |
| Regime classification | Same file | 105-111 | Yes, as-is |
| Ring buffer | `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/src/libraries/TickObserver.sol` | 30-52 (write), 59-81 (read) | Yes, with size adaptation |
| Fee interpolation | `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/src/libraries/FeeCurve.sol` | 32-57 | Pattern reusable |
| Momentum boost | `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/src/TempestHook.sol` | 348-364 | Reusable for hedge urgency signal |
| Keeper reward | Same file | 332-336 | Pattern reusable |
| Stale fail-safe | Same file | 158-163 | Pattern reusable for oracle liveness |
| Dust filter | Same file | 193-201 | Directly reusable |
| Hook integration | Same file | 91-109 (permissions), 126-210 (callbacks) | Reference for our hook design |
| Test harness | `/home/jmsbpp/apps/liq-soldk-dev/lib/tempest/contracts/test/utils/TempestTestBase.sol` | All | Template for our test setup |

---

## 10. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| EMA approximation diverges for long gaps | Medium | Clamp at weight=1000 already present; add explicit handling for gaps > 7 days |
| 1024-entry buffer insufficient for 7d vol window | High | Either expand buffer, use V4 native oracles, or compute off-chain from events |
| `sqrt` not optimized | Low | Replace with Solmate/PRBMath sqrt if gas-sensitive |
| Tick encoding: int24 stored as uint24 | Low | Two's complement preserved; tested at boundaries |
| No formal verification | Medium | Critical for production; consider Certora or Halmos for vol engine |
| Keeper centralization risk | Medium | Permissionless design mitigates; but incentive alignment needs monitoring |

---

## 11. Conclusion

Tempest provides a high-quality, battle-tested volatility oracle implementation that directly serves our project's needs. The `VolatilityEngine` library is the most valuable component -- it gives us a gas-efficient, on-chain realized vol computation that can serve as the sigma input for Prop 3.5's IL decomposition. The EWMA smoothing, regime classification, and momentum detection are immediately applicable to the Hedge Builder's decision logic.

The primary gap is that Tempest operates at pool level, while our IL Oracle requires per-position granularity. The recommended integration path is to import `VolatilityEngine` as-is for pool-level vol, then build position-level IL computation on top using the position's tick range and the pool vol as inputs.
