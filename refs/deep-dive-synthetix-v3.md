# Deep Dive: Synthetix V3 Perpetual Futures

**Date**: 2026-03-31
**Status**: Comprehensive research report
**Scope**: Architecture, markets, liquidity, oracles, governance, forkability, and remittance hedging relevance

---

## Executive Summary

Synthetix V3 is the most architecturally sophisticated on-chain perpetual futures protocol in production. It uses a custom Router Proxy pattern (inspired by ERC-2535 Diamonds) to achieve modular upgradeability, supports 80+ perps markets across crypto/FX/commodities, and has undergone a major strategic pivot: **sunsetting L2 deployments (Arbitrum) to consolidate on Base and Ethereum Mainnet**. The protocol launched perps on Ethereum L1 in December 2025 under the "Big Freaking Perps" (BFP) product line, targeting Ethereum's deep stablecoin liquidity. The codebase is fully open source (MIT license), deployed via the Cannon framework, and theoretically forkable to other EVM chains -- though the operational complexity is substantial.

For remittance hedging purposes, Synthetix V3 offers: (a) on-chain readable funding rates and market data via PerpsMarketProxy view functions, (b) existing FX pairs (EUR/USD, GBP/USD, AUD/USD) with forex expansion planned for June 2026, (c) composable account permissions enabling smart contract integration, and (d) a governance pathway to propose new FX markets -- but no EM currency pairs (NGN, PHP, MXN, BRL, INR) exist today, and deploying to Celo would require a full fork and independent liquidity bootstrapping.

---

## 1. Available Pairs

### 1.1 Current Deployment Topology (March 2026)

| Chain | Status | Product | Collateral |
|-------|--------|---------|------------|
| **Ethereum Mainnet** | LIVE (limited access) | BFP (Big Freaking Perps) | SNX, sUSD |
| **Base** | LIVE (primary L2) | Perps V3 (Andromeda) | USDC, stataUSDC |
| **Optimism** | Legacy only | Perps V2 | SNX (staking) |
| **Arbitrum** | SUNSET (close-only) | Perps V3 | Migrated to Base |

### 1.2 Ethereum Mainnet Markets (BFP)

Launched December 2025 with an initial capped set:
- **BTC/USD** -- up to 50x leverage
- **ETH/USD** -- up to 50x leverage
- **SOL/USD** -- up to 50x leverage

New markets are being added weekly ("New Market Mondays" program) with expansion through Q1 2026. Multi-collateral trading (ETH, cbBTC as margin) is scheduled for April 2026.

### 1.3 Base Markets (Andromeda)

Base is the most mature V3 deployment with **81+ markets** as of October 2024, expanded further since. Known categories:

**Major Crypto (sample -- not exhaustive):**
ETH, BTC, SOL, DOGE, AVAX, LINK, OP, ARB, MATIC, BNB, ADA, DOT, ATOM, NEAR, FTM, APT, SUI, SEI, TIA, INJ, PYTH, JUP, WIF, BONK, PEPE, ORDI, MEME, FET, GRT, ANKR, TRB, IMX, COMP, MAV, YFI, MKR, RPL, XMR, ETC, RUNE, FXS, BAL, KNC, RNDR, ONE, PERP, ZIL, SUSHI, ZEC, ENJ, 1INCH, CELO, ALGO, EOS, XLM, ICP, XTZ, ENA, stETH/ETH

**FX Pairs:**
- EUR/USD
- GBP/USD
- AUD/USD

**Commodities:**
- Commodities launch planned for April 2026

**Stablecoin pairs:**
- stETH/ETH (basis trade pair)

### 1.4 FX Pairs Analysis

**Currently live:** EUR/USD, GBP/USD, AUD/USD (all G7 currencies).

**NOT available as of March 2026:**
- NGN/USD (Nigerian Naira) -- NO
- PHP/USD (Philippine Peso) -- NO
- MXN/USD (Mexican Peso) -- NO
- BRL/USD (Brazilian Real) -- NO
- INR/USD (Indian Rupee) -- NO
- JPY/USD -- Not confirmed live; may be available on Base

