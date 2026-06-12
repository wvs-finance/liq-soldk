# Research: EVM Open-Source Perpetual Futures Protocols for Remittance Pair Liquidity

**Date:** March 31, 2026
**Author:** Papa Bear Deep Research Analysis

---

## Executive Summary

This report catalogs and analyzes all major EVM-based perpetual futures protocols relevant to building remittance-focused hedging infrastructure. The investigation covers 20+ protocols across architecture type, license, composability, FX pair availability, and deployment chains.

**Key findings:**

1. **GMX v2** remains the most composable EVM perp protocol with the richest on-chain reader infrastructure, but lacks FX pairs natively.
2. **Gains Network (gTrade)** offers the broadest FX pair coverage (1000x leverage on forex) with MIT-licensed contracts and Chainlink oracle integration.
3. **Ostium** is the standout protocol for RWA/FX perpetuals on Arbitrum, built as a Gains v5 fork with dedicated FX, commodity, and index markets.
4. **UpDown** is the only protocol discovered that operates natively on Celo with FX futures on stablecoin pairs including NGN -- directly relevant to remittance corridors.
5. **Synthetix Perps v3** on Base offers strong composability via its modular market system but has consolidated away from multi-chain deployment.
6. **Hyperliquid** dominates volume (80% market share) but its core perp engine is NOT EVM smart contracts -- HyperEVM provides composability hooks but the order book runs on HyperCore (custom L1).

**For remittance infrastructure specifically**, the recommended stack is: UpDown (Celo, native FX), Ostium (Arbitrum, RWA/FX perps), and GMX v2 (Arbitrum, composable funding rate reads) as the primary protocols to integrate with or fork from.

---

## Protocol-by-Protocol Analysis

---

### 1. GMX (v1 and v2)

| Field | Details |
|-------|---------|
| **Chain Deployments** | Arbitrum (primary), Avalanche |
| **GitHub** | https://github.com/gmx-io/gmx-synthetics (v2), https://github.com/gmx-io/gmx-contracts (v1) |
| **License** | BUSL-1.1 (converts to GPL v2+ on August 31, 2026 or earlier per ENS date) |
| **Architecture** | Oracle-based pool model with isolated GM markets. Each market has index token, long token, short token, and GM liquidity token. NOT a vAMM or order book. |
| **Key Contracts (Arbitrum)** | ExchangeRouter: `0x87d66368cD08a7Ca42252f5ab44B2fb6d1Fb8d15`, DataStore: `0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8`, OrderVault: `0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5` |
| **Funding Rate** | Adaptive funding rate where dominant side pays weaker side. Adjusts in segments to incentivize balance. Fully on-chain, readable from DataStore. |
| **Available Pairs** | Crypto majors (BTC, ETH, SOL, AVAX, etc.). No native FX or stablecoin pairs. |
| **TVL** | ~$603M (January 2026) |
| **Oracle** | Chainlink Data Streams (low-latency). 1.2% of protocol fees go to Chainlink. |
| **Composability** | **Excellent.** Reader contract provides market data, positions, open interest. DataStore is queryable. 80+ protocols built on GMX. TypeScript SDK available. |
| **API/SDK** | REST API, TypeScript SDK, comprehensive developer docs |

**Assessment:** Best-in-class composability for reading on-chain state (funding rates, OI, mark prices). BUSL license is a limitation until August 2026 conversion. No FX pairs limits direct remittance use but funding rate signals are highly valuable as macro indicators.

---

### 2. dYdX (v4)

| Field | Details |
|-------|---------|
| **Chain Deployments** | dYdX Chain (Cosmos SDK appchain). v3 was on StarkEx (NOT EVM). |
| **GitHub** | https://github.com/dydxprotocol/v4-chain |
| **License** | AGPL-3.0 (Cosmos modules) |
| **Architecture** | Off-chain order book with Cosmos SDK consensus. NOT EVM smart contracts. |
| **Key Contracts** | Cosmos modules, not Solidity contracts. EVM bridging via Axelar GMP. |
| **Funding Rate** | Standard perp funding. Calculated off-chain in the order book engine. |
| **Available Pairs** | 35+ crypto pairs |
| **TVL** | ~$200M daily volume early 2025 |
| **Oracle** | Custom oracle network within validator set |
| **Composability** | **Poor for EVM.** IBC-native, requires Axelar bridge for EVM interaction. No direct Solidity composability. |
| **API/SDK** | REST/WebSocket API, TypeScript/Python clients |

**Assessment:** Not suitable for EVM composability. The Cosmos architecture means no direct smart contract interaction from Arbitrum, Base, or Celo. Useful only as a data source via off-chain APIs.

---

### 3. Perpetual Protocol (v2 "Curie")

