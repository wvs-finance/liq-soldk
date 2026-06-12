# Deep Dive: Gains Network (gTrade)

**Research Date:** March 31, 2026
**Status:** Comprehensive analysis based on public documentation, GitHub repositories, DeFiLlama, Dune, and protocol announcements through Q1 2026.

---

## Executive Summary

Gains Network is a decentralized leveraged trading protocol operating a synthetic perpetuals platform called gTrade. It supports 290+ trading pairs across crypto, forex, commodities, stocks, and indices, with leverage up to 1000x on forex. The protocol runs on Arbitrum (primary), Polygon, Base, and Solana. It uses a unique vault-as-counterparty model (gToken vaults) and a custom Chainlink DON for oracle pricing.

From a remittance-hedging perspective, gTrade is both promising and limiting. It has infrastructure for forex pairs and has even registered exotic EM pairs (USD/MXN, USD/BRL, USD/INR, USD/KRW) in its pair index, but these are all currently **inactive**. No NGN, PHP, or KES pairs exist even as placeholders. The v8+ contract source code (Diamond pattern) is **not open-sourced on GitHub**, making a realistic fork extremely difficult without reverse-engineering verified bytecode from block explorers.

---

## 1. Available Trading Pairs

### Overview

gTrade advertises 290+ pairs. The breakdown by asset class:

| Asset Class   | Approx. Count | Max Leverage | Notes |
|---------------|---------------|-------------|-------|
| Crypto        | ~240+         | 150x        | BTC, ETH, SOL, top altcoins, memecoins |
| Forex         | ~35           | 1000x       | 7 majors, 21 minors, ~7 exotics |
| Commodities   | ~6-8          | 150x        | XAU, XAG, and others via v10 RWA model |
| Stocks        | ~13+          | 150x        | TSLA, AAPL, GOOGL, etc. (returned in 2025) |
| Indices       | ~5+           | 150x        | Available on Arbitrum, Base, Solana |

### Forex Pairs -- Detailed Breakdown

gTrade offers ~35 forex pairs at 10x-1000x leverage. The pair list uses a `pairIndex` numbering system on-chain.

**Major Pairs (7):**
- EUR/USD, USD/JPY, GBP/USD, USD/CHF, AUD/USD, NZD/USD, USD/CAD

**Minor/Cross Pairs (21):**
- Standard crosses among G10 currencies: EUR/GBP, EUR/JPY, EUR/CHF, EUR/AUD, EUR/NZD, EUR/CAD, GBP/JPY, GBP/CHF, GBP/AUD, GBP/NZD, GBP/CAD, AUD/JPY, AUD/CHF, AUD/NZD, AUD/CAD, NZD/JPY, NZD/CHF, NZD/CAD, CAD/JPY, CAD/CHF, CHF/JPY

**Exotic Pairs (Active):**
- USD/CNH, USD/SGD, EUR/SEK, USD/ZAR -- these are **active**

**Exotic Pairs (INACTIVE -- registered but not tradable):**

| Pair     | pairIndex | Status |
|----------|-----------|--------|
| USD/KRW  | 96        | Inactive |
| EUR/NOK  | 97        | Inactive |
| USD/INR  | 98        | Inactive |
| USD/MXN  | 99        | Inactive |
| USD/TWD  | 100       | Inactive |
| USD/BRL  | 102       | Inactive |

**Critical finding for remittance use case:** No NGN/USD, PHP/USD, KES/USD, or other frontier-market EM pairs exist even as inactive placeholders. The protocol has demonstrated intent to support exotics (registering pairIndex slots), but activation requires oracle support.

### G10 Coverage

All G10 currencies are represented in some combination:
- USD, EUR, JPY, GBP, CHF, AUD, NZD, CAD, SEK (via EUR/SEK), NOK (registered but inactive)
- Coverage is strong for G10 but only through specific pair combinations, not all permutations.

