# Deep Dive: GMX v2 (Synthetics) Perpetual Futures

**Date**: March 31, 2026
**Scope**: Comprehensive technical and market analysis of GMX v2 as of Q1 2026

---

## Executive Summary

GMX v2 (also called "GMX Synthetics") is the second-generation perpetual futures DEX from the GMX protocol, live since August 4, 2023. It replaced the monolithic GLP pool model with isolated GM (GMX Market) pools per trading pair, introduced Chainlink Data Streams for sub-second oracle pricing, and added a sophisticated funding/borrowing rate mechanism driven by open interest imbalance. As of March 2026, GMX operates across Arbitrum, Avalanche, Botanix, and has multichain access via Base and Ethereum. The protocol has facilitated over $345 billion in cumulative trading volume from 735,000+ traders and supports 70+ tradeable tokens with up to 100x leverage.

The codebase (`gmx-io/gmx-synthetics`) is under BUSL-1.1 with a change date of **August 31, 2026**, after which it converts to GPL v2.0+. This is directly relevant for composability planning -- full fork/reuse rights open in ~5 months.

---

## 1. Available Pairs and Markets

### 1.1 Market Count and Structure

GMX v2 supports **70+ tokens** for perpetual trading across its deployed chains. On Arbitrum alone, over 40 markets are available. Each market is an isolated GM pool defined by three parameters:

- **Index token** (the asset being speculated on, e.g., BTC, ETH, SOL)
- **Long collateral token** (typically the index token itself or WBTC/WETH)
- **Short collateral token** (typically USDC or USDT)

Markets come in two types:

1. **Fully Backed Markets**: The index token matches the long collateral (e.g., ETH/USD backed by ETH + USDC). Positions are fully collateralized by the underlying asset.
2. **Synthetic Markets**: The index token differs from the collateral (e.g., DOGE/USD backed by ETH + USDC). Open interest can theoretically exceed pool value -- these carry additional risk for LPs.

### 1.2 Major Pairs on Arbitrum

| Market | Type | Max Leverage | Collateral Backing |
|--------|------|-------------|-------------------|
| BTC/USD | Fully Backed | 100x | WBTC + USDC |
| ETH/USD | Fully Backed | 100x | WETH + USDC |
| SOL/USD | Synthetic | 50x | ETH + USDC |
| DOGE/USD | Synthetic | 50x | ETH + USDC |
| XRP/USD | Synthetic | 50x | ETH + USDC |
| ARB/USD | Synthetic | 50x | ETH + USDC |
| LINK/USD | Synthetic | 50x | LINK + USDC |
| UNI/USD | Synthetic | 50x | UNI + USDC |
| LTC/USD | Synthetic | 50x | ETH + USDC |
| AVAX/USD | Synthetic | 50x | AVAX + USDC |
| AAVE/USD | Synthetic | 50x | ETH + USDC |
| OP/USD | Synthetic | 50x | ETH + USDC |
| BNB/USD | Synthetic | 50x | ETH + USDC |
| NEAR/USD | Synthetic | 50x | ETH + USDC |
| ATOM/USD | Synthetic | 50x | ETH + USDC |
| SATS/USD (Ordinals) | Synthetic | -- | BTC + USDC |
| CVX/USD | Synthetic | -- | ETH + USDC |
| KAS/USD | Synthetic | -- | ETH + USDC |
| OKB/USD | Synthetic | -- | ETH + USDC |
| GMX/USD | Synthetic | -- | ETH + USDC |

**Note**: BTC and ETH also have **single-token pools** (e.g., gmBTC backed purely by WBTC, gmETH backed purely by ETH) for LPs who want single-asset exposure without stablecoin risk.

Multiple GM pools may exist for the same index token with different collateral (e.g., ETH-USDC pool and ETH-USDT pool).

### 1.3 Pairs on Avalanche

Avalanche has a smaller subset: SOL, XRP, LTC, DOGE, BTC, ETH, AVAX as primary markets.

### 1.4 Pairs on Botanix