| Field | Details |
|-------|---------|
| **Chain Deployments** | Optimism |
| **GitHub** | https://github.com/perpetual-protocol/perp-curie-contract, https://github.com/perpetual-protocol/perp-oracle-contract |
| **License** | GPL-3.0-or-later (oracle contracts). Core contracts appear GPL-licensed. |
| **Architecture** | vAMM built on Uniswap V3 concentrated liquidity. Virtual tokens placed in Uni V3 pools. Clearinghouse manages USDC collateral. |
| **Key Contracts** | Deployed on Optimism. ClearingHouse, OrderBook, AccountBalance, Exchange contracts. |
| **Funding Rate** | Block-by-block settlement. Driven by vAMM price vs. Chainlink index price. |
| **Available Pairs** | Crypto pairs with Chainlink feeds. Permissionless market creation planned. No FX pairs observed. |
| **TVL** | ~$2.8M (significantly declined). PERP delisted from Binance Nov 2025. |
| **Oracle** | Chainlink for index price. vAMM for execution price. |
| **Composability** | **Good in theory.** Contracts are on-chain and readable, but extremely low liquidity makes practical composability questionable. |
| **API/SDK** | SDK and subgraph available |

**Assessment:** Architecturally interesting (vAMM + Uni V3 hybrid) and GPL-licensed, making it forkable. However, the protocol is in severe decline with ~$2.8M TVL and major exchange delistings. Useful primarily as a reference implementation, not as live infrastructure. The permissionless market concept (any Chainlink feed = perpetual market) is relevant for remittance pairs.

---

### 4. Synthetix Perps v3 / Kwenta

| Field | Details |
|-------|---------|
| **Chain Deployments** | Base (primary). Sunsetted on Arbitrum (close-only). Legacy v2 on Optimism. |
| **GitHub** | https://github.com/Synthetixio/synthetix-v3 (monorepo), https://github.com/Synthetixio/v3-contracts (ABIs + addresses) |
| **License** | MIT (Synthetix v3 monorepo) |
| **Architecture** | Modular market system. PerpsMarket module extends core Synthetix v3 protocol. Cross-margin with NFT-based account controls. |
| **Key Contracts** | Perps market module at `markets/perps-market/` in v3 monorepo. Addresses in v3-contracts repo (chain 8453, preset "andromeda"). |
| **Funding Rate** | Velocity-based funding. Rate changes proportionally to skew. Fully on-chain and queryable. |
| **Available Pairs** | 81+ markets on Kwenta. Crypto-focused. No FX pairs observed. |
| **TVL** | ~$210M (Synthetix V3), ~$21.5M USDC collateral |
| **Oracle** | Pyth Network (primary for v3 on Base) |
| **Composability** | **Very good.** Modular architecture designed for integrators. Multi-collateral support (USDC, sUSD, sETH, sBTC). Perps V3 developer docs specifically target integrators. |
| **API/SDK** | Synthetix SDK, detailed integrator documentation |

**Assessment:** MIT license and modular architecture make this highly attractive for forking or integrating. The consolidation to Base-only is a limitation for Celo deployment. The velocity-based funding rate model is elegant and on-chain readable. Kwenta acquisition by Synthetix means tighter integration. Strong candidate for funding rate reads and potential fork-and-deploy to other chains.

---

### 5. Gains Network (gTrade)

| Field | Details |
|-------|---------|
| **Chain Deployments** | Arbitrum (primary), Polygon |
| **GitHub** | https://github.com/GainsNetwork/gTrade-v6.1 (v6.1), https://github.com/GainsNetwork/gTrade-v6 (v6), https://github.com/GainsNetwork/gTrade-v5 (v5). Organization: https://github.com/GainsNetwork-org |
| **License** | MIT |
| **Architecture** | Synthetic oracle-based AMM. Trades settled against liquidity pools (not order book). Diamond proxy pattern (v8+). Collateral in USDC/DAI. |
| **Key Contracts (Arbitrum)** | GNSMultiCollatDiamond (main entry). GNS Token: `0x18c11FD286C5EC11c3b683Caa813B77f5163A122` |
| **Funding Rate** | Core markets use funding fees (moved from borrowing fees in v10). OI hedging introduced 2025. |
| **Available Pairs** | **290+ pairs: crypto, forex, commodities, stocks, indices.** Up to 1000x leverage on forex. |
| **TVL** | Not precisely reported in searches but active with significant volume |
| **Oracle** | Chainlink custom DON (Decentralized Oracle Network) for real-time on-demand spot prices. Also integrating Chainlink CCIP and Data Streams. |
| **Composability** | **Good.** Diamond pattern enables direct smart contract interaction (v8+). Comprehensive Natspec docs. SDK available. |
| **API/SDK** | TypeScript SDK, backend integrator docs, subgraph |

**Assessment:** **Top candidate for remittance use cases.** MIT license, 290+ pairs including extensive forex coverage, 1000x forex leverage, and Chainlink oracle integration. The v5 codebase was forked by Ostium for RWA perps. The diamond pattern (v8+) enables clean external contract integration. Forex pairs can serve as proxy hedges for remittance corridor risk.