### How New Pairs Are Listed

New pair listing requires:
1. Oracle support -- a Chainlink Data Streams feed or custom DON configuration for the asset
2. Protocol team activation -- pairs are registered with a `pairIndex` on the GNSMultiCollatDiamond contract
3. No separate liquidity bootstrapping needed -- all pairs share the gToken vault liquidity pool (a major architectural advantage over order-book DEXes)

The process appears to be team-driven rather than governance-driven as of Q1 2026, though the roadmap mentions DAO transition.

---

## 2. Liquidity, TVL, and Volume

### TVL

- **DeFiLlama page:** https://defillama.com/protocol/gains-network
- gTrade is notable for extreme capital efficiency -- routinely handling ~$100M daily volume with only ~$10M in TVL
- Exact current TVL as of March 2026 should be checked live on DeFiLlama; historical data shows the protocol operating with relatively low TVL compared to GMX (~5x smaller)

### Chain Breakdown (Activity)

| Chain     | Status | 24h Volume (sample) | Notes |
|-----------|--------|---------------------|-------|
| Arbitrum  | Primary | ~$20.9M            | Highest activity, main deployment |
| Base      | Active  | ~$2.1M             | Growing, stocks/indices available |
| Polygon   | Legacy  | ~$171K             | Significantly reduced, original chain |
| Solana    | New     | Growing            | Launched 2025, 270+ pairs, gasless UX |

Arbitrum dominates activity by roughly 10x over Base. Polygon is effectively legacy.

### Volume Statistics

- **Lifetime volume:** $100B+ (surpassed $85B in early 2025, crossed $100B by end of 2025)
- **Daily volume:** ~$20-25M on Arbitrum in typical conditions (varies with market activity)
- **Annual revenue (2024):** ~$24.5M
- **Daily protocol revenue (Dec 2025):** ~$130K -- notably exceeding Uniswap's $95K despite 178x smaller FDV
- **Revenue (lifetime):** $60M+

### gToken Vault Sizes

- **gUSDC:** Primary vault on Arbitrum (introduced Jan 2024)
- **gDAI:** Original vault, still active on Polygon
- **gETH, gAPE, gGNS, gBTCUSD:** Additional vault types added over time
- All follow ERC-4626 tokenized vault standard
- Vault sizes fluctuate; check gains.trade/vaults for current figures

### Fee Revenue Distribution

| Recipient          | Share |
|-------------------|-------|
| GNS Burn          | 54%   |
| Governance (DAO)  | 22%   |
| Vault (LPs)       | 15%   |
| Referrals         | 5%    |
| Trigger Keepers   | 4%    |

### Dune Dashboards

- **Official:** https://dune.com/gains/gtrade_stats
- **Community:** https://dune.com/unionepro/Everthing-Gains-Network
- **By Asset Class:** https://dune.com/unionepro/Gains-Network-gTrade-Stats-by-Asset-Class

---

## 3. Architecture (Technical Deep Dive)

### Version History

| Version | Date | Key Change |
|---------|------|------------|
| v5      | Early history | Original contracts |
| v6      | 2022-2023 | Major rewrite, public on GitHub |
| v6.1    | 2023 | Improvements, borrowing fees, public on GitHub |
| v6.3.2  | 2023 | Funding fees to borrowing fees transition |
| v6.4    | 2023-2024 | Guaranteed execution, lookbacks |
| v7      | 2024 | Multi-collateral (gETH, gUSDC) |
| v8      | May 2024 | **Diamond Pattern refactor** -- major architecture change |
| v9      | 2024-2025 | Enhanced spreads, competitive liquidations (v9, v9.1, v9.2) |
| v10     | Aug 4, 2025 | **Current version** -- funding fees, counter trades, scalability |

**Current deployed version: v10.2+** (with incremental updates v10, v10.1, v10.2)

### Core Contract: GNSMultiCollatDiamond