GMX launched on Botanix's Spiderchain (Bitcoin L2) on July 2, 2025, enabling native BTC trading and yield opportunities. Market selection is narrower, focused on BTC-denominated pairs.

### 1.5 FX / Non-Crypto Pairs

**GMX v2 is described as supporting "forex pairs" in some documentation**, though specifics are sparse. The architecture fundamentally supports any asset class for which a Chainlink Data Stream oracle exists. The synthetic market design means an FX pair like EUR/USD could theoretically be created with ETH+USDC backing and a EUR/USD Chainlink oracle feed as the index price. However, **as of March 2026, the vast majority of live markets are cryptocurrency pairs**. No dedicated FX, commodity, or equity markets have been confirmed as actively trading on the mainnet frontend.

### 1.6 Market Creation: Governance vs. Permissionless

The technical architecture supports permissionless market creation -- `MarketFactory.createMarket()` accepts arbitrary token triplets. However, **in practice, market creation is governance-controlled**:

- New markets require appropriate Chainlink oracle support
- The GMX DAO votes on which assets to list
- Risk parameters (leverage caps, OI limits, fee factors) are set by governance
- The isolated pool design was explicitly built to eventually enable permissionless listings, but this has not been fully activated as of Q1 2026

The 2025 roadmap mentions moving toward more permissionless market creation as v2.2 and v2.3 mature.

---

## 2. Liquidity and TVL

### 2.1 Total Value Locked

| Metric | Value (approx. Q1 2026) |
|--------|------------------------|
| Total TVL (GMX v1 + v2) | ~$263M (DeFiLlama) |
| GMX v2 Perps TVL | Majority of total; v1 is in sunset mode |
| Cumulative Trading Volume | ~$345B+ all-time |
| Traders | 735,000+ |

### 2.2 TVL by Chain

- **Arbitrum**: Dominant chain, holding the vast majority of TVL
- **Avalanche**: Smaller allocation, focused subset of markets
- **Botanix**: Nascent, BTC-focused
- **Base/Ethereum**: Available via GMX Multichain (cross-chain access via LayerZero, not native deployment of liquidity pools)

### 2.3 Fee Revenue and Distribution

GMX v2 fee allocation as of late 2025:

| Recipient | Share |
|-----------|-------|
| GM Pool LPs | 63% |
| GMX Stakers (via token buybacks) | 27% |
| Protocol Treasury | 8.2% |
| Chainlink (oracle costs) | 1.2% |

**Key revenue streams**: Trading fees, price impact fees, borrowing fees, funding fees, and swap fees.

GM pool LPs have historically earned **15-30% APR** from a combination of trading fees, borrowing fees, and incentive rewards.

### 2.4 Governance Fee Discussions (Late 2025 - Early 2026)

- A proposal was initiated to reallocate the 27% GMX staker buyback to instead fund the GM GMX-USD liquidity pool and trader incentives
- A separate proposal allocated 600,000 USDC for GMX buybacks to fund a fee-rebate campaign (December 2025 - March 2026)

### 2.5 Deepest Liquidity Pools

BTC/USD and ETH/USD consistently have the deepest liquidity, followed by SOL/USD, DOGE/USD, and ARB/USD on Arbitrum. The GLV (GMX Liquidity Vault) product further concentrates liquidity by auto-rebalancing across multiple GM pools.

### 2.6 Data Sources

- **stats.gmx.io** -- Official GMX analytics dashboard
- **DeFiLlama**: defillama.com/protocol/gmx and defillama.com/protocol/gmx-v2-perps
- **Dune Analytics**: dune.com/gmx-io/gmx-analytics
- **CoinGlass**: coinglass.com/currencies/GMX (OI, funding rates)
- **CoinAnalyze**: coinalyze.net/gmx/open-interest/

---

## 3. Architecture (Technical Deep Dive)

### 3.1 Core Design Philosophy

GMX v2 uses a **request-execute pattern** (also called two-phase commit). Most user actions do not execute atomically. Instead:

1. User submits a request (order, deposit, withdrawal) via `ExchangeRouter`
2. Request is stored in the `DataStore`
3. Off-chain **keepers** monitor pending requests
4. Keepers bundle signed oracle prices and call execution functions
5. Execution settles the request against current oracle prices