---

### 6. Ostium

| Field | Details |
|-------|---------|
| **Chain Deployments** | Arbitrum |
| **GitHub** | https://github.com/0xOstium/smart-contracts-public, https://github.com/0xOstium/ostium-python-sdk |
| **License** | Adapted from Gains v5 (MIT upstream). Check repository header for modifications. |
| **Architecture** | Fork of Gains v5 with significant modifications for RWA perpetuals. Oracle-based synthetic trades against liquidity pools. USDC settlement. |
| **Key Contracts** | Deployed on Arbitrum One. Repository contains official deployed contracts. |
| **Funding Rate** | Rolling fees mechanism (adapted from Gains). On-chain, queryable. |
| **Available Pairs** | **FX (GBP, EUR, JPY), commodities (gold, silver, copper, crude oil), indices (S&P500, Nikkei, Dow), and crypto.** 95%+ of OI is in traditional/RWA markets. |
| **TVL** | ~$56.6M |
| **Oracle** | Custom oracle infrastructure for RWA price feeds |
| **Composability** | **Good.** Open-source contracts on GitHub. Python SDK for programmatic access (order placement, market listings, rolling fees, OI caps). Supports testnet. |
| **API/SDK** | Python SDK (PyPI package), REST API for historical queries |

**Assessment:** **Critical protocol for remittance hedging infrastructure.** Ostium is the leading on-chain venue for FX perpetuals. Its focus on traditional market assets (FX, commodities, indices) directly serves the remittance corridor hedging use case. The Gains v5 fork heritage means familiar Solidity patterns. $24M+ in funding from General Catalyst and Jump Crypto signals institutional backing. FX pairs like GBP/USD, EUR/USD, JPY/USD are directly relevant. The missing piece is emerging market currencies (NGN, PHP) which are not yet listed.

---

### 7. Vertex Protocol

| Field | Details |
|-------|---------|
| **Chain Deployments** | Arbitrum (was primary). **SHUT DOWN August 2025.** |
| **GitHub** | https://github.com/vertex-protocol |
| **License** | N/A (defunct) |
| **Architecture** | Hybrid order book + AMM. Off-chain sequencer with on-chain settlement. |
| **Status** | Acquired by Ink Foundation July 2025. All trading ended August 14, 2025. |

**Assessment:** No longer operational. Historical reference only.

---

### 8. HMX (now DESK)

| Field | Details |
|-------|---------|
| **Chain Deployments** | Arbitrum |
| **GitHub** | Not clearly identified in searches |
| **License** | Unknown |
| **Architecture** | Cross-margin, multi-asset collateral. Up to 1000x leverage. Velocity-based funding fees, adaptive pricing. |
| **Status** | Rebranded to DESK. Active but limited information. |

**Assessment:** Insufficient public documentation for integration assessment. The rebrand to DESK suggests a pivot. Not recommended as primary infrastructure.

---

### 9. Hyperliquid

| Field | Details |
|-------|---------|
| **Chain Deployments** | Hyperliquid L1 (custom chain). HyperEVM for smart contract composability. |
| **GitHub** | https://github.com/hyperliquid-dex (node software), https://github.com/hyperliquid-dev/hyper-evm-lib |
| **License** | Node software is open source. Core perp engine is proprietary. |
| **Architecture** | **Dual-layer:** HyperCore (custom L1, CLOB order book, 200K orders/sec) + HyperEVM (EVM-compatible layer for smart contracts). |
| **Key Contracts** | HyperEVM contracts can interact with HyperCore via precompiles. hyper-evm-lib abstracts these interactions. |
| **Funding Rate** | Standard perp funding. Readable via API (REST/WebSocket). Funding rate data available at `/info` endpoint. |
| **Available Pairs** | 100+ crypto pairs. S&P 500 perpetual (licensed, March 2026). HIP-3 enables permissionless perp deployment. |
| **TVL** | Dominant: 80% market share, $357B monthly volume, $30B daily |
| **Oracle** | Custom oracle validators within Hyperliquid consensus |
| **Composability** | **Mixed.** HyperEVM allows atomic composability with CLOB via precompiles. But this is Hyperliquid-native only -- no composability from Arbitrum/Base/Celo. The hyper-evm-lib provides the developer interface. |
| **API/SDK** | Comprehensive REST/WebSocket API. Python SDK. TypeScript SDK. |

**Assessment:** Hyperliquid is the volume leader by an enormous margin. HyperEVM composability is powerful but locked within the Hyperliquid ecosystem. For cross-chain remittance infrastructure, you cannot call Hyperliquid contracts from Arbitrum or Celo. Best used as a data source (funding rates via API) or if deploying directly on HyperEVM. The HIP-3 permissionless perp deployment could theoretically enable stablecoin/FX pairs, but requires 500K HYPE ($20M) stake. USDH native stablecoin (backed by Treasuries via Stripe Bridge/BlackRock) is in development.