Since v8, all protocol logic lives behind a single Diamond Proxy (EIP-2535) contract per chain. Each "facet" handles a specific domain (trading, borrowing, referrals, etc.) but all calls route through the Diamond.

**Contract Addresses:**

| Chain    | GNSMultiCollatDiamond Address |
|----------|-------------------------------|
| Arbitrum | `0xFF162c694eAA571f685030649814282eA457f169` |
| Polygon  | `0x209A9A01980377916851af2cA075C2b170452018` |
| Base     | `0x6cD5aC19a07518A8092eEFfDA4f1174C72704eeb` |

Full contract address list: https://docs.gains.trade/what-is-gains-network/contract-addresses

### Synthetic Trading Model

gTrade uses a **vault-as-counterparty** model:

1. Traders open leveraged positions by depositing collateral (USDC, DAI, ETH, etc.)
2. Positions are synthetic -- no actual spot asset is bought/sold
3. The gToken vault (e.g., gUSDC) acts as counterparty to all trades
4. When traders profit, vaults pay. When traders lose, vaults receive
5. Vaults also earn trading fees, which historically exceed PnL payouts (net positive for LPs)
6. Because liquidity is shared, adding a new pair requires zero new liquidity -- just oracle support

### Oracle System

**Original Architecture (v6-v8):**
- Custom Chainlink DON with 8 on-demand nodes
- Each node fetches median price from 7 exchange APIs
- Aggregator contract double-checks each node's median against official Chainlink Price Feed
- Circuit breaker triggers if prices differ by more than 1.5%
- Second median taken across all node responses
- On-demand pricing (not streaming) to minimize gas waste

**Current/Planned Architecture (v9+):**
- Migrating to Chainlink Data Streams for high-frequency, real-time market data
- Integrating Chainlink CCIP for cross-chain vault interoperability
- Data Streams used for trade execution, conditional orders, and liquidations
- DON being upgraded to support improved schedules, sources, and futures-based pricing

### Funding/Borrowing Fee Mechanism

**Pre-v10 (Borrowing Fees):**
- Formula: `max_apr * (net_OI / max_OI)^exponent`
- Borrowing fees went to gToken vault overcollateral layer
- Applied to all open positions

**v10+ (Funding Fees -- for major pairs):**
- Skew-based funding: longs pay shorts (or vice versa) based on OI imbalance
- Rates evolve gradually over time (no sudden spikes)
- Counter Trades: trades that rebalance skew receive fee discounts and better execution
- Holding costs dropped 90%+ vs borrowing fee model
- Initially applied to BTC, ETH, SOL, XRP, BNB; expanding to more pairs

### Spread and Fee Structure

- **BTC/ETH:** 0% fixed spread
- **Other crypto:** Dynamic spread based on: open interest, position size, trade direction (long/short)
- **Forex:** Tight fixed spreads with dynamic component
- **Opening/closing fee:** Percentage of position size, distributed per fee table above

### Liquidation Mechanism

```
Liquidation Price Distance = Open Price * (Collateral * Liquidation Threshold - Closing Fee - Borrowing Fees) / Collateral / Leverage
```

- Liquidation prices move closer over time as borrowing/funding fees accrue
- v9.2 introduced competitive liquidations and enhanced spread formulas to prevent exploitative trading patterns

---

## 4. Open Source Status

### GitHub Repositories

**Organization 1:** https://github.com/GainsNetwork (legacy, individual repos)
**Organization 2:** https://github.com/GainsNetwork-org (current org)

| Repository | Version | License | Status |
|-----------|---------|---------|--------|
| GainsNetwork/gTrade-v5 | v5 | Likely MIT | Public, legacy |
| GainsNetwork/gTrade-v6 | v6 | MIT | **Public, open source** |
| GainsNetwork/gTrade-v6.1 | v6.1 | MIT | **Public, open source** |
| GainsNetwork-org/sdk | SDK | MIT | Public |
| GainsNetwork-org/gtrade-stats-subgraph | Subgraph | Unknown | Public |

