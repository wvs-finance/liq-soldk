# Cross-Check Synthesis: Volatility Oracle Repos vs. Our LP Hedging Pipeline

**Date**: 2026-03-29

---

## Our Pipeline (for reference)

```
afterSwap() → IL Oracle (LeftRightILX96.sol) → Hedge Builder (Strikes/Ricks) → PanopticPool.mintOptions()
                  │                                    │
                  ▼                                    ▼
        UIL^R, UIL^L                    optionRatio (K^{-3/2} weights)
        (per-position)                  positionSize = f(|UIL|, L, sigma)
                                                          ↑
                                                    NEED: sigma (vol estimate)
```

**The critical missing input**: `sigma` — a volatility estimate to scale `positionSize` and determine hedge urgency/rebalance triggers. None of our current code computes or consumes volatility.

---

## What Each Repo Actually Delivers

### 1. Risk-Neutral Hook (`univ4-risk-neutral-hook`)

| Component | Extractable? | Quality | Notes |
|-----------|-------------|---------|-------|
| **On-chain IV oracle** (Daniel Alcarraz formula) | YES | Medium | `sigma = sqrt((8/t) * [mu_pool*t - ln(cosh(u*t/2))])` with fixed-point iteration. BUG: `mu_pool` sourced from Chainlink price feed instead of pool fee returns — must fix. |
| **Streaming RV** (Welford's online variance) | YES | Good | Enables VRP = IV - RV for hedge urgency signal |
| **Power perp hedging concept** | Architectural only | Low | Commented-out stubs, no implementation |
| **Dynamic fee** | YES | Medium | Vol-scaled fee adjustment via `beforeSwap` |

**Verdict**: Extract IV oracle + RV estimator. Fix the mu_pool bug. Wire sigma → positionSize.

---

### 2. Algebra (`Algebra`)

| Component | Extractable? | Quality | Notes |
|-----------|-------------|---------|-------|
| **Plugin architecture** | Reference only | High | 8-bit config bitmap, `beforeSwap` returns `(overrideFee, pluginFee)`. Well-documented pattern. |
| **Adaptive fee formula** | Documented, not in this repo | Production-proven | `fee = baseFee + alpha / (1 + (gamma/vol)^beta)` — sigmoid mapping. Actual code in `integral-team-plugins` (separate repo). |
| **Timepoints ring buffer** | Interface only | High | Core defines the interface; plugin implements cumulative tick variance storage. |
| **Sliding fee plugin** | Not present | N/A | Newer approach in separate repo, claimed 15% efficiency gain. |

**Verdict**: The architecture is the gold standard for hook-based vol → fee pipelines. Install `cryptoalgebra/integral-team-plugins` separately to get the actual vol computation. The sigmoid fee formula is worth studying for our fee-awareness layer (hedge cost estimation).

---

### 3. ReBalancer (`ReBalancer`)

| Component | Extractable? | Quality | Notes |
|-----------|-------------|---------|-------|
| **afterSwap trigger pattern** | YES | Good | Swap → check oracle → conditionally act. Directly maps to our afterSwap → recompute IL → trigger hedge. |
| **External oracle push pattern** | YES | Good | Clean `Oracle.sol` template for receiving off-chain vol data. Replace `(price, predictedPrice)` with `(currentIV, RV, eventFlag)`. |
| **Reentrancy guard for rebalance** | YES | Critical | `nonReentrantRebalance` prevents infinite loops when hedge actions cause swaps that re-enter the hook. **We need this.** |
| **IV computation** | NO | N/A | Despite marketing, zero IV computation on-chain. Just a price-ratio threshold. |
| **Rebalancing math** | NO | N/A | Balancer weighted pool invariant — irrelevant to concentrated liquidity. |

**Verdict**: Extract the trigger pattern and reentrancy guard. The oracle push pattern is a clean template for external vol feeds. The gap ReBalancer exposes is exactly what our IL Oracle fills.

---

### 4. Valorem Oracles (`valorem-oracles`)

| Component | Extractable? | Quality | Notes |
|-----------|-------------|---------|-------|
| **Fee-growth IV estimator** (`Volatility.sol`) | YES | Good | Guillaume Lambert method: `feeGrowthGlobal` deltas → 24h IV. Pure library, zero dependencies. Most immediately usable vol component across all repos. |
| **Compound V3 yield oracle** | YES | Medium | Risk-free rate via USDC supply rate TWAP. Useful for carry cost in hedge sizing. |
| **BSM pricer** | NO | Stub only | Interface exists, zero implementation. |
| **Greeks** | NO | Absent | Not even an interface. |
| **Realized volatility** | NO | Explicit revert | `revert("not implemented")` |

**Verdict**: Fork `Volatility.sol`, adapt data-fetching for V4 (feeGrowthGlobal0X128/1X128 from PoolManager). This is the fastest path to a sigma input. Don't use for Panoptic pricing (wrong model — streaming premia ≠ BSM lump-sum).

---

### 5. Tempest (`tempest`)

| Component | Extractable? | Quality | Notes |
|-----------|-------------|---------|-------|
| **VolatilityEngine library** | YES | **Production-grade** | Zero dependencies. Tick deltas = log returns directly. Time-weighted annualized RV. |
| **Dual EWMA smoothing** (7d + 30d) | YES | High | Linear approximation of exponential decay. Regime detection via EMA crossover. |
| **Packed ring buffer** (4 obs/slot) | YES | High | ~5,200 gas/write. 4 observations packed per storage slot. |
| **Keeper pattern** | YES | Good | Permissionless `updateVolatility()` with gas-price-scaled ETH reward. |
| **Piecewise-linear vol→fee mapping** | YES | Good | 6 governance-configurable control points. Momentum boost when `currentVol > ema7d`. |
| **Staleness protection** | YES | Good | Escalates to cap fee (500 bps) when keeper offline > 1 hour. |

**Verdict**: **Best-in-class RV computation.** The `VolatilityEngine` is directly importable. Dual EWMA provides both short-term (hedge urgency) and long-term (baseline regime) signals. The packed ring buffer is a gas optimization we should adopt. Only gap: pool-level only, no per-position awareness.

---

### 6. VolatilityHook-UniV4 (`VolatilityHook-UniV4`)

| Component | Extractable? | Quality | Notes |
|-----------|-------------|---------|-------|
| **SP1 ZK-proven RV** | Concept only | Low | Off-chain `s^2 = (1/(n-1)) * SUM(delta_tick - mean)^2` over 7-8K observations, verified on-chain via SP1Verifier. |
| **RV → fee formula** | YES | Medium | `fee = MIN_FEE + 2 * volume * (rv/longTermVol)^2` |
| **Natural-log conversion** | YES | Small | `rv = s * ln(1.0001)` converts tick-log to natural-log base |

**Critical security issues**:
- `setProgramKey()` has **no access control** — anyone can change the ZK verification key
- `setVolatility()` owner bypass — defeats the entire proof system
- SP1 circuit source code is **missing** from repo
- No staleness protection
- Single-pool data (not cross-DEX as claimed)

**Verdict**: Interesting ZK-RV concept for future exploration but NOT production-ready. The conversion formula (`s * ln(1.0001)`) is a useful reference. The security holes disqualify direct use.

---

## Synthesis: What to Extract and Where It Fits

### The Sigma Pipeline We Can Build

```
                    ┌─────────────────────────────────┐
                    │   Volatility Layer (NEW)         │
                    │                                  │
  afterSwap() ────→│  1. Tempest VolatilityEngine     │──→ sigma_RV (realized)
                    │     (tick delta² EWMA, 7d/30d)   │
                    │                                  │
  feeGrowthGlobal →│  2. Valorem Volatility.sol       │──→ sigma_IV (implied, Lambert)
                    │     (fee-growth → 24h IV)        │
                    │                                  │
  (optional)       │  3. Risk-neutral IV oracle       │──→ sigma_IV2 (Alcarraz formula)
                    │     (mu_pool iteration, FIX BUG) │
                    │                                  │
                    │  VRP = sigma_IV - sigma_RV       │──→ hedge urgency signal
                    │                                  │
                    └──────────────┬───────────────────┘
                                   │
                                   ▼ sigma
                    ┌─────────────────────────────────┐
                    │   IL Oracle (EXISTING)            │
                    │   LeftRightILX96.sol              │
                    │                                  │
                    │   UIL^R, UIL^L (per-position)    │
                    │                                  │
                    │   E[IL] = f(sigma², T, range)    │──→ expected IL magnitude
                    │                                  │
                    └──────────────┬───────────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────────┐
                    │   Hedge Builder (EXISTING)        │
                    │   Strikes.sol + Ricks.sol         │
                    │                                  │
                    │   positionSize = |UIL| · L / Σ(optionRatio · value)  │
                    │                                  │
                    │   Trigger: VRP > threshold        │ ← from ReBalancer pattern
                    │   Guard: nonReentrantRebalance    │ ← from ReBalancer
                    │                                  │
                    └──────────────┬───────────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────────┐
                    │   PanopticPool.mintOptions()      │
                    └─────────────────────────────────┘
```

### Priority Extraction List

| Priority | What | From | Effort | Impact |
|----------|------|------|--------|--------|
| **P0** | `VolatilityEngine` library (RV + EWMA + ring buffer) | Tempest | Low (zero deps, direct import) | sigma_RV for positionSize scaling |
| **P0** | `nonReentrantRebalance` guard | ReBalancer | Trivial | Prevents infinite loop when hedge → swap → re-enter hook |
| **P1** | `Volatility.sol` fee-growth IV estimator | Valorem | Low (adapt V3→V4 data fetch) | sigma_IV for forward-looking hedge sizing |
| **P1** | afterSwap trigger + threshold pattern | ReBalancer | Low (pattern, not code) | When to rehedge (not every swap — only when delta exceeds threshold) |
| **P2** | IV oracle (Alcarraz formula) | Risk-neutral-hook | Medium (must fix mu_pool bug) | Alternative sigma_IV, enables VRP computation |
| **P2** | Welford streaming RV | Risk-neutral-hook | Low | Complements Tempest EWMA with unbiased variance |
| **P3** | Algebra sigmoid fee formula | Algebra docs | Reference only | Design pattern for fee-awareness in hedge cost estimation |
| **P3** | Compound V3 yield oracle | Valorem | Low | Risk-free rate for carry cost in hedge sizing |
| **P4** | ZK-proven RV concept | VolatilityHook-UniV4 | High (needs new circuit) | Manipulation-resistant vol — future work |

### What None of These Repos Have (Our Unique Value)

1. **IL decomposition into call/put replicable components** (LeftRightILX96.sol — Prop 3.5)
2. **K^{-3/2} strike weighting** for option leg construction (Strikes.sol)
3. **Panoptic integration** for on-chain option settlement
4. **Per-position vol-adjusted hedge sizing** (positionSize = f(sigma, |UIL|, L))
5. **VRP-driven rehedge triggers** (IV - RV → urgency signal → selective rebalancing)

### Recommended Integration Order

**Phase 1 — Get sigma flowing**:
- Import Tempest `VolatilityEngine` → expose `getRealizedVol(poolId)` in our hook
- Wire sigma_RV into positionSize computation

**Phase 2 — Add forward-looking vol**:
- Fork Valorem `Volatility.sol` → adapt for V4 feeGrowthGlobal
- Compute VRP = sigma_IV - sigma_RV as rehedge trigger

**Phase 3 — Harden the trigger**:
- Adopt ReBalancer's reentrancy guard pattern
- Implement threshold-based rehedging (not every swap)

**Phase 4 — Optional enhancements**:
- Fix and integrate risk-neutral-hook's Alcarraz IV for a second IV source
- Evaluate ZK-proven RV for manipulation resistance (long-term)

---

## Per-Repo Verdicts (One Line Each)

| Repo | Verdict |
|------|---------|
| **risk-neutral-hook** | Extractable IV oracle with fixable bug + Welford RV. Hedging logic is stubs only. |
| **Algebra** | Architecture gold standard but actual vol code lives in separate repo. Install `integral-team-plugins` for the real thing. |
| **ReBalancer** | IV marketing is vapor, but trigger pattern + reentrancy guard are critical infrastructure. |
| **Valorem oracles** | 80% vapor, but `Volatility.sol` (Lambert fee-growth IV) is the fastest path to sigma. |
| **Tempest** | **Best overall.** Production-grade RV engine, zero-dep library, packed ring buffer, dual EWMA. Import first. |
| **VolatilityHook-UniV4** | Interesting ZK concept, unusable in current state. Security holes + missing circuit source. |