---

### 10. Level Finance

| Field | Details |
|-------|---------|
| **Chain Deployments** | BNB Chain (primary), Arbitrum |
| **GitHub** | https://github.com/level-fi (org). Repos: level-core-contracts, level-trading-contracts, v2-core-contracts, v2-trading-contracts |
| **License** | Not confirmed in searches (check repo LICENSE files) |
| **Architecture** | Pool-based model similar to GMX. Programmatic liquidity pools. Chainlink oracles. |
| **Key Contracts** | Deployed on BNB Chain and Arbitrum |
| **Funding Rate** | Standard pool-based funding mechanism |
| **Available Pairs** | Crypto majors on BNB Chain |
| **TVL** | Declined from peak. Specific 2026 figure not found. |
| **Oracle** | Chainlink |
| **Composability** | **Moderate.** Open GitHub repos suggest readable contracts. |
| **API/SDK** | Limited SDK presence |

**Assessment:** Smaller protocol primarily on BNB Chain. The v2 contracts are publicly available on GitHub which provides forking potential. Not directly relevant for Celo/remittance use but the pool-based architecture is a reference implementation.

---

### 11. MUX Protocol

| Field | Details |
|-------|---------|
| **Chain Deployments** | Arbitrum (primary), BNB Chain, Optimism, Avalanche, Fantom |
| **GitHub** | https://github.com/mux-world/mux-protocol, https://github.com/mux-world/mux-aggregator-protocol, https://github.com/mux-world/mux3-protocol |
| **License** | Check repo (multiple repos available) |
| **Architecture** | **Aggregator + native pools.** Aggregator routes to best liquidity source (GMX, Gains, etc.). Creates position containers that interact with underlying protocols. |
| **Key Contracts** | ProxyFactory for position containers. MUXLP native pools. |
| **Funding Rate** | Depends on underlying protocol routed to |
| **Available Pairs** | Whatever underlying protocols support |
| **TVL** | Multi-chain presence but modest TVL |
| **Oracle** | Depends on underlying protocols |
| **Composability** | **Good.** Aggregator pattern is inherently composable. Position containers are smart contracts. |
| **API/SDK** | API available |

**Assessment:** Interesting as an aggregation layer. MUX could potentially route to multiple perp DEXes to find best execution for FX hedges. The mux3-protocol repo suggests active development. The aggregator pattern (creating position containers per trade) is architecturally relevant for building hedging infrastructure that spans multiple venues.

---

### 12. Vela Exchange

| Field | Details |
|-------|---------|
| **Chain Deployments** | Arbitrum |
| **GitHub** | https://github.com/VelaExchange/vela-exchange-contracts |
| **License** | Check repo |
| **Architecture** | Hybrid on-chain/off-chain. Vault-based (USDC-backed VLP). |
| **Key Contracts** | Vault contract (deposit, withdraw, open/close positions). Access contracts for configuration. |
| **Funding Rate** | Standard vault-based mechanism |
| **Available Pairs** | Crypto, some commodity pairs |
| **TVL** | Modest. Participated in Arbitrum STIP Round 1. |
| **Oracle** | Custom price feed system |
| **Composability** | **Moderate.** Contracts are on GitHub. Vault is USDC-backed. |
| **API/SDK** | Limited |

**Assessment:** Smaller Arbitrum protocol. Open-source contracts provide forking potential but limited FX coverage and modest TVL reduce practical utility.

---

### 13. ApolloX / APX Finance (now part of Aster)

| Field | Details |
|-------|---------|
| **Chain Deployments** | BNB Chain, Arbitrum |
| **GitHub** | https://github.com/apollox-finance/apollox-contracts, https://github.com/apollox-finance/apollox-perp-contracts |
| **License** | Check repo |
| **Architecture** | Fully on-chain perpetual trading (V2). Permissionless DEX Engine SDK for white-label perp DEX deployment. |
| **Status** | Merged with Astherus to form **Aster** (mid-2025). Backed by YZi Labs (formerly Binance Labs). |
| **Available Pairs** | Crypto pairs primarily |
| **Composability** | **Good SDK presence.** Permissionless DEX Engine allows launching custom perp DEXes. |

**Assessment:** The Permissionless DEX Engine concept is highly relevant -- it enables deploying a custom perp DEX on BNB Chain or Arbitrum. However, the merger into Aster changes the development trajectory. The SDK broker solution could theoretically be used to launch a remittance-focused perp DEX.

---

### 14. Aster (formerly APX + Astherus)

