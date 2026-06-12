# Deep Dive: Ostium Protocol

**Date:** 2026-03-31
**Status:** Comprehensive research report
**Protocol:** Ostium (ostium.com)
**Chain:** Arbitrum One (Ethereum L2)
**Category:** RWA Perpetuals DEX

---

## Executive Summary

Ostium is the leading onchain perpetuals venue for Real World Assets, deployed on Arbitrum One. Founded in 2022 by Harvard alumni Kaledora Kiernan-Linn and Marco Antonio Ribeiro, the protocol has processed over $34 billion in cumulative trading volume, with 95%+ of open interest concentrated in traditional market assets (FX, commodities, indices, stocks). The protocol is adapted from the Gains Network v5 open-source codebase with substantial modifications, particularly around its custom-built RWA oracle infrastructure powered by Stork Network and QUODD market data. With $27.8M in total funding (including a $20M Series A led by General Catalyst and Jump Crypto), 44 live trading pairs, and $56.6M TVL, Ostium is positioned as the primary onchain venue for non-crypto perpetual exposure.

Critically for remittance hedging research: Ostium already lists emerging market FX pairs including USD/MXN and USD/BRL, and the underlying oracle infrastructure (Stork + QUODD) is designed to be extensible to new asset classes. The protocol's open-source smart contracts (Gains v5 fork) and available Python/Rust SDKs make integration feasible.

---

## 1. Available Trading Pairs

### Total Count

**44 trading pairs** as of March 2026 (source: CoinGecko exchange page).

### By Category

**Crypto (3 pairs, up to 100x leverage):**
- BTC/USD
- ETH/USD
- SOL/USD

**Forex (estimated 10-12+ pairs, up to 200x leverage):**
Confirmed live pairs:
- EUR/USD
- USD/JPY
- GBP/USD
- AUD/USD (added late 2025)
- NZD/USD (added late 2025)
- USD/CHF (added late 2025)
- USD/MXN
- USD/BRL

The platform has blogged about expansions to FX pairs, with AUD/USD, NZD/USD, and USD/CHF being among the most recently added.

**Commodities (estimated 6-8 pairs):**
Confirmed:
- XAU/USD (Gold) -- Ostium captured 50%+ of total onchain gold OI during the 2025 gold rally
- XAG/USD (Silver)
- CL/USD (Crude Oil) -- Most active pair by volume ($45M+ 24h volume)
- Copper

Over $5 billion in cumulative metals trading alone.

**Indices (estimated 4-6 pairs):**
Confirmed:
- SPX/USD (S&P 500)
- NDX/USD (Nasdaq 100)
- DJI/USD (Dow Jones)
- NKY/USD (Nikkei 225)

**Stocks (estimated 10-15+ pairs):**
- TSLA and other large-cap equities available as perpetual contracts
- Stock day-trades have higher intraday leverage with auto-close before market bell
- Stocks leverage up to 100x for day trades; overnight leverage is lower

**ETFs:**
- Dune dashboard categories include ETF as a separate asset class, suggesting at least some ETF pairs are live

### Leverage Limits by Category

| Category    | Max Leverage | Notes                                    |
|-------------|-------------|------------------------------------------|
| Forex       | 200x        | Highest leverage tier                     |
| Commodities | Up to 200x  | Varies by asset                           |
| Indices     | Up to 200x  | Varies by asset                           |
| Stocks      | 100x        | Day-trade leverage; lower overnight       |
| Crypto      | 100x        | BTC, ETH, SOL only                        |

### Emerging Market FX Coverage

This is a critical finding: **Ostium already lists USD/MXN and USD/BRL.** Search results also reference NGN (Nigerian Naira) and PHP (Philippine Peso) in context with Ostium, though whether USD/NGN and USD/PHP are currently live pairs or planned additions requires direct platform verification.

**No evidence found for:** USD/KES (Kenyan Shilling) as a live pair.

### Pair Listing Process

New pairs appear to be added by the Ostium team based on oracle data availability and market demand. There is no documented governance process or permissionless listing mechanism. QUODD data partnerships enable "faster evaluations and scalable launches" for new assets.

---

## 2. Liquidity & TVL

### Key Metrics (March 2026)

