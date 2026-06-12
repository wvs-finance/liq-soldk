# Analysis: scab24/univ4-risk-neutral-hook

## Contribution Assessment for IL Oracle / Hedge Builder Pipeline

---

## Executive Summary

The risk-neutral-hook (scab24) is a Uniswap V4 hook implementing dynamic fee adjustment and a volatility oracle. Its core value to this project lies in (1) the on-chain implied volatility computation via the Daniel Alcarraz formula, (2) the Welford online variance estimator for realized volatility, and (3) a concrete reference for `beforeSwap`/`afterSwap` dynamic fee architecture on V4. However, it does **not** compute IL decomposition, K^{-3/2} weighting, hedge ratios, or option greeks. It is a PoC-grade codebase with significant incompleteness (commented-out tests, placeholder pool addresses, unreachable code paths), but several mathematical primitives and architectural patterns can be extracted and adapted.

**Bottom line**: The hook provides a **volatility layer** that feeds into the Hedge Builder's sigma requirement, but contributes nothing to the IL Oracle or strike-grid construction. Its vol oracle + dynamic fee architecture is the extractable value.

---

## 1. Repository Structure

```
lib/risk-neutral-hook/
  src/
    Hook/univ4-risk-neutral-hook.sol        -- Main hook contract (684 lines)
    Math/implied volatility_solidity.sol     -- VolatilityCalculator (active)
    Math/implied volatility_backend.sol      -- Backend version (entirely commented out)
  test/
    univ4-risk-neutral-hook.t.sol            -- Test file (entirely commented out)
  lib/
    abdk-libraries-solidity/                 -- ABDKMath64x64 fixed-point
    chainlink-brownie-contracts/             -- Chainlink AggregatorV3Interface
    v4-core/, v4-periphery/                  -- Uniswap V4
```

**Solidity version**: 0.8.26 (Cancun EVM)
**Fixed-point**: ABDKMath64x64 (signed 64.64 fixed-point, int128)
**External dependencies**: Chainlink oracles (IV, RV, price, liquidity, volume), OpenZeppelin Ownable

---

## 2. Volatility Oracle / IV Computation Methodology

### 2.1 The Alcarraz Implied Volatility Formula

The central mathematical contribution is the on-chain IV extraction from LP pool returns. The formula implemented is:

```
sigma = sqrt( (8/t) * [mu_pool * t - ln(cosh(u * t / 2))] )
```

Where:
- `mu_pool` = mean return of pool fees over time t (drift from fee income)
- `u` = risk-neutral drift of the underlying asset
- `t` = time in years
- `sigma` = implied volatility

This is the formula derived by Daniel Alcarraz for extracting the implied volatility "priced" by an AMM from the relationship between pool fee returns and underlying asset drift.

**Location**: `/lib/risk-neutral-hook/src/Hook/univ4-risk-neutral-hook.sol`, lines 615-637 (`computeSigma`) and lines 588-612 (`computeImpliedVolatilityAndDriftIterative`).

### 2.2 Iterative Convergence Scheme

The IV and drift are coupled (sigma depends on u, u depends on sigma), so the hook uses a fixed-point iteration:

```
1. Initialize u = mu_pool
2. Compute sigma = f(mu_pool, u, t)        -- via the Alcarraz formula
3. Recompute u = mu_pool - sigma^2/2       -- drift = mu - sigma^2/2 (GBM)
4. Check |u_new - u_old| < tolerance
5. Repeat up to maxIterations (default: 10)
```

**Location**: Lines 588-612, `computeImpliedVolatilityAndDriftIterative()`

**Tolerance**: 1e-6 in 64.64 fixed-point.

### 2.3 Realized Volatility (Welford Online Estimator)

The `VolatilityCalculator` contract maintains an **online** (streaming) variance estimate using Welford's algorithm:

```
For each new log-return r_i:
  count++
  delta = r_i - mean
  mean += delta / count
  delta2 = r_i - mean    (note: using updated mean)
  M2 += delta * delta2

Variance = M2 / (count - 1)
Sigma_realized = sqrt(variance) * sqrt(252)   -- annualized
```