This pattern prevents front-running and enables Chainlink Data Streams integration.

### 3.2 DataStore Pattern

The `DataStore` is the central state repository for the entire protocol. Rather than storing state in individual contract storage slots, GMX v2 uses a **key-value store pattern**:

- All market state, positions, orders, deposits, withdrawals are stored as key-value pairs
- `StoreUtils` contracts serialize/deserialize struct data to/from the DataStore
- Keys are computed deterministically (e.g., from market address + position key)
- `EnumerableSets` maintain indexed lists of orders and positions for efficient enumeration
- This pattern allows new fields to be added to structs without storage layout conflicts
- Avoids reliance on indexers (which may lag) for critical state queries

### 3.3 Key Contracts (Arbitrum)

| Contract | Address | Role |
|----------|---------|------|
| DataStore | `0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8` | Central key-value state store |
| MarketFactory | `0xf5F30B10141E1F63FC11eD772931a8294a591996` | Creates new market pools |
| ExchangeRouter | `0x602b805EedddBbD9ddff44A7dcBD46cb07849685` | Main user entry point for all actions |
| OrderVault | `0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5` | Holds collateral for pending orders |
| Reader | (see docs.gmx.io/docs/api/contracts-v2/) | Read-only query contract |
| GlvReader | (see docs.gmx.io/docs/api/contracts/glv-reader/) | Read-only GLV queries |
| Oracle | (on-chain verification of Chainlink Data Streams) | Price verification |

**Full contract list**: https://docs.gmx.io/docs/api/contracts-v2/

### 3.4 Contract Architecture Layers

```
User Interaction Layer
  ExchangeRouter -- entry point for createOrder, createDeposit, createWithdrawal, createShift

Request Storage Layer
  DataStore -- stores all pending requests and active state
  OrderVault -- holds collateral tokens during order lifecycle

Execution Layer
  OrderHandler -- keeper calls to execute orders
  PositionHandler -- position management during execution
  DepositHandler / WithdrawalHandler / ShiftHandler

Business Logic Layer (Utils)
  PositionUtils, MarketUtils, OrderUtils, SwapUtils
  PricingUtils -- price impact calculations
  FundingFeeUtils -- funding rate accumulation
  BorrowingFeeUtils -- borrowing rate calculations

Oracle Layer
  Oracle.sol -- verifies Chainlink Data Stream signed prices
  ChainlinkPriceFeedUtils.sol -- fallback to traditional Chainlink feeds

Market Layer
  MarketFactory -- creates new markets
  MarketStoreUtils -- market state serialization
```

### 3.5 GM Liquidity Pools

Each GM pool is an ERC-20 token representing a share of the pool. Pool composition:

- ~50% long collateral token (e.g., ETH)
- ~50% short collateral token (e.g., USDC)
- The ratio shifts based on trader PnL and net position exposure

**Deposit flow**: User deposits long token + short token (or just one) -> receives GM tokens
**Withdrawal flow**: User burns GM tokens -> receives proportional share of pool assets

LPs earn: trading fees + borrowing fees + funding fees (net of trader PnL)
LPs risk: adverse trader PnL (if traders are net profitable, LPs lose)

### 3.6 Position Lifecycle

```
1. CREATE ORDER
   User -> ExchangeRouter.createOrder(params)
   Collateral transferred to OrderVault
   Order struct stored in DataStore

2. EXECUTION
   Keeper detects pending order
   Keeper fetches signed Chainlink prices
   Keeper -> OrderHandler.executeOrder(key, oracleParams)
   Oracle verifies signed prices
   Position created/modified in DataStore

3. ONGOING (while position is open)
   Funding fees accrue per second (based on OI imbalance)
   Borrowing fees accrue per second (based on utilization)
   Both tracked via cumulative factor approach

4. CLOSE / LIQUIDATION
   Close: User creates a decrease order -> same keeper execution flow
   Liquidation: Keeper detects undercollateralized position -> executes liquidation
   PnL settled from pool; collateral returned/absorbed
```

