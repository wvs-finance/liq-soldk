# ReBalancer Analysis: Balancer V3 Hook for IV-Driven LP Rebalancing

**Repository**: `lib/ReBalancer` (github.com/utkarshdagoat/ReBalancer)
**Date**: 2026-03-29
**Purpose**: Assess applicability to IL hedge trigger design in liq-soldk-dev

---

## Executive Summary

ReBalancer is a Balancer V3 hook that rebalances weighted pool LP positions in response to predicted price movements fed by an external oracle. Despite its README claiming "implied volatility" drives rebalancing, the on-chain implementation contains **no IV computation whatsoever**. The system is a price-ratio threshold trigger: an off-chain oracle pushes `(latestRoundPrice, predictedPrice)` pairs per token, and the hook fires a rebalance when `predictedPrice / latestRoundPrice` exceeds a configurable `minRatio`. The mathematical model preserves the weighted-pool value function invariant across anticipated price changes. The dynamic fee hook (`onComputeDynamicSwapFee`) is **stubbed out** and returns the static fee.

For our project, the valuable takeaways are: (1) the Balancer V3 hook callback pattern for swap-triggered rebalancing, (2) the external-oracle push pattern for feeding off-chain signals on-chain, and (3) the threshold-gated position adjustment pattern. The actual rebalancing math is specific to Balancer weighted pools and does not transfer to Uni V4 concentrated liquidity. The IV-consumption gap is precisely what we need to fill with our own IL oracle + Prop 3.5 discretization.

---

## 1. Repository Structure

Core contracts (all under `packages/foundry/contracts/hooks/rebalancer/`):

| File | Lines | Role |
|------|-------|------|
| `Rebalancer.sol` | 633 | Hook + Router; rebalancing logic, LP tracking, Balancer V3 callbacks |
| `Oracle.sol` | 61 | On-chain oracle storage; receives off-chain pushes of price/predicted data |
| `interfaces/IOracle.sol` | 51 | Interface: `getFee()`, `getPoolTokensData()`, `setFee()`, `setPoolTokensData()` |
| `MinimalRouterWithSwap.sol` | 169 | Extends Balancer MinimalRouter with swap capability |

Supporting contracts:
- `pools/ConstantProductPool.sol` -- standard x*y=k pool (not used by the rebalancer)
- `pools/ConstantSumPool.sol` -- x+y=k pool (not used by the rebalancer)
- `factories/` -- factory contracts for the above pools

Test: `test/ReBalancerE2E.t.sol` (285 lines) -- end-to-end test demonstrating the full flow.

---

## 2. How Implied Volatility Is (Not) Consumed

### Finding: No On-Chain IV Computation

Despite the README stating the hook uses "real-time events and market implied volatility," the Solidity code contains zero references to volatility, sigma, IV, or any stochastic model. The oracle interface deals exclusively in price data:

```solidity
// IOracle.sol, line 10-13
struct TokenData {
    uint256 latestRoundPrice;   // current Chainlink-style price (1e8)
    uint256 predictedPrice;     // forward price from off-chain "event oracle"
}
```

The `predictedPrice` field is described in the NatSpec as coming from a "forward event oracle" -- this is where IV would implicitly live, but it arrives as a single scalar price prediction, not as a volatility surface or even a single sigma value.

### The `onComputeDynamicSwapFee` Stub

At `Rebalancer.sol` line 293-301, the dynamic fee hook is present but commented out:

```solidity
function onComputeDynamicSwapFeePercentage(
    PoolSwapParams calldata params,
    address pool,
    uint256 staticSwapFeePercentage
) public view override onlyVault returns (bool, uint256) {
    // uint256 dynamicFee = IOracle(oracle).getFee(pool);
    return (true, staticSwapFeePercentage);
}
```

The Oracle contract does have `setFee()` / `getFee()` plumbing (`Oracle.sol` lines 32-35, 53-55), but the hook never calls it. The infrastructure for IV-driven dynamic fees exists as skeleton code only.

### Where IV Would Enter

The off-chain component (not present in the repo, but implied by the architecture) would:
1. Monitor macro events (coupon payments, rate decisions, CPI releases)
2. Compute predicted prices -- presumably using some IV model
3. Push `TokenData[]` to the Oracle contract via `setPoolTokensData()`
4. Optionally push dynamic fees via `setFee()`

This is a classic "oracle push" pattern. The on-chain contract is IV-agnostic; it only sees the downstream effect (price prediction).

---

## 3. LP Rebalancing Logic: How Price Drives Position Changes

### Trigger Mechanism

The rebalance check occurs inside `onAfterSwap` (`Rebalancer.sol` line 275-290). Every swap on a registered pool triggers the check:

```
onAfterSwap() --> isRebalanceRequired(pool) --> [if true] rebalance(pool, priceActionRatio)
```

### Threshold Test (`isRebalanceRequired`, line 358-378)

For each token in the pool:
1. Fetch `TokenData` from the Oracle (latestRoundPrice, predictedPrice)
2. Compute `priceActionRatio = predictedPrice * 1e18 / latestRoundPrice` (FixedPoint 18-decimal division)
3. Compare against `poolRebalanceData[i].minRatio` (configurable per-token threshold)
4. If ratio exceeds threshold for any token, set `rebalanceRequired = true`

Key detail: tokens that do not breach the threshold get `priceActionRatio = 1e18` (FixedPoint.ONE), meaning "no change."

### Rebalancing Math (`_calculateAmounts`, line 535-567)

The math preserves the Balancer weighted pool value function `V = prod(B_i ^ W_i)` across anticipated price changes. For each token requiring rebalance:

```
innerProduct = prod_j( priceActionRatio[j] ^ (W_j / K) )    // K = number of tokens
newBalance_i = (currentBalance_i / priceActionRatio_i) * innerProduct
tokenDelta_i = |newBalance_i - currentBalance_i|
remove_i     = (newBalance_i < currentBalance_i)
```

This comes from the derivation in the README:
```
B_t' = (B_t / r_t) * prod_j(r_j ^ (W_j/K))
```

where `r_t = P_t' / P_t` is the price ratio.

### Liquidity Redistribution (`_changeLiqudity`, line 386-428)

After computing deltas, the hook:
1. Gets active LPs (tracked in `liquidityProviders` mapping)
2. Splits deltas across top 2 LPs (hardcoded, noted as "not for production")
3. Calls `_vault.addLiquidity()` / `_vault.removeLiquidity()` on behalf of LPs via Permit2

This is the most fragile part: the hook acts as a router that moves LP funds without explicit per-rebalance consent. It relies on the LP having pre-approved the hook via Permit2.

---

## 4. Balancer V3 Hook Callbacks Used

From `getHookFlags()` at line 237-244:

| Callback | Enabled | Purpose in ReBalancer |
|----------|---------|----------------------|
| `shouldCallBeforeAddLiquidity` | true | Gate: only allow adds through the hook's own router (`onlySelfRouter`) |
| `shouldCallAfterRemoveLiquidity` | true | Gate: only allow removes through the hook's own router; passthrough |
| `shouldCallComputeDynamicSwapFee` | true | **Stubbed** -- returns static fee unchanged |
| `shouldCallAfterSwap` | true | **Core trigger**: checks oracle, fires rebalance if threshold breached |
| `shouldCallBeforeSwap` | false | Not used |
| `shouldCallAfterAddLiquidity` | false | Not used |
| `shouldCallBeforeRemoveLiquidity` | false | Not used |

### Callback Flow

```
User swap --> Vault.swap() --> pool.onSwap()
         --> ReBalancerHook.onComputeDynamicSwapFeePercentage() [stubbed]
         --> ReBalancerHook.onAfterSwap()
               |
               +--> isRebalanceRequired(pool)
               |      |
               |      +--> Oracle.getPoolTokensData(pool)
               |      +--> compare ratios vs thresholds
               |
               +--> [if triggered] rebalance(pool, priceActionRatio)
                      |
                      +--> _calculateAmounts() --> weighted invariant math
                      +--> _changeLiqudity() --> vault.addLiquidity/removeLiquidity
```

---

## 5. Adaptability Assessment for IL Hedge Trigger

### What Transfers Directly

**5.1 The afterSwap-as-trigger pattern.**
The pattern of using `afterSwap` (or the Uni V4 equivalent) as the entry point for checking whether a rebalance/hedge adjustment is needed is directly applicable. In our Uni V4 hook, `afterSwap()` would:
- Read updated sqrtPriceX96
- Recompute UIL^R and UIL^L via LeftRightILX96
- Check against hedge thresholds
- If breached, invoke Hedge Builder to mint/burn Panoptic options

**5.2 The external oracle push pattern.**
The `Oracle.sol` contract pattern -- a simple storage contract where an authorized off-chain agent pushes data -- is reusable for feeding IV data. For our system, an off-chain keeper could push:
- Current realized vol (from tick-level TWAP variance)
- IV surface snapshots (from Deribit, or computed from Panoptic SFPM premiums)
- Macro event flags (rate decision dates, earnings, etc.)

**5.3 The per-pool configurable threshold (`RebalanceData`).**
The `minRatio` threshold per token maps to our concept of a hedge adjustment threshold. We would replace price-ratio thresholds with IL-magnitude thresholds (e.g., "rehedge when |delta_UIL^R| > X basis points of position value").