**Location**: `/lib/risk-neutral-hook/src/Math/implied volatility_solidity.sol`, lines 187-205 (`_addLogReturn_internal`)

The annualization factor `sqrt(252)` is approximated as `15 + 87401/100000 = 15.87401` (line 223).

### 2.4 Log-Return Computation

Log returns are computed from price ratios using a **Taylor series approximation** for `ln(x)`:

```
ln(x) = z - z^2/2 + z^3/3 - z^4/4 + ...   (6 terms)
```

Where `x` is first normalized to `[0.5, 1.5]` by factoring out powers of 2 (lines 76-138, `approximateLn()`).

This is used instead of `ABDKMath64x64.ln()` in some paths. The `naturalLog()` function wrapping `ABDKMath64x64.ln()` also exists. The backend version (commented out) uses `naturalLog` directly.

### 2.5 Supporting Math Functions

- `cosh(x) = (e^x + e^{-x}) / 2` -- hyperbolic cosine, lines 44-51
- `sqrt(x)` -- delegated to ABDKMath64x64.sqrt()
- All math in ABDKMath64x64 signed 64.64 fixed-point (int128)

---

## 3. Dynamic Fee Mechanism

### 3.1 Fee Computation Architecture

The fee is computed in `beforeSwap` and applied via `poolManager.updateDynamicLPFee()`. It uses the `LPFeeLibrary.DYNAMIC_FEE_FLAG` pattern (the pool must be initialized with this flag).

**Constants**:
- `BASE_FEE = 3000` (0.3%)
- `MAX_FEE = 10000` (1.0%)
- `MIN_FEE = 500` (0.05%)

### 3.2 Fee Adjustment Factors

The fee is a multiplicative composition of five adjustments applied sequentially to the base fee:

| Factor | Condition | Multiplier |
|---|---|---|
| **Volatility** | Always | `fee * (10000 + vol) / 10000` |
| **Volume (high)** | volume > 300k tokens | fee * 90% (discount) |
| **Volume (low)** | volume < 100k tokens | fee * 110% (surcharge) |
| **Swap size** | abs(amount) > maxSwapSize/2 | fee * 120% |
| **Liquidity** | liquidity < 100k tokens | fee * 150% |
| **Gas price (high)** | gasPriceDiff > 20% and gas > EMA | fee * 80% |
| **Gas price (low)** | gasPriceDiff > 20% and gas < EMA | fee * 120% |

**Location**: Lines 326-370, `calculateCustomFee()`

### 3.3 Post-Swap Adjustment

In `afterSwap`, a post-hoc adjustment is computed from:
- Gas price delta (current vs. initial)
- Slippage (actual vs. specified amount, at 0.1% factor)
- Volatility change during the swap
- Liquidity change during the swap

**Location**: Lines 379-425, `calculateAdjustment()`

**Note**: The adjustment is returned as `int128` but is not actually applied to modify the swap delta (BeforeSwapDelta is set to ZERO_DELTA). This is an incomplete PoC -- the adjustment is computed but not enacted.

### 3.4 Gas Price EMA

The hook maintains an exponential moving average of gas prices:

```
EMA_new = (currentGas * alpha + EMA_old * (1 - alpha)) / denominator
alpha = 100, denominator = 1000  --> smoothing factor = 10%
```

Updated in `afterSwap`. Used to detect MEV/unusual gas conditions.

---

## 4. LVR/IL Hedging Logic

### 4.1 What Is Implemented

**Almost nothing concrete.** The README describes the intent to use power perpetuals and/or borrowing for gamma hedging, but the actual code contains only:

- Commented-out struct and mapping for Greeks tracking (lines 256-263):
  ```solidity
  // struct Greeks { int24 delta; int24 gamma; }
  // mapping (address => Greeks greeks)
  // updateGreeks()
  ```
- References to Chainlink realized volatility feed (used for market data, not for hedging)
- References to Brevis ZK coprocessor for volume data (commented out, lines 650-683)

### 4.2 What Is NOT Implemented

- No power perpetual position management
- No borrowing/lending integration
- No delta hedge computation
- No gamma hedge computation
- No IL decomposition into call/put components
- No strike grid or option leg construction
- No integration with any options protocol (Panoptic or otherwise)
- No position sizing logic