| Field | Details |
|-------|---------|
| **Chain Deployments** | BNB Chain, Arbitrum, Ethereum, Solana, 7+ chains total. Aster Chain (custom L1). |
| **GitHub** | Inherits from apollox-finance repos |
| **License** | Unknown for unified Aster contracts |
| **Architecture** | Hybrid. Aster Chain L1 (100K+ TPS, 50ms blocks) for private perps. EVM deployments for composability. |
| **Available Pairs** | Crypto pairs. $650B+ cumulative volume. |
| **TVL** | $450M+ |
| **Oracle** | Multiple oracle integrations |
| **Composability** | **Varies by chain.** EVM deployments are composable. Aster Chain is isolated. |

**Assessment:** Large scale but complex multi-chain architecture. The Binance Labs backing and BNB Chain focus make it less relevant for Celo-centric remittance infrastructure.

---

### 15. Cap Finance

| Field | Details |
|-------|---------|
| **Chain Deployments** | Arbitrum |
| **GitHub** | Limited public information found |
| **Website** | https://www.cap.finance/ |
| **Status** | Appears to be a smaller/less active protocol. Limited 2025-2026 presence in search results. |

**Assessment:** Insufficient information for meaningful evaluation. Not recommended.

---

### 16. Pika Protocol

| Field | Details |
|-------|---------|
| **Chain Deployments** | Optimism |
| **GitHub** | Contract addresses documented at docs.pikaprotocol.com/contracts |
| **License** | Not confirmed |
| **Architecture** | vAMM design with oracle price feeds. Dynamic liquidity adjustments and funding rates. Up to 200x leverage. |
| **Available Pairs** | Crypto, forex, commodities |
| **Oracle** | Real-time oracle price feeds (likely Chainlink) |
| **Composability** | **Moderate.** On-chain contracts on Optimism. |

**Assessment:** Interesting for its forex and commodity coverage on Optimism. The vAMM + oracle hybrid is similar to Perpetual Protocol. Worth investigating further if Optimism deployment is relevant.

---

### 17. Hubble Exchange

| Field | Details |
|-------|---------|
| **Chain Deployments** | Avalanche subnet ("Hubblenet") |
| **GitHub** | Not prominently found |
| **License** | Unknown |
| **Architecture** | Fully decentralized matching and liquidation engine on Avalanche subnet. Multi-collateral (AVAX, USDC, hUSD), cross-margin. USDC as gas token. |
| **Available Pairs** | AVAX, ETH, SOL initially. Plans for expansion. |
| **TVL** | Modest per DefiLlama |
| **Composability** | **Limited.** Subnet isolation reduces cross-chain composability. |

**Assessment:** Novel subnet approach with USDC gas token is interesting for UX. However, Avalanche subnet isolation limits composability. Not directly relevant for remittance infrastructure.

---

### 18. Contango

| Field | Details |
|-------|---------|
| **Chain Deployments** | Ethereum (primary, 69% volume), Arbitrum, Base, Optimism, Gnosis, Polygon (10 chains total) |
| **GitHub** | https://github.com/contango-xyz/core, https://github.com/contango-xyz/core-v2 |
| **License** | BSL-1.1 (Business Source License) |
| **Architecture** | **Unique: Looping strategy.** Automates recursive lending/borrowing on money markets to create leveraged positions. Not a traditional perp DEX. Aggregates liquidity from spot + money markets. |
| **Available Pairs** | 250+ trading pairs. Fixed-maturity futures available. |
| **TVL** | ~$31.7M (Q1 2025) |
| **Oracle** | Inherits from underlying money markets (Aave, Compound, etc.) |
| **Composability** | **Good.** Multi-chain deployment. Integrates with existing DeFi primitives. Positions built on Aave/Compound/etc. |
| **API/SDK** | Not prominently found |

**Assessment:** Contango's looping architecture is fundamentally different from perp DEXes. It creates synthetic leverage by automating what users already do manually (deposit, borrow, swap, repeat). This means: (a) funding costs are money market borrow rates, not perp funding rates, and (b) the positions are deeply composable with existing DeFi. For remittance infrastructure, Contango could enable leveraged stablecoin positions using existing money markets. The BSL license limits forking potential.

---

### 19. Aark Digital

| Field | Details |
|-------|---------|
| **Chain Deployments** | Arbitrum (primary), expanding multi-chain |
| **GitHub** | Not prominently found |
| **License** | Unknown |
| **Architecture** | CLOB (Centralized Limit Order Book) via Orderly Network partnership. Up to 1000x leverage. 0.01% trading fee. |
| **Available Pairs** | Crypto pairs |
| **TVL** | ~$200M daily volume claimed |
| **Oracle** | Via Orderly Network infrastructure |
| **Composability** | **Limited.** Orderly Network dependency means off-chain order matching. |

**Assessment:** High-performance trading but limited composability and no FX pairs. Not suitable for remittance infrastructure.

---

### 20. UpDown (Celo)

