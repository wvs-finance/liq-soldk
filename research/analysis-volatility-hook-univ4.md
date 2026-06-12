# VolatilityHook-UniV4: Deep Analysis Report

**Date:** 2026-03-29
**Repo Path:** `/home/jmsbpp/apps/liq-soldk-dev/lib/VolatilityHook-UniV4`
**Purpose:** Assess how this ZK-verified realized volatility hook can feed into LP hedge sizing for the liq-soldk project.

---

## 1. Executive Summary

VolatilityHook-UniV4 is a Uniswap V4 dynamic fee hook built by Semiotics (a Brevis/ZK-focused team) that adjusts LP swap fees in real time based on **SNARK-verified realized volatility** of ETH/USDC. The ZK proof system used is **SP1 (Succinct)** -- not Brevis as initially assumed. The circuit computes realized volatility off-chain from Uniswap V3 tick data, produces a proof, and the on-chain verifier accepts the proven RV to update a volatility oracle. The hook's `beforeSwap` callback queries this oracle through a fee calculation library to set dynamic LP fees proportional to RV^2 * volume.

**Key finding for our project:** The ZK-verified RV feed is directly usable as an input to hedge sizing. The on-chain `rv` value from `SnarkBasedVolatilityOracle.getVolatility()` can drive the mapping `RV -> expected IL -> positionSize` in our hedge builder. However, the current implementation has notable limitations: the RV is a single scalar (no term structure), the update cadence is ~50 minutes between proofs, and there is no cross-DEX aggregation -- the data comes from a single Uniswap V3 pool.

---

## 2. Architecture Overview

```
Off-chain SP1 Program (Rust/RISC-V)
  |-- Reads Uniswap V3 tick observations
  |-- Computes: s2 = (1/(n-1)) * sum((tick_i - tick_mean)^2)  [sample variance of tick deltas]
  |-- Outputs: (n_inv_sqrt, n1_inv, s2, n, digest) as public values
  |-- Generates SP1 proof
  v
SnarkBasedVolatilityOracle.verifyAndUpdate(claimed_s, proof, publicValues)
  |-- RvVerifier.verifyRvProof() -> SP1Verifier.verifyProof()
  |-- On-chain bounds checks: s2_check, n1_check, n_sqrt_test
  |-- rv = claimed_s * ln(1.0001) >> 40   [convert from tick-log to natural-log base]
  v
CalcFeeLib.getFee(volume, sqrtPriceX96)
  |-- Queries oracle.getVolatility() for rv
  |-- fee_per_lot = MIN_FEE + 2 * scaled_volume * (rv / LONG_ETH_VOL_FIXED)^2
  |-- Converts to basis points relative to pool price
  v
OracleBasedFeeHook.beforeSwap()
  |-- Calls calcLib.getFee(volume, sqrtPriceX96)
  |-- poolManager.updateDynamicLPFee(key, fee)
```

---

## 3. Detailed Component Analysis

### 3.1 RvVerifier (ZK Proof Verification Layer)

**File:** `src/RvVerifier.sol` (lines 1-35)