| Metric                     | Value                  | Source             |
|---------------------------|------------------------|--------------------|
| TVL                       | ~$56.6M                | DeFiLlama          |
| Cumulative Volume         | $34B+                  | Multiple sources    |
| Daily Volume              | ~$100-180M             | CoinGecko/DeFiLlama|
| 24h Open Interest         | ~$162M                 | CoinGecko           |
| Total Users               | 13,000+                | CryptoWinRate       |
| Annualized Fees           | ~$61.6M                | DeFiLlama           |
| Annualized Revenue        | ~$19.6M                | DeFiLlama           |
| Most Active Pair (24h)    | CL/USD ($45M+ vol)    | CoinGecko           |

### TVL History

- Pre-points program (early 2025): ~$5.5M TVL
- Post-points program launch (April 2025): TVL surged 10x to ~$53.6M
- Current (March 2026): ~$56.6M, relatively stable

### OI Breakdown

**The 95%+ traditional markets claim is verified.** Multiple sources confirm that over 95% of open interest on Ostium is in non-crypto assets (FX, commodities, indices, stocks). This is the defining characteristic that sets Ostium apart from all other perps DEXs.

The Dune dashboard at `dune.com/ostium_app/stats` breaks down volume and OI by asset class: crypto, forex, commodities, indices, stocks, and ETF.

### Fee Revenue

- Weekly fees (sample from April 2025): ~$411K in 7 days on ~$938M weekly volume
- Annualized fees (March 2026): ~$61.6M
- Fee revenue growth: 62% increase in 7-day period (recent trend)
- Vault LPs receive: 100% of liquidation rewards, 50% of opening fees, 100% of volatility fees

---

## 3. Architecture

### Gains Network Fork -- Confirmed

The smart contracts are explicitly described as "adapted from the Gains v5 open-source codebase, with significant modifications and new functionality introduced to align with Ostium's protocol architecture and design objectives."

This is **Gains v5** (also known as gTrade v5), not an earlier version.

### Key Architectural Differences from Gains

1. **Custom RWA Oracle**: Ostium's most significant divergence. Gains uses Chainlink feeds; Ostium built a custom pull-based oracle system from scratch for RWA-specific complexities (market hours, contract rolls, price gaps, etc.)
2. **Shared Liquidity Layer**: Two-tier system (Liquidity Buffer + Market Making Vault) rather than Gains' single-vault approach
3. **Quote-based pricing model**: Draws from offchain liquidity venues rather than purely oracle-based execution
4. **Market hours handling**: Built-in logic for traditional market trading sessions, weekends, holidays
5. **Asset-specific rollover fees**: Instead of unified funding rates, non-crypto assets have rollover fees reflecting real-world carry costs

### Core Contract Addresses (Arbitrum One)

| Contract            | Proxy Address                                | Implementation                              |
|--------------------|----------------------------------------------|---------------------------------------------|
| Trading Storage    | `0xcCd5891083A8acD2074690F65d3024E7D13d66E7` | OstiumTradingStorage                        |
| Trading            | `0x6D0bA1f9996DBD8885827e1b2e8f6593e7702411` | OstiumTrading                               |

Both use **EIP-1967 Transparent Proxy** pattern. The full system uses a **registry pattern** (IOstiumRegistry) for service discovery -- contracts locate each other through the registry rather than hardcoded addresses, enabling upgradability.

### System Architecture (from DeepWiki analysis)

The Ostium V2 system follows a **service-oriented design pattern** with these subsystems:

1. **Trading Engine**: Core contracts handling trade lifecycle (open, close, modify)
2. **Shared Liquidity Layer (SLL)**:
   - **Liquidity Buffer**: Primary settlement layer for trader PnL. Acts as the protocol's "shock absorber" -- pays winning trades, receives losing trade collateral.
   - **Market Making Vault**: LPs deposit USDC, receive OLP tokens. LPs are NOT immediate counterparties to traders. They only bear risk if the Liquidity Buffer is insufficient to cover trader gains.
3. **Oracle System**: Pull-based, custom-built for RWA complexities
4. **Automated Keeper System**: Off-chain automation via Gelato Functions for liquidations and order execution

### Oracle System (Critical Detail)

Ostium uses a **multi-layer oracle architecture**:

| Layer              | Provider              | Asset Class        |
|--------------------|-----------------------|--------------------|
| RWA Price Feeds    | Stork Network + QUODD | FX, Commodities, Indices, Stocks |
| Crypto Price Feeds | Chainlink Data Streams| BTC, ETH, SOL      |

**Stork Network**: Manages majority of node infrastructure. Decentralized network of data publishers capable of signing verifications on blockchains while performing initial processing off-chain. Price updates are push-on-demand (pull-based), achieving ~50ms latency.

**QUODD Financial**: Provides institutional-grade real-time market data as a core input into the oracle model. Supplies reliable pricing, bid-ask spreads, and market depth across global assets. Partnership announced February 2026.

**Custom Oracle Logic**: The Ostium development company builds data partnerships/sourcing, market hours data, and asset-specific node price feed aggregation logic. This addresses RWA-specific challenges:
- Out-of-market hours handling
- Futures contract rolls
- Price gaps at market open
- Weekend/holiday periods

### Fee Mechanism

**Opening Fees:**
- Crypto: Maker 0.03% / Taker 0.10% (differential based on OI rebalancing)
- Non-crypto (FX, commodities, indices, stocks): Flat 0.04% (4 bps)
- Low leverage (1-20x) counter-trades on crypto get reduced maker fees

**Closing Fees:** None (zero closing fee)

**Ongoing Costs:**
- Crypto: Funding fee (compensates OI imbalances, accrues continuously per block, increases non-linearly with imbalance)
- Non-crypto: Rollover fee (reflects real-world carry costs: interest-rate differentials, convenience yield, storage/borrow costs)

### Liquidation Mechanism

- Backstop liquidation at **25% remaining collateral** for all leveraged trades
- At maximum leverage, liquidation occurs at a 75% position loss
- Liquidation threshold dynamically adjusts based on leverage used
- Liquidations executed automatically via **Gelato Functions** keeper bots
- No margin calls -- positions are auto-liquidated

### Collateral

- **USDC only** -- all positions collateralized in USDC on Arbitrum One
- Vault deposits also in USDC, receiving OLP tokens in return

---

## 4. Open Source Status

### GitHub Organization: `0xOstium`

**Repositories:**

1. **`smart-contracts-public`** -- Core protocol contracts
   - URL: https://github.com/0xOstium/smart-contracts-public
   - Adapted from Gains v5 open-source codebase
   - Deployed on Arbitrum One
   - Development environment: Hardhat
   - License: References original Gains v5 license (likely BUSL or similar -- needs direct verification of LICENSE file)

2. **`ostium-python-sdk`** -- Python SDK (v3.10)
   - URL: https://github.com/0xOstium/ostium-python-sdk
   - Available on PyPI: `ostium-python-sdk` (latest 0.1.16)
   - Features: Read platform state, place orders (Market/Limit/Stop), read PnL, edit/close positions
   - Subgraph integration: `SubgraphClient` for querying pairs, open trades, open orders
   - Network support: Arbitrum One (mainnet) + Arbitrum Sepolia (testnet)

3. **`use-ostium-python-sdk`** -- Example project
   - URL: https://github.com/0xOstium/use-ostium-python-sdk
   - Demonstrates: LIMIT orders, MARKET orders, TP/SL, PnL reading, trade closing

4. **`ostium-rust-sdk`** -- Rust SDK
   - URL: https://crates.io/crates/ostium-rust-sdk
   - Modern, type-safe Rust SDK built with Alloy for Ethereum interactions
   - Async/await support (Tokio)
   - GraphQL integration for direct API access
   - Feature flags: `env` (default), `full`, `update-contracts`
   - Automatic ABI fetching from Python SDK

### Code Completeness

The public smart contracts repo contains the deployed contracts but the degree of completeness (whether all contracts are published or just the core trading contracts) requires direct inspection. The oracle and keeper infrastructure code appears to be proprietary/off-chain.

### API Documentation

Official docs at: https://ostium-labs.gitbook.io/ostium-docs/developer/api-and-sdk

---

## 5. Team & Backing

### Founders

**Kaledora Fontana Kiernan-Linn** -- CEO
- Harvard University graduate
- Former quantitative researcher at Bridgewater Associates
- Prior: Royal Danish Ballet dancer (4 years as teenager)
- Met Marco in 2019 during freshman fall at Harvard