### 4.3 Hedging Architecture (From README, Not Code)

The README describes a two-pronged approach:
1. **Delta hedge**: Futures or borrowing with rebalance threshold
2. **Full hedge**: Power perpetuals or options for gamma neutrality

The Greek update mechanism was planned to occur in `beforeSwap`, updating delta/gamma after each price change, but this was never implemented.

---

## 5. Components Extractable for the IL Oracle / Hedge Builder Pipeline

### 5.1 HIGH VALUE -- Volatility Oracle (sigma computation)

**What**: The Alcarraz IV formula and the iterative convergence scheme.

**Why it matters**: The Hedge Builder needs sigma to compute option pricing when sizing the hedge. The `computeImpliedVolatilityAndDriftIterative()` function extracts IV from pool fee returns, which is exactly the vol parameter needed to price Panoptic options and determine `positionSize`.

**Adaptation needed**:
- Replace Chainlink oracle feeds with on-chain Uniswap V4 TWAP or the project's own price observation mechanism
- The mu_pool computation needs a real fee accumulator (currently comes from Chainlink price feed, which is conceptually wrong -- mu_pool should be the fee APR, not the asset price)
- Port from ABDKMath64x64 to the project's math library (FixedPointMathLib from Solady, or keep 64.64 as a separate layer)
- Add Volatility Risk Premium computation: VRP = IV - RV (mentioned in README but not coded)

**Files**:
- `/lib/risk-neutral-hook/src/Math/implied volatility_solidity.sol` (entire VolatilityCalculator)
- `/lib/risk-neutral-hook/src/Hook/univ4-risk-neutral-hook.sol`, lines 588-637

### 5.2 MEDIUM VALUE -- Welford Online RV Estimator

**What**: Streaming realized volatility from log-returns with O(1) state per update.

**Why it matters**: The Hedge Builder needs RV to compute VRP = IV - RV, which determines whether LPs are overcompensated or undercompensated by fees. This drives hedge urgency.

**Adaptation needed**:
- Feed log-returns from Uniswap V4 tick observations instead of external price feeds
- Consider using a windowed (EWMA) rather than all-history Welford estimator for recency weighting
- The annualization factor (sqrt(252)) assumes daily returns; adjust for block-time granularity

**File**: `/lib/risk-neutral-hook/src/Math/implied volatility_solidity.sol`, lines 140-233

### 5.3 MEDIUM VALUE -- Dynamic Fee Hook Architecture

**What**: The `beforeSwap`/`afterSwap` callback pattern with `updateDynamicLPFee()`.

**Why it matters**: The project's V4 hook needs the same callback structure. The risk-neutral-hook demonstrates:
- How to use `LPFeeLibrary.DYNAMIC_FEE_FLAG`
- The `getHookPermissions()` pattern for beforeSwap + afterSwap
- Swap context storage pattern (save state in beforeSwap, use in afterSwap)
- Fee clamping between MIN and MAX

**Adaptation needed**:
- The project's hook will need different callbacks (likely `afterSwap` for IL recalculation, `afterAddLiquidity`/`afterRemoveLiquidity` for position tracking)
- The dynamic fee logic is primitive (percentage bumps) -- replace with vol-surface-aware fee model

**File**: `/lib/risk-neutral-hook/src/Hook/univ4-risk-neutral-hook.sol`, lines 140-317

### 5.4 LOW VALUE -- Math Primitives (cosh, approximateLn, etc.)

**What**: Fixed-point transcendental function implementations.

**Why it matters**: Marginal. The project already uses Solady's `FixedPointMathLib` and Panoptic's `Math.sol`. The `cosh()` function is only needed if the Alcarraz IV formula is adopted. The Taylor series `approximateLn()` is inferior to `ABDKMath64x64.ln()` for general use.

**File**: `/lib/risk-neutral-hook/src/Math/implied volatility_solidity.sol`, lines 44-138

---

## 6. What It Computes vs. What We Need