| Field | Details |
|-------|---------|
| **Chain Deployments** | **Celo** (exclusive) |
| **GitHub** | Not found in searches. Likely early-stage. |
| **License** | Unknown |
| **Architecture** | Leveraged FX futures on stablecoin pairs. Up to 50x leverage. |
| **Website** | updown.xyz |
| **Available Pairs** | **Stablecoin pairs tracking GBP, JPY, NGN, and others** from Tether and Mento Labs. |
| **Oracle** | Likely Celo SortedOracles or Chainlink on Celo |
| **Composability** | **Unknown.** Very new protocol (March 2026 launch). |
| **TVL** | New launch, data not yet available |

**Assessment:** **The most directly relevant protocol for remittance use cases.** UpDown is the ONLY protocol discovered that: (a) operates on Celo, (b) offers FX futures specifically, (c) supports NGN stablecoin pairs, and (d) uses Mento Labs stablecoins (cUSD, cNGN). Launched March 2026, it is very early stage. Critical to monitor and potentially integrate with. The 50x leverage on stablecoin FX pairs is a powerful primitive for remittance corridor hedging.

---

### 21. Drift Protocol

| Field | Details |
|-------|---------|
| **Chain Deployments** | Solana only |
| **Status** | No EVM components or plans found |

**Assessment:** Solana-only. Not relevant for EVM-based remittance infrastructure.

---

## Summary Comparison Table

| Protocol | Chain(s) | License | Architecture | FX Pairs | Composability | TVL | Status |
|----------|----------|---------|-------------|----------|---------------|-----|--------|
| **GMX v2** | Arbitrum, Avalanche | BUSL-1.1 | Oracle pool | No | Excellent | $603M | Active |
| **Synthetix v3** | Base | MIT | Modular markets | No | Very Good | $210M | Active |
| **Gains/gTrade** | Arbitrum, Polygon | MIT | Synthetic oracle AMM | **Yes (290+ incl. forex)** | Good | Active | Active |
| **Ostium** | Arbitrum | MIT (Gains v5 fork) | RWA perps | **Yes (FX, indices, commodities)** | Good | $56.6M | Active, funded |
| **UpDown** | **Celo** | Unknown | FX futures | **Yes (GBP, JPY, NGN)** | Unknown | New | Launched Mar 2026 |
| **Hyperliquid** | HyperL1 + HyperEVM | Partial OSS | CLOB + EVM | Limited | Mixed | Dominant | Active |
| **Perpetual v2** | Optimism | GPL-3.0 | vAMM + Uni V3 | No | Good (low liq) | $2.8M | Declining |
| **Contango** | 10 chains | BSL-1.1 | Looping/money markets | Indirect | Good | $31.7M | Active |
| **MUX** | 5 chains | Check repo | Aggregator | Inherited | Good | Modest | Active |
| **Level Finance** | BNB, Arbitrum | Check repo | Pool-based | No | Moderate | Declining | Active |
| **Vela** | Arbitrum | Check repo | Hybrid vault | Limited | Moderate | Modest | Active |
| **ApolloX/Aster** | BNB, Arbitrum, 7+ | Unknown | CLOB + SDK | No | Good (SDK) | $450M | Active (merged) |
| **Pika** | Optimism | Unknown | vAMM + oracle | Some forex | Moderate | Modest | Active |
| **Hubble** | Avalanche subnet | Unknown | CLOB on subnet | No | Limited | Modest | Active |
| **Aark** | Arbitrum | Unknown | CLOB (Orderly) | No | Limited | Active | Active |
| **dYdX v4** | Cosmos | AGPL-3.0 | Off-chain CLOB | No | None (EVM) | Active | Active |
| **Vertex** | -- | -- | -- | -- | -- | -- | **Shutdown** |

---

## Recommendations

### 1. Reading On-Chain Funding Rates as Macro Signals

**Primary:** GMX v2 on Arbitrum
- Reader contract and DataStore provide direct on-chain access to funding rates, open interest, and market state
- Adaptive funding rate mechanism gives nuanced long/short skew signals
- 80+ protocol integrations validate the composability pattern
- Contract: Query DataStore at `0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8`

**Secondary:** Synthetix Perps v3 on Base
- Velocity-based funding rates are on-chain and queryable
- MIT license enables forking the rate-reading infrastructure
- PerpsMarketConfiguration contract stores all rate parameters

**Data Supplement:** Hyperliquid API
- `/info` endpoint provides funding rate data for 100+ pairs
- Not on-chain composable from other EVM chains but excellent for off-chain signal aggregation

### 2. Trading Stablecoin/FX Perpetuals for Hedging

**Primary:** Ostium on Arbitrum
- Purpose-built for RWA/FX perpetuals (GBP, EUR, JPY, indices, commodities)
- 95%+ of open interest is in traditional market assets
- USDC settlement on Arbitrum
- Python SDK for programmatic trading
- $24M+ institutional funding signals longevity

