# Research: Algebra Protocol Pools with ALL Plugins Enabled

**Date**: 2026-03-31
**Status**: Comprehensive research report
**Relevance**: Identifying which Algebra-powered DEX pools have the full plugin suite active for macro-observable extraction (volatility, TWAP, dynamic fees as signals)

---

## Executive Summary

Algebra Integral (V4) is a modular concentrated liquidity AMM powering 50+ DEXes across 70+ chains. Its plugin architecture separates critical liquidity storage (Core) from peripheral functionality (Plugins), allowing hot-swappable feature modules. The "standard plugin" (BasePluginV1) bundles three core modules -- TWAP Oracle, Adaptive Fee, and Farming Proxy -- into a single contract deployed per pool. However, the critical finding is that **only one plugin can be attached to a pool at any time**. DEXes that want multiple features (e.g., adaptive fees + limit orders + sliding fees) must use a combined/proxy plugin that embeds all desired modules. Most Algebra DEXes deploy the standard BasePluginV1 with TWAP oracle + adaptive fees + farming. Newer DEXes (Camelot V4, THENA V3,3, SwapX) are deploying enhanced plugins that add sliding fees, limit orders, and anti-snipe features.

For our macro-observable use case, the key data sources are:
- **volatilityCumulative** from the TWAP oracle module (active in all standard-plugin pools)
- **Dynamic fee level** as a real-time volatility proxy (readable from any pool with DYNAMIC_FEE flag)
- **Tick accumulators** for TWAP price feeds (active in all pools with the oracle module)

---

## 1. Algebra Plugin Architecture -- Complete Technical Reference

### 1.1 Core + Plugin Separation

Algebra Integral splits the AMM into:

- **Core**: Immutable. Handles liquidity storage, swap math, position management. Cannot be changed without liquidity migration.
- **Plugin**: Peripheral smart contract connected to a pool. Can be replaced, upgraded, or disconnected without touching liquidity. Communicates with the pool via **hooks** (callbacks before/after pool actions).

**Critical constraint**: Only ONE plugin contract can be attached to a pool at any time. To combine features, a single plugin must implement all desired modules internally (or use a proxy plugin pattern, which is planned but not yet standard).

### 1.2 The pluginConfig Bitmap -- All 8 Flags

The plugin configuration is stored as a `uint8` bitmap in the pool's global state. Each bit controls a specific hook or feature. From the source code at `lib/Algebra/src/core/contracts/libraries/Plugins.sol`:

```
Bit 0 (1):     BEFORE_SWAP_FLAG          -- Call plugin before every swap
Bit 1 (2):     AFTER_SWAP_FLAG           -- Call plugin after every swap
Bit 2 (4):     BEFORE_POSITION_MODIFY_FLAG -- Call plugin before any mint/burn
Bit 3 (8):     AFTER_POSITION_MODIFY_FLAG  -- Call plugin after any mint/burn
Bit 4 (16):    BEFORE_FLASH_FLAG         -- Call plugin before flash loans
Bit 5 (32):    AFTER_FLASH_FLAG          -- Call plugin after flash loans
Bit 6 (64):    AFTER_INIT_FLAG           -- Call plugin after pool initialization
Bit 7 (128):   DYNAMIC_FEE               -- Enable dynamic fee logic (plugin sets fee)
```

A pool with ALL hooks and dynamic fee enabled would have pluginConfig = `0xFF` (255). In practice, most plugins only activate the hooks they need.

### 1.3 The Standard Plugin: BasePluginV1

The default plugin shipped by Algebra bundles three modules:

**Default pluginConfig**: `AFTER_INIT_FLAG | BEFORE_SWAP_FLAG | DYNAMIC_FEE` = 0b11000001 = **193**

This means by default:
- afterInitialize hook: active (sets up oracle on pool init)
- beforeSwap hook: active (recalculates and sets adaptive fee before each swap, writes oracle timepoint)
- DYNAMIC_FEE: active (pool reads fee from plugin instead of using static fee)