### 3.7 Funding Rate Mechanism

The funding rate incentivizes OI balance between longs and shorts:

```
funding_fee_per_second = funding_factor * (|long_OI - short_OI|)^exponent / (long_OI + short_OI)
```

Where:
- `funding_factor` is a configurable parameter per market
- `exponent` (funding_exponent_factor) is configurable (typically > 1 for super-linear response)
- The dominant side (larger OI) pays the weaker side

The rate adjusts **gradually over time** in segments, not instantaneously. This creates a smooth funding curve rather than abrupt rate changes:
- If longs > shorts: funding rate for longs gradually increases
- Once balance flips: rate gradually decreases
- Upper limits prevent extreme rates

Implementation uses **cumulative factor tracking**: a global `Cumulative_F` is updated on every interaction, and individual position fees are calculated as the change in cumulative factor since the position's last touch.

### 3.8 Borrowing Fee Mechanism

Separate from funding, borrowing fees prevent the exploit where a user opens equal long + short positions to reserve all liquidity for negligible cost:

- The side with more OI pays borrowing fees
- Rate models: either **exponential curve** or **kinked rate model** (configurable per market)
- Key inputs: `reserved_USD`, `usage_factor`
- Fees flow to LP pool

### 3.9 Price Impact Model

Price impact emulates order book dynamics:

- Larger positions incur higher price impact fees
- Positions that worsen the long/short imbalance pay more
- Positions that improve balance may receive a rebate
- The formula is configured per market with impact parameters
- This design elevates the cost of price manipulation and prevents sudden price crashes/spikes

---

## 4. Oracle System

### 4.1 Chainlink Data Streams

GMX v2 was the **exclusive launch partner** of Chainlink Data Streams. Key properties:

- **Off-chain signed prices**: Prices are signed by the Chainlink Decentralized Oracle Network (DON) off-chain
- **On-chain verification**: Cryptographic signatures are verified on-chain in `Oracle.sol`
- **Sub-second latency**: Data Streams provide near-real-time pricing
- **Bid-ask spread**: Both a minimum and maximum price are signed, encoding spread information
- **Commit-and-reveal**: Transaction privacy is preserved pre-execution, mitigating front-running

### 4.2 Keeper Flow

```
1. User submits order (stored in DataStore)
2. Keeper monitors for pending orders
3. Keeper queries Chainlink Data Streams for signed price report
4. Keeper bundles: order key + signed oracle params
5. Keeper calls OrderHandler.executeOrder()
6. Oracle.sol verifies signatures on-chain
7. Execution proceeds with verified prices
```

### 4.3 Price Precision

Prices stored in the Oracle contract use **30 decimals of precision** per unit of the token.

### 4.4 Fallback Mechanism

For tokens without Data Streams support, `ChainlinkPriceFeedUtils.sol` falls back to traditional Chainlink price feeds. These have longer heartbeat durations and higher latency but provide broader token coverage.

### 4.5 Available Price Feeds

Any token with a Chainlink Data Stream or traditional Chainlink price feed can potentially be supported. Chainlink Data Streams currently cover major crypto assets (BTC, ETH, SOL, DOGE, XRP, ARB, LINK, etc.) and are expanding to FX and commodity feeds.

### 4.6 Custom Price Feeds

Adding a new market requires a corresponding Chainlink oracle feed. The process involves:
1. Chainlink must support the Data Stream (or have a traditional feed)
2. GMX governance approves the market listing
3. MarketFactory creates the market with appropriate oracle configuration

### 4.7 Oracle Manipulation Resistance

- Decentralized signing by Chainlink DON nodes
- Commit-and-reveal prevents front-running
- Min/max price (bid-ask) signed together
- Price impact fees make manipulation expensive
- Keeper-based execution (not user-triggered) adds an execution delay

---

## 5. Open Source Status

### 5.1 Repository

- **GitHub**: https://github.com/gmx-io/gmx-synthetics
- **Language**: Solidity
- **Framework**: Hardhat (with some Foundry integration)
- **Test suite**: TypeScript tests in `test/` directory

### 5.2 License: BUSL-1.1