| Quantity | Risk-Neutral Hook | Our Pipeline Needs It? | Status |
|---|---|---|---|
| **Implied Volatility (IV)** | Yes -- Alcarraz formula | Yes -- for option pricing and VRP | EXTRACTABLE, needs input refactoring |
| **Realized Volatility (RV)** | Yes -- Welford from log-returns | Yes -- for VRP = IV - RV | EXTRACTABLE, needs windowing |
| **Vol Surface** | No | Yes (future) -- for multi-strike pricing | NOT PRESENT |
| **Fee-Adjusted IL** | No | Yes -- IL net of fees earned | NOT PRESENT |
| **Hedge Ratios** | No (planned, not coded) | Yes -- delta, gamma per position | NOT PRESENT |
| **K^{-3/2} Weighting** | No | Yes -- Prop 3.5 kernel | NOT PRESENT (we have this in ARCHITECTURE.md) |
| **IL Decomposition** | No | Yes -- UIL^R / UIL^L | NOT PRESENT (we have LeftRightILX96.sol) |
| **Dynamic Fees** | Yes -- multi-factor | Peripheral interest | REFERENCE ONLY |
| **Power Perp Pricing** | No (mentioned in README) | Possible future hedge instrument | NOT PRESENT |
| **EMA Gas Price** | Yes | No direct need | NOT RELEVANT |

---

## 7. Hook Callbacks and V4 Integration

### 7.1 Callbacks Used

| Callback | Enabled | Purpose |
|---|---|---|
| `beforeSwap` | Yes | Compute dynamic fee, update market data, store swap context |
| `afterSwap` | Yes | Update gas EMA, compute post-swap adjustment |
| `beforeInitialize` | No (commented out) | Was intended to enforce DYNAMIC_FEE_FLAG |
| All others | No | -- |

### 7.2 Key Integration Patterns

1. **Dynamic fee via `updateDynamicLPFee`**: The hook calls `poolManager.updateDynamicLPFee(key, customFee)` in `beforeSwap`. This sets the fee for the current swap (and potentially subsequent swaps until changed again).

2. **Pool liquidity query**: `poolManager.getLiquidity(key.toId())` using StateLibrary -- retrieves current pool liquidity.

3. **Swap context pattern**: State is stored in a mapping keyed by `keccak256(poolAddress, nonce)` in `beforeSwap`, then retrieved and deleted in `afterSwap`. This enables pre/post comparison.

4. **BeforeSwapDelta**: Set to `ZERO_DELTA` -- the hook does not modify the swap amounts, only the fee.

### 7.3 Notable Issues

- **Pool address is never set**: `address poolAddress;` is declared but never assigned from the PoolKey (lines 207, 294). The code comments acknowledge this: `@audit => Research not found`. This means the marketData mapping is always keyed by `address(0)`.
- **`onlyByPoolManager` is commented out**: Both hook functions lack access control.
- **Tests are entirely commented out**: No working test suite exists.

---

## 8. Mathematical Formulas and Models Implemented

### 8.1 Alcarraz Implied Volatility

```
sigma = sqrt( (8/t) * [mu_pool * t - ln(cosh(u * t / 2))] )
u = mu_pool - sigma^2 / 2
```

This is a fixed-point iteration between sigma and u until convergence.

**Derivation context**: This formula comes from equating the expected LP return under GBM to the fee-adjusted return of the AMM. The `cosh` term arises from the V2 CPMM payoff structure. It assumes:
- Concentrated liquidity is approximated as V2-style full-range
- The pool drift mu_pool reflects fee income
- GBM dynamics with drift u and volatility sigma

### 8.2 Welford Online Variance

```
delta = x_n - mean_{n-1}
mean_n = mean_{n-1} + delta / n
delta2 = x_n - mean_n
M2_n = M2_{n-1} + delta * delta2
variance = M2_n / (n - 1)
```

Numerically stable single-pass variance computation.

### 8.3 EMA for Gas Price

```
EMA_n = (x_n * alpha + EMA_{n-1} * (1 - alpha))
alpha = 100/1000 = 10%
```

### 8.4 Taylor Series ln(x)

```
ln(1+z) = z - z^2/2 + z^3/3 - z^4/4 + z^5/5 - z^6/6
```

With normalization: `x = (1+z) * 2^k`, so `ln(x) = ln(1+z) + k*ln(2)`.