**Not activated by default**: AFTER_SWAP, BEFORE/AFTER_POSITION_MODIFY, BEFORE/AFTER_FLASH

The three internal modules:

| Module | Purpose | Hooks Used |
|--------|---------|------------|
| **TWAP Oracle** (VolatilityOracle.sol) | Stores price timepoints, computes tickCumulative, volatilityCumulative, averageTick | AFTER_INIT, BEFORE_SWAP |
| **Adaptive Fee** (AdaptiveFee.sol) | Calculates fee from double-sigmoid function of volatility | BEFORE_SWAP, DYNAMIC_FEE |
| **Farming Proxy** | Connects to AlgebraEternalFarming for LP incentives via virtual pool | BEFORE_SWAP (routes to virtual pool), AFTER_POSITION_MODIFY (when incentive connected) |

### 1.4 All Known Algebra Plugins (from Plugin Marketplace + ecosystem)

| Plugin | Description | Status | Key DEXes |
|--------|-------------|--------|-----------|
| **Standard Plugin (BasePluginV1)** | TWAP oracle + adaptive fee + farming proxy | Default on all pools | All Algebra DEXes |
| **Sliding Fee Plugin** | Adjusts fees based on swap direction relative to last block's price movement; up to 15% LP revenue increase | Production | Swapsicle, KIM, THENA, Camelot, SwapX, Fenix, YAKA |
| **Limit Order Plugin** | On-chain limit orders executed when price crosses specified tick | Production | Camelot, and available in marketplace |
| **Anti-Snipe Plugin** | Blocks trading until governance-set time; applies high fee to early trades post-launch (up to 90%) | Production | SwapX |
| **Brevis ZK Dynamic Fee Plugin** | Volume-based dynamic fees using Brevis ZK coprocessor; VIP fee discounts based on historical trading volume | Production | THENA |
| **Safety Switch Plugin** | Emergency kill switch for pool operations | Available in marketplace | On-demand |
| **Whitelist Fee Discount Plugin** | Fee discounts for whitelisted addresses | Available in marketplace | On-demand |
| **Managed Swap Fee Plugin** | Admin-managed manual fee setting | Available in marketplace | On-demand |
| **Dynamic Fee Based on Trading Volume** | Adjusts fees based on pool trading volume metrics | Available in marketplace | On-demand |
| **Stub Plugin (AlgebraStubPlugin)** | Minimal no-op plugin for pools that want no peripheral features | Available | Testing/minimal pools |

### 1.5 Plugin Architecture Implications

Since only ONE plugin per pool is allowed, "all plugins enabled" means a **combined plugin** that internally implements multiple modules. The standard BasePluginV1 already combines oracle + adaptive fee + farming. The limit-order variant (in the local codebase at `lib/algebra-plugins/src/plugin/limit-order/`) extends BasePluginV1 with limit order logic while retaining all three base modules.

DEXes like Camelot that advertise "adaptive fee + sliding fee + limit orders + TWAP" are running a custom combined plugin that merges these modules into a single contract.

---

## 2. Algebra-Powered DEXes -- Complete Catalog

### 2.1 Version Classification

Algebra has shipped multiple protocol generations:

| Version | Architecture | Plugin Support | Notable Features |
|---------|-------------|----------------|------------------|
| **Algebra V1.0** | Monolithic concentrated liquidity | No plugins | Built-in dynamic fees, oracle, farming |
| **Algebra V1.9** | Monolithic with improvements | No plugins | Changeable tick spacing, directional fees |
| **Algebra V2.0** | Monolithic with directional fees | No plugins | Separate buy/sell fees |
| **Algebra Integral 1.0** | Modular Core + Plugin | Yes (V4) | First plugin-based version |
| **Algebra Integral 1.1** | Modular Core + Plugin | Yes | Improvements |
| **Algebra Integral 1.2** | Modular Core + Plugin | Yes | Disables hooks during plugin-to-pool calls (anti-recursion), latest stable |
| **Algebra Integral 1.2.1/1.2.2** | Modular Core + Plugin | Yes | Patch releases |