**Primary (Celo-native):** UpDown on Celo
- **Only protocol with NGN stablecoin pairs** on Celo
- Direct integration with Mento Labs stablecoins (cUSD, cNGN)
- 50x leverage on FX futures
- Critical for Nigeria-corridor remittance hedging
- VERY new (March 2026) -- monitor for stability and liquidity depth

**Secondary:** Gains Network (gTrade) on Arbitrum
- 290+ pairs including extensive forex at 1000x leverage
- MIT license enables forking for custom deployment
- Mature protocol with battle-tested contracts
- Chainlink DON integration provides reliable price feeds

### 3. Composability with External Smart Contracts

**Tier 1 (Best composability):**
1. **GMX v2** -- Reader contract, DataStore, 80+ integrations, TypeScript SDK
2. **Synthetix v3** -- MIT license, modular market architecture, integrator-focused docs
3. **Gains/gTrade** -- Diamond proxy pattern (v8+), MIT license, SDK

**Tier 2 (Good composability):**
4. **Ostium** -- Open-source contracts, Python SDK
5. **MUX** -- Aggregator pattern with position containers
6. **Contango** -- Multi-chain, builds on existing DeFi primitives

**Tier 3 (Limited/conditional):**
7. **Hyperliquid** -- Only composable within HyperEVM, not from external chains
8. **Perpetual v2** -- GPL contracts, but dangerously low liquidity

### 4. Deployment on Chains Where Remittance Stablecoins Exist

**Celo (cUSD, cNGN, cEUR):**
- **UpDown** is the only active perp-like protocol on Celo (launched March 2026)
- No other perp DEX has deployed on Celo
- **Recommendation:** Fork Gains v5 or Synthetix v3 (both MIT-licensed) and deploy on Celo with Mento Labs stablecoin integration. Celo's low-cost L2 architecture and native stablecoin support make it ideal.
- Oracle infrastructure: Celo SortedOracles + Chainlink on Celo are available

**Arbitrum (USDC, USDT):**
- Richest perp DEX ecosystem: GMX, Gains, Ostium, MUX, Vela, Level
- Best for reading funding rates and trading FX perps

**Base (USDC):**
- Synthetix v3 Perps is the primary option
- Growing ecosystem but fewer perp protocols than Arbitrum

**Optimism (USDC):**
- Perpetual Protocol v2 (declining) and Pika Protocol
- Less vibrant than Arbitrum for new deployments

---

## Strategic Architecture Recommendation

For a remittance-focused hedging system, the recommended multi-protocol architecture is:

```
Layer 1: Signal Aggregation
  - GMX v2 (Arbitrum) -- on-chain funding rate reads via Reader/DataStore
  - Hyperliquid API -- off-chain funding rate data for 100+ pairs
  - Ostium (Arbitrum) -- FX-specific OI and rate data

Layer 2: Hedging Execution
  - Ostium (Arbitrum) -- primary FX perp execution (GBP, EUR, JPY)
  - Gains/gTrade (Arbitrum) -- secondary execution for exotic pairs
  - UpDown (Celo) -- NGN corridor hedging, cNGN pairs

Layer 3: Custom Deployment (future)
  - Fork Synthetix v3 (MIT) or Gains v5 (MIT) to Celo
  - Integrate with Mento Labs stablecoins (cUSD, cNGN, cEUR)
  - Use Celo SortedOracles + Chainlink for FX price feeds
  - Target remittance-specific pairs: NGN/USD, PHP/USD, KES/USD
```

The critical gap in the current ecosystem is **emerging market FX perpetuals on Celo**. UpDown's March 2026 launch partially addresses this for NGN, but a purpose-built protocol using MIT-licensed Gains or Synthetix code would provide the most control and composability for the hedging use case described in this project's broader vision.

---

## Key Repository Links (Quick Reference)

| Protocol | Repository |
|----------|-----------|
| GMX v2 Synthetics | https://github.com/gmx-io/gmx-synthetics |
| GMX v1 | https://github.com/gmx-io/gmx-contracts |
| Synthetix v3 | https://github.com/Synthetixio/synthetix-v3 |
| Synthetix v3 Addresses | https://github.com/Synthetixio/v3-contracts |
| Gains gTrade v6.1 | https://github.com/GainsNetwork/gTrade-v6.1 |
| Gains gTrade v5 | https://github.com/GainsNetwork/gTrade-v5 |
| Ostium | https://github.com/0xOstium/smart-contracts-public |
| Ostium Python SDK | https://github.com/0xOstium/ostium-python-sdk |
| Perpetual Protocol v2 | https://github.com/perpetual-protocol/perp-curie-contract |
| Perp Oracle | https://github.com/perpetual-protocol/perp-oracle-contract |
| MUX Aggregator | https://github.com/mux-world/mux-aggregator-protocol |
| MUX v3 | https://github.com/mux-world/mux3-protocol |
| Contango Core | https://github.com/contango-xyz/core |
| Contango v2 | https://github.com/contango-xyz/core-v2 |
| Level Finance | https://github.com/level-fi |
| Vela Exchange | https://github.com/VelaExchange/vela-exchange-contracts |
| ApolloX | https://github.com/apollox-finance/apollox-contracts |
| ApolloX Perps | https://github.com/apollox-finance/apollox-perp-contracts |
| Hyperliquid EVM Lib | https://github.com/hyperliquid-dev/hyper-evm-lib |
| dYdX v4 Chain | https://github.com/dydxprotocol/v4-chain |