---

## 9. Assessment and Recommendations

### 9.1 Integration Path

The recommended extraction plan for the IL Oracle / Hedge Builder pipeline:

**Phase 1 -- Vol Layer** (immediate value):
1. Extract `VolatilityCalculator` (Welford estimator + Alcarraz IV formula)
2. Port to Solady FixedPointMathLib or maintain as ABDKMath64x64 helper
3. Wire the `addPrice()` mechanism to Uniswap V4 `afterSwap` tick observations
4. Feed IV output into Hedge Builder's `positionSize` computation

**Phase 2 -- VRP Signal** (hedge urgency):
1. Compute VRP = IV_pool - RV_chainlink (or RV from our own observations)
2. VRP > 0 means LP fees overcompensate for vol --> hedge is less urgent
3. VRP < 0 means LP fees undercompensate --> hedge is urgent
4. Use VRP magnitude as a scaling factor on `positionSize`

**Phase 3 -- Dynamic Fee Hook** (optional, complementary):
1. If the project's V4 hook also adjusts fees (beyond just hedging), the `beforeSwap` fee computation pattern is a useful skeleton
2. Replace the ad-hoc percentage bumps with vol-surface-derived fees

### 9.2 What We Already Have That This Hook Lacks

| Our Component | What It Does | Hook Equivalent |
|---|---|---|
| `LeftRightILX96.sol` | IL decomposition into call/put replicable components | Nothing |
| `Strikes.sol` | 4-strike grid from LP range bounds | Nothing |
| `Ricks.sol` | Signed tick-space distances, updated per price move | Nothing |
| ARCHITECTURE.md K^{-3/2} weighting | Prop 3.5 discretization kernel | Nothing |
| Panoptic TokenId construction | Option leg encoding | Nothing |

### 9.3 Maturity Assessment

| Dimension | Rating | Notes |
|---|---|---|
| Code completeness | LOW | Pool address unresolved, Greeks stub only, tests commented out |
| Mathematical correctness | MEDIUM | IV formula is well-sourced (Alcarraz), Welford is standard, but the mu_pool input path is broken (uses Chainlink price instead of fee APR) |
| V4 integration quality | MEDIUM | Correct hook pattern, but `onlyByPoolManager` disabled and pool address unresolved |
| Security | LOW | No access control on hook functions, no tests, no formal verification (despite README claims of planned verification) |
| Extractability | HIGH | Clean separation between VolatilityCalculator and Hook; the math module is independently useful |

### 9.4 Key Risks

1. **The IV formula assumes V2 full-range liquidity**. For V3/V4 concentrated liquidity, the `cosh` payoff structure is an approximation. The project should investigate whether the Alcarraz formula generalizes or whether the Lambert IV formula (mentioned in the README as "under investigation") is more appropriate for CLAMM.

2. **The mu_pool input is currently the Chainlink price feed**, not the actual pool fee return. This is a conceptual error in the hook. For our pipeline, mu_pool must be derived from actual fee accumulation data (Uniswap V4 `feeGrowthGlobal` or Panoptic's fee tracking).

3. **ABDKMath64x64 is a different fixed-point system** than the project's X96 (unsigned Q64.96) and Solady (uint256 WAD/RAY). Mixing these requires careful conversion boundaries.

---

## 10. Conclusion

The risk-neutral-hook provides two concrete, extractable contributions:

1. **An on-chain implied volatility oracle** using the Alcarraz formula with iterative convergence -- this is the sigma input the Hedge Builder needs for option pricing and position sizing.

2. **A streaming realized volatility estimator** via Welford's algorithm -- this enables VRP computation, which determines hedge urgency.

Everything else in the hook (dynamic fees, gas EMA, volume/liquidity thresholds) is peripheral to the IL Oracle / Hedge Builder pipeline. The hook does not compute IL, does not decompose it, does not construct option legs, and does not interface with any options protocol. Those capabilities already exist or are being built in `LeftRightILX96.sol`, `Strikes.sol`, `Ricks.sol`, and the Panoptic integration layer.

The recommended integration is: **extract the vol layer, fix the mu_pool input path, and wire it as a sigma provider to the Hedge Builder**.
