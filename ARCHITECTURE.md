# Macro Risk Markets — Architecture

**Balancer V3 / Algebra / Uniswap**

*Status: High-Level Design — In Progress*
*Date: 2026-03-31*

---

## Vision

On-chain hedging instruments for macro variables (currency depreciation, capital flight, inflation, interest rate shocks) targeting **underserved countries** — any EM economy lacking TradFi derivatives coverage.

Each CFMM pool is treated as a **measure-theoretic instrument**. A pool on pair X/Y defines a measure μ_{X/Y} on the observable space (price, volume, fees, adaptive fees, liquidity). The choice of numeraire encodes which macro question is being asked.

---

## Core Principles

1. **Zero bootstrapped liquidity** — The protocol is parasitic on existing DeFi liquidity. All positions borrow from or read existing pools. Follows the Panoptic V2 pattern (borrow via SFPM, don't compete for LPs).

2. **Measure theory foundation** — Each pool defines a measure. Multi-token pools give the joint distribution. Pairwise pools give marginals. The product of marginals ≠ joint (independence breaks in a crisis = contagion). The architecture captures both.

3. **Universal entry** — Any country's stablecoin plugs into the same measurement apparatus and immediately gets the full macro observable set.

4. **Adaptive fee as observable** — Algebra's sigmoid adaptive fee is part of the measure space, not a derived quantity. The fee encodes volatility information that fixed-fee pools miss. Comparing same-pair pools with different fee mechanisms isolates the fee's information content.

---

## Three-Layer Architecture

```
Layer 1: ALGEBRA PAIRWISE          Layer 2: BALANCER V3 VIRTUAL SIMPLEX
(read existing pools)               (synthetic pool, no real liquidity,
                                     virtual balances from Layer 1 + CCIP)
         │                                    │
         └────────── observables ─────────────┘
                          │
                          ▼
               ┌─────────────────────┐
               │  LAYER 3: MODULAR   │
               │  INDEX ENGINE       │
               │                     │
               │  Users define       │
               │  custom indexes →   │
               │  settlement →       │
               │  hedging instruments│
               └──────────┬──────────┘
                          │
                          ▼
                 SETTLEMENT LAYER
              (Panoptic / Voltaire)
```

### Layer 1 — Algebra Pairwise Measures (Polygon, QuickSwap V3)

**Purpose**: Read observables from existing concentrated liquidity pools with adaptive fees.

**Pools read** (existing on Polygon):
- USDC/DAI — USD peg stability, centralization risk
- [EM-stable]/USDC — country-specific FX measurement
- Same pair on Uniswap V3 (fixed fee) for cross-mechanism comparison

**Observables per pool** (the measure space):
- Spot price, TWAP (configurable window)
- Realized volatility (from Algebra volatility oracle accumulator)
- Adaptive fee level (sigmoid output)
- Adaptive fee change rate (dFee/dt)
- Fee revenue / feeGrowthGlobal
- Volume (directional, net flow)
- Liquidity distribution (TVL, active liquidity ratio, tick skew)

**Key insight**: μ_{USDC/DAI}^{Algebra} vs μ_{USDC/DAI}^{UniV3} — the Radon-Nikodym derivative between these two measures on the **same pair** isolates the information content of the adaptive fee mechanism.

**Existing code**:
- `src/libraries/AlgebraVolatilityLens.sol` — queries Algebra volatility oracle
- `src/libraries/LeftRightILX96.sol` — IL computation (Deng-Zong-Wang Eq. 2 & 3)
- `research/analysis-algebra-vol-oracle.md` — adaptive fee sigmoid analysis

**Reference**: [Algebra Integration Notes](notes/ALGEBRA_INTEGRATION_NOTES.md)

---

### Layer 2 — Balancer V3 Virtual Synthetic Simplex (Polygon or Arbitrum)

**Purpose**: Compute the joint distribution across 5-8 tokens without holding real liquidity. Uses Balancer V3's custom pool architecture to create a virtual pool with virtual balances derived from Layer 1 data.

**The Universal Measurement Basis (5 fixed tokens)**:

| Token | Numeraire Role | Macro Dimension |
|-------|---------------|-----------------|
| DAI | Decentralized nominal USD | Base measure (σ-finite reference) |
| USDC | Centralized nominal USD | Issuer risk / centralization |
| AMPL | CPI-targeting, real purchasing power | Inflation / real vs nominal split |
| ETH | On-chain unit of account | Crypto risk premium / global sentiment |
| wstETH | ETH + staking yield | On-chain risk-free rate |

**Variable entry slots (up to 3)**:
- Slot 6: EM stablecoin 1 (e.g., cCOP)
- Slot 7: EM stablecoin 2 (e.g., cNGN) — enables direct cross-EM contagion measurement
- Slot 8: Additional asset (PAXG, commodity token, or third EM stablecoin)

**Why multi-token matters**: The weighted invariant V = ∏(Bᵢ^{wᵢ}) enforces triangle consistency by construction. In a 3+ token pool:
- dμ_{cCOP}/dμ_{DAI} is computed directly (not via chain rule through USDC)
- Conditional measures μ_{cCOP/DAI | USDC} are available
- Correlation structure between all pairs is captured jointly
- Contagion (correlation breakdown) is observable

**Virtual pool mechanics**:
- No real token deposits — virtual balances derived from pairwise Layer 1 data + CCIP cross-chain reads
- Custom hook handles AMPL rebase normalization
- Invariant surface exists computationally as a pure measurement instrument
- Triangle consistency calibrates synthetic cross-rates against real pairwise data

**Numeraire is question-dependent**:
- "Is USDC going to depeg?" → numeraire = DAI
- "Is COP depreciating in nominal terms?" → numeraire = USDC
- "Is COP depreciating in real terms?" → numeraire = AMPL
- "What's the monetary policy spread for Colombia?" → numeraire = wstETH
- "Is there EM contagion?" → cross-EM pair (cCOP/cNGN directly)

**Reference**: [Balancer V3 Hooks Research](notes/research-balancer-v3-hooks.md)

---

### Layer 3 — Modular Index Engine

**Purpose**: User-facing product. Permissionless registry where anyone can:
1. Define a custom index from available pool observables
2. Deploy a settlement contract referencing that index
3. Create hedging instruments that settle on the index (via Panoptic / Voltaire)

**Example indexes** (from synthesis matrix):

**Currency Crisis Index (CCI)**:
```
CCI(t) = 0.30 × parallelMarketPremium(30d TWAP)
       + 0.20 × realizedVol(7d) / historicalMeanVol
       + 0.15 × (1 - activeLiquidityRatio)
       + 0.15 × netFlowDirection(7d)
       + 0.10 × volumeAcceleration(1d)
       + 0.10 × feeRevenueVol(7d) / historicalMean
```

**Remittance Health Index (RHI)**:
```
RHI(t) = w1 × sellSideVolume(30d) / historicalMean
       + w2 × weeklyVolumePattern_correlation
       + w3 × feeRevenue(30d) / historicalMean
       - w4 × buySideVolume(30d) / historicalMean
```

**Monetary Policy Divergence Index (MPDI)**:
```
MPDI(t) = feeYield(pool, 30d) - stETH_yield(30d) - historicalSpread
```

Users compose their own from any combination of Layer 1 and Layer 2 observables.

**Reference**: [Synthesis Matrix](refs/macro-risk/synthesis-pair-primitive-macro-matrix.md), [Macro Risks Framework](notes/MACRO_RISKS.md)

---

## Cross-Chain Infrastructure

**Problem**: cCOP lives on Celo. Algebra pools live on Polygon. Balancer V3 is not on Celo.

**Solution**: Chainlink CCIP for Polygon ↔ Celo observable relay.
- Celo adopted CCIP as canonical cross-chain infrastructure
- Arbitrary messaging encodes pool state (sqrtPriceX96, tick, liquidity, volatility)
- LayerZero lzRead does NOT support Celo as data source (only Ethereum, Base, Polygon, Avalanche, BNB, Optimism, Arbitrum)
- All five major protocols (LayerZero, Axelar, Wormhole, CCIP, Hyperlane) support both Polygon and Celo for push-based messaging

**Superfluid** (deployed on both Polygon and Celo):
- Not cross-chain itself, but enables **continuous-time streaming** of hedge premiums intra-chain
- Maps to dt-by-dt option premium accrual in continuous-measure pricing
- Use CCIP for inter-chain data relay (discrete pushes), Superfluid for intra-chain continuous flows

**Reference**: [Cross-Chain Protocols Research](notes/research-cross-chain-protocols.md), [cCOP Stablecoin Research](notes/research-ccop-stablecoin.md)

---

## Settlement Layer

**Panoptic**: Perpetual options settlement. IL oracle (LeftRightILX96) → TokenId construction → SFPM minting. Borrows liquidity from Uniswap V3.

**Voltaire**: Alternative perpetual futures protocol. Under evaluation.

**Income-based settlement** preferred over price-based:
- Fee accrual is deterministic (feeGrowthGlobal is exactly computable)
- No cash market bootstrapping needed
- More robust against manipulation (income accrues over time, not flash-loanable)

**Reference**: [Panoptic Architecture Integration](notes/panoptic/PANOPTIC_ARCHITECTURE_INTEGRATION.md), [Pension Funds Use Case](notes/PENSION_FUNDS.md)

---

## Existing Solidity Libraries

| Library | Purpose | Path |
|---------|---------|------|
| LeftRightILX96 | IL oracle (Deng-Zong-Wang Eq. 2 & 3) | `src/libraries/LeftRightILX96.sol` |
| Strikes | Strike grid packing (Prop 3.5 quadrature) | `src/libraries/Strikes.sol` |
| Ricks | Rounded tick distances | `src/libraries/Ricks.sol` |
| AlgebraVolatilityLens | Algebra volatility oracle query | `src/libraries/AlgebraVolatilityLens.sol` |

---

## Key Research Documents

| Document | Path |
|----------|------|
| Synthesis: Pair × Primitive → Macro Variable Matrix | `refs/macro-risk/synthesis-pair-primitive-macro-matrix.md` |
| Academic Literature: CFMMs as Macro Oracles | `refs/macro-risk/academic-literature-cfmm-macro-oracles.md` |
| Macro Risks Framework | `notes/MACRO_RISKS.md` |
| Pension Funds: PutWrite Strategy | `notes/PENSION_FUNDS.md` |
| Stablecoin Flows (IMF 2026) | `notes/STABLECOIN_FLOWS.md` |
| Algebra Volatility Oracle Analysis | `research/analysis-algebra-vol-oracle.md` |
| Perp DEX Comparison | `notes/MACRO_RISKS_CHECKPOINT.md` |
| Balancer V3 Hooks Research | `notes/research-balancer-v3-hooks.md` |
| Cross-Chain Protocols Research | `notes/research-cross-chain-protocols.md` |
| cCOP Stablecoin Ecosystem | `notes/research-ccop-stablecoin.md` |

---

## EM Pool Inventory (Existing Liquidity)

| Pool | Chain | DEX | TVL | Daily Volume |
|------|-------|-----|-----|-------------|
| cKES/USDT | Celo | Uniswap V3 | ~$35K | ~$124K |
| BRZ/USDT | Polygon | Uniswap V4 | ~$42K | ~$16K |
| cCOP/USDT | Celo | Uniswap V3 | ~$15K | ~$7K |
| PAXG/WETH | Ethereum | Uniswap V2 | $15.8M | $1.8M |
| WETH/USDC | Ethereum | Uniswap V3 | $200M+ | $500M+ |
| wstETH/WETH | Ethereum | Balancer | $50M+ | High |
| USDC/DAI | Polygon | QuickSwap V3 (Algebra) | Exists | Active |
