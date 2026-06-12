# Brainstorm: Claims on USDC/DAI feeRevenue and Volatility Structure
## Building the Toolkit to Ask the Right Questions

*Date: 2026-03-31*

---

## 1. What Does "Volatility on USDC/DAI" Mean?

This is the first thing to get right. USDC/DAI is NOT like ETH/USDC. On ETH/USDC, volatility is price discovery -- the market finding what ETH is worth. On USDC/DAI, **both tokens want to be $1.00**. Volatility here is not discovery. It is the cost of maintaining two independent pegs simultaneously.

### Decomposition of USDC/DAI volatility

There are at least three distinct layers, and they have different time scales and different economic content:

**Layer 1 -- Arbitrage friction (seconds to minutes)**
The spread between USDC and DAI on this pool vs. other venues (Curve, Uniswap mainnet, Maker PSM if still active, CEXes). Arbers close gaps. The residual noise after arb is the cost of cross-venue synchronization: gas, latency, inventory risk. This layer is **microstructural**, not macro. But it sets the floor on observable volatility -- you cannot extract macro signal below this noise floor.

*What you need to study*: What is the minimum tick deviation that persists for more than N blocks? What is the arb round-trip cost (gas + slippage + bridge if cross-chain)? This defines the **resolution limit** of the instrument.

**Layer 2 -- Peg mechanism stress (hours to days)**
USDC redemption: 1:1 via Circle, T+1 banking settlement. DAI redemption: via Maker vaults, requires collateral liquidation or PSM (if active). These are fundamentally different mechanisms with different latencies and different failure modes. When one mechanism is under stress and the other isn't, the spread widens.

Examples:
- SVB (March 2023): USDC broke peg because Circle had $3.3B at SVB. DAI followed because DAI had USDC as collateral. But the *sequence* mattered -- USDC broke first, DAI broke second, and the USDC/DAI spread itself told you which leg was failing.
- Maker PSM shutdown: If Maker disables the PSM (Peg Stability Module), the DAI redemption mechanism changes from "instant at 1:1" to "via vault liquidation" -- this changes the volatility structure of the pair entirely.

*What you need to study*: The Maker PSM state (is it active? what are its limits?), USDC reserve composition, Circle attestation cadence, and DAI collateral composition over time. These are the **state variables** of the peg mechanisms.

**Layer 3 -- Systemic / macro regime (days to weeks)**
When the entire stablecoin ecosystem is under stress (regulatory action, banking crisis, crypto crash affecting DAI collateral), the USDC/DAI spread reflects the **differential survival probability** of the two peg mechanisms. This is the macro layer.

*What you need to study*: Historical stress events and the USDC/DAI spread behavior during each. Not the spread level -- the **dynamics**: how fast it widened, whether it was symmetric (both depeg) or asymmetric (one depeg), and the error-correction speed back to peg.

### Key insight: USDC/DAI volatility is a SPREAD volatility

In fixed-income terms, USDC and DAI are both "bonds" promising to pay $1. Their prices should both be par. The USDC/DAI exchange rate is the **relative credit spread** between two different $1 claims. Volatility of this spread is the volatility of the credit spread differential.

This means the relevant literature is not equity volatility modeling -- it is **credit spread dynamics**: Duffie-Singleton (1999), reduced-form credit models, Merton structural models. The tools from credit risk are the right starting point.

---

## 2. What Does feeRevenue Incorporate Beyond Price?

### The structure of feeRevenue on any CFMM

```
feeRevenue = integral_0^T [ fee_rate(t) * |volume(t)| ] dt
```

On a vanilla Uni v3 pool with fixed fee f:

```
feeRevenue_uniV3 = f * integral_0^T |volume(t)| dt
```

Volume on a near-peg pair is driven by arbitrage. Arb volume scales with:
- The SIZE of the price deviation from peg (bigger deviation = bigger arb trade)
- The FREQUENCY of deviations (more deviations per unit time = more trades)

So volume ~ (deviation_size * deviation_frequency), which is roughly proportional to realized variance of the price. Therefore:

```
feeRevenue_uniV3 ~ f * realized_variance(price)     [approximately linear in variance]
```

This makes Uni v3 feeRevenue on USDC/DAI approximately a **variance swap** -- it pays out proportionally to realized variance.

### What Algebra's adaptive fee adds

On Algebra, the fee itself is a function of volatility:

```
fee_algebra(t) = baseFee + sigmoid1(vol(t)) + sigmoid2(vol(t))
```

Where vol(t) is the 24h rolling average volatility from the accumulator. The dual-sigmoid structure means:
- At LOW volatility: fee ~ baseFee (flat, ~1 bip)
- At MODERATE volatility: fee rises steeply (sigmoid1 kicks in, up to ~30 bips)
- At HIGH volatility: fee rises further but saturates (sigmoid2, up to ~150 bips)

So:

```
feeRevenue_algebra = integral_0^T [ (baseFee + sigmoid(vol(t))) * |volume(t)| ] dt
```

Since both `fee_rate` and `volume` are increasing functions of volatility:

```
feeRevenue_algebra ~ baseFee * variance + sigmoid(vol) * variance
                   ~ variance + f(variance) * variance
```

**This is a CONVEX claim on variance.** It's not linear -- it pays more than proportionally when volatility is high. The sigmoid structure means:
- In normal times: feeRevenue_algebra ~ feeRevenue_uniV3 (both linear in variance, small fee)
- In stress: feeRevenue_algebra >> feeRevenue_uniV3 (Algebra captures the vol spike in BOTH the fee rate and the volume)

### Additional structure in feeRevenue vs. pure price data

feeRevenue incorporates information that raw price does NOT:

1. **Liquidity-weighted throughput**: feeGrowthGlobal is normalized by active liquidity. 
A $1M swap through a pool with $100K liquidity generates 10x the feeGrowth of the same swap through a $1M liquidity pool. This means feeGrowthGlobal encodes not just "how much activity" but "how much stress per unit of available liquidity" -- an intensity measure.

2. **Directional asymmetry**: feeGrowthGlobal0Token and feeGrowthGlobal1Token accumulate separately. The RATIO between them tells you which direction the volume flows. If feeGrowth0 >> feeGrowth1 over a period, agents are predominantly selling token0 (USDC) for token1 (DAI), or vice versa. Price alone is mean-reverting on a peg pair; the directional fee decomposition reveals the *pressure* even when the price reverts.

3. **Cumulative and monotonic**: feeGrowthGlobal only increases. This makes it a natural integrator -- you don't need to worry about sampling rate to compute total activity over a period. Price you must sample frequently to estimate volatility; feeGrowthGlobal you can difference between any two points in time and get the exact total.

4. **Manipulation resistance**: Manipulating the price (a flash loan attack) costs the attacker proportionally to the fee. The feeGrowthGlobal captures the FEE PAID by the manipulator, not the manipulated price. So feeGrowthGlobal is more manipulation-resistant than price as a signal source.

---

## 3. What Does Comparing Algebra feeRevenue vs. Vanilla Uni v3 feeRevenue Reveal?

If both pools exist for USDC/DAI (Algebra on QuickSwap, Uni v3 on Uniswap), the comparison is structurally informative.

### The fee adaptation premium

```
delta_feeRevenue = feeRevenue_algebra - feeRevenue_uniV3_scaled
```

(Where "scaled" adjusts for TVL differences so we compare per-unit-liquidity.)

This delta isolates the **value of dynamic fee adjustment** -- the premium that Algebra LPs earn by having fees that rise with volatility.

In calm periods: delta ~ 0 (both earn similar low fees)
In stress periods: delta >> 0 (Algebra captures the vol spike)

**delta_feeRevenue is itself a volatility derivative.** It pays nothing in calm, pays a lot in stress. It has the payoff profile of a **straddle** or a **variance swap with a strike at the normal-regime variance level**.

### What this comparison tells you that neither pool alone does