**Marco Antonio Ribeiro** -- CTO/Technical Lead
- Harvard University graduate
- Former competitor in International Olympiads for physics, biology, and chemistry
- Led development of all Ostium smart contracts and RFQ engine architecture
- Previously core developer for several DeFi protocols

### Team Size

~15 employees (as of late 2025)

### Funding History

| Round       | Amount | Date        | Lead Investors                           |
|-------------|--------|-------------|------------------------------------------|
| Seed        | $3.5M  | Oct 2023    | Localglobe, Alliance DAO                 |
| Strategic   | $4M    | 2025        | Undisclosed                              |
| Series A    | $20M   | Dec 2025    | General Catalyst, Jump Crypto            |
| **Total**   | **$27.8M** |         |                                          |

### Full Investor List

**Lead investors:**
- General Catalyst
- Jump Crypto (crypto arm of Jump Trading)

**Other investors:**
- Coinbase Ventures
- Wintermute
- Susquehanna International Group (SIG)
- GSR
- Localglobe
- Crucible Capital
- Alliance DAO

**Angel investors:**
- Balaji Srinivasan
- Nick Van Eck
- Shiliang Tang
- Angels from Bridgewater, Two Sigma, and Brevan Howard

### Token Status

- **No token launched yet** as of March 2026
- Points program running (Season 2 since Jan 5, 2026, 25M point cap)
- Season 1 retroactively distributed 10M points (launched March 31, 2025)
- TGE expected but unconfirmed; on-chain claim portal confirmed
- Expected token utility: governance, staking, fee sharing, liquidity incentives

### Multi-Chain Plans

No confirmed multi-chain deployment plans found. Currently Arbitrum-only. The $20M Series A will fund "infrastructure scaling" and "asset class coverage expansion" but no specific chain expansion has been announced.

---

## 6. Composability

### SDK Integration

**Python SDK** (`ostium-python-sdk`):
- `OstiumSDK` -- main entry point
- `sdk.subgraph` -- SubgraphClient for reading platform state
  - `get_pairs()` -- list all trading pairs with parameters
  - `get_open_trades()` -- query open positions
- `sdk.ostium` -- contract interactions (open, close, modify trades)
- `sdk.balance` -- account balance queries
- `sdk.faucet` -- testnet USDC

**Rust SDK** (`ostium-rust-sdk`):
- Type-safe contract interactions via Alloy
- GraphQL API integration
- Async/await with Tokio

### Subgraph

Ostium has a deployed subgraph accessible through the SDK. The SubgraphClient provides:
- Pair details (fees, OI caps, rollover rates)
- Open trades and orders
- Historical data

### Dune Analytics

Multiple dashboards available:
- Official: `dune.com/ostium_app/stats`
- Trading stats: `dune.com/queries/4064767/6859952`
- Monthly breakdown: `dune.com/queries/5707849/9266991`
- Daily volume + 7dma: `dune.com/queries/5761653/9347396`
- Weekly by asset type: `dune.com/queries/5495838`

### On-Chain Readability

The EIP-1967 proxy contracts on Arbitrum are verified and readable. External contracts can:
- Read the TradingStorage contract for pair data, OI, and trade state
- The registry pattern (IOstiumRegistry) allows service discovery
- Price feeds from Stork are verifiable on-chain (cryptographic attestations)

### API

The protocol exposes data through:
1. GraphQL subgraph (pair data, trades, orders)
2. On-chain contract reads (via registry)
3. Dune SQL queries (historical analytics)

### Integration Limitations

- Oracle data (Stork + QUODD) is not freely composable -- it is a pull-based system managed by Stork's node network
- No documented "hook" or callback system for external protocol integration
- Trading requires going through the OstiumTrading contract; no atomic composability with other DeFi protocols documented
- USDC-only collateral limits composability with other token ecosystems

---

## 7. Relevance for Remittance Hedging

### Current EM FX Coverage

This is the most significant finding for remittance hedging:

| Pair     | Status on Ostium | Remittance Corridor |
|----------|-----------------|---------------------|
| USD/MXN  | LIVE            | US -> Mexico        |
| USD/BRL  | LIVE            | US -> Brazil        |
| USD/NGN  | Referenced       | US/UK -> Nigeria    |
| USD/PHP  | Referenced       | US/ME -> Philippines|
| USD/KES  | Not found       | US/UK -> Kenya      |

**USD/MXN and USD/BRL are confirmed live.** NGN and PHP are referenced in Ostium context but whether they are currently live pairs requires direct platform verification.

### Oracle Infrastructure for EM FX

The Stork + QUODD oracle stack is designed for extensibility:
- QUODD provides institutional-grade data across "a broad range of global assets"
- Stork's chain-agnostic delivery and composable aggregation support new asset onboarding
- The custom oracle logic handles market hours, price gaps, and asset-specific nuances
- Adding a new FX pair requires: data source availability (QUODD or equivalent), Stork node configuration, and Ostium team deployment

For EM FX pairs not currently available (USD/KES, etc.), the bottleneck is likely **reliable institutional-grade price feed availability** rather than technical architecture limitations.

### Forking Viability for Celo Deployment

**Technical feasibility: Moderate-to-High**

Favorable factors:
- Smart contracts are open source (Gains v5 fork, published on GitHub)
- Solidity contracts, compatible with Celo's EVM
- Hardhat development environment
- Well-documented architecture (DeepWiki, GitBook docs)
- Registry pattern makes component replacement feasible

Significant challenges:
1. **Oracle infrastructure is the hardest part to replicate.** Stork + QUODD data partnerships are proprietary. A Celo fork would need:
   - Alternative oracle provider (Chainlink on Celo, Pyth, or custom Stork integration)
   - FX price feed sources with sufficient coverage for EM pairs
   - Market hours logic for each asset class
2. **Liquidity cold-start problem.** The Shared Liquidity Layer needs USDC deposits. Celo's DeFi ecosystem is much smaller than Arbitrum's.
3. **Keeper infrastructure.** Gelato Functions (or equivalent) needed for liquidations and order execution on Celo.
4. **USDC availability on Celo.** Circle has deployed USDC on Celo, but liquidity depth is limited.

### Alternative Approaches

Rather than forking Ostium for Celo, consider:

1. **Build hedging instruments on top of Ostium on Arbitrum**: Use the Python/Rust SDK to programmatically open FX hedge positions. A remittance protocol on Celo could bridge to Arbitrum for hedging.

2. **Cross-chain integration**: Use Ostium's subgraph + SDK to read FX rates and OI data, then construct hedging vaults that interact with Ostium via bridge.

3. **Lobby for new pairs**: If Ostium does not yet list specific EM FX pairs (USD/KES, USD/NGN, USD/PHP), the team's stated goal is to expand asset coverage. Their oracle infrastructure supports it -- the constraint is data partnerships.

4. **Use Ostium as price oracle**: Even if not trading on Ostium directly, the Stork oracle feeds could potentially be consumed by external protocols for FX rate data.

---

## 8. Comparison with Competitors

| Feature           | Ostium          | Hyperliquid      | Gains (gTrade)  | GMX v2           |
|-------------------|-----------------|------------------|-----------------|------------------|
| RWA Focus         | 95%+ OI in RWA  | Crypto-dominant  | Mixed           | Crypto-dominant  |
| FX Pairs          | 10-12+          | Limited          | Several         | None             |
| EM FX (MXN, BRL)  | Yes             | No               | Some            | No               |
| Max Leverage      | 200x            | 50x              | 150x            | 100x             |
| Oracle (RWA)      | Stork + QUODD   | N/A              | Chainlink       | Chainlink        |
| Chain             | Arbitrum        | Own L1           | Arbitrum/Polygon| Arbitrum/Avalanche|
| Open Source       | Yes (Gains fork)| Partially        | Yes             | Yes              |
| SDK               | Python + Rust   | Python + REST    | None official   | None official    |

---

## 9. Key Risks & Considerations

1. **Oracle centralization**: The Stork + QUODD oracle stack, while performant, introduces centralization risk. A majority of node infrastructure is managed by Stork. Custom aggregation logic is built by Ostium's development company.

2. **No token yet**: The protocol is pre-TGE. Governance is centralized with the team. Pair listings, parameter changes, and upgrades are team-controlled.