### 2.2 Complete DEX-by-Version Matrix

#### Algebra V1.0 (Pre-Plugin Era -- NO plugin architecture)

| DEX | Chain | TVL Estimate | Notes |
|-----|-------|-------------|-------|
| QuickSwap V3 | Polygon PoS | ~$451M+ | Largest Algebra V1 deployment. Has built-in dynamic fees and oracle (not plugin-based) |
| QuickSwap | Polygon zkEVM | Lower | Same V1 codebase |
| QuickSwap | Dogechain | Minimal | Legacy deployment |
| THENA (legacy) | BNB Chain | See V3,3 below | Original deployment, now migrating to Integral |
| StellaSwap (legacy) | Moonbeam | ~$10-20M | Originally V1, upgrading to Integral 1.2 |

#### Algebra V1.9 (Pre-Plugin Era -- NO plugin architecture)

| DEX | Chain | Notes |
|-----|-------|-------|
| Camelot (legacy V3) | Arbitrum | Original Algebra V1.9 deployment; now has V4 |
| Lynex | Linea | V1.9 base; may have upgraded |
| SwapBased | Base | V1.9 |
| SynthSwap | Base | V1.9 |
| ZyberSwap | Optimism | V1.9 |
| Hercules | Metis | Listed under V1.9 in docs, but also under Integral 1.0 |

#### Algebra Integral 1.0 (FIRST version with plugin support)

| DEX | Chain | Plugin Support | Key Plugins Deployed |
|-----|-------|---------------|---------------------|
| **SwapX** | Sonic (FTM) | Full plugin support | Standard + Sliding Fee + Anti-Snipe |
| **KIM** | Mode Network | Full plugin support | Standard + Sliding Fee |
| **Fenix Finance** | Blast | Full plugin support | Standard + Sliding Fee |
| **BladeSwap** | Blast | Full plugin support | Standard |
| **Hercules** | Metis | Full plugin support | Standard |
| **Swapsicle** | Telos, Mantle | Full plugin support | Standard + Sliding Fee (early adopter) |
| **SilverSwap** | Fantom, Sonic | Full plugin support | Standard |
| **Horizon** | Various | Full plugin support | Standard |
| **Glyph Exchange** | Various | Full plugin support | Standard |
| **Bulla** | Various | Full plugin support | Standard |

#### Algebra Integral 1.2 (Latest version, best plugin support)

| DEX | Chain | Plugin Support | Key Plugins Deployed |
|-----|-------|---------------|---------------------|
| **Camelot V4** | Arbitrum | Full plugin support | Adaptive Fee + Sliding Fee + Limit Orders + TWAP Oracle |
| **THENA V3,3** | BNB Chain, opBNB | Full plugin support | Volatility-based fees + Sliding Fee + Brevis ZK fee + TWAP Oracle |
| **StellaSwap V4** | Moonbeam | Full plugin support | Standard (dynamic fees, limit orders mentioned) |
| **Fibonacci** | Various | Full plugin support | Standard |
| **Voltage** | Fuse | Full plugin support | Standard |
| **Henjin** | Various | Full plugin support | Standard |
| **Wasabee** | Various | Full plugin support | Standard |
| **MorFi** | Various | Full plugin support | Standard |
| **TrebleSwap** | Various | Full plugin support | Standard |
| **QuickSwap Soneium** | Soneium | Full plugin support | Standard |
| **YAKA Finance** | Various | Full plugin support | Standard + Sliding Fee (planned) |

### 2.3 DEXes with the RICHEST Plugin Suite

Based on research, the DEXes with the most comprehensive plugin deployments:

**Tier 1 -- Maximum Plugin Coverage**:

1. **Camelot V4** (Arbitrum) -- Integral 1.2
   - Adaptive Fee (volatility-based)
   - Sliding Fee (directional arbitrage protection)
   - Limit Orders (on-chain)
   - TWAP Oracle
   - Farming