The Business Source License 1.1 applies with these specific parameters:

| Parameter | Value |
|-----------|-------|
| Licensor | GMX |
| Licensed Work | GMX Synthetics Contracts |
| Change Date | **August 31, 2026** (or earlier per `synthetics-contracts-license-date.gmxresearch.eth` ENS) |
| Change License | **GNU General Public License v2.0 or later** |

### 5.3 BUSL Restrictions (Until August 31, 2026)

Under BUSL-1.1:

- **You CAN**: Read the code, study it, build integrations that call it (composability), run tests, audit it, reference it in research
- **You CAN**: Deploy it for non-production use (testing, development, research)
- **You CANNOT**: Deploy it as a production service that competes with GMX without explicit permission from the licensor
- **You CANNOT**: Fork it and launch your own perpetual exchange using the code

The key restriction is on **production use** -- the exact "Additional Use Grant" terms in GMX's LICENSE file define what constitutes permitted production use.

### 5.4 Post-Conversion (After August 31, 2026)

After the change date, the code becomes GPL v2.0+:
- Full open source
- Anyone can fork, modify, and deploy
- Derivative works must also be GPL v2.0+
- Commercial use is permitted under GPL terms

**This is 5 months away from today (March 2026).**

### 5.5 Code Quality

- Audited by Guardian Audits (multiple rounds)
- Sherlock audit contest (2023)
- Comprehensive test suite
- Active development with regular updates
- Well-structured separation of concerns (Utils pattern, DataStore abstraction)

### 5.6 Deployment Scripts

The repository includes deployment scripts and a `deployments/` folder with contract addresses for each chain. Hardhat tasks handle deployment orchestration.

---

## 6. Composability

### 6.1 Reader.sol -- On-Chain Query Interface

`Reader.sol` is the primary composability surface for external contracts. Key functions:

**Market Queries**:
- `getMarket(DataStore, key)` -- Returns Market.Props for a single market
- `getMarkets(DataStore, start, end)` -- Returns array of markets
- `getMarketBySalt(DataStore, salt)` -- Market lookup by salt
- `getMarketInfo(DataStore, prices, key)` -- Full market info including rates
- `getMarketInfoList(DataStore, prices[], start, end)` -- Batch market info

**Position Queries**:
- `getPosition(DataStore, key)` -- Single position data
- `getAccountPositions(DataStore, account, start, end)` -- All positions for an account

**Order Queries**:
- `getOrder(DataStore, key)` -- Single order data
- `getAccountOrders(DataStore, account, start, end)` -- All orders for an account

**Deposit/Withdrawal Queries**:
- `getDeposit(DataStore, key)` -- Deposit request data
- `getWithdrawal(DataStore, key)` -- Withdrawal request data

**Pricing Queries** (via ReaderPricingUtils):
- Price impact calculations for swaps and positions

### 6.2 GlvReader.sol -- GLV Vault Queries

For querying GLV (GMX Liquidity Vault) state:
- GLV composition and rebalancing data
- Underlying GM pool allocations

### 6.3 What External Contracts Can Read

| Data Point | Available On-Chain? | How |
|-----------|-------------------|-----|
| Mark price | Yes (via oracle at execution) | Oracle.sol / Chainlink Data Streams |
| Funding rate | Yes (cumulative factor) | Reader.getMarketInfo() |
| Open interest (long/short) | Yes | Reader.getMarketInfo() |
| Pool composition | Yes | Reader.getMarketInfo() |
| Borrowing rate | Yes (cumulative factor) | Reader.getMarketInfo() |
| Position details | Yes | Reader.getPosition() |
| GM token price | Yes (calculated from pool state) | Reader / MarketUtils |

### 6.4 REST API (Off-Chain)

For off-chain integrations:

| Chain | Endpoint |
|-------|----------|
| Arbitrum | `https://arbitrum-api.gmxinfra.io/markets/info` |
| Avalanche | `https://avalanche-api.gmxinfra.io/markets/info` |
| Botanix | `https://botanix-api.gmxinfra.io/markets/info` |