**Roadmap:** Forex expansion is explicitly planned for June 2026 per the official 2026 roadmap. The specific pairs have not been announced, but the forex category is being actively developed.

### 1.5 Max Leverage

Leverage is configured per-market via governance (SCCPs). General ranges observed:
- Major crypto (BTC, ETH, SOL): up to **50x-100x**
- Mid-cap crypto: typically **25x-50x**
- Small-cap / meme tokens: typically **10x-25x**
- FX pairs: typically **50x-100x** (lower volatility assets)

Exact per-market leverage is set by `maxMarketSize` and related parameters in governance proposals.

### 1.6 Total Market Count

Approximately **80-100+ markets** across all deployments as of March 2026, with the number growing weekly.

---

## 2. Liquidity and TVL

### 2.1 TVL Overview

Synthetix V3 TVL data is tracked on DefiLlama under "Synthetix V3" (separate from legacy V2).

**Key context:** The Ethereum Mainnet deployment is still in a **limited/capped launch phase** as of March 2026. Only the top 500 traders from the V3 competition and whitelisted SLP depositors can currently deposit. The team has explicitly stated they prioritize safety over flashy TVL numbers.

**Estimated TVL ranges (approximate, March 2026):**
- Base (Andromeda): Primary L2 liquidity hub
- Ethereum Mainnet: Growing but capped
- Optimism: V2 legacy staking positions
- Arbitrum: Wind-down / migration