### CRITICAL FINDING: v8/v9/v10 Contracts Are NOT Open-Sourced

**The v8 Diamond refactor, v9 updates, and v10 (current production) contract source code are NOT published on GitHub.** Only v6 and v6.1 are publicly available. The v8+ architecture is fundamentally different from v6 (Diamond pattern vs. individual contracts), so the open-source v6.1 code is architecturally obsolete relative to production.

This means:
- The MIT-licensed v6/v6.1 contracts are available but represent a **2+ year old architecture**
- The current Diamond-based contracts are only available as verified bytecode on block explorers (Arbiscan, Polygonscan, Basescan)
- No test suites, deployment scripts, or development tooling for v8+ are public
- The SDK and subgraph are open-source but these are integration tools, not core contracts

### Can You Realistically Fork This?

**Forking v6/v6.1:** Possible but you would be forking an outdated architecture without funding fees, Diamond pattern, or multi-collateral support. This is roughly equivalent to forking Uniswap v2 when v3 is live.

**Forking v8+/v10:** Not feasible without significant reverse engineering. You would need to:
1. Decompile verified contracts from Arbiscan
2. Reconstruct the Diamond facet structure
3. Reverse-engineer the custom Chainlink DON integration
4. Build your own test suite from scratch
5. Handle the oracle dependency (you cannot reuse their DON)

**Assessment:** gTrade is NOT a realistic fork candidate for current-version code.

---

## 5. Composability

### On-Chain Read Interfaces

Since v8, the GNSMultiCollatDiamond contract exposes read methods through its facets. External contracts can:
- Read current prices (through oracle integration)
- Query open interest per pair
- Read borrowing/funding fee rates
- Query vault state

v8 explicitly enabled smart contract integration: "Smart contracts are now able to interact directly with trading contracts, opening the door to a new set of use cases where other protocols integrate trading."

### SDK

- **Repository:** https://github.com/GainsNetwork-org/sdk
- Open-sourced, MIT license
- TypeScript SDK for interacting with gTrade contracts
- Documented at https://docs.gains.trade/developer/technical-reference/sdk

### Subgraph

- **Repository:** https://github.com/GainsNetwork-org/gtrade-stats-subgraph
- Used for the gTrade Stats & Points system
- Enables indexing and querying of historical trade data

### Backend/API

- Backend integration guide: https://docs.gains.trade/developer/integrators/backend
- Integrator documentation: https://docs.gains.trade/developer/integrators
- Trading contract interaction guide: https://docs.gains.trade/developer/integrators/trading-contracts
- v10 migration guide for integrators: https://docs.gains.trade/developer/integrators/guides/v10-migration

### Integration Ecosystem

More than 5 projects are actively integrating with gTrade. The v8 Diamond refactor was specifically designed to enable composability.

---

## 6. Ecosystem

### Frontends and Aggregators

- **Primary frontend:** gains.trade
- **Stats dashboard:** gains.trade/stats/overview
- **Vault interfaces:** gains.trade/vaults/gUSDC, gains.trade/vaults/gDAI
- Third-party funding rate tools: fundingview.app, fundingfarmer
- Listed on DeFiLlama, DappRadar, CoinGecko, CoinMarketCap

### GNS Token Utility

- **Staking:** Stake GNS to earn share of platform fees
- **Fee discounts:** Holding GNS provides reduced trading fees
- **Burn mechanism:** 54% of fees used to buy back and burn GNS
- **Governance:** GNS holders stake for veGNS to vote on proposals
- **Collateral:** GNS helps secure liquidity pools (gGNS vault)

### Governance

- Currently team-driven with transition to DAO planned
- veGNS governance model (stake GNS -> vote)
- No formal on-chain governance for pair listings yet

### Team