Returns: liquidity, open interest, token amounts, funding/borrowing/net rates.

API v2 coverage: markets, tickers, tokens, pairs, rates, APY, performance, positions, orders, OHLCV.

### 6.5 SDK

- **TypeScript SDK**: `@gmx-io/sdk` (npm) -- https://github.com/gmx-io/gmx-interface/tree/master/sdk
- **Demo**: https://codesandbox.io/p/sandbox/gmx-sdk-example-8zg296
- **Python SDK** (community): https://github.com/snipermonke01/gmx_python_sdk
- **Integration API**: https://github.com/gmx-io/gmx-integration-api

### 6.6 Subgraph / Indexing

- **Subsquid endpoints** for GraphQL-based historical data queries
- Repository: https://github.com/gmx-io/gmx-subgraph
- Covers: trades, positions, liquidity events, fees

### 6.7 Integration Complexity

For a protocol wanting to read GMX state:
- **Low complexity**: Call Reader.sol view functions (no oracle params needed for basic queries)
- **Medium complexity**: Use getMarketInfo with price params to get calculated rates
- **High complexity**: Create orders programmatically via ExchangeRouter (requires keeper infrastructure or relying on GMX keepers)

---

## 7. Ecosystem

### 7.1 Protocols Built on GMX

Over **80 protocols** have integrated with GMX. Notable ones:

| Protocol | Integration Type |
|----------|-----------------|
| Jones DAO | Delta-neutral vault strategies on GM pools |
| Rage Trade | Delta-neutral farming strategies |
| Abracadabra (MIM) | Leveraged farming on GM pools |
| Umami DAO | Yield optimization vaults |
| Dolomite | Margin/lending integration |
| IVX | Options protocol using GMX liquidity |
| Plutus | Yield aggregation |
| GMD Protocol | Pseudo-delta-neutral vaults |
| Beefy Finance | Auto-compounding vaults |
| GoldLink | Funding rate farming |
| OpenOcean | DEX aggregator with GMX routing |

### 7.2 GLV (GMX Liquidity Vaults)

GLV is a "pool of pools" -- a vault of auto-rebalancing GM tokens:
- Backed by 50% ETH or BTC + 50% USDC
- Automatically shifts liquidity to highest-utilization GM pools
- Fully liquid and permissionless (for depositing/withdrawing)
- Higher capital efficiency than individual GM pools
- Live on Arbitrum and Avalanche

### 7.3 Chain Deployments

| Chain | Status | Notes |
|-------|--------|-------|
| Arbitrum | Live (primary) | Deepest liquidity, most markets |
| Avalanche | Live | Subset of markets |
| Botanix | Live (July 2025) | Bitcoin L2, BTC-native trading |
| Ethereum | Live (Multichain) | Cross-chain access via LayerZero, not native pools |
| Base | Live (Multichain) | Cross-chain access to Arbitrum liquidity |
| BNB Chain | Live (Multichain) | Cross-chain access |
| Solana | Rebranded to GMTrade (Nov 2025) | Independent entity, no longer part of core GMX |
| MegaETH | Proposed | Governance proposal for ultra-low latency trading |

GMX Multichain (launched 2025) uses LayerZero to let users on Base, Ethereum, and BNB Chain trade against Arbitrum liquidity without bridging.

### 7.4 Governance

- **GMX token**: Powers governance and earns fee revenue
- **GMX DAO**: Votes on market listings, parameter changes, treasury allocation
- **Staking**: GMX stakers receive 27% of v2 fees (via buyback)
- **Governance forum**: gov.gmx.io

### 7.5 2026 Roadmap

- **Q2 2026**: Gasless transactions and network fee subsidies
- **Mid 2026**: Cross-collateral support (stablecoins as collateral in single-token pools)
- **Late 2026**: Cross-margin and market grouping (v2.3) -- unifies similar perp markets under single groups for better capital efficiency

---

## 8. Relevance for Remittance Hedging

### 8.1 Non-Crypto Pairs: Current State