For current real-time TVL: [Synthetix V3 on DefiLlama](https://defillama.com/protocol/synthetix-v3)

### 2.2 Trading Volume

- Q4 2025 trading competitions generated **$11 billion in volume** across two seasons
- Those competitions earned **$4.5 million in fees** in a 6-week period
- As of late March 2026, 24h futures volume approximately **$34M** (CoinGlass data)
- Open interest approximately **$18M** (early mainnet phase)

### 2.3 Deepest Liquidity

BTC, ETH, and SOL consistently have the deepest liquidity given they were the first mainnet markets and have the highest OI caps.

### 2.4 Fee Revenue

Fee distribution split (Base/Andromeda):
- 20% to Integrators
- 40% to SNX stakers
- 40% to Base LPs

Dune dashboards for detailed fee tracking:
- [Synthetix V3 - Base Perpetuals](https://dune.com/synthetix_community/synthetix-v3)
- [Synthetix Fee Overview](https://dune.com/leifu/synthetix-fee-overview)
- [Synthetix Stats](https://dune.com/synthetix_community/synthetix-stats)

### 2.5 SLP (Synthetix Liquidity Pool)

The community-owned market-making vault is in **private beta** showing approximately **45% annualized yields**. No management fees, no performance fees. Public launch planned for Q2 2026, targeting at least $15M sUSD by end of June 2026.

---

## 3. Architecture (Technical Deep Dive)

### 3.1 Router Proxy Pattern (SIP-307)

Synthetix V3 does **not** use ERC-2535 Diamond directly. Instead, it uses a custom "Router Proxy" architecture defined in [SIP-307](https://sips.synthetix.io/sips/sip-307/).

**How it works:**

1. **Modules**: Individual Solidity contracts containing business logic (e.g., `PerpsMarketModule`, `LiquidationModule`, `AccountModule`)
2. **Router**: A generated contract that merges all modules into a single "super-contract" by mapping function selectors to their corresponding module addresses
3. **Proxy**: A UUPS proxy that delegates all calls to the Router implementation
4. **DELEGATECALL**: Since the Router DELEGATECALLs to modules, all code runs in a single execution context with shared storage

**Key properties:**
- Binary search routing algorithm for gas-efficient selector lookup
- Overcomes EVM contract size limit (24KB) by splitting logic across modules
- Tooling checks for storage collisions, upgrade safety, and initialization state
- UUPS proxy is more gas-efficient than transparent proxy (upgradeability logic in implementation, not proxy)

**Difference from ERC-2535:**
The Diamond standard uses a `diamondCut` function and standardized facet management. Synthetix's Router Proxy achieves the same modularity but with a custom-generated routing table rather than the Diamond's standardized storage/interface pattern. The result is functionally equivalent but with Synthetix-specific tooling.

### 3.2 Key Contracts

| Contract | Role |
|----------|------|
| **CoreProxy** | Main system proxy; manages accounts, collateral, vaults, pools |
| **PerpsMarketProxy** | Perps market proxy; order commitment, settlement, position management |
| **AccountProxy** | NFT-based account representation (ERC-721) |
| **SpotMarketProxy** | Spot synth wrapping/unwrapping |
| **OracleManager** | Composable oracle aggregation |
| **USDProxy** | sUSD/snxUSD token |

### 3.3 Contract Addresses

Addresses are managed via the `synthetix-deployments` repository and the Cannon registry. They can be retrieved programmatically:

```
# Via Cannon CLI
cannon inspect synthetix --chain-id 8453 --preset andromeda
```

For Base Mainnet (chain 8453, "andromeda" preset):
- Deployment config: `omnibus-base-mainnet-andromeda.toml`
- Full address list: [Synthetix Deployment Info](https://docs.synthetix.io/v3/for-developers/deployment-info)
- NPM package: `@synthetixio/v3-contracts` (contains meta.json with addresses and ABIs)

For Ethereum Mainnet (chain 1):
- Deployment config in `synthetix-deployments` repo
- [Mainnet Deployment Info](https://docs.synthetix.io/v3/for-developers/deployment-info/1-main)

### 3.4 Market Creation

Markets are **governance-controlled**, not permissionless (as of March 2026).

**Process to add a new perps market:**
1. Community proposes via SIP (Synthetix Improvement Proposal) or SCCP (Synthetix Configuration Change Proposal)
2. Requires Pyth and/or Chainlink oracle price feed for the asset
3. Spartan Council votes (4/7 approval required)
4. Market parameters configured: `maxMarketSize`, `maxFundingVelocity`, `skewScale`, leverage limits, liquidation parameters
5. Deployed via governance transaction

**Long-term vision:** Permissionless market creation is part of the V3 vision, where anyone could create a market backed by their own collateral pool. This capability exists in the architecture but is not yet enabled for perps in production.

### 3.5 Margin System

**Cross-margin architecture:**
- Traders create an **Account** (ERC-721 NFT)
- Deposit margin (USDC on Base, SNX/sUSD on Mainnet) into the account
- Open multiple positions across different markets using the same pooled margin
- PnL from all positions offsets against each other
- Account's `availableMargin` is computed as: deposited collateral + unrealized PnL + accrued funding across all positions

### 3.6 Liquidation Mechanism

**Gradual, non-sandwichable liquidation:**

1. **Flagging**: Any address can call `liquidate()` on an account when `availableMargin < maintenanceMargin` (sum across all positions)
2. **Partial liquidation**: Large positions are liquidated in configurable chunks, not all at once
3. **Configurable delays**: Time delays between partial liquidation rounds prevent MEV sandwich attacks
4. **Liquidation reward**: Configured per market as a percentage of notional size being liquidated, paid to the keeper who executes
5. **Anti-MEV**: Account data privacy and progressive liquidation prevent front-running

### 3.7 Funding Rate: Velocity-Based Model (SIP-279)

This is one of Synthetix's most distinctive innovations.

**Core formula:**

```
dr/dt = (maxFundingVelocity / skewScale) * skew
```

Where:
- `dr/dt` = funding rate velocity (rate of change of funding rate per unit time)
- `maxFundingVelocity` = maximum rate at which funding can change (governance parameter)
- `skewScale` = scaling parameter (governance parameter)
- `skew` = longOI - shortOI (net open interest imbalance)

**Key properties:**
- Funding rate has **memory** -- it accumulates over time based on persistent skew
- When skew is zero, funding rate velocity is zero (funding rate stays constant)
- When there is a long skew, funding rate increases continuously (longs pay shorts more over time)
- The rate changes **gradually** even when large trades cause sudden skew changes
- Between trades, the average funding rate is interpolated using velocity and elapsed time

**Example calculation:**
- longOI = 500 ETH, shortOI = 150 ETH
- skew = 350 ETH (long-heavy)
- constant c = maxFundingVelocity / skewScale = 300% / 1,000,000 ETH
- fundingRateVelocity = c * skew = 0.105% per day

**Implications for hedging:**
The velocity model means funding rates are more predictable and less susceptible to manipulation than instantaneous-skew models (like those used by dYdX or GMX). This is highly relevant for any protocol reading funding rates on-chain to hedge positions.

### 3.8 Settlement Mechanism

**Commit-reveal pattern:**

1. **Commit**: Trader submits an order commitment (direction, size, acceptable price)
2. **Settlement window**: A configurable delay period (seconds to minutes)
3. **Settle**: Keeper (or anyone) calls `settle()` after the delay, providing a Pyth price update
4. **Execution price**: The earliest valid Pyth price after the commitment timestamp
5. **Deterministic**: Execution price is deterministic given the commitment time, minimizing the impact of network congestion

This two-step process prevents oracle front-running and ensures fair execution.

---

## 4. Oracle System

### 4.1 Pyth Integration

Synthetix V3 primarily uses **Pyth Network** oracles for perps markets (since SIP-285).

**How Pyth works with Synthetix:**
- Pyth uses an **on-demand (pull-based)** oracle model
- Price updates are NOT continuously pushed on-chain
- Instead, anyone can submit a Pyth price update to the on-chain Pyth contract
- Keepers submit price updates as part of the settlement transaction
- Pyth prices update multiple times per second off-chain; each update is an aggregate of multiple data providers

**Latency:**
- Off-chain: sub-second updates
- On-chain: price is as fresh as the most recent submitted update (typically seconds old, depending on keeper activity)

### 4.2 Oracle Manager (Composable Oracles)

Synthetix V3 includes an **OracleManager** that supports composable oracle aggregation:
- Combine multiple oracle sources (Chainlink, Pyth, Uniswap TWAP)
- Custom aggregation logic (e.g., use the lowest of three prices for extra safety)
- Market creators can configure oracle nodes in a tree structure

### 4.3 Chainlink Integration

Chainlink is still used as a supplementary/fallback oracle for some markets and for the core protocol's collateral pricing. All Synths on V2 were powered by Chainlink; V3 primarily uses Pyth for perps settlement but Chainlink for other pricing needs.

### 4.4 Pyth FX Price Feeds

Pyth Network covers:
- **G7 currencies**: EUR/USD, GBP/USD, JPY/USD, CAD/USD, AUD/USD, CHF/USD
- **Some EM currencies**: Available feeds vary; Pyth has been expanding coverage

**Critically for remittance use case:**
- Full list of Pyth FX feeds: [pyth.network/price-feeds](https://www.pyth.network/price-feeds) (filter by "FX" asset class)
- NGN/USD, PHP/USD, BRL/USD, INR/USD, MXN/USD availability must be checked directly on Pyth's price feed registry. Pyth has been expanding EM coverage but historically focused on G7 + select EM.

### 4.5 Adding a New FX Feed (e.g., NGN/USD)

**Path to adding NGN/USD on Synthetix V3:**

1. **Oracle availability**: Verify NGN/USD exists on Pyth Network. If not, work with Pyth data providers to add it (Pyth is designed to be extensible -- data providers can publish new feeds).
2. **Propose market via SIP/SCCP**: Draft a governance proposal to add NGN-PERP market with specified parameters
3. **Configure OracleManager**: Set up an oracle node pointing to the Pyth NGN/USD price feed ID
4. **Governance vote**: Spartan Council approves (4/7)
5. **Deployment**: Market goes live with configured parameters

**Realistic timeline**: 2-4 months if the Pyth feed exists; 4-8 months if the feed needs to be created first.

---

## 5. Open Source Status

### 5.1 GitHub Repositories

| Repository | Description |
|------------|-------------|
| [Synthetixio/synthetix-v3](https://github.com/Synthetixio/synthetix-v3) | Core V3 monorepo -- all smart contracts |
| [Synthetixio/synthetix-deployments](https://github.com/Synthetixio/synthetix-deployments) | GitOps deployment configs (Cannon toml files) |
| [Synthetixio/v3-contracts](https://github.com/Synthetixio/v3-contracts) | Published ABIs and addresses |
| [Synthetixio/python-sdk](https://github.com/Synthetixio/python-sdk) | Python SDK for trading and integration |
| [Synthetixio/perps-keepers](https://github.com/Synthetixio/perps-keepers) | Keeper bot reference implementation |
| [Synthetixio/sample-v3-keeper](https://github.com/Synthetixio/sample-v3-keeper) | Sample keeper using Python SDK + Silverback |
| [Synthetixio/SIPs](https://github.com/Synthetixio/SIPs) | All governance proposals |
| [Synthetixio/synthetix-v3-labs](https://github.com/Synthetixio/synthetix-v3-labs) | Experimental V3 components |

### 5.2 License

**MIT License** -- confirmed across all smart contracts in the V3 monorepo. Contract files include `SPDX-License-Identifier: MIT` headers.

### 5.3 Monorepo Structure

```
synthetix-v3/
  markets/
    perps-market/       # Perpetual futures market contracts
    spot-market/        # Spot synth market contracts
    bfp-market/         # Big Freaking Perps (L1 optimized)
    legacy-market/      # V2 <-> V3 bridge
  protocol/
    synthetix/          # Core protocol (accounts, collateral, pools, vaults)
    governance/         # On-chain voting
    oracle-manager/     # Composable oracle system
  utils/                # Shared utilities and tooling
  auxiliary/            # Supporting contracts
```

### 5.4 Code Quality

- **Solidity version**: 0.8.x throughout
- **Testing**: Hardhat + Foundry hybrid; extensive integration tests
- **Audits**: Multiple audits by firms including Iosiro and others (security overview on GitHub)
- **Deployment tooling**: Cannon (custom deployment framework built by Synthetix contributors)
- **CI/CD**: GitHub Actions for testing, linting, and deployment

### 5.5 Can You Fork and Deploy to a New Chain (e.g., Celo)?

**Technically feasible, operationally complex.**

**What you would need:**
1. Fork `synthetix-v3` and `synthetix-deployments`
2. Set up Cannon for the target chain (Celo would need Cannon chain support)
3. Deploy Pyth Network oracle contracts on Celo (Pyth already supports Celo)
4. Configure deployment toml for Celo with appropriate collateral (e.g., cUSD, CELO)
5. Deploy core system + perps market + oracle manager
6. Configure market parameters
7. Set up keeper infrastructure
8. Bootstrap liquidity (the hardest part)

**Major challenges:**
- Liquidity bootstrapping: You need LPs willing to backstop the system on Celo
- Keeper infrastructure: Settlement and liquidation keepers must be running
- Oracle coverage: Pyth is on Celo, but specific price feeds may vary
- Governance: A forked deployment would need its own governance structure
- Ongoing maintenance: Upgrades and parameter tuning require active governance

**Estimated effort**: 3-6 months for a skilled team of 3-5 engineers, plus ongoing operational costs.

---

## 6. Ecosystem and Frontends

### 6.1 Frontend Integrators

| Frontend | Status | Notes |
|----------|--------|-------|
| **Kwenta** | Acquired by Synthetix | Primary trading frontend, now owned/operated by Synthetix |
| **Polynomial** | Active integrator | Alternative trading interface |
| **Infinex** | Active (Kain Warwick's project) | CEX-like UX, aims to compete with Binance/Coinbase |
| **dHEDGE** | Active integrator | Vault/strategy platform |
| **TLX** | Acquired by Synthetix | Leveraged token product |

### 6.2 Integrator Program

- **Fee share**: 20% of trading fees on Base go to integrators
- **Onboarding**: Administered by Treasury Council; evaluates integration quality and volume potential
- **Partner Volume Rewards**: Tiered rebate system based on volume driven

### 6.3 SDKs

**Python SDK:**
```bash
pip install --upgrade synthetix
```
```python
from synthetix import Synthetix
snx = Synthetix(
    provider_rpc="https://base.llamarpc.com",
    private_key="<key>"
)
# Get open positions
positions = snx.perps.get_open_positions()
# Commit an order
snx.perps.commit_order(size=1.0, market_name="ETH")
```

**TypeScript/NPM:**
- `@synthetixio/v3-contracts` -- ABIs and addresses
- `@parifi/synthetix-sdk-ts` -- Community TypeScript SDK (uses viem)
- `synthetix` (npm) -- Legacy V2 package

### 6.4 Keeper Network

Keepers are essential infrastructure for Synthetix V3 perps:

**Settlement keepers:**
- Listen for committed orders
- Fetch Pyth price updates
- Call `settle()` on PerpsMarketProxy with the price data
- Earn settlement rewards

**Liquidation keepers:**
- Monitor account health across all positions
- Call `liquidate()` on undercollateralized accounts
- Earn liquidation rewards (percentage of notional)

**Reference implementations:**
- [perps-keepers](https://github.com/Synthetixio/perps-keepers) -- Production keeper codebase
- [sample-v3-keeper](https://github.com/Synthetixio/sample-v3-keeper) -- Python SDK-based example

---

## 7. Governance and Roadmap

### 7.1 Governance Model

**Spartan Council** -- the sole governance body since Referendum SR-2 (October 2024).

- **7 seats** total
- **4 seats** elected by SNX stakers each epoch
- **4/7 signatures** required for all governance actions
- Controls: SIPs (protocol upgrades), SCCPs (parameter changes), STPs (treasury proposals), treasury transactions

Elections held periodically; most recent: **January 2026**.

Governance portal: [governance.synthetix.io](https://governance.synthetix.io/)

### 7.2 2026 Roadmap

| Timeline | Initiative |
|----------|-----------|
| Q1 2026 | Crypto markets expansion (weekly new markets) |
| April 2026 | Multi-collateral trading (ETH, cbBTC as margin) |
| April 2026 | Commodities launch |
| Q2 2026 | SLP public launch (community market-making vault) |
| Q2 2026 | Basis Trade Vaults (delta-neutral yield) |
| June 2026 | Forex expansion |
| Ongoing | Pre-launch perpetuals for pre-token protocols |

### 7.3 Permissionless Market Creation

The V3 architecture supports permissionless market creation in theory. The core system allows anyone to deploy a new market module that connects to a Synthetix pool. However, **perps markets specifically are still governance-gated**. There is no announced timeline for fully permissionless perps market creation, though the infrastructure exists for it.

### 7.4 RWA / FX Expansion Plans

From the 2026 roadmap and V3 vision documents:
- **Forex by June 2026**: Explicit roadmap item
- **RWA vision**: Markets could be developed for real-world assets (art, carbon credits, off-chain instruments) with sufficient oracle infrastructure and trusted entity verification
- **No specific EM FX announcements** as of March 2026

---

## 8. Relevance for Remittance Hedging

### 8.1 On-Chain Funding Rate Readability

**YES** -- funding rates can be read on-chain by external contracts.

The `PerpsMarketProxy` exposes view functions including:
- `getMarketSummary(uint128 marketId)` -- returns a `MarketSummary` struct containing:
  - `currentFundingRate`
  - `currentFundingVelocity`
  - `marketSkew`
  - `marketSize`
  - `price`
  - `maxLeverage`
  - and more
- `getFundingParameters(uint128 marketId)` -- returns `skewScale` and `maxFundingVelocity`

An external hedging contract could call these view functions to read real-time funding rate data and make hedging decisions programmatically.

### 8.2 Composability with External Protocols

**YES** -- Synthetix V3 is designed for composability.

Key composability features:
- **Account permissions delegation**: Account owners can grant specific permissions (modify collateral, manage positions) to other addresses, including smart contracts
- **Smart wallet integration**: External contracts can hold Synthetix accounts and manage positions programmatically
- **Account abstraction support**: The permission system enables integration with account abstraction patterns

**Integration pattern for a hedging protocol:**
1. Hedging contract creates a Synthetix account (receives ERC-721)
2. Deposits collateral into the account
3. Reads market data (funding rate, skew) from PerpsMarketProxy
4. Commits orders based on hedging logic
5. Keepers settle the orders
6. Contract monitors and rebalances positions

### 8.3 Deploying Synthetix V3 Perps on Celo

**What it would take:**

| Requirement | Difficulty | Notes |
|-------------|-----------|-------|
| Fork V3 codebase | Medium | MIT license, well-structured monorepo |
| Cannon deployment tooling | Medium | May need Celo-specific Cannon support |
| Pyth oracle on Celo | Low | Pyth already deployed on Celo |
| FX price feeds (EM currencies) | High | NGN, PHP, MXN feeds may not exist on Pyth |
| Collateral configuration | Medium | Use cUSD (Mento) as primary collateral |
| Keeper infrastructure | Medium | Need settlement + liquidation keepers |
| Liquidity bootstrapping | Very High | Need LPs willing to deposit on Celo |
| Governance/maintenance | High | Need ongoing parameter management |

**Total estimated effort**: 6-12 months with a team of 5+ engineers, plus $2-5M+ for liquidity bootstrapping incentives.

### 8.4 Integration Path with Mento Stablecoins

**Theoretical integration:**

1. **cUSD as collateral**: Configure Synthetix V3 fork to accept cUSD (Mento's USD stablecoin on Celo) as LP and trader collateral
2. **cEUR, cREAL, eXOF as synths**: Mento already provides EUR, BRL, and XOF stablecoins that could serve as settlement/reference assets
3. **Oracle bridge**: Use Pyth FX feeds to price Mento stables against USD for margin calculations
4. **Hedging loop**: User holds cUSD -> opens FX perp position -> hedges exposure to target remittance corridor

**Practical challenges:**
- Mento stablecoins have limited liquidity compared to USDC/USDT
- Celo DeFi ecosystem is small, limiting LP participation
- EM currency Pyth feeds (NGN, PHP) may not exist
- Mento V3 is deploying on Celo and Monad, but not yet widely adopted outside Celo

### 8.5 Alternative: Use Synthetix on Base/Mainnet Directly

Rather than forking to Celo, the more practical path may be:

1. **Build a hedging vault on Base** that integrates with Synthetix V3 Perps
2. **Use existing FX pairs** (EUR/USD, GBP/USD, AUD/USD) for hedging
3. **Advocate for EM FX pairs** via Synthetix governance (SIP process) -- the June 2026 forex expansion is the natural window
4. **Bridge Mento stablecoins** to Base via cross-chain bridges if needed
5. **Read funding rates on-chain** from PerpsMarketProxy for automated hedging

This avoids the massive overhead of forking while still accessing Synthetix's deep liquidity and proven infrastructure.

---

## Key Takeaways for This Project

1. **Synthetix V3 is the most composable perps protocol available** -- view functions for funding rates, delegatable account permissions, and modular architecture make it ideal for programmatic hedging integration.

2. **FX pairs exist but are limited to G7 currencies** -- EM currency pairs (the ones most relevant for remittance hedging) are not available today. The June 2026 forex expansion is the key window to advocate for EM pairs.

3. **Forking to Celo is technically possible but economically impractical** -- the MIT license and open-source tooling make it feasible, but liquidity bootstrapping on Celo would be the critical bottleneck.

4. **The velocity-based funding rate model is predictable and composable** -- its gradual, memory-based behavior makes it more suitable for hedging strategies than instantaneous-skew models.

5. **Pyth oracle availability is the binding constraint for EM FX** -- if Pyth does not support NGN/USD or PHP/USD, no Synthetix market can be created for those pairs regardless of governance appetite.

6. **The Base deployment is the pragmatic integration target** -- mature, liquid, 80+ markets, USDC-denominated, with strong SDK support and active keeper infrastructure.

---

## Sources

- [Synthetix 2026 Roadmap](https://blog.synthetix.io/2026-roadmap/)
- [SIP-307: Router Proxy Architecture](https://sips.synthetix.io/sips/sip-307/)
- [SIP-279: Perps V2 (Funding Rate Velocity)](https://github.com/Synthetixio/SIPs/blob/master/content/sips/sip-279.md)
- [SIP-285: Pyth Network Oracles](https://sips.synthetix.io/sips/sip-285/)
- [Synthetix V3 GitHub Monorepo](https://github.com/Synthetixio/synthetix-v3)
- [Synthetix Deployments Repository](https://github.com/Synthetixio/synthetix-deployments)
- [Synthetix V3 Contracts (ABIs/Addresses)](https://github.com/Synthetixio/v3-contracts)
- [Synthetix Python SDK](https://github.com/Synthetixio/python-sdk)
- [Perps Keepers Reference](https://github.com/Synthetixio/perps-keepers)
- [Synthetix V3 on DefiLlama](https://defillama.com/protocol/synthetix-v3)
- [Perps V3 Developer Docs](https://docs.synthetix.io/developer-docs/for-perp-integrators/perps-v3)
- [Synthetix V3 Deployment Info](https://docs.synthetix.io/v3/for-developers/deployment-info)
- [Synthetix Governance Portal](https://governance.synthetix.io/)
- [Synthetix Dynamic Funding Rates Blog](https://blog.synthetix.io/synthetix-perps-dynamic-funding-rates/)
- [Perps V3 Features Explainer](https://blog.synthetix.io/perps-v3-features-release-explainer/)
- [Synthetix Acquires Kwenta](https://blog.synthetix.io/synthetix-acquires-ecosystem-leading-perps-platform-kwenta/)
- [Synthetix Multi-Collateral Perps (81 Markets)](https://blog.synthetix.io/synthetix-multi-collateral-perps-with-81-new-markets-on-kwenta/)
- [Synthetix Sunsets Arbitrum](https://blog.synthetix.io/synthetix-sunsets-arbitrum-deployment-as-it-vertically-integrates-on-base/)
- [Synthetix Mainnet Launch](https://blog.synthetix.io/synthetix-mainnet-launch/)
- [Synthetix Perps on Ethereum Mainnet](https://blog.synthetix.io/synthetix-perps-on-ethereum-mainnet/)
- [Partner Volume Rewards](https://blog.synthetix.io/partner-volume-rewards-for-synthetix-perps-integrators/)
- [Pyth Network Price Feeds](https://www.pyth.network/price-feeds)
- [Dune: Synthetix V3 Base Perpetuals](https://dune.com/synthetix_community/synthetix-v3)
- [Cannon Package Registry](https://usecannon.com/packages/synthetix)
- [Synthetix Funding Docs](https://docs.synthetix.io/exchange/perps-basics/funding)
- [Market Development Guide](https://docs.synthetix.io/developer-docs/for-derivatives-market-builders/market-development-guide)
- [Mento Protocol Docs](https://docs.mento.org/mento/use-mento/getting-mento-stables/on-celo)
