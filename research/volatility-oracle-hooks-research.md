# Volatility Oracle Hooks: Open Source Research Report

**Date**: 2026-03-29
**Scope**: Uniswap V4 Hooks | Balancer V3 Hooks | Algebra Integral Plugins | Generic On-chain Vol Oracles

---

## Executive Summary

The landscape of on-chain volatility oracles integrated into DEX hook systems is nascent but growing rapidly. Most implementations fall into the **dynamic fee hook** pattern: computing realized volatility from swap/tick data and adjusting pool fees accordingly. True standalone volatility oracle hooks (exposing IV/RV as a consumable feed) are rarer. The most mature production-grade system is **Algebra Integral's adaptive fee plugin**, which has been battle-tested across multiple DEXes (Camelot, THENA, QuickSwap). Uniswap V4 has the richest ecosystem of experimental hooks. Balancer V3 has fewer entries but includes a high-quality geomean oracle hook.

---

## 1. UNISWAP V4 HOOKS

### 1.1 Official Reference: Volatility Fee Hook Guide

- **Source**: [Uniswap V4 Docs - Volatility Fee Hook](https://docs.uniswap.org/contracts/v4/guides/hooks/Volatility-fee-hook)
- **Description**: Official Uniswap Foundation guide showing how to build a dynamic fee hook that adjusts fees based on realized volatility using a `VolatilityOracle` contract
- **Hook callbacks**: `beforeSwap` (returns `lpFeeOverride` with bit 23 set)
- **Methodology**: Tracks tick movement variance across time windows, scales fee proportionally
- **Status**: Reference implementation / tutorial

### 1.2 VolatilityHook-UniV4 (Brevis ZK-Proven RV)

- **Repo**: [0xth4nh/VolatilityHook-UniV4](https://github.com/0xth4nh/VolatilityHook-UniV4) (also forked by [0xekkila](https://github.com/0xekkila/VolatilityHook-UniV4))
- **Last active**: 2025-03-13
- **Description**: Uniswap V4 hook using **Brevis** (ZK coprocessor) to compute SNARK-verified realized volatility of ETH/USDC across multiple DEXes off-chain, then post the proof on-chain
- **Methodology**: Off-chain RV computation over historical swap data across DEXes, ZK-proven and submitted to hook; hook uses verified RV to set dynamic fees
- **Hook callbacks**: `afterSwap` triggers fee recalculation based on latest Brevis-attested RV
- **Relevance**: **HIGH** - Most sophisticated approach, cross-DEX RV with cryptographic guarantees
- **Quality**: Moderate (hackathon-grade, but well-documented concept)

### 1.3 Tempest (Volatility-Responsive Dynamic Fee)

- **Repo**: [fabrknt/tempest](https://github.com/fabrknt/tempest)
- **Last active**: 2026-03-17
- **Description**: "Volatility-responsive dynamic fee hook for Uniswap v4"
- **Status**: Active, recent (created 2026-02)
- **Relevance**: **HIGH** - Recent, actively maintained

### 1.4 VolatiFee

- **Repo**: [Dhruv-Varshney-developer/VolatiFee](https://github.com/Dhruv-Varshney-developer/VolatiFee)
- **Last active**: 2025-03-30
- **Description**: "Uniswap v4 hook that dynamically adjust fees based on volatility"
- **Hook callbacks**: Uses `DynamicFeeHook.sol` pattern
- **Relevance**: **MEDIUM** - Straightforward vol-based fee implementation

### 1.5 dynamicfee-uniswapv4-hook (Multi-Signal)

- **Repo**: [rusrio/dynamicfee-uniswapv4-hook](https://github.com/rusrio/dynamicfee-uniswapv4-hook)
- **Last active**: 2025-12-28
- **Description**: "Uniswap V4 hook that handles fee dynamically based on market conditions such as volatility, Fear and Greed index, IV, etc..."
- **Relevance**: **HIGH** - Explicitly mentions implied volatility and multiple market signals

### 1.6 BVCC Dynamic Fee Hook (Production-Grade LP Protection)

- **Repo**: [blockventurechaincapital-crypto/bvcc-dynamic-fee-hook](https://github.com/blockventurechaincapital-crypto/bvcc-dynamic-fee-hook)
- **Last active**: 2026-03-11
- **Description**: "Professional-grade Uniswap v4 hook for LP protection. Automatically increases fees during bot attacks, adjusts dynamically to volatility and volume conditions, penalizes rapid-fire swaps, and caps fees with circuit breakers. Deployed on BSC, Ethereum, Arbitrum, and Base."
- **Relevance**: **HIGH** - Claims production deployment, multi-chain, sophisticated LP protection
- **Quality**: Higher quality signals (circuit breakers, bot detection, multi-chain deploy)

### 1.7 Voltaic Fee Adjuster (Deployed on Unichain)

- **Repo**: [Moses-main/voltaic-fee-adjuster](https://github.com/Moses-main/voltaic-fee-adjuster)
- **Last active**: 2026-03-19
- **Description**: "Dynamically adjusts swap fees in real time based on recent pool volatility — automatically raising fees during sharp price swings to protect LPs from impermanent loss and lowering them in calm, stable markets. Deployed on Unichain."
- **Relevance**: **MEDIUM** - Claims Unichain deployment

### 1.8 Mantua Dynamic Fee (Multi-Signal)

- **Repo**: [DelleonMcglone/dynamic-fee](https://github.com/DelleonMcglone/dynamic-fee)
- **Last active**: 2026-03-27
- **Description**: "Multi-signal dynamic fee hook that automatically adjusts swap fees based on volatility, volume, and pool state. Built as the enhancement layer of the Mantua.AI DeFi suite on Uniswap v4"
- **Relevance**: **MEDIUM** - Very recent, multi-signal approach

### 1.9 Risk-Neutral Hook (LVR/IL Hedge + Power Perps)

- **Repo**: [scab24/univ4-risk-neutral-hook](https://github.com/scab24/univ4-risk-neutral-hook)
- **Audited by**: [ZealynxSecurity](https://github.com/ZealynxSecurity/univ4-risk-neutral-hook-UHI2)
- **Last active**: 2024-09-18
- **Description**: "LVR & IL Hedge Hook: Dynamic Fees for pools and Power Perps / Borrowing hedges for LPs. Towards a risk neutral DeFi."
- **Relevance**: **VERY HIGH** - Directly targets LVR/IL hedging using power perpetuals alongside dynamic fees. Most aligned with your LP hedging research direction.
- **Methodology**: Combines dynamic fee adjustment with power perp borrowing to hedge LP risk

### 1.10 Vanna Hook (Options Greeks)

- **Repo**: [EazyReal/v4-periphery-vanna](https://github.com/EazyReal/v4-periphery-vanna)
- **Description**: Hook related to vanna (options greek: dVega/dSpot) for Uniswap V4
- **Relevance**: **HIGH** - Options-theory-informed hook, likely uses vol surface data
- **Code found**: `src/Vanna.sol` in code search

### 1.11 AdaptiveSwapHook

- **Repo**: [CJ42/adaptive-swap-hook-uhi](https://github.com/CJ42/adaptive-swap-hook-uhi)
- **Description**: Adaptive swap hook for Uniswap V4
- **Code found**: `src/AdaptiveSwapHook.sol`

### 1.12 FlexFee (Brevis + IL Protection)

- **Mentioned in**: awesome-uniswap-hooks, Uniswap community contributions
- **Description**: "Protecting LPs from impermanent loss using dynamic fees based on volatility (calculated with Brevis) and swap size"
- **Methodology**: Uses Brevis ZK coprocessor for off-chain volatility computation, adjusts fees per-swap
- **Relevance**: **HIGH** - IL protection via vol-adjusted fees

### 1.13 Arrakis Pro Hook

- **Source**: [Arrakis Blog](https://arrakis.finance/blog/the-arrakis-pro-hook-dynamic-fees-for-token-issuers-on-uniswap-v4)
- **Description**: Dynamic fee hook for token issuers on Uniswap V4 by Arrakis Finance (major MEV-aware market making protocol)
- **Status**: Production protocol, may not be fully open source
- **Relevance**: **MEDIUM** - Professional implementation but focused on token issuers

---

## 2. BALANCER V3 HOOKS

### 2.1 Geomean Oracle Hook (Beirao)

- **Source**: [beirao.xyz - Balancer V3 Geomean Oracle](https://www.beirao.xyz/blog/ENG5-BalancerV3_TWAP_Oracle)
- **Registry**: [hooks.balancer.fi](https://hooks.balancer.fi/)
- **Description**: Robust manipulation-resistant price oracle for Balancer V3 pools using geometric mean prices over customizable time periods
- **Methodology**:
  - Geometric mean TWAP (more manipulation-resistant than arithmetic)
  - Block-level granularity, updates on every swap
  - `_manipulationSafeGuard`: Clamps price changes to +/- 10% between consecutive blocks
  - Supports both Weighted and Stable pools (any number of assets, any weight)
  - Optional Chainlink-compatible adaptor for downstream consumption
- **Relevance**: **HIGH** - While primarily a price oracle, the manipulation-safe TWAP infrastructure is directly usable for computing realized volatility (variance of log returns from TWAP observations). The clamping mechanism is itself a vol-aware feature.
- **Quality**: **HIGH** - Well-documented, zero maintenance post-deployment, Chainlink integration
- **License**: Check repo

### 2.2 ReBalancer (Implied Volatility-Driven LP Rebalancing)

- **Repo**: [0xnullifier/ReBalancer](https://github.com/0xnullifier/ReBalancer)
- **Description**: "Balancer v3 hook that dynamically rebalances LP positions and LP Fees for RWAs, LSTs and bond-based tokens based on event and market implied volatility"
- **Methodology**:
  - Forward-looking (implied) volatility for fee adjustments
  - Event-driven: Central bank rate decisions, CPI releases, earnings, coupon payments, dividend announcements
  - Rebalances LP positions proactively based on anticipated price movements
  - Acts as both Hook + Router (modifies and removes liquidity)
- **Relevance**: **VERY HIGH** - Uses implied volatility (not just realized), event-driven rebalancing, directly targets LP risk management
- **Quality**: Hackathon project (DoraHacks submission)

### 2.3 Dynamic Fee Adjustment Hook (DoraHacks)

- **Source**: [DoraHacks Buidl #17686](https://dorahacks.io/buidl/17686)
- **Description**: Balancer V3 hook that dynamically adjusts swap fees based on market volatility and trading volume
- **Key component**: Contains a `VolatilityOracle` library for calculating and tracking market volatility
- **Relevance**: **HIGH** - Has a dedicated volatility oracle library

### 2.4 Balancer V3 Hook Architecture

- **Hook callbacks available**: `onBeforeSwap`, `onAfterSwap`, `onBeforeAddLiquidity`, `onAfterAddLiquidity`, `onBeforeRemoveLiquidity`, `onAfterRemoveLiquidity`, `onRegister`, `onComputeDynamicSwapFeePercentage`
- **Key difference from Uni V4**: `onComputeDynamicSwapFeePercentage` is a dedicated callback for dynamic fees (more explicit than V4's `lpFeeOverride` bit pattern)
- **Official repos**: [balancer/balancer-v3-monorepo](https://github.com/balancer/balancer-v3-monorepo), [balancer/scaffold-balancer-v3](https://github.com/balancer/scaffold-balancer-v3)

---

## 3. ALGEBRA INTEGRAL PLUGINS

### 3.1 Adaptive Fee Plugin (Production - Most Mature)

- **Repos**:
  - [cryptoalgebra/Algebra](https://github.com/cryptoalgebra/Algebra) — Main AMM repo
  - NPM: `@cryptoalgebra/integral-base-plugin`
  - [cryptoalgebra/IntegralFeeSimulation](https://github.com/cryptoalgebra/IntegralFeeSimulation) — Simulation tool
- **Documentation**: [Algebra Integral - Adaptive Fee](https://docs.algebra.finance/algebra-integral-documentation/algebra-integral-technical-reference/plugins/adaptive-fee)
- **Description**: Production-grade volatility oracle + adaptive fee system deployed across multiple major DEXes
- **Deployed on**: Camelot (Arbitrum), THENA (BNB Chain), QuickSwap (Polygon), and others
- **Methodology**:
  - TWAP-oracle based price change tracking over last 24 hours
  - Tick-based volatility estimation from oracle observations
  - Sigmoid-based fee curve mapping vol → fee (original version)
  - Sliding fee mechanism (newer version, claimed 15% efficiency improvement)
  - Configurable min/max fee bounds
  - DEX owners can tune volatility's impact on fee through configuration params
- **Plugin architecture**:
  - Modular plugin system (similar to Uni V4 hooks but predates it)
  - Plugins attach to pool lifecycle events
  - Base plugin includes: volatility oracle, dynamic fee manager, farmings adapter
  - Plugins can be updated independently without liquidity migration
- **Quality**: **VERY HIGH** - Production battle-tested, multi-DEX deployment, active maintenance
- **License**: BUSL-1.1 for plugin contracts, GPL-2.0+ for interfaces
- **Solidity**: 0.8.20+
- **Relevance**: **CRITICAL** - The most mature on-chain volatility oracle in any DEX hook system. The vol computation methodology is directly extractable/adaptable.

### 3.2 IntegralFeeSimulation (Backtesting Tool)

- **Repo**: [cryptoalgebra/IntegralFeeSimulation](https://github.com/cryptoalgebra/IntegralFeeSimulation)
- **Description**: Large-scale simulation tool for Algebra Integral volatility oracle and adaptive fee behavior using historical data
- **Relevance**: **HIGH** - Useful for validating vol oracle parameters before deployment

### 3.3 Sliding Fee Plugin (Newer Approach)

- **Source**: [Algebra Medium - Sliding Fee Plugin](https://medium.com/@crypto_algebra/the-sliding-fee-plugin-for-algebra-integral-new-calculation-approach-with-15-efficiency-3b350fc7c0db)
- **Description**: Evolution of the adaptive fee plugin with a new calculation approach claiming 15% efficiency improvement
- **Methodology**: Different fee curve that responds to directional flow rather than pure volatility
- **Relevance**: **HIGH** - Represents the cutting edge of dynamic fee computation

### 3.4 Algebra Plugin Architecture

- **Plugin lifecycle hooks**: `beforeInitialize`, `afterInitialize`, `beforeModifyPosition`, `afterModifyPosition`, `beforeSwap`, `afterSwap`, `beforeFlash`, `afterFlash`
- **Key difference**: Algebra had this plugin system before Uniswap V4 launched hooks. Their system is more battle-tested but less open (BUSL license).
- **Plugin marketplace**: [market.algebra.finance](https://market.algebra.finance/plugin/dynamic-fee/)

---

## 4. GENERIC / CROSS-PLATFORM VOLATILITY ORACLES

### 4.1 Valorem Oracles (Greeks + Vol + Black-Scholes)

- **Repo**: [valorem-labs-inc/oracles](https://github.com/valorem-labs-inc/oracles)
- **Created**: 2022-09-01
- **Last push**: 2022-10-04 (stale)
- **Description**: "Oracles for greeks, realized volatility, implied volatility, risk free rate, black scholes using on chain data. Useful for pricing options and other derivatives in on-chain AMMs."
- **Relevance**: **VERY HIGH** - Full options pricing oracle stack (RV, IV, greeks, BSM) designed for on-chain AMM consumption
- **Quality**: Low (appears abandoned/early stage), but the architecture is highly relevant
- **License**: Check repo

### 4.2 Squeeth Vol Oracle

- **Repo**: [antoncoding/squeeth-vol-oracle](https://github.com/antoncoding/squeeth-vol-oracle)
- **Description**: On-chain volatility oracle derived from Squeeth (Opyn's power perpetual)
- **Methodology**: Extracts implied volatility from Squeeth funding rates
- **Relevance**: **HIGH** - IV oracle from power perpetuals, directly relevant to options pricing

### 4.3 EVIX Oracle (Opyn V2 Based IV)

- **Repo**: [tir-finance/EVIX-oracle](https://github.com/tir-finance/EVIX-oracle)
- **Created**: 2020-10-07 (very early, likely stale)
- **Description**: On-chain Implied Volatility oracle built using Opyn V2
- **Relevance**: **MEDIUM** - Early attempt at on-chain IV, architecture may be instructive

### 4.4 Realized Strangle (Uni V3 Vol)

- **Repo**: [Lucas-Kohorst/realized-strangle](https://github.com/Lucas-Kohorst/realized-strangle)
- **Created**: 2021-07-20 (stale)
- **Description**: "Strangle realized volatility on Uniswap V3"
- **Relevance**: **MEDIUM** - Uses Uni V3 tick data for RV computation

### 4.5 Chainlink Volatility Oracles

- **Source**: [Chainlink Blog - Volatility Oracles](https://blog.chain.link/volatility-oracles/)
- **Description**: Chainlink introducing support for realized and implied volatility oracles
- **Status**: Announced/in development
- **Relevance**: **HIGH** - If available, could serve as external vol feed for any hook system

---

## 5. COMPARATIVE ANALYSIS

### Hook System Comparison for Volatility Oracle Use

| Feature | Uniswap V4 | Balancer V3 | Algebra Integral |
|---------|------------|-------------|-----------------|
| **Hook points** | before/afterSwap, before/afterAddLiquidity, etc. | onBefore/AfterSwap, onComputeDynamicSwapFee | before/afterSwap, before/afterModifyPosition |
| **Dynamic fee mechanism** | `lpFeeOverride` via beforeSwap (bit 23) | Dedicated `onComputeDynamicSwapFeePercentage` callback | Plugin-managed fee state |
| **Maturity** | Mainnet Jan 2026, 200+ hooks deployed | Mainnet, growing ecosystem | Multi-year production, deployed on 5+ DEXes |
| **Vol oracle implementations** | 10+ experimental repos | 2-3 quality implementations | 1 production-grade (adaptive fee) |
| **Best for** | Experimentation, ZK-verified vol | Multi-asset weighted pools | Production dynamic fees |
| **License landscape** | Mostly MIT/open | BSL for core, hooks vary | BUSL-1.1 (restrictive) |
| **Oracle integration** | Custom (Brevis, Chainlink, Pyth) | Chainlink-compatible adaptors | Built-in TWAP oracle |

### Volatility Computation Approaches Found

| Approach | Used By | On/Off-chain | Methodology |
|----------|---------|-------------|-------------|
| **Tick variance** | Uniswap V4 official guide, VolatiFee | On-chain | Variance of tick changes over time window |
| **ZK-proven cross-DEX RV** | VolatilityHook-UniV4 (Brevis) | Hybrid | Off-chain RV computation, ZK-verified on-chain |
| **TWAP-derived 24h vol** | Algebra Integral | On-chain | Tick change accumulation from TWAP oracle |
| **Geometric mean TWAP** | Balancer Geomean Oracle | On-chain | Manipulation-resistant price feed (vol derivable) |
| **Event-driven IV** | ReBalancer | Off-chain feed | Implied vol from macro events |
| **Power perp funding rate** | Squeeth vol oracle | On-chain | IV extraction from perpetual funding |
| **Multi-signal (vol + FnG + IV)** | rusrio/dynamicfee | Hybrid | Multiple market condition signals |

---

## 6. KEY REPOS RANKED BY RELEVANCE (to LP hedging / vol oracle for options)

### Tier 1: Directly Relevant to Your Work

1. **[scab24/univ4-risk-neutral-hook](https://github.com/scab24/univ4-risk-neutral-hook)** — LVR/IL hedge via power perps + dynamic fees (UniV4)
2. **[cryptoalgebra/Algebra](https://github.com/cryptoalgebra/Algebra)** — Production vol oracle + adaptive fee (Algebra)
3. **[0xnullifier/ReBalancer](https://github.com/0xnullifier/ReBalancer)** — IV-driven LP rebalancing (Balancer V3)
4. **[valorem-labs-inc/oracles](https://github.com/valorem-labs-inc/oracles)** — Full greeks/RV/IV/BSM oracle stack
5. **[0xth4nh/VolatilityHook-UniV4](https://github.com/0xth4nh/VolatilityHook-UniV4)** — ZK-verified cross-DEX RV (UniV4)

### Tier 2: Strong Implementations

6. **[fabrknt/tempest](https://github.com/fabrknt/tempest)** — Active vol-responsive fee hook (UniV4)
7. **[rusrio/dynamicfee-uniswapv4-hook](https://github.com/rusrio/dynamicfee-uniswapv4-hook)** — Multi-signal including IV (UniV4)
8. **[blockventurechaincapital-crypto/bvcc-dynamic-fee-hook](https://github.com/blockventurechaincapital-crypto/bvcc-dynamic-fee-hook)** — Production-deployed LP protection (UniV4)
9. **Balancer V3 Geomean Oracle** (beirao) — Manipulation-resistant TWAP infrastructure
10. **[EazyReal/v4-periphery-vanna](https://github.com/EazyReal/v4-periphery-vanna)** — Options-greek-informed hook (UniV4)

### Tier 3: Reference / Inspirational

11. **[antoncoding/squeeth-vol-oracle](https://github.com/antoncoding/squeeth-vol-oracle)** — IV from power perps
12. **[cryptoalgebra/IntegralFeeSimulation](https://github.com/cryptoalgebra/IntegralFeeSimulation)** — Vol oracle backtesting
13. **[Moses-main/voltaic-fee-adjuster](https://github.com/Moses-main/voltaic-fee-adjuster)** — Unichain-deployed vol fee
14. **[Dhruv-Varshney-developer/VolatiFee](https://github.com/Dhruv-Varshney-developer/VolatiFee)** — Simple vol fee hook
15. **[DelleonMcglone/dynamic-fee](https://github.com/DelleonMcglone/dynamic-fee)** — Multi-signal fee (Mantua.AI)
16. **[tir-finance/EVIX-oracle](https://github.com/tir-finance/EVIX-oracle)** — Early on-chain IV oracle
17. **[Lucas-Kohorst/realized-strangle](https://github.com/Lucas-Kohorst/realized-strangle)** — RV from Uni V3

---

## 7. OBSERVATIONS & GAPS

### What exists:
- **Dynamic fee hooks** are the dominant use case for vol oracles in hook systems
- **Realized volatility** computation (from tick/swap data) is well-explored
- **Algebra Integral** has the most mature production system
- **Uniswap V4** has the richest experimental ecosystem
- **ZK-verified vol** (Brevis) is an emerging pattern

### What's missing:
- **Standalone vol oracle hooks** that expose RV/IV as a consumable on-chain feed (most are tightly coupled to fee adjustment)
- **On-chain implied volatility** from LP positions (Panoptic's approach) — no open-source hook implementation found
- **GARCH/EWMA on-chain** — mentioned in theory but no production Solidity implementation found in hook systems
- **Vol surface construction** on-chain — no implementations found
- **Cross-hook vol feeds** — no standard for one hook to expose vol data to other hooks/protocols
- **Balancer V3** ecosystem is thin relative to Uni V4 for this use case

### Recommendations for your project:
1. Study Algebra's adaptive fee plugin deeply — it's the production gold standard for on-chain vol computation
2. The risk-neutral hook (scab24) is architecturally closest to your LP hedging goals
3. The Brevis ZK-verified RV pattern could solve the "trusted vol feed" problem
4. ReBalancer's IV-driven approach on Balancer V3 is novel and worth examining
5. Consider building a standalone vol oracle hook that other hooks/protocols can consume

---

## 8. CURATED LISTS & RESOURCES

- [fewwwww/awesome-uniswap-hooks](https://github.com/fewwwww/awesome-uniswap-hooks) — Actively maintained, 200+ hooks catalogued
- [johnsonstephan/awesome-uniswap-v4-hooks](https://github.com/johnsonstephan/awesome-uniswap-v4-hooks) — Comprehensive tutorial-focused list
- [hooks.balancer.fi](https://hooks.balancer.fi/) — Official Balancer V3 hook registry
- [market.algebra.finance](https://market.algebra.finance/plugin/dynamic-fee/) — Algebra plugin marketplace
- [DoraHacks Balancer Hooks](https://dorahacks.io/buidl/16753) — Hackathon submissions
- [Uniswap V4 Volatility Fee Hook Guide](https://docs.uniswap.org/contracts/v4/guides/hooks/Volatility-fee-hook) — Official tutorial