1. **Regime identification without a model**: If you only have one pool, you need a statistical model (e.g., Hamilton regime switching) to identify "calm" vs "stress" regimes. With BOTH pools, the regime boundary is revealed by when delta_feeRevenue begins to diverge from zero. The market itself is telling you where the regime boundary is.

2. **Volatility risk premium**: In TradFi, the difference between implied vol (options) and realized vol (historical) is the volatility risk premium. Here, the Algebra fee is an "implied" fee set by the volatity accumulator (forward-looking, based on recent vol), while the Uni v3 fee is fixed (no vol information). The delta captures something analogous: how much extra the market pays for volatility-responsive infrastructure.

3. **LP selection as information**: LPs choose WHERE to provide liquidity. The ratio of TVL between Algebra-USDC/DAI and UniV3-USDC/DAI pools reveals LP beliefs about future volatility. 

If LPs expect high vol, they should prefer Algebra (higher fees compensate for higher IL). The TVL ratio is a revealed-preference vol forecast.

4. **Arb routing as information**: When arbitrageurs have a choice between routing through Algebra (high adaptive fee during stress) and Uni v3 (fixed low fee), their routing decision reveals the urgency of the arb. Urgent arbs (large deviations) will pay the higher Algebra fee; small arbs will route through Uni v3. The volume split between pools during stress events is an information signal about deviation intensity.

---

## 4. What Macro Questions Can Be Asked?

These emerge from the structure above -- not as claims, but as **testable hypotheses once data is in hand**:

### From the variance swap structure of feeRevenue:
- Is the realized variance of USDC/DAI (measured via feeRevenue) correlated with any macro variable? Which ones? At what lag?
- Does the variance of USDC/DAI lead or lag the variance of ETH/USDC? (If it leads, stablecoin stress precedes crypto stress; if it lags, crypto stress transmits into stablecoin stress.)
- Is there a seasonal/cyclical component to USDC/DAI variance? (e.g., month-end, quarter-end, banking settlement cycles)

### From the convexity of Algebra feeRevenue:
- Does the convex (Algebra) fee revenue signal detect regime changes earlier than the linear (Uni v3) fee revenue? The convex instrument amplifies tail events -- it should provide earlier detection of stress onset.
- How does the Algebra fee level (the sigmoid output) compare to the VIX or ETH implied vol? Is there a stable relationship, or does it break during specific event types?

### From the directional decomposition:
- During stress, does the USDC->DAI flow (feeGrowth1 increasing faster) or DAI->USDC flow (feeGrowth0 increasing faster) dominate? The direction tells you WHICH peg mechanism the market is losing confidence in.
- Is there a lead-lag between directional flow in USDC/DAI and flows in ETH/USDC? (If flight from DAI precedes ETH selling, DAI collateral fears drive crypto selling.)

### From the cross-pool comparison:
- Does the TVL ratio (Algebra/UniV3) predict future realized variance? If LPs are informed, their allocation decision should lead volatility.
- Does the arb volume routing split (fraction going through Algebra vs UniV3) predict the persistence of stress events?

### What you need before asking these questions:
- The data (on-chain history for both pools)
- Aligned off-chain time series (Fed funds, DSR, ETH price, stablecoin market caps)
- A clear definition of "stress event" (threshold for the spread? for the Algebra fee level? for the volume spike?)
- The statistical tools to estimate the relationships (cointegration, Granger, regime-switching, event study)

---

## 5. What Hedging Instruments Can Be Created SOLELY from On-Chain Data?

The key constraint: **no external oracles, no off-chain feeds.** Everything must settle from pool state.

### Instrument 1: feeRevenue claim as a variance swap

An LP position in USDC/DAI is ALREADY a long variance position (it earns more when vol is higher). To create a hedging instrument:

- **Long vol**: Be an LP in the pool. Your feeRevenue is your variance swap payoff.
- **Short vol**: Use Panoptic to sell options on the USDC/DAI LP position. The option seller is effectively short the feeRevenue stream -- they are short variance.
- **Settlement**: feeGrowthGlobal is on-chain, monotonic, manipulation-resistant. It can be the settlement index directly.