**GMX does not currently offer dedicated FX, commodity, or equity perpetual markets on its live frontend.** While the architecture supports any oracle-fed asset, all actively traded markets are cryptocurrency pairs (BTC, ETH, SOL, DOGE, ARB, etc. -- all denominated in USD).

### 8.2 Could FX Markets Be Added?

**Architecturally, yes.** The requirements are:

1. A Chainlink Data Stream (or traditional feed) for the FX pair (e.g., EUR/USD, MXN/USD, PHP/USD)
2. Governance approval to create the market
3. A GM pool backed by appropriate collateral (e.g., USDC + USDC for a pure stablecoin-backed FX market, or ETH + USDC)

Chainlink already provides FX price feeds for major pairs (EUR/USD, GBP/USD, JPY/USD, etc.) and is expanding Data Streams coverage. The technical barrier is low; the practical barrier is governance priority and LP demand.

**For remittance corridors** (MXN/USD, PHP/USD, NGN/USD, etc.), Chainlink feed availability would be the bottleneck. Major FX pairs have Chainlink feeds, but exotic EM currency pairs may not have Data Streams support yet.

### 8.3 GMX as a Signal Layer

Even without FX markets, GMX v2 is valuable as a **crypto signal layer**:

| Signal | Accessibility | Usefulness for Remittance |
|--------|--------------|--------------------------|
| BTC/USD funding rate | On-chain via Reader.sol | Proxy for crypto-dollar demand; spikes correlate with EM currency stress |
| ETH/USD funding rate | On-chain via Reader.sol | DeFi leverage demand indicator |
| OI imbalance (long vs. short) | On-chain via Reader.sol | Market sentiment indicator |
| Borrowing rates | On-chain via Reader.sol | Capital cost in DeFi; relevant for stablecoin-denominated remittance products |
| Price impact parameters | On-chain | Liquidity depth indicator |

Funding rates on GMX can serve as a **macro proxy**: when BTC funding rates are highly positive, there is excess leveraged long demand, often correlated with risk-on environments where EM currencies are strengthening against USD. Negative funding rates signal risk-off / dollar strength.

### 8.4 Integration Complexity for External Protocols

| Integration Level | Complexity | Description |
|------------------|-----------|-------------|
| Read funding rates | Low | Call Reader.getMarketInfo() -- pure view function |
| Read OI and pool state | Low | Same Reader contract |
| Automated hedging via GMX | High | Requires ExchangeRouter interaction + keeper dependency |
| Build custom vault on GM pools | Medium-High | LP into GM pools programmatically |

For a remittance hedging protocol:
- **Reading signals**: Trivially composable, no permissions needed
- **Hedging crypto exposure**: Possible but requires managing the keeper execution flow
- **FX hedging**: Not currently possible on GMX mainnet without governance adding FX markets

### 8.5 Strategic Assessment

GMX v2's architecture is the closest thing DeFi has to a general-purpose perpetual futures platform that could support non-crypto assets. The isolated pool model, oracle-agnostic design, and forthcoming GPL license make it a strong candidate for:

1. **Fork-and-extend** (after August 31, 2026): Deploy a GMX v2 fork with custom FX markets using Chainlink FX feeds
2. **Compose-and-read** (today): Use Reader.sol to pull crypto funding rates as macro signals
3. **Lobby for FX markets** (governance): Propose FX market creation on existing GMX deployment

The main gaps for remittance use cases:
- No live FX markets today
- Exotic EM currency oracle availability uncertain
- High keeper infrastructure dependency for automated trading
- LP risk model assumes crypto-native participants

---

## Key Contract References

### Arbitrum Addresses (Verified)

```
DataStore:        0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8
MarketFactory:    0xf5F30B10141E1F63FC11eD772931a8294a591996
ExchangeRouter:   0x602b805EedddBbD9ddff44A7dcBD46cb07849685
OrderVault:       0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5
```

Full address list: https://docs.gmx.io/docs/api/contracts-v2/

### GitHub Repositories

- **Core contracts**: https://github.com/gmx-io/gmx-synthetics
- **Subgraph**: https://github.com/gmx-io/gmx-subgraph
- **Integration API**: https://github.com/gmx-io/gmx-integration-api
- **Interface + SDK**: https://github.com/gmx-io/gmx-interface