2. **THENA V3,3** (BNB Chain) -- Integral 1.2
   - Volatility-based dynamic fees
   - Sliding Fee
   - Brevis ZK dynamic fee (volume-based VIP discounts)
   - TWAP Oracle
   - Farming

3. **SwapX** (Sonic) -- Integral 1.0
   - Standard adaptive fee
   - Sliding Fee
   - Anti-Snipe plugin
   - TWAP Oracle
   - Farming

**Tier 2 -- Standard + Sliding Fee**:

4. **KIM** (Mode Network) -- Integral 1.0
5. **Swapsicle** (Telos, Mantle) -- Integral 1.0
6. **Fenix Finance** (Blast) -- Integral 1.0

**Tier 3 -- Standard Plugin Only (Oracle + Adaptive Fee + Farming)**:

7. **Hercules** (Metis)
8. **BladeSwap** (Blast)
9. **StellaSwap V4** (Moonbeam)
10. All other Integral DEXes

---

## 3. Pools with Full Plugin Suite -- Key Pairs

### 3.1 Camelot V4 (Arbitrum) -- Richest Plugin Suite

Camelot is the largest Algebra DEX on Arbitrum with significant TVL. Their V4 pools include:

**High-TVL pairs (estimated from ecosystem data)**:
- ETH/USDC -- Highest volume pair
- ETH/USDT
- ETH/ARB
- ARB/USDC
- USDC/USDT (stablecoin)
- wstETH/ETH (LST pair)
- GRAIL/ETH (native token)
- GMX/ETH

**Stablecoin pairs**: USDC/USDT is the primary stablecoin pair. Camelot's concentrated liquidity model makes these attractive with narrow range LP.

**EM Stablecoin pairs**: No dedicated EM stablecoin pairs identified on Camelot. Arbitrum's stablecoin landscape is dominated by USDC and USDT.

### 3.2 THENA V3,3 (BNB Chain) -- Richest Plugin Suite

THENA's V3,3 launched May 2025 with full Algebra Integral + Brevis ZK plugins.

**Key pairs (BNB Chain)**:
- BNB/USDT -- Highest volume
- BNB/USDC
- ETH/BNB
- USDT/USDC (stablecoin, leveraging Curve-style efficiency)
- THE/BNB (native token)
- BTCB/BNB

**Stablecoin landscape**: BNB Chain has $9.0B USDT and $1.3B USDC as of Q4 2025. THENA's hybrid AMM merges concentrated liquidity with Curve-style stable pools.

**EM relevance**: BNB Chain has some regional stablecoin activity but no dedicated EM stablecoin CFMM pairs identified on THENA specifically.

### 3.3 SwapX (Sonic) -- Anti-Snipe + Sliding Fee

SwapX is the native liquidity layer for Sonic (formerly Fantom).

**Key pairs (Sonic)**:
- S/USDC (native token/stablecoin)
- S/USDT
- ETH/USDC
- wstETH/ETH

**TVL**: Still early (~$612K TVL for Algebra portion). Sonic ecosystem is nascent but growing.

### 3.4 QuickSwap V3 (Polygon) -- Legacy but Largest

QuickSwap on Polygon runs Algebra V1.0 (NOT Integral). It does NOT have the plugin architecture. However, it has **built-in** dynamic fees and oracle functionality baked into the core contracts (pre-modular era).