- Inherits from `SP1Verifier` (Succinct's on-chain SNARK verifier)
- Stores a `programKey` (bytes32) that identifies the specific SP1 program (circuit)
- `verifyRvProof(proof, publicValues)` calls `this.verifyProof(programKey, publicValues, proof)` and ABI-decodes:
  - `n_inv_sqrt` (bytes8): fixed-point 1/sqrt(n) where n = number of observations
  - `n1_inv` (bytes8): fixed-point 1/(n-1)
  - `s2` (bytes8): fixed-point sample variance of tick deltas (sigma^2 in tick space)
  - `n_bytes` (bytes8): number of observations
  - `digest` (bytes32): commitment to the input data (Uniswap V3 observations)

**Key detail:** The `programKey` is mutable via `setProgramKey()` with **no access control** -- this is a security concern (anyone can change the verification key).

### 3.2 SnarkBasedVolatilityOracle (Core Oracle)

**File:** `src/SnarkBasedVolatilityOracle.sol` (lines 1-81)

**Fixed-point arithmetic:** Uses 40 fractional bits throughout (constant `fraction_bits = 40`).

**RV computation methodology:**

The circuit computes sample variance of tick deltas in Uniswap's log_1.0001 space. The on-chain contract then:

1. Verifies the SP1 proof
2. Validates claimed_s against proven s2 using error bounds:
   - `s2_check`: verifies `claimed_s^2 ~= s2` within `+/- (2*claimed_s + 1)` error (one unit of fixed-point precision)
3. Validates auxiliary values n_inv_sqrt and n1_inv against n
4. Converts from tick-log base to natural-log base:

```
rv = claimed_s * ln_1_0001 >> fraction_bits
```

where `ln_1_0001 = 109945666` (this is ln(1.0001) in Q40 fixed point: 109945666 / 2^40 ~ 0.00009999... which matches ln(1.0001) = 9.9995e-5).

**The resulting `rv` is the realized volatility (standard deviation) of log-returns, expressed as a fixed-point Q40 number.**

**State:**
- `s` (uint256): claimed standard deviation in tick space (Q40)
- `rv` (uint256): realized volatility in natural-log space (Q40)

**Escape hatch:** `setVolatility(uint256 _rv)` allows owner to manually override RV -- useful but undermines trustlessness.

### 3.3 CalcFeeLib (Fee Calculation)

**File:** `src/Calc/CalcFeeLib.sol` (lines 1-67)

**Fee formula (reconstructed):**

```
scaled_volume = volume / ETH_VOL_SCALE       (ETH_VOL_SCALE = 150)
scaled_vol = rv / LONG_ETH_VOL_FIXED         (LONG_ETH_VOL_FIXED ~ 0.708 in real units)
fee_per_lot = MIN_FEE + 2 * scaled_volume * scaled_vol^2
```

Where:
- `MIN_FEE = 2 ether` (2e18, in Q40 fixed point, so ~2e18 * 2^40 raw)
- `LONG_ETH_VOL_FIXED = 777943209666519 << 40` -- this is approximately 0.708 (long-run ETH volatility estimate) scaled into Q40
- The fee is quadratic in RV: `fee ~ rv^2`, which aligns with the theoretical relationship between variance and IL

**Conversion to basis points:**
```
fee_bips = 10000 * fee_per_lot / price
```

This means the fee is expressed as a fraction of the trade notional, scaled by 10,000 to get basis points.

**Test data confirms:** At RV=710903863 (~0.000646 in real terms, annualized ~1.2%) and volume=1 ETH, fee=3858417325538. At 150 ETH volume and sqrtPrice corresponding to ~3700 USDC/ETH, this yields 13 bips.

### 3.4 OracleBasedFeeHook (V4 Hook)

**File:** `src/OracleBasedFeeHook.sol` (lines 1-94)

**Hook callbacks used:**
- `beforeInitialize`: Validates pool uses dynamic fee (`key.fee.isDynamicFee()`)
- `beforeSwap`: Core logic -- reads current sqrtPriceX96 and swap amount, calls CalcFeeLib to compute fee, updates pool's dynamic LP fee

**Hook permissions (from getHookPermissions):**
- `beforeInitialize: true`
- `beforeSwap: true`
- All others: false

**Fee update mechanism:**
The hook does NOT store state per-pool. On every swap, it:
1. Gets current pool price from `poolManager.getSlot0(poolId)`
2. Encodes `(abs(amountSpecified), sqrtPriceX96)` as calldata
3. Calls `calcLib.getFee(feeData)` which internally queries the oracle
4. Calls `poolManager.updateDynamicLPFee(key, fee)`

This means the fee is re-computed on every single swap, always reflecting the latest oracle RV.

---

## 4. RV Computation Methodology

### 4.1 Data Source

The SP1 circuit reads **Uniswap V3 tick observations** (the on-chain oracle array in V3 pools). From the fixture data:
- Fixture 1: n = 8699335998963712 >> 40 = **7909 observations** (n raw is Q40)
- Fixture 2: n = 7621814603743232 >> 40 = **6929 observations**
- Fixture 3: n = 7636108254904320 >> 40 = **6942 observations**

These are large observation counts, suggesting the circuit reads the full observation buffer.

### 4.2 Formula

The circuit computes the **sample standard deviation of tick deltas**:

```
s^2 = (1/(n-1)) * SUM_i (delta_tick_i - mean_delta_tick)^2
```

where `delta_tick_i = tick_{i+1} - tick_i` represents the log-return in tick space.

The on-chain conversion to natural-log RV is:
```
rv = s * ln(1.0001)
```

This is because ticks in Uniswap are spaced by `log_1.0001(price)`, so converting to natural log requires multiplying by `ln(1.0001)`.

### 4.3 Time Window

From the volatility_updates.json data:
- Updates span July-August 2024 (timestamps 1721854560 to 1724888400)
- Update frequency: approximately every ~3000-3100 seconds (~50 minutes) between consecutive updates
- Some gaps of ~75,000 seconds (~21 hours) between batches suggest periodic proof generation jobs

### 4.4 Observed RV Values

From the historical data (168 updates), RV values range:
- Low regime: ~360,000,000 (~0.000327 in real terms)
- Normal regime: ~600,000,000-1,000,000,000 (~0.00055-0.00091)
- High regime (Aug 5-6 crash): ~4,650,000,000 (~0.00423 -- about 7x normal)
- Corresponding fee bips range: 10-169 bips (the 169-bip spike matches the Aug 5 ETH crash)

---

## 5. Circuit/Proof Structure

### 5.1 SP1 Program (Off-chain)

The SP1 program (RISC-V binary) is **not included in this repository**. Only the on-chain verifier contracts are present. The program is identified by its verification key (vkey):
- Fixture 1 vkey: `0x00dc70908ac47157cd47feacd62a458f405707ffbcea526fcd5620aedd5d828d`
- Fixture 2 vkey: `0x00c34724e8e40995f870ac2363f557e7d26cdc16c152f064fa495641a3f51676`
- Fixture 3 vkey: `0x00549123d8ece1b8d01de30bc5e07a825a5a73c00007b5150668ebcd44b119e7`

Note: different vkeys suggest the program was iterated/updated between proof generations.

### 5.2 Public Values Layout

From the proof fixtures, the ABI-encoded public values are:
```
(bytes8 n_inv_sqrt, bytes8 n1_inv, bytes8 s2, bytes8 n_bytes, bytes32 digest)
```

The `digest` is a commitment hash to the input data (likely a Merkle root or hash of the Uniswap V3 observation array), providing data integrity but **no on-chain verification that this digest matches actual on-chain state**. This is a trust assumption -- one must trust that the SP1 prover read correct blockchain data.

### 5.3 Verification Flow

1. SP1Verifier checks the SNARK proof against the programKey and publicValues
2. SnarkBasedVolatilityOracle performs **additional on-chain arithmetic checks**:
   - `s2_check`: claimed_s^2 matches proven s2 within fixed-point rounding
   - `n1_check`: n1_inv * (n-1) approximates 1.0
   - `n_sqrt_test`: n_inv_sqrt^2 * n approximates 1.0

These extra checks serve to validate that the auxiliary values (which the circuit exposes as public outputs for efficiency) are consistent. The circuit proves the variance s2, and the contract accepts a claimed square root `claimed_s` and verifies it on-chain rather than computing the square root in-circuit.

---

## 6. Cross-DEX Volatility Aggregation

**Finding: There is no cross-DEX aggregation in this codebase.**

Despite the initial description mentioning "realized volatility of ETH/USDC across DEXes," the actual implementation reads observations from a **single Uniswap V3 pool**. The `digest` in the public values commits to one set of observations. The subgraph query in `fetch_fees.py` also queries a single subgraph endpoint.

The architecture is extensible to cross-DEX aggregation by:
1. Modifying the SP1 program to read observations from multiple pools
2. Including multiple digests in the public values
3. Computing a volume-weighted or liquidity-weighted combined RV

But this is not implemented.

---

## 7. Integration Assessment: ZK-Verified RV for Hedge Sizing

### 7.1 Direct Usability

The `SnarkBasedVolatilityOracle.getVolatility()` function returns `rv` as a Q40 fixed-point value representing the standard deviation of log-returns (in natural-log space). This is directly usable for:

**RV to Expected IL:**
Under the Deng-Zong-Wang framework (Prop 3.5), IL is decomposed as:
```
IL = UIL^R (call-replicable) + UIL^L (put-replicable)
```

Both components depend on the price process volatility sigma. The ZK-verified RV provides exactly this sigma estimate. Specifically:

```
Expected |IL| ~ sigma^2 * T / 2   (for concentrated LP near current price)
```

So: `positionSize = hedgeNotional / (sigma^2 * T * f(K, tickRange))`

where `sigma = rv` from the oracle and `f` captures the strike-grid weighting K^{-3/2}.

### 7.2 Integration Path

```solidity
// In HedgeBuilder or ILOracle
IVolatilityOracle volatilityOracle = IVolatilityOracle(snarkOracleAddress);
uint256 rv = volatilityOracle.getVolatility();  // Q40 fixed-point

// Convert to expected IL magnitude for position sizing
// rv is sigma (annualized would need time-scaling)
uint256 rv_squared = (rv * rv) >> 40;  // sigma^2 in Q40
uint256 expectedIL = (rv_squared * timeHorizon) >> 1;  // sigma^2 * T / 2
uint256 hedgeLots = targetCoverage / expectedIL;
```

### 7.3 Limitations for Hedge Sizing

1. **No term structure:** A single scalar RV has no time-horizon awareness. For hedge sizing, you need RV estimates at different horizons (1-hour RV vs 1-day RV vs 1-week RV). The current oracle provides one aggregate number.

2. **Update latency:** ~50-minute update frequency means the RV feed is stale during rapid market moves. The August 5 crash data shows a jump from ~840M to ~4650M between two consecutive updates -- during the gap, hedges would be under-sized.

3. **No confidence interval:** The RV is a point estimate. Hedge sizing benefits from knowing the estimation error (which the circuit could provide via n_inv_sqrt but doesn't expose as a usable confidence bound).

4. **Single-pool data source:** RV from one V3 pool may not represent the volatility experienced by positions in other pools or on V4.

5. **Fixed-point precision:** Q40 with 40 fractional bits gives ~10 decimal digits of precision, which is sufficient for financial calculations.

### 7.4 Recommended Integration Architecture

```
SnarkBasedVolatilityOracle (existing)
  |
  v
VolatilityAdapter (new - to build)
  |-- Converts Q40 rv to the format needed by LeftRightILX96
  |-- Applies time-scaling: sigma_T = rv * sqrt(T / T_sample)
  |-- Optionally applies a vol-of-vol multiplier for conservative hedging
  v
HedgeBuilder.computeHedgeSize(rv, K_grid, tickRange)
  |-- Uses rv^2 to estimate expected IL per tick
  |-- Discretizes into option legs at strike grid with K^{-3/2} weighting
  |-- Calls PanopticPool.mintOptions() for settlement
```

---

## 8. Code Quality Assessment

### 8.1 Strengths

- **Clean separation of concerns:** Oracle, fee calculation, and hook logic are properly separated behind interfaces (IVolatilityOracle, ICalcFee)
- **Pluggable CalcFeeLib:** The hook takes a generic ICalcFee, allowing fee formula upgrades without redeploying the hook
- **Comprehensive test fixtures:** Three separate proof fixtures with real mainnet data
- **Python tooling:** Subgraph fetching, encoding scripts, and Jupyter notebook for validation

### 8.2 Weaknesses and Concerns

1. **Missing access control on RvVerifier.setProgramKey()** (line 17): Anyone can change the verification key, which would allow accepting proofs from a different (potentially malicious) program. This is a critical vulnerability.

2. **Owner override on SnarkBasedVolatilityOracle.setVolatility()** (line 78): Bypasses the entire ZK proof system. The owner can set arbitrary RV values.

3. **No staleness check:** `getVolatility()` returns whatever the last proven RV was, even if the proof is days old. A timestamp should be stored and checked.

4. **No data freshness verification:** The `digest` in the public values is not verified against any on-chain state root. The prover could submit a proof for historical data and the contract would accept it.

5. **Hardcoded constants in CalcFeeLib:**
   - `LONG_ETH_VOL_FIXED` embeds a long-run ETH volatility estimate as a normalization factor
   - `ETH_VOL_SCALE = 150` is a magic number (appears to be a volume scaling factor in ETH units)
   - These would need recalibration for different pairs or market regimes

6. **Test completeness:** The `OracleBasedFeeHook.t.sol` test file references undefined variables (`SUSDC_ADDRESS`, `SETH_ADDRESS`, `hook`) -- it appears incomplete/broken. The `CalcFeeLibTest.t.sol` and `SP1VerifyRv.t.sol` are more functional.

7. **SP1 program source absent:** The actual circuit code (Rust program compiled to RISC-V) is not in this repo, making it impossible to audit what exactly is being proven.

---

## 9. Novel Patterns Worth Adopting

### 9.1 Hybrid On-chain/ZK Verification

The pattern of having the ZK circuit prove the expensive computation (variance of thousands of observations) while performing cheap verification checks on-chain (square-root validation via `s2_check`) is elegant. The circuit outputs `s2` and the contract accepts `claimed_s` and verifies `s^2 ~= s2` -- avoiding in-circuit square root computation.

**Applicability:** For our IL oracle, we could use a similar pattern where the ZK circuit proves the integral of IL over a price path, and the on-chain contract validates boundary conditions.

### 9.2 Fixed-Point Convention

The consistent use of Q40 fixed-point throughout the stack (oracle, fee lib, proof public values) with the `fraction_bits = 40` constant is a clean pattern. Our project should adopt a consistent fixed-point standard -- Q96 is already used in Uniswap, so bridging between Q40 (RV oracle) and Q96 (price space) will need careful handling.

### 9.3 Dynamic Fee via beforeSwap

The pattern of computing fees dynamically in `beforeSwap` by querying an external oracle is directly applicable to our hook design. We could extend this to make hedge-related adjustments (e.g., adjusting fees to fund the hedge program).

---

## 10. Summary and Recommendations

### For liq-soldk Integration

| Aspect | Assessment | Action |
|--------|-----------|--------|
| RV feed usability | High -- directly provides sigma for IL estimation | Integrate via IVolatilityOracle interface |
| Data quality | Medium -- single pool, ~50min latency | Acceptable for position sizing; not for real-time hedging triggers |
| Trust model | Medium -- SP1 proof is sound but data freshness unverified | Add staleness check; verify digest against state root |
| Code reuse | High -- clean interfaces, pluggable design | Fork CalcFeeLib pattern for our HedgeSizingLib |
| Missing pieces | SP1 program source, cross-DEX aggregation, term structure | Build our own or request from Semiotics |

### Immediate Next Steps

1. **Write a VolatilityAdapter contract** that wraps `IVolatilityOracle` and provides time-scaled RV for hedge sizing with staleness protection.

2. **Map the Q40 rv to LeftRightILX96 inputs:** Determine the exact conversion from `rv` (Q40 natural-log sigma) to the sigma parameter needed by the IL decomposition in Prop 3.5.

3. **Evaluate whether to deploy the existing oracle or build a custom one:** The existing oracle is functional but has security gaps (setProgramKey access control, no staleness). A hardened fork would be appropriate.

4. **Investigate obtaining the SP1 program source** from Semiotics to audit and potentially extend for cross-DEX aggregation and term structure.

---

## 11. File Reference

| File | Purpose | Lines |
|------|---------|-------|
| `src/OracleBasedFeeHook.sol` | V4 hook with beforeInitialize + beforeSwap | 94 |
| `src/SnarkBasedVolatilityOracle.sol` | ZK-verified RV oracle with SP1 proofs | 81 |
| `src/RvVerifier.sol` | SP1 proof verification base contract | 35 |
| `src/Calc/CalcFeeLib.sol` | Fee = f(volume, rv, price) in bips | 67 |
| `src/interfaces/IVolatilityOracle.sol` | Oracle interface (getVolatility, getPrice) | 7 |
| `src/interfaces/ICalcFee.sol` | Fee calculator interface | 8 |
| `src/interfaces/IFeeOracle.sol` | Fee oracle interface (unused in main flow) | 8 |
| `src/interfaces/IAggregatorV3.sol` | Chainlink-style price feed interface | 20 |
| `src/fixtures/fixture.json` | SP1 proof fixture with ~7909 observations | -- |
| `src/fixtures/fixture2.json` | SP1 proof fixture with ~6929 observations | -- |
| `src/fixtures/fixture3.json` | SP1 proof fixture with ~6942 observations | -- |
| `notes/volatility_updates.json` | 168 historical RV updates from subgraph | -- |
| `notes/fees.json` | Computed fee bips for each RV update | -- |
| `test/SP1VerifyRv.t.sol` | Proof verification tests | 97 |
| `test/CalcFeeLibTest.t.sol` | Fee calculation tests with mock oracle | 120 |
| `script/DeploymentScript.s.sol` | Full deployment: tokens, oracle, hook, pool | 138 |
| `script/python/fetch_fees.py` | Subgraph query for RV update history | 63 |