---

## Sources

- [GMX Official Site](https://gmx.io/)
- [GMX v2 Trading Docs](https://docs.gmx.io/docs/trading/v2/)
- [GMX Contracts for V2](https://docs.gmx.io/docs/api/contracts-v2/)
- [GMX REST API Docs](https://docs.gmx.io/docs/api/rest/)
- [GMX SDK v2 Docs](https://docs.gmx.io/docs/api/sdk-v2/)
- [GMX Synthetics GitHub](https://github.com/gmx-io/gmx-synthetics)
- [GMX Synthetics README](https://github.com/gmx-io/gmx-synthetics/blob/main/README.md)
- [GMX Synthetics LICENSE](https://github.com/gmx-io/gmx-synthetics/blob/main/LICENSE)
- [GMX Stats Dashboard](https://stats.gmx.io/)
- [GMX DeFiLlama](https://defillama.com/protocol/gmx)
- [GMX V2 Perps DeFiLlama](https://defillama.com/protocol/gmx-v2-perps)
- [GMX Dune Analytics](https://dune.com/gmx-io/gmx-analytics)
- [GMX V2 Powered by Chainlink Data Streams](https://gmxio.substack.com/p/gmx-v2-powered-by-chainlink-data)
- [GMX Low-Latency Chainlink Feeds Governance Post](https://gov.gmx.io/t/gmx-v2-new-low-latency-chainlink-feeds/2050)
- [GMX Development Plan for 2025](https://gmxio.substack.com/p/gmx-development-plan-for-2025)
- [GMX Introduces GLV](https://gmxio.substack.com/p/gmx-introduces-gmx-liquidity-vaults)
- [GMX Multichain Launch](https://gmxio.substack.com/p/gmx-multichain-is-now-live-unlocking)
- [GMX on Botanix](https://gov.gmx.io/t/gmx-v2-hybrid-deployment-on-botanix/4500)
- [GMX on MegaETH Proposal](https://gov.gmx.io/t/gmx-v2-deployment-on-megaeth-proposal/4954)
- [GMX Fee Allocation Proposal](https://coincu.com/defi/gmx-v2-proposes-fee-allocation-options/)
- [Arbitrum Blog: GMX Deep Dive](https://blog.arbitrum.io/gmx-an-in-depth-look-at-arbitrums-leading-permissionless-exchange-for-on-chain-leverage-trading/)
- [Compass Labs: Guide to Perpetual Contracts and GMX V2](https://medium.com/@compasslabs/a-guide-to-perpetual-contracts-and-gmx-v2-a4770cbc25e3)
- [LD Capital: Changes and Impacts of GMX V2](https://ld-capital.medium.com/changes-and-impacts-of-gmx-v2-6ed0e4c10f93)
- [Castle Capital: Deciphering GMX v2](https://chronicle.castlecapital.vc/p/deciphering-gmx-v2-next-wave-decentralized-perps)
- [Guardian Audits: GMX Case Study](https://guardianaudits.com/casestudies/gmx-case-study)
- [Cyfrin Updraft: GMX Perpetuals Trading Course](https://updraft.cyfrin.io/courses/gmx-perpetuals-trading)
- [CoinBureau: GMX Review 2025](https://coinbureau.com/review/gmx-review/)
- [Reader.sol Source](https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/reader/Reader.sol)
- [Oracle.sol Source](https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/oracle/Oracle.sol)
- [ReaderUtils.sol Source](https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/reader/ReaderUtils.sol)
- [GlvReader.sol Source](https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/reader/GlvReader.sol)
- [DataStore on Arbiscan](https://app.dedaub.com/arbitrum/address/0xfd70de6b91282d8017aa4e741e9ae325cab992d8/transactions/incoming)
- [MarketFactory on Arbiscan](https://arbiscan.io/address/0xf5f30b10141e1f63fc11ed772931a8294a591996)
- [ExchangeRouter on Arbiscan](https://ww4.arbiscan.io/address/0x602b805EedddBbD9ddff44A7dcBD46cb07849685)