---

## Sources

- [GMX Docs - Contracts V2](https://gmx-docs.io/docs/api/contracts-v2/)
- [GMX Synthetics GitHub](https://github.com/gmx-io/gmx-synthetics)
- [GMX Development Plan 2025](https://gmxio.substack.com/p/gmx-development-plan-for-2025)
- [Compass Labs - Guide to GMX V2](https://medium.com/@compasslabs/a-guide-to-perpetual-contracts-and-gmx-v2-a4770cbc25e3)
- [Perpetual Protocol - perp-curie-contract](https://github.com/perpetual-protocol/perp-curie-contract)
- [Synthetix V3 GitHub](https://github.com/Synthetixio/synthetix-v3)
- [Synthetix V3 on Base](https://blog.synthetix.io/synthetix-v3-on-base/)
- [Synthetix Acquires Kwenta](https://blog.synthetix.io/synthetix-acquires-ecosystem-leading-perps-platform-kwenta/)
- [Synthetix Sunsets Arbitrum Perps](https://www.theblock.co/post/333973/synthetix-sunsets-v3-perps-on-arbitrum-to-focus-solely-on-base)
- [Gains Network 2026 Roadmap](https://medium.com/gains-network/2026-roadmap-the-blueprint-for-gains-network-gtrade-and-gns-de08d050296a)
- [gTrade Overview](https://docs.gains.trade/gtrade-leveraged-trading/overview)
- [gTrade Chainlink Integration](https://medium.com/gains-network/gtrade-is-integrating-chainlinks-ccip-data-streams-to-bring-you-the-best-in-on-chain-leveraged-ac3c88b7bb5c)
- [Gains Network Contract Addresses - Arbitrum](https://docs.gains.trade/what-is-gains-network/contract-addresses/arbitrum-mainnet)
- [Ostium - smart-contracts-public](https://github.com/0xOstium/smart-contracts-public)
- [Ostium $20M Series A](https://www.businesswire.com/news/home/20251203478893/en/Ostium-Raises-$20-Million-Series-A-from-General-Catalyst-Jump-Crypto-to-Bring-Global-Markets-Onchain)
- [Ostium Documentation](https://ostium-labs.gitbook.io/ostium-docs)
- [Ostium Review 2026](https://www.cryptowinrate.com/ostium-review)
- [UpDown Launches FX Futures on Celo](https://crypto-economy.com/updown-leveraged-fx-futures-on-celo/)
- [UpDown on Celo Blog](https://blog.celo.org/updown-brings-leveraged-fx-futures-to-celo-16a183747610)
- [Hyperliquid hyper-evm-lib](https://github.com/hyperliquid-dev/hyper-evm-lib)
- [Hyperliquid Docs](https://hyperliquid.gitbook.io/hyperliquid-docs)
- [Hyperliquid S&P 500 Perps](https://www.coindesk.com/markets/2026/03/18/traders-can-now-bet-on-the-s-and-p-500-around-the-clock-without-ever-touching-a-traditional-stock-exchange)
- [MUX Aggregator Protocol](https://github.com/mux-world/mux-aggregator-protocol)
- [MUX Documentation](https://docs.mux.network/protocol/overview/leveraged-trading-aggregator)
- [Contango Core GitHub](https://github.com/contango-xyz/core)
- [Contango Q1 2025 Brief - Messari](https://messari.io/report/contango-q1-2025-brief)
- [Level Finance GitHub](https://github.com/level-fi)
- [Level Finance Docs](https://docs.level.finance/)
- [Vela Exchange Contracts](https://github.com/VelaExchange/vela-exchange-contracts)
- [ApolloX Contracts](https://github.com/apollox-finance/apollox-contracts)
- [Aster DEX Docs](https://docs.asterdex.com)
- [Perpetual DEXs 2025 Overview](https://atomicwallet.io/academy/articles/perpetual-dexs-2025)
- [Top Perp DEXs 2026](https://bingx.com/en/learn/article/top-perp-dex-perpetual-decentralized-exchange-to-know)
- [dYdX v4 Architecture](https://www.dydx.xyz/blog/v4-technical-architecture-overview)
- [Celo Protocol](https://celo.org/)
- [How Funding Rates Work on Perp DEXs 2026](https://www.bitcoin.com/get-started/how-funding-rates-work-on-perp-dex/)
- [Chainlink Data Streams](https://blog.chain.link/data-streams-mainnet/)