*What you need to study*: The exact mapping between feeGrowthGlobal delta and realized variance. Is it linear? Convex? Does it depend on the liquidity distribution?

### Instrument 2: Algebra fee level as a vol index

The Algebra adaptive fee is already an on-chain volatility index (it's computed from the volatility accumulator). A derivative that pays based on the time-weighted average Algebra fee over a period is a **volatility index derivative**.

- **Settlement index**: `timewAvg(pool.globalState().fee)` over the settlement period
- **Payoff**: Could be a perpetual (continuous settlement against the fee TWAP) or a fixed-maturity contract
- **No oracle needed**: The fee is endogenous to the pool

*What you need to study*: The volatility accumulator formula (already extracted above). Whether `volatilityCumulative` in the Timepoint struct can serve directly as an accumulator for settlement.

### Instrument 3: Directional flow claim

The ratio feeGrowthGlobal0Token / feeGrowthGlobal1Token over a period measures net directional pressure. A derivative that pays based on the asymmetry of this ratio is a **directional risk instrument** -- it pays when flow is predominantly one-directional (stress) and doesn't pay when flow is balanced (calm).

- **Settlement index**: `|feeGrowth0_delta - feeGrowth1_delta| / (feeGrowth0_delta + feeGrowth1_delta)` over the period
- **Payoff**: Binary (pays if asymmetry exceeds threshold) or linear

*What you need to study*: Whether this ratio is actually informative in historical data, or whether it's dominated by noise from arb routing.

### Instrument 4: Cross-pool basis (Algebra vs Uni v3)

If both pools exist, the difference in per-unit-liquidity feeGrowth between Algebra and Uni v3 is the "fee adaptation premium." A derivative on this basis is a **vol-of-vol instrument** (it pays when vol spikes enough to activate the Algebra sigmoid, not just when vol exists).

- **Settlement index**: `(feeGrowthAlgebra / liquidityAlgebra) - (feeGrowthUniV3 / liquidityUniV3)` over the period
- **Entirely on-chain**: Both pools are EVM contracts with public state

*What you need to study*: Whether a USDC/DAI pool exists on Uni v3 on Polygon with meaningful liquidity. If not, the comparison must be cross-chain (Algebra on Polygon vs Uni v3 on mainnet), which introduces bridge/settlement complexity.

### Instrument 5: Error correction speed as a health index

The speed at which the USDC/DAI price reverts to 1.0 after a shock is a measure of market health. Faster reversion = more arb capital available = healthier market. A derivative that pays based on the **half-life of deviations** over a period is an instrument for hedging market structure risk.

*What you need to study*: How to define and measure reversion speed purely from on-chain swap data. One approach: for each swap that moves the price away from 1.0, measure the number of blocks until a swap moves it back. The distribution of these "reversion times" IS the health index.

---

## 6. What We Need to Study / Prepare Before Touching Data

### Mathematical prerequisites
- Credit spread dynamics (Duffie-Singleton, Merton) -- the right framework for a near-peg pair
- Variance swap replication theory -- how feeRevenue maps to realized variance
- Sigmoid function analysis -- exact convexity properties of the Algebra fee formula
- Error correction models (Engle-Granger, Johansen) -- for the cointegration structure

### Data prerequisites
- Pool addresses on Polygon (QuickSwap USDC/DAI, and Uniswap USDC/DAI if it exists)
- Full Swap event history with decoded fee at each swap
- feeGrowthGlobal snapshots at regular intervals (or compute from Swap events)
- Algebra volatilityOracle timepoint history (if queryable from archive nodes / Dune)
- Maker PSM state history (is it active? limits? utilization?)
- DAI collateral composition over time

### Conceptual prerequisites
- Precise definition of "volatility" for a mean-reverting near-peg process (this is NOT the same as vol for a random walk -- you need OU-process volatility, not GBM volatility)
- Understanding of the resolution limit (arb friction floor) below which signal is noise
- Understanding of how Algebra's 24h rolling window and per-block update constraint affect the fee's responsiveness to different shock durations