- **Seb:** Founder and original full-stack developer
- **Nathan:** Core developer
- **Uri:** Developer
- **Crumb:** Developer
- **Dreamersnat:** Front-end
- **Konrad:** Front-end
- Pseudonymous team, no known institutional backers. The protocol was bootstrapped without VC funding.

---

## 7. Relevance for Remittance Hedging

### Does gTrade Support EM FX Pairs Beyond G10?

**Active exotic FX pairs:** USD/CNH, USD/SGD, EUR/SEK, USD/ZAR -- these are tradable.

**Registered but inactive EM pairs:** USD/MXN, USD/BRL, USD/INR, USD/KRW, USD/TWD, EUR/NOK

**Not registered at all:** NGN/USD, PHP/USD, KES/USD, or any other frontier-market currency.

The presence of inactive EM pair slots suggests the team considered expansion but lacked oracle support or demand to activate them.

### How Hard Would It Be to Add NGN/USD, PHP/USD Pairs?

**On gTrade itself (as a user/integrator):** You cannot add pairs -- only the team can register and activate new pairIndex entries with associated oracle configurations.

**On a fork:** Even on the forkable v6.1 architecture, adding a new FX pair requires:
1. **A reliable oracle feed** for the pair -- this is the hard constraint. Chainlink does not offer NGN/USD or KES/USD Data Streams feeds. You would need a custom oracle solution.
2. Registering the pair in the contracts with appropriate group parameters (spread, leverage limits, fees)
3. The synthetic vault model handles liquidity automatically -- no pair-specific liquidity needed

**Oracle is the binding constraint.** Without a Chainlink feed for NGN or KES, you would need to build or source a custom oracle, which undermines the security model that gTrade relies on.

### Is gTrade the Best Fork Candidate for a Remittance-Focused Perp DEX?

**Arguments FOR gTrade fork:**
- Vault-as-counterparty model eliminates per-pair liquidity bootstrapping
- FX-native design with 1000x leverage and tight spreads
- v6.1 is MIT licensed and publicly available
- Proven track record ($100B+ lifetime volume)
- Adding new pairs is architecturally trivial (just oracle + config)

**Arguments AGAINST gTrade fork:**
- v6.1 is architecturally obsolete (no Diamond, no funding fees, no multi-collateral)
- v10 (production) is NOT open source
- Custom Chainlink DON cannot be replicated without Chainlink partnership
- No EM FX oracle infrastructure exists in Chainlink ecosystem for frontier currencies
- Team is pseudonymous; no path to collaboration on custom oracle work

### Comparison: Forking gTrade v6.1 vs Synthetix v3

| Dimension | gTrade v6.1 Fork | Synthetix v3 Fork |
|-----------|-------------------|-------------------|
| License | MIT (v6.1 only) | MIT (v3 core is open) |
| Architecture currency | Outdated (pre-Diamond) | Current (modular, v3 is production) |
| FX leverage | Up to 1000x native | Configurable |
| Oracle dependency | Custom Chainlink DON (hard to replicate) | Chainlink or Pyth (more flexible) |
| Per-pair liquidity | Not needed (shared vault) | Pool-based but configurable |
| Code completeness | Contracts only, no tests for v8+ | Full stack including tests |
| EM FX oracle | Not solved by either | Not solved by either |
| Composability | Limited in v6.1 | Strong in v3 |
| Community/docs | Moderate | Extensive |
| Realistic forkability | Low (v6.1 too old, v10 closed) | **Medium-High** (v3 is open and current) |

### Recommendation

**Synthetix v3 is a stronger fork candidate** for a remittance-focused perp DEX because:
1. The current production architecture is open-source with tests and deployment tooling
2. Oracle flexibility (Pyth Network supports more exotic feeds than Chainlink DON)
3. Modular pool design allows custom collateral configurations
4. Active developer ecosystem with integration documentation