3. **Proxy contracts**: All core contracts are upgradeable proxies (EIP-1967). The team can modify contract logic.

4. **Regulatory risk**: Offering leveraged FX and equity perpetuals to global users operates in a gray area. The "competing with brokers" positioning invites regulatory scrutiny.

5. **Liquidity Buffer risk**: In extreme scenarios where trader PnL exceeds the Liquidity Buffer, Market Making Vault LPs bear the losses. This is similar to GLP-style vault risk.

6. **EM FX liquidity depth**: Even if pairs are listed, EM FX pairs likely have lower OI caps and wider spreads than majors like EUR/USD or Gold.

---

## Sources

### Primary
- [Ostium Official Site](https://www.ostium.com/)
- [Ostium Documentation (GitBook)](https://ostium-labs.gitbook.io/ostium-docs)
- [Ostium GitHub](https://github.com/0xOstium)
- [Smart Contracts Public Repo](https://github.com/0xOstium/smart-contracts-public)
- [Ostium Python SDK](https://github.com/0xOstium/ostium-python-sdk)
- [Ostium DeFiLlama](https://defillama.com/protocol/ostium)
- [Ostium on CoinGecko](https://www.coingecko.com/en/exchanges/ostium)

### Funding & Team
- [The Block: $24M Funding](https://www.theblock.co/post/381241/harvard-alumni-founded-ostium-lands-24-million-in-fresh-funding-to-scale-onchain-perpetuals-for-rwas)
- [CoinDesk: $20M Series A](https://www.coindesk.com/business/2025/12/03/ostium-raises-usd20m-series-a-led-by-general-catalyst-jump-crypto-to-put-tradfi-perps-onchain)
- [Fortune: Harvard Grads Raise $20M](https://fortune.com/2025/12/03/ostium-series-a-fundraise-perpetuals-perps-crypto/)
- [BusinessWire: Series A Announcement](https://www.businesswire.com/news/home/20251203478893/en/Ostium-Raises-$20-Million-Series-A-from-General-Catalyst-Jump-Crypto-to-Bring-Global-Markets-Onchain)

### Architecture & Oracle
- [DeepWiki: System Architecture](https://deepwiki.com/0xOstium/smart-contracts-public/2-system-architecture)
- [Stork Network: Ostium Case Study](https://www.stork.network/case-studies/ostium-rwa-custom-oracle)
- [QUODD Partnership (PR Newswire)](https://www.prnewswire.com/news-releases/ostium-leverages-quodd-market-data-to-deliver-institutional-grade-pricing-for-onchain-trading-302696989.html)
- [Chainlink Data Streams Integration](https://chainlinktoday.com/chainlink-data-streams-to-power-ostiums-low-latency-crypto-feeds/)

### Analytics
- [Dune: Ostium Stats](https://dune.com/ostium_app/stats)
- [Blockworks: RWA-Based DEX Analysis](https://blockworks.com/news/ostium-dex-points-rwa-arbitrum)
- [CryptoWinRate: 2026 Review](https://www.cryptowinrate.com/ostium-review)

### Reviews & Analysis
- [Decentralised.news: 2026 Review](https://decentralised.news/ostium-review-2026-on-chain-perpetual-exchange-for-real-world-assets)
- [CoinCodeCap: Feb 2026 Review](https://signals.coincodecap.com/ostium-review)
- [Shoal Research: Macro Markets Onchain](https://www.shoal.gg/p/bringing-macro-markets-onchain-with)
- [Ostium Blog: New FX Pairs](https://www.ostium.com/blog/new-fx-pairs-aud-usd-nzd-usd-and-usd-chf)

### SDK & Integration
- [Ostium Rust SDK (crates.io)](https://crates.io/crates/ostium-rust-sdk)
- [Ostium Python SDK (PyPI)](https://pypi.org/project/ostium-python-sdk/0.1.16/)
- [Ostium API & SDK Docs](https://ostium-labs.gitbook.io/ostium-docs/developer/api-and-sdk)
- [Fee Breakdown Docs](https://ostium-labs.gitbook.io/ostium-docs/fee-breakdown)
- [Price Oracle Docs](https://ostium-labs.gitbook.io/ostium-docs/supporting-infrastructure/price-oracle)