**5.4 The reentrancy guard pattern for rebalancing.**
The `nonReentrantRebalance` modifier (line 144-149) prevents recursive rebalancing. This is critical for our design since hedge adjustments via Panoptic will themselves cause swaps that could re-trigger the hook.

### What Does NOT Transfer

**5.5 The weighted-pool invariant math.**
The `_calculateAmounts` function is entirely specific to Balancer weighted pools. Our system operates on Uni V4 concentrated liquidity positions where IL is decomposed into call/put components via Prop 3.5, not via value-function invariant preservation.

**5.6 The LP tracking mechanism.**
ReBalancer manually tracks LPs in a mapping because Balancer V3 pools do not natively expose LP lists. In Uni V4 with hooks, we would track positions via `positionKey` directly within the hook state, which is already part of our IL Oracle design.

**5.7 The naive LP fund redistribution.**
Moving LP funds via `_vault.addLiquidity()` on behalf of arbitrary LPs is problematic from both a trust and gas perspective. Our design uses Panoptic options (minted by the hedger, not by involuntary LPs), which is a cleaner authorization model.

---

## 6. Event-Driven Volatility Patterns

### README Claims vs Implementation

The README describes a system motivated by RWA events (coupon payments, rate decisions, CPI releases, earnings). The `predictedPrice` field in `TokenData` is the conduit for this. However:

- There is no on-chain event calendar
- There is no event-type classification
- There is no graduated response (e.g., "pre-event fee increase, post-event rebalance")
- The "forward event oracle" is entirely off-chain and its logic is not in the repository

### Applicable Pattern for Our Design

The event-driven concept is valuable for our IL hedge system:

1. **Pre-event hedge tightening**: Before known vol events (FOMC, CPI, major protocol upgrades), the hedge builder could increase option coverage or tighten strike spacing.
2. **Post-event hedge release**: After the event resolves and vol collapses, reduce hedge positions to save premium.
3. **Macro event flags in oracle**: An off-chain keeper could push event-type flags alongside IV data, allowing the on-chain hook to apply different threshold multipliers.

This would require extending the oracle interface beyond what ReBalancer provides:

```solidity
struct VolData {
    uint256 currentIV;          // implied vol (1e18 = 100%)
    uint256 realizedVol;        // trailing realized vol
    uint8   eventFlag;          // 0=normal, 1=pre-event, 2=event-day, 3=post-event
    uint256 eventVolMultiplier; // threshold adjustment factor
}
```

---

## 7. Mathematical Models Used

### 7.1 Value Function Invariant Preservation

The core model preserves `V = prod(B_i ^ W_i)` for Balancer weighted pools. The derivation (from README):

Given price ratios `r_i = P_i' / P_i`, new liquidity:
```
L' = L * prod_i(r_i ^ (W_i / K))
```
New token balances:
```
B_i' = (B_i / r_i) * prod_j(r_j ^ (W_j / K))
```

This is implemented in `_calculateAmounts` using Balancer's `FixedPoint` library for 18-decimal fixed-point arithmetic with `mulUp`, `divUp`, and `powUp` operations.

### 7.2 Exponentiation Details

At line 549: `uint256 exponent = normalizedWeights[j].divUp(length * FixedPoint.ONE)`

Note: The exponent is `W_j / K` where K is the number of tokens. For a 2-token 50/50 pool, this is `0.5 / 2 = 0.25`. The `powUp` function uses Balancer's LogExpMath under the hood (natural log + exp approximation).

### 7.3 Fee Model (Unrealized)

The Oracle stores a per-pool `dynamicFee` but the hook never reads it. The intended model was likely: higher IV -> higher swap fee -> compensate LPs for adverse selection during volatile periods. This is the same concept as Uniswap V4 dynamic fee hooks (e.g., the Algebra-style vol oracle approach analyzed in `analysis-algebra-vol-oracle.md`).

---

## 8. Bugs and Limitations Noted

1. **Line 549**: `normalizedWeights[j].divUp(length * FixedPoint.ONE)` -- the exponent should be `W_j / K` but `length` here is `poolRebalanceData.length`, not necessarily the token count. If rebalance data length differs from weight array length, this breaks.

2. **Line 400**: LP distribution hardcoded to top 2 LPs: `uint256 numberOfLps = activeLiquidityProviders.length >= 2 ? 2 : activeLiquidityProviders.length` -- acknowledged as "not for production."

3. **Line 424**: Bug in LP2 remove distribution: `_distributeLiquidity(pool, activeLiquidityProviders[1], lpOneTokens.removeTokens, false, wethIsEth)` passes `lpOneTokens.removeTokens` instead of `lpTwoTokens.removeTokens`.

4. **Line 142**: `bool private isRebalancing` -- Solidity does not support `private` as a visibility modifier on state variables in this position (should be after the type). This may not compile cleanly on all Solidity versions.