**However, neither protocol solves the fundamental oracle problem for frontier EM currencies.** The real bottleneck is not the perp DEX architecture -- it is sourcing reliable, manipulation-resistant price feeds for NGN/USD, PHP/USD, KES/USD on-chain. This requires either:
- Building a custom oracle network with licensed FX data providers
- Using Pyth Network (which has some EM pairs including MXN/USD, BRL/USD)
- Partnering with DIA (which already works with Gains Network for gUSDC pricing and supports custom oracle feeds)

---

## Sources

- [Gains Network Official Site](https://gains.trade/)
- [Gains Network Documentation](https://docs.gains.trade/)
- [Gains Network GitBook (Legacy)](https://gains-network.gitbook.io/docs-home/)
- [gTrade v10 Launch Announcement](https://medium.com/gains-network/gtrade-v10-is-live-built-to-scale-22dbd635de20)
- [2026 Roadmap](https://medium.com/gains-network/2026-roadmap-the-blueprint-for-gains-network-gtrade-and-gns-de08d050296a)
- [gTrade v8 Diamond Refactor](https://medium.com/gains-network/introducing-gtrade-v8-diamond-refactor-and-smart-contract-integration-a175b96ccb82)
- [Chainlink DON Deep Dive](https://thereadingape.substack.com/p/chainlink-build-a-custom-chainlink)
- [Chainlink Data Streams + CCIP Integration](https://medium.com/gains-network/gtrade-is-integrating-chainlinks-ccip-data-streams-to-bring-you-the-best-in-on-chain-leveraged-ac3c88b7bb5c)
- [gToken Vaults Documentation](https://docs.gains.trade/liquidity-farming-pools/gtoken-vaults)
- [GainsNetwork GitHub (Legacy)](https://github.com/GainsNetwork)
- [GainsNetwork-org GitHub](https://github.com/GainsNetwork-org)
- [gTrade v6.1 Repository](https://github.com/GainsNetwork/gTrade-v6.1)
- [GainsNetwork-org SDK](https://github.com/GainsNetwork-org/sdk)
- [gTrade Stats Subgraph](https://github.com/GainsNetwork-org/gtrade-stats-subgraph)
- [DeFiLlama - Gains Network](https://defillama.com/protocol/gains-network)
- [Dune - gTrade Stats](https://dune.com/gains/gtrade_stats)
- [Dune - Everything Gains Network](https://dune.com/unionepro/Everthing-Gains-Network)
- [Contract Addresses](https://docs.gains.trade/what-is-gains-network/contract-addresses)
- [Arbitrum Contract Addresses](https://docs.gains.trade/what-is-gains-network/contract-addresses/arbitrum-mainnet)
- [gTrade and GNS in 2025](https://medium.com/gains-network/gtrade-and-gns-in-2025-where-vision-and-value-coalesce-90e2c5af03c0)
- [CoinCodeCap gTrade Review (Jan 2026)](https://coincodecap.com/gains-networks-gtrade-review)
- [GNS Token Documentation](https://gains-network.gitbook.io/docs-home/what-is-gains-network/gfarm2-token)
- [Pair List Documentation](https://gains-network.gitbook.io/docs-home/gtrade-leveraged-trading/pair-list)
- [Forex Asset Class](https://docs.gains.trade/gtrade-leveraged-trading/asset-classes/forex)
- [Fees & Spread](https://docs.gains.trade/gtrade-leveraged-trading/fees-and-spread)
- [DIA Partnership for gUSDC Oracle](https://www.diadata.org/blog/post/partnership-gains-network-oracle-gusdc-arbitrum/)
- [v9.2 Enhanced Spreads](https://medium.com/gains-network/v9-2-enhanced-spread-formula-and-competitive-liquidations-9cd99ea3497e)
- [gTrade Solana Launch](https://medium.com/gains-network/gtrade-solana-your-gateway-to-effortless-trading-22d1fe30bd80)