**Key pairs** (Polygon's largest DEX, ~$451M TVL):
- MATIC(POL)/USDC
- MATIC/USDT
- ETH/USDC
- USDC/USDT
- ETH/MATIC
- WBTC/ETH

**EM stablecoin pairs**: Polygon has strong stablecoin activity ($3.28B stablecoin supply). QuickSwap may have pairs with EURS or other regional stablecoins, but these are not prominently featured.

**Important**: QuickSwap's oracle and dynamic fee data is accessible from the pool contract directly (not via plugin) since it's V1.0. The data structures (tickCumulative, volatilityCumulative) are equivalent but accessed differently.

---

## 4. Plugin-Specific Data

### 4.1 Dynamic Fee Configuration

The adaptive fee module uses a double-sigmoid function:

```
fee = baseFee + sigmoid1(volatility) + sigmoid2(volatility)
```

**Default parameters** (from `AdaptiveFee.sol` in the local codebase):

| Parameter | Default Value | Description |
|-----------|--------------|-------------|
| baseFee | 100 (0.01%) | Minimum possible fee in hundredths of a bip (1e-6) |
| alpha1 | 2900 | Max value of first sigmoid (adjusts to 3000 - baseFee) |
| alpha2 | 12000 | Max value of second sigmoid (adjusts to 15000 - 3000) |
| beta1 | 360 | X-axis shift for first sigmoid (volatility threshold) |
| beta2 | 60000 | X-axis shift for second sigmoid (high volatility threshold) |
| gamma1 | 59 | Horizontal stretch for first sigmoid |
| gamma2 | 8500 | Horizontal stretch for second sigmoid |

**Fee range**:
- **Minimum fee**: baseFee = 100 hundredths of a bip = **0.01%** (1 bip)
- **Maximum fee**: baseFee + alpha1 + alpha2 = 100 + 2900 + 12000 = **15000 hundredths of a bip = 1.5%** (150 bips)
- Constrained by: `baseFee + alpha1 + alpha2 <= type(uint16).max` (65535)

**Fee as macro signal**: The current fee is directly readable from any pool with DYNAMIC_FEE enabled via `pool.fee()` or the plugin's fee calculation. Since the fee is a monotonic function of 24-hour volatility, **the fee itself IS a volatility signal** -- higher fee = higher recent volatility. This is extremely useful as a macro observable.

### 4.2 TWAP Oracle Data

The oracle stores `Timepoint` structs in a circular buffer of 65536 entries:

```solidity
struct Timepoint {
    bool initialized;
    uint32 blockTimestamp;
    int56 tickCumulative;          // tick * elapsed time (for TWAP price)
    uint88 volatilityCumulative;   // cumulative standard deviation
    int24 tick;                    // tick at this timestamp
    int24 averageTick;             // average tick over WINDOW (1 day)
    uint16 windowStartIndex;       // pointer to oldest timepoint within window
}
```

**Key accumulators**:
- `tickCumulative`: Standard Uniswap V3-style tick accumulator for TWAP computation
- `volatilityCumulative`: Cumulative volatility (standard deviation) -- unique to Algebra
- `averageTick`: Moving average tick over the 1-day WINDOW

**Reading TWAP**: Call `getTimepoints(uint32[] secondsAgos)` on the plugin contract (Integral) or pool contract (V1.0). Returns arrays of tickCumulatives, volatilityCumulatives.

**Volatility window**: The oracle uses a 1-day (86400 seconds) window, defined as `WINDOW = 1 days` in VolatilityOracle.sol.

### 4.3 volatilityCumulative -- Active Status

`volatilityCumulative` is tracked in **every pool that has the standard plugin (BasePluginV1) connected**, which is the vast majority of Algebra Integral pools. For V1.0 pools (QuickSwap Polygon), the equivalent accumulator is built into the core contract.

**How it works**: On every swap (via the BEFORE_SWAP hook), the oracle writes a new timepoint that includes the cumulative volatility. The volatility is computed as the standard deviation of tick changes over the 1-day window.

**Which pools have it active**: Essentially all pools on:
- Camelot V4 (Arbitrum)
- THENA V3,3 (BNB Chain)
- SwapX (Sonic)
- KIM (Mode)
- Fenix (Blast)
- Swapsicle (Telos, Mantle)
- Hercules (Metis)
- StellaSwap V4 (Moonbeam)
- QuickSwap (Polygon -- built-in, not plugin)
- All other Integral DEXes with standard plugin

### 4.4 Farming Status

Farming is activated per-pool when an incentive is connected to the plugin via the `setIncentive()` function. Not all pools have active farming incentives -- this is governed by each DEX's governance/emissions schedule.

DEXes with active farming programs (as of Q1 2026):
- QuickSwap (Polygon) -- extensive farming program
- Camelot (Arbitrum) -- xGRAIL incentives
- THENA (BNB Chain) -- ve(3,3) emissions model
- SwapX (Sonic) -- SWPX incentives
- Lynex (Linea) -- LYNX incentives

---

## 5. Macro-Observable Capabilities

### 5.1 volatilityCumulative as a Macro Signal

**Availability**: Active in every pool with the standard plugin (all Integral DEXes) and all V1.0 pools (QuickSwap).

**How to read it**:
```solidity
// Integral: call the plugin contract directly
(int56[] tickCumulatives, uint88[] volatilityCumulatives) = plugin.getTimepoints([3600, 0]);
// Volatility over last hour = volatilityCumulatives[1] - volatilityCumulatives[0]
```

**Cross-chain volatility surface**: By reading volatilityCumulative from stablecoin pairs across:
- Polygon (QuickSwap): USDC/USDT -- USD stablecoin vol
- Arbitrum (Camelot): USDC/USDT -- USD stablecoin vol, ETH/USDC -- crypto vol
- BNB Chain (THENA): USDT/USDC -- USD stablecoin vol, BNB/USDT -- EM-adjacent vol

...one can construct a multi-chain volatility surface that reflects real-time trading conditions.

### 5.2 Dynamic Fee as a Volatility Proxy

**The fee IS the volatility signal**, processed through the double-sigmoid function. Reading `pool.fee()` gives:
- Fee near baseFee (0.01%): Very low volatility
- Fee near 0.30% (first sigmoid saturated): Moderate volatility
- Fee near 1.50% (both sigmoids saturated): Extreme volatility

This is a **pre-processed, normalized volatility indicator** available from any Algebra pool with DYNAMIC_FEE enabled. No oracle querying needed -- just read the current fee.

**For macro use**: Compare dynamic fees across pairs (ETH/USDC vs BNB/USDT vs stablecoin pairs) to detect cross-asset volatility divergences in real time.

### 5.3 TWAP from Algebra Pools

**Every pool with the oracle module** (standard plugin) supports TWAP computation:

```solidity
// Get 1-hour TWAP
(int56[] ticks, , ) = plugin.getTimepoints([3600, 0]);
int24 twapTick = int24((ticks[1] - ticks[0]) / 3600);
// Convert tick to price: price = 1.0001^tick
```

This is equivalent to Uniswap V3 TWAP oracles but accessed via the plugin contract instead of the pool.

**Key difference from Uniswap V3**: In Algebra Integral, the oracle is in the plugin, not the pool. In V1.0 (QuickSwap), it is in the pool directly.

### 5.4 Specific Pools for Macro Monitoring

**Priority 1 -- Stablecoin Volatility (FX/macro sensitivity)**:
| Pool | DEX | Chain | Why |
|------|-----|-------|-----|
| USDC/USDT | Camelot V4 | Arbitrum | Pure USD stablecoin vol |
| USDT/USDC | THENA V3,3 | BNB Chain | USD stablecoin vol, BSC ecosystem |
| USDC/USDT | QuickSwap | Polygon | Largest TVL, deep liquidity |

**Priority 2 -- Crypto Asset Volatility**:
| Pool | DEX | Chain | Why |
|------|-----|-------|-----|
| ETH/USDC | Camelot V4 | Arbitrum | ETH/USD vol on leading L2 |
| BNB/USDT | THENA V3,3 | BNB Chain | BNB/USD vol |
| ETH/USDC | QuickSwap | Polygon | ETH/USD on Polygon |
| S/USDC | SwapX | Sonic | Sonic native asset vol |

**Priority 3 -- LST/Derivative Pairs**:
| Pool | DEX | Chain | Why |
|------|-----|-------|-----|
| wstETH/ETH | Camelot V4 | Arbitrum | LST spread vol |

---

## 6. Key Findings and Recommendations

### 6.1 No Single DEX Has Literally "ALL" Plugins

Because only one plugin can attach to a pool, and the plugin marketplace has 10+ separate plugins, no pool runs every plugin simultaneously. The closest to "maximum" are:

- **Camelot V4**: Standard (Oracle + Adaptive Fee + Farming) + Sliding Fee + Limit Orders = 5 modules in one combined plugin
- **THENA V3,3**: Standard + Sliding Fee + Brevis ZK Dynamic Fee = 5+ modules

### 6.2 For Macro Observables, the Standard Plugin Is Sufficient

The standard BasePluginV1 already provides everything needed for macro signal extraction:
- `volatilityCumulative` for realized vol measurement
- `tickCumulative` for TWAP price computation
- `fee()` as a pre-processed volatility indicator
- `averageTick` as a 24-hour moving average price

The additional plugins (sliding fee, limit orders, anti-snipe) add LP optimization features but do not provide additional macro-readable data beyond what the standard plugin offers.

### 6.3 V1.0 Pools (QuickSwap) Have the Same Data, Different Access Pattern

QuickSwap V1.0 on Polygon has the same oracle accumulators (tickCumulative, volatilityCumulative) built into the core pool contract. The access pattern is `pool.getTimepoints()` instead of `plugin.getTimepoints()`. QuickSwap has the deepest liquidity of any Algebra deployment, making it the best source for macro data despite its older architecture.

### 6.4 EM Stablecoin Gap

None of the Algebra-powered DEXes have dedicated EM stablecoin pairs (e.g., BRLUSD, MXNUSD, TRYLIRA). The stablecoin landscape across all chains is dominated by USDC and USDT. For EM exposure, one would need to look at:
- Native chain token/stablecoin pairs on EM-relevant chains
- BNB/USDT on THENA as the closest proxy to EM-adjacent volatility

### 6.5 Recommended Data Pipeline

For building a macro-observable feed from Algebra pools:

1. **Deploy multicall readers** on Arbitrum, BNB Chain, Polygon
2. **Target pools**: USDC/USDT and ETH/USDC on each chain
3. **Read per block**: `plugin.getTimepoints([0])` for latest accumulator values, `pool.fee()` for current dynamic fee
4. **Compute**: Delta of volatilityCumulative between snapshots = realized volatility over interval
5. **Cross-chain**: Compare vol levels across chains for divergence detection

---

## 7. Technical Reference -- Source Code Locations

### Local Codebase

- Plugin flags: `/home/jmsbpp/apps/liq-soldk-dev/lib/Algebra/src/core/contracts/libraries/Plugins.sol`
- Standard plugin: `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/AlgebraBasePluginV1.sol`
- Limit order plugin: `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/limit-order/contracts/AlgebraBasePluginV1.sol`
- Volatility oracle: `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/libraries/VolatilityOracle.sol`
- Adaptive fee: `/home/jmsbpp/apps/liq-soldk-dev/lib/algebra-plugins/src/plugin/stub/contracts/libraries/AdaptiveFee.sol`
- Pool core: `/home/jmsbpp/apps/liq-soldk-dev/lib/Algebra/src/core/contracts/AlgebraPool.sol`

### GitHub Repositories

- Main repository: [cryptoalgebra/Algebra](https://github.com/cryptoalgebra/Algebra)
- Team plugins: [cryptoalgebra/integral-team-plugins](https://github.com/cryptoalgebra/integral-team-plugins)
- Plugin template: [cryptoalgebra/algebra-plugin-template](https://github.com/cryptoalgebra/algebra-plugin-template)
- Fee simulation: [cryptoalgebra/IntegralFeeSimulation](https://github.com/cryptoalgebra/IntegralFeeSimulation)
- Brevis ZK fee plugin: [brevis-network/algebra-vip-plugin-contract](https://github.com/brevis-network/algebra-vip-plugin-contract)

---

## Sources

- [Algebra Integral Documentation -- How It Works: Core + Plugins](https://docs.algebra.finance/algebra-integral-documentation/introducing-algebra-integral-to-dexes/overview-of-algebra-integral/how-it-works-core-+-plugins)
- [Algebra Integral -- Plugins Technical Reference](https://docs.algebra.finance/algebra-integral-documentation/algebra-integral-technical-reference/core-logic/plugins)
- [Algebra Integral -- Plugin Development Guide](https://docs.algebra.finance/algebra-integral-documentation/algebra-integral-technical-reference/guides/plugin-development)
- [Algebra Integral -- Adaptive Fee Documentation](https://docs.algebra.finance/algebra-integral-documentation/algebra-integral-technical-reference/plugins/adaptive-fee)
- [Algebra Integral -- Plugin Overview](https://docs.algebra.finance/algebra-integral-documentation/algebra-integral-technical-reference/plugins/overview)
- [Algebra Integral -- Partners and Ecosystem](https://docs.algebra.finance/algebra-integral-documentation/overview/partners-and-ecosystem)
- [Algebra Integral -- Changes v1.2](https://docs.algebra.finance/algebra-integral-documentation/algebra-integral-technical-reference/changes-v1.2)
- [Algebra Medium -- Plugins Technical Overview](https://medium.com/@crypto_algebra/algebra-integral-plugins-technical-overview-315e6e7bc72f)
- [Algebra Medium -- Sliding Fee Plugin](https://medium.com/@crypto_algebra/the-sliding-fee-plugin-for-algebra-integral-new-calculation-approach-with-15-efficiency-3b350fc7c0db)
- [Algebra Medium -- Dynamic Fees vs. Sliding Fee](https://medium.com/@crypto_algebra/dynamic-fees-vs-sliding-fee-mechanism-in-algebra-powered-amms-26b65b8249aa)
- [Algebra Medium -- Brevis ZK Dynamic Fees Plugin](https://medium.com/@crypto_algebra/integrals-brand-new-dynamic-fees-plugin-by-brevis-algebra-a7c86c36fe8b)
- [Algebra Medium -- Algebra and Brevis Partnership](https://medium.com/@crypto_algebra/algebra-joins-forces-with-brevis-new-integral-plugin-utilizing-the-zk-coprocessor-4cc82712f2e5)
- [Algebra Medium -- SwapX Anti-Snipe Plugin](https://medium.com/@crypto_algebra/algebra-integrals-v4-pools-get-sniper-proof-with-anti-snipe-plugin-by-swapx-3bd817bd60a6)
- [Algebra Plugin Marketplace](https://market.algebra.finance/)
- [Algebra Labs -- Build Plugins](https://algebra.finance/plugins/)
- [Camelot V4 Documentation](https://docs.camelot.exchange/protocol/amm-v4)
- [THENA Medium -- BNB Chain Innovation Hackathon and Algebra Plugins](https://medium.com/@ThenaFi/bnb-chain-innovation-hackathon-diving-deeper-into-algebra-integral-and-plugins-e7e33c35c47e)
- [THENA Medium -- V3,3 Launch](https://medium.com/@ThenaFi/thena-v3-3-igniting-the-next-era-of-defi-on-bnb-chain-152ce501c1d9)
- [SwapX Documentation -- Algebra Integral V4](https://swapxfi.gitbook.io/swapx-docs/protocol-design-and-features/algebra-integral-v4)
- [QuickSwap Blog -- V4 Governance Proposal](https://blog.quickswap.exchange/posts/governance-proposal-quickswap-v4-implementation-modularity-with-plugins-hooks)
- [QuickSwap V3 -- DefiLlama](https://defillama.com/protocol/quickswap-v3)
- [Blocmates -- Algebra Integral Overview](https://www.blocmates.com/articles/algebra-integral-the-uniswap-v4-inspired-dex-solutions-provider)
- [MixBytes Audit -- Algebra Plugins](https://github.com/mixbytes/audits_public/blob/master/Algebra%20Finance/Plugins/README.md)
- [Brevis -- THENA Partnership](https://blog.brevis.network/2024/12/12/thena-partners-with-brevis-to-launch-intelligent-dex-features/)