5. **No staleness check on oracle data**: `isRebalanceRequired` reads `predictedPrice` without checking age. Stale predictions could trigger spurious rebalances.

6. **Gas**: Every swap triggers a full oracle read + ratio computation + potential rebalance. The rebalance itself does multiple vault interactions. This would be extremely expensive on mainnet.

---

## 9. Recommendations for liq-soldk-dev Integration

### 9.1 Adopt the Oracle Push Pattern

Create a `VolOracle.sol` that receives off-chain IV data pushes. Interface:

```solidity
interface IVolOracle {
    function getIV(address pool) external view returns (uint256 iv, uint256 timestamp);
    function getRealizedVol(address pool) external view returns (uint256 rv, uint256 timestamp);
    function getEventFlag(address pool) external view returns (uint8 flag);
}
```

This separates the IV source question (Deribit feed? SFPM-implied? Realized vol estimator?) from the on-chain consumption.

### 9.2 Adapt the afterSwap Trigger for Uni V4

In our Uni V4 hook:

```
afterSwap() {
    sqrtPrice = pool.sqrtPriceX96
    (uilR, uilL) = LeftRightILX96.leftRightIlXLiq(sqrtPrice, tickLower, tickUpper)
    delta = abs(uilR - lastHedgedUilR)
    if (delta > threshold) {
        // invoke hedge builder
        // apply event-flag multiplier from VolOracle
    }
}
```

### 9.3 Replace Price-Ratio Thresholds with IL-Based Thresholds

Instead of `minRatio` (price change percentage), use:
- `minILDelta`: minimum change in UIL^R or UIL^L since last hedge (in X96 units)
- `minVolChange`: minimum IV change to trigger hedge width adjustment
- `eventThresholdMultiplier`: scale thresholds down before known events (more sensitive trigger)

### 9.4 Use Panoptic Settlement Instead of LP Fund Redistribution

ReBalancer's approach of moving LP funds is fragile. Our design uses Panoptic option minting, which is cleaner:
- The hedger mints options with their own collateral
- Option payoffs offset IL for the hedged position
- No need to move other LPs' funds without consent

### 9.5 Implement the Dynamic Fee Component That ReBalancer Left Stubbed

The `onComputeDynamicSwapFee` hook is the right place for IV-driven fee adjustment. Our hook should actually implement it:
- Read current IV from VolOracle
- Apply fee = baseFee * (1 + k * (IV - baselineIV)) where k is a sensitivity parameter
- This compensates LPs for adverse selection during high-vol periods
- This is complementary to (not a substitute for) the option-based hedge

---

## 10. Key File References

| File | Path | Key Lines |
|------|------|-----------|
| Rebalancer hook | `lib/ReBalancer/packages/foundry/contracts/hooks/rebalancer/Rebalancer.sol` | L275-290 (afterSwap trigger), L358-378 (threshold check), L535-567 (rebalance math) |
| Oracle | `lib/ReBalancer/packages/foundry/contracts/hooks/rebalancer/Oracle.sol` | L37-51 (data push), L53-59 (data read) |
| IOracle | `lib/ReBalancer/packages/foundry/contracts/hooks/rebalancer/interfaces/IOracle.sol` | L10-13 (TokenData struct) |
| Router extension | `lib/ReBalancer/packages/foundry/contracts/hooks/rebalancer/MinimalRouterWithSwap.sol` | L56-87 (swap routing) |
| E2E test | `lib/ReBalancer/packages/foundry/test/ReBalancerE2E.t.sol` | L206-284 (rebalancing test with mock oracle data) |
| README math | `lib/ReBalancer/README.md` | L50-81 (value function invariant derivation) |

---

## 11. Summary Table

| Aspect | ReBalancer Status | Applicability to Our Project |
|--------|-------------------|------------------------------|
| IV consumption | None on-chain; oracle receives price predictions | Pattern reusable; replace prices with IV/vol data |
| Rebalance trigger | afterSwap, price-ratio threshold | Directly applicable; replace with IL-delta threshold |
| Rebalance math | Weighted pool invariant preservation | Not applicable; we use Prop 3.5 call/put decomposition |
| Dynamic fees | Stubbed / not implemented | We should implement what they left unfinished |
| Event-driven vol | Conceptual only (README) | Valuable concept; implement via event flags in oracle |
| Hook pattern | Balancer V3 (afterSwap, computeDynamicSwapFee) | Translates to Uni V4 hook equivalents |
| LP fund management | Involuntary redistribution via Permit2 | Replace with Panoptic option minting (consensual) |
| Reentrancy protection | Basic boolean guard | Adopt; critical for preventing hedge-loop recursion |
