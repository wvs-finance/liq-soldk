# Research: Open-Source Solidity Perpetual Futures Contracts

**Date:** 2026-03-31

---

## Summary

Five major protocols were audited for open-source Solidity contracts suitable for forking, composing with, or deploying on new chains. The table below gives a quick orientation before the per-protocol deep-dives.

| Protocol | License | Permissionless markets | External funding-rate reads | Fork complexity |
|---|---|---|---|---|
| GMX v2 (synthetics) | BUSL-1.1 → GPL-2.0 (Aug 2026) | No — governance-approved | Yes — `Reader.sol` public | High |
| Perpetual Protocol v2 | GPL-3.0 | No — Optimism-only, fixed markets | Yes — `AccountBalance` view | Moderate |
| Synthetix Perps v3 | MIT | Transitioning to permissionless | Yes — `PerpsMarketProxy` views | Moderate |
| Gains Network gTrade v6/v10 | Unlicensed / All-rights-reserved | No | Limited — custom DON | High |
| Cap Finance v4 | Not specified (source-available) | No | Yes — Chainlink-based reads | Low |

---

## GMX v2 (gmx-synthetics)

### Repository
- Primary: https://github.com/gmx-io/gmx-synthetics
- Legacy v1: https://github.com/gmx-io/gmx-contracts

### Key Contracts

| Contract | Path | Role |
|---|---|---|
| `DataStore` | `contracts/data/DataStore.sol` | Central key-value store for all protocol state |
| `Reader` | `contracts/reader/Reader.sol` | Public read-only façade over market, position, and fee state |
| `ReaderUtils` | `contracts/reader/ReaderUtils.sol` | Assembles `MarketInfo` structs including virtual inventory |
| `Oracle` | `contracts/oracle/Oracle.sol` | Validates keeper-signed prices from Chainlink or custom signers |
| `FundingUtils` | `contracts/pricing/FundingUtils.sol` (implied) | Computes funding accrual per position |
| `PositionPricingUtils` | `contracts/pricing/PositionPricingUtils.sol` | Price impact and fee math |
| `AdlHandler` | `contracts/exchange/AdlHandler.sol` | Auto-deleveraging logic |
| `MarketStoreUtils` | `contracts/market/MarketStoreUtils.sol` | Encodes/decodes market structs into DataStore |

### Funding Rate Mechanism

GMX v2 separates two cost components:

1. **Funding fee** — paid by the overweight OI side to the underweight side. Proportional to the imbalance between long OI and short OI per market. Accrued per second; stored as a cumulative index in `DataStore`.
2. **Borrowing fee** — paid only by the dominant-OI side. Uses either a flat curve model or a kink model: `borrowingFactorPerSecond = baseBorrowingFactor * usageFactor`, with an above-optimal-usage premium. This prevents the pool from being fully absorbed by equal long/short positions.

All formulas are on-chain in the `*Utils` libraries. Keepers supply signed prices at execution time; the oracle does not store a persistent on-chain mark price between transactions.

### External Composability

`Reader.sol` is fully public and permissionless. External contracts can call:
- `getMarket(dataStore, marketAddress)` — market metadata
- `getPosition(dataStore, positionKey)` — position state including accrued fees
- `getMarketTokenPrice(...)` — pool token price
- `ReaderUtils.getMarketInfo(...)` — combined struct with open interest, funding rates, and borrowing rates

Open interest and liquidation thresholds are readable without any role. Mark price is not stored on-chain between orders; it must be reconstructed from signed oracle prices.

### License

BUSL-1.1. Non-production use permitted. Change date: **31 August 2026** or earlier per `synthetics-contracts-license-date.gmxresearch.eth`. On the change date the license converts to GPL-2.0 or later. Forking for production today requires explicit permission from the licensor.

---

## Perpetual Protocol v2 (Curie)

### Repository
- Core contracts: https://github.com/perpetual-protocol/perp-curie-contract
- v1 (vAMM, reference only): https://github.com/perpetual-protocol/perpetual-protocol

### Key Contracts

| Contract | Role |
|---|---|
| `ClearingHouse` | Entry point; routes trades, manages collateral, settles PnL |
| `AccountBalance` | Stores per-trader position size, position value, pending PnL |
| `Exchange` | Executes swaps in the underlying Uniswap v3 pool |
| `Vault` | Holds USDC collateral; converts between real and virtual tokens |
| `MarketRegistry` | Maps base tokens to their Uniswap v3 pool addresses |
| `BaseToken` / `VToken` | Virtual ERC-20s minted into Uniswap v3 pools |

### Architecture (vAMM-on-Uniswap-v3)

Curie does not maintain its own AMM. Instead it mints virtual tokens (`vETH`, `vBTC`, etc.) into Uniswap v3 concentrated-liquidity pools. Real collateral (USDC) stays in `Vault`. Makers deposit real USDC and receive virtual tokens placed as LP positions in the Uniswap v3 pool. Traders swap virtual tokens; the clearing house settles PnL against the USDC vault.

### Funding Rate Mechanism

Funding is calculated as the time-weighted average price (TWAP) divergence between the vAMM mark price (Uniswap v3 pool) and the Chainlink index price:

```
fundingPayment = positionSize * (markTWAP - indexTWAP) / indexTWAP * (elapsedSeconds / SECONDS_PER_DAY)
```

Longs pay shorts when mark > index; shorts pay longs otherwise. Updated lazily on each trade. The TWAP window is a governance parameter.

### External Composability

`AccountBalance` has a documented integration surface:
- `getMarkPrice(baseToken)` — returns current mark price
- `getTakerPositionSize(trader, baseToken)` — position size
- `getPnlAndPendingFee(trader)` — unrealised PnL

The protocol publishes an npm package (`@perp/curie-contract`) with ABI + deployed addresses, making integration straightforward. However markets are fixed (governed addition only) and the protocol is Optimism-only.

### License

GPL-3.0. Fully open-source; forks permitted under copyleft terms.

---

## Synthetix Perps v2 / v3

### Repositories
- v2 (Optimism): https://github.com/Synthetixio/synthetix — `contracts/PerpsV2Market*.sol`
- v3 monorepo: https://github.com/Synthetixio/synthetix-v3 — `markets/perps-market/`

### Key Contracts (v2)

| Contract | Role |
|---|---|
| `PerpsV2Market.sol` | Core position and order logic |
| `PerpsV2MarketViews.sol` | All read-only (view) functions — external-friendly |
| `PerpsV2MarketData.sol` | Aggregated market stats for integrators |
| `PerpsV2MarketSettings.sol` | Governance-controlled parameters (skewScale, maxFundingVelocity) |
| `PerpsV2MarketState.sol` | Storage layout |
| `PerpsV2MarketDelayedExecution.sol` | Keeper-executed delayed order logic |

### Key Contracts (v3)

Located under `markets/perps-market/contracts/`:
- `PerpsMarketProxy` — ERC-2535 Diamond proxy; main integration point
- `storage/PerpsMarketConfiguration.sol` — per-market params
- `storage/PerpsMarket.sol` — position and OI state
- `modules/` — atomic, liquidation, settlement, async order modules

### Funding Rate Mechanism (v2 — dynamic)

Synthetix v2 uses a **velocity-based** dynamic funding rate introduced via SIP-279:

```
dr/dt = maxFundingVelocity * (skew / skewScale)
```

Where `skew = longOI - shortOI`. The funding rate changes continuously, not just when trades occur. This creates a mean-reverting pressure: persistent long skew causes funding to drift up, incentivising shorts. `PerpsV2MarketViews.currentFundingRate()` returns the instantaneous rate.

v3 inherits this model with additional controls per market.

### Pyth Oracle Integration

SIP-285 formalized Pyth Network as the primary oracle for Synthetix Perps. Pyth uses **push-on-demand**: keepers fetch a signed price from Pyth off-chain and submit it with each order. The on-chain Pyth contract (`IPyth`) verifies the signature. This means Synthetix perps markets work with any Pyth-listed feed. Custom feeds can be added if Pyth supports the price ID.

### External Composability

`PerpsV2MarketViews` is entirely public view functions. Key reads:
- `currentFundingRate()` — current funding rate per second
- `currentFundingVelocity()` — rate of change of funding rate
- `marketSummary()` — OI, skew, price, funding in one call
- `assetPrice()` — current oracle price

v3 exposes equivalent functions via `PerpsMarketProxy`. Market creation transitions from governance-approved to permissionless as part of the v3 roadmap.

### License

MIT. Unrestricted use, fork, and deploy.

---

## Gains Network (gTrade)

### Repositories
- v6: https://github.com/GainsNetwork/gTrade-v6
- v6.1: https://github.com/GainsNetwork/gTrade-v6.1
- v10 (current): https://github.com/GainsNetwork-org (org-level)

### Key Contracts (v6)

| Contract | Role |
|---|---|
| `GNSTradingV6` | Order entry point; trade open/close/modify |
| `GNSPriceAggregatorV6` | Aggregates 8 Chainlink DON nodes; circuit-breaker against official Chainlink feeds |
| `GNSTradingCallbacksV6` | Executes keeper callbacks after price fulfillment |
| `GNSVaultV6` | Liquidity vault (USDC/DAI); absorbs trader PnL |
| `GNSPairsStorageV6` | Per-pair parameters (spread, max leverage, etc.) |

### Oracle Mechanism

gTrade uses a **custom Chainlink DON** (Decentralised Oracle Network):
1. Trading contract requests price from `GNSPriceAggregatorV6`.
2. Aggregator contacts 8 Chainlink nodes on-demand; each node returns the median of 7 CEX APIs.
3. Aggregator takes the median of received answers.
4. Any node answer deviating >1.5% from the official Chainlink Price Feed is rejected (circuit breaker).
5. Minimum 3 answers required before settlement.

This oracle is **not modular** — it is tightly coupled to Gains Network's own DON nodes. Substituting a custom price feed requires replacing the entire aggregator contract and operator set.

### Fee Structure Evolution

- v6.0–v6.2: Funding fees (long/short imbalance) + rollover fees.
- v6.3.2: Funding fees replaced by borrowing fees — dominant-OI side pays, based on `(netOI / vaultTVL)^exponent`.
- v10+: Hybrid — funding fees for stablecoin-collateral positions; borrowing fees for GNS/ETH/APE-collateral positions.

### External Composability

No clean read interface for external contracts. Fee state and OI are readable from storage but there is no documented integrator API analogous to GMX's `Reader` or Synthetix's `MarketViews`.

### License

The gTrade-v6 and gTrade-v6.1 repositories do not include a permissive open-source license in the search results. The contracts appear source-available but not freely forkable under a standard OSI license. Verify the LICENSE file in the repository before any production use.

---

## Cap Finance v4

### Repository
https://github.com/capofficial/protocol

### Architecture

Cap v4 is a minimalist perpetuals protocol built for Arbitrum. Architecture highlights:
- All orders (including market orders) are keeper-executed after `minSettlementTime`.
- Chainlink price feeds serve as the primary oracle; the sequencer uptime feed is checked for Arbitrum L2 safety.
- A single `Store.sol` contract holds all protocol state (positions, orders, pool balances).
- `Pool.sol` acts as the counterparty vault (equivalent to GMX's GLP).
- Governance powers are bounded by `MAX_FEE` constants embedded in `Store.sol`, preventing arbitrary fee manipulation.
- Supports deposits through Uniswap Router for single-asset on-ramp.

### Funding Rate

Cap v4 uses a simple **borrowing fee** model tied to pool utilisation. Funding rates are not velocity-based. The Chainlink feed determines mark price at settlement.

### External Composability

Because state is centralised in `Store.sol` and prices are standard Chainlink feeds, external contracts can read positions and current fees with straightforward calls. No special roles required for reads.

### License

The repository does not prominently declare an OSI license in available search results. The codebase appears source-available. Verify before forking.

---

## Pika Protocol v4

### Repository
- https://github.com/PikaProtocol/PikaContract

### Architecture

Pika v4 is an inverse perpetual contract protocol on Optimism. Key features:
- Inverse contract: quoted in USD, margined and settled in the base token (e.g., ETH).
- Supports up to 100x leverage.
- Underwent PeckShield audit before v4 deployment.
- Core contract: `PikaPerp.sol`.

### Oracle

Chainlink price feeds. No custom oracle aggregator.

### Composability and License

The repository is publicly accessible and the contracts are readable, but license terms were not confirmed from search results. Lower activity level vs. the protocols above; last major update was mid-2023.

---

## Key Questions Answered

### 1. Which protocols allow reading funding rates from external contracts without special permissions?

**Best options:**

- **Synthetix v2/v3**: `PerpsV2MarketViews.currentFundingRate()` and `PerpsV2MarketViews.marketSummary()` are fully public view functions. No roles, no approvals. The most integrator-friendly interface of any protocol reviewed.
- **GMX v2**: `Reader.sol` is public and returns full `MarketInfo` structs including accrued funding and borrowing rates. Requires constructing the correct `DataStore` key but no permissions.
- **Perpetual Protocol v2**: `AccountBalance.getMarkPrice()` and funding-related views are publicly callable.
- **Cap Finance v4**: Chainlink-based price reads are permissionless; pool state in `Store.sol` is readable.

**Avoid for external reads:** Gains Network — no clean public interface; tightly coupled to their DON.

### 2. Which protocols support permissionless market creation (so you could create a cNGN/USDC perp)?

None of the reviewed protocols are **currently** fully permissionless for market creation:

- **Synthetix v3** is the closest — the roadmap explicitly targets permissionless market creation, and the architecture (Diamond proxy, modular market configs) is designed for it. Market creation is currently governance-approved but transitioning. Custom oracles can be specified per market including Pyth price IDs.
- **GMX v2** markets are governance-approved; synthetic market expansion is controlled by the GMX DAO.
- **Perpetual Protocol v2** markets are governance-only; no plan for permissionless expansion documented.
- **Gains Network** markets are added by the team.

**Practical recommendation for cNGN/USDC perp:** Fork Synthetix Perps v3 (MIT license, modular oracle, approaching permissionless) or fork Cap Finance v4 (minimal codebase, Chainlink-pluggable, governance-bounded).

### 3. Which have the simplest/cleanest Solidity for forking?

Ranked by fork-friendliness (architecture simplicity + license):

1. **Cap Finance v4** — fewest contracts, single `Store.sol` state, Foundry test suite, Chainlink oracle wired directly. Best choice for a minimal fork.
2. **Synthetix Perps v2** — more contracts but MIT-licensed, well-documented, battle-tested on Optimism with $38B+ in volume.
3. **Perpetual Protocol v2** — GPL-3.0, clean separation of ClearingHouse / AccountBalance / Exchange, but permanently coupled to Uniswap v3 liquidity model.
4. **GMX v2** — sophisticated DataStore + Utils architecture is powerful but complex. BUSL-1.1 blocks production forks until August 2026.
5. **Gains Network** — tightly coupled oracle DON makes meaningful forks very difficult without replacing the entire oracle layer.

### 4. Which use modular oracle systems that could accept custom price feeds?

- **Synthetix Perps v3**: Most modular. Market creators can select oracle resolvers. Pyth integration (SIP-285) is the standard path; adding a custom Pyth price ID is the cleanest route for exotic pairs. MIT licensed.
- **GMX v2**: Oracle is a signed-price system where a set of whitelisted signers provide prices per transaction. Modular in that you can deploy with different signers, but the validation logic is built in. Not suitable for adding an arbitrary custom feed without core modifications.
- **Cap Finance v4**: Chainlink-only. Swapping in a custom oracle requires patching `Store.sol` but the codebase is small enough that this is tractable.
- **Perpetual Protocol v2**: Oracle is a Chainlink index feed per market, wired at market creation. Swappable at market setup but not upgradeable afterwards.
- **Gains Network**: Custom Chainlink DON — hardest to replace. Not suitable for new oracle integrations without significant rework.

---

## Recommendations for This Project

Given the goal of building LP hedging instruments (IL-hedging via options on top of Bunni/Panoptic infrastructure), the most relevant protocols for composing with or forking are:

1. **Synthetix Perps v3** (MIT, modular oracle, approaching permissionless) — best long-term base if you need to deploy a custom market (e.g., LP-delta perp or cNGN hedge).
2. **GMX v2 Reader interface** — best for reading mark price and open interest from an existing deployed market without deploying your own perp. Worth waiting for the August 2026 BUSL expiry if you need to fork.
3. **Cap Finance v4** — best if you need a minimal, auditable reference implementation to understand perpetual contract mechanics before building something custom.

---

## Sources

- [gmx-io/gmx-synthetics](https://github.com/gmx-io/gmx-synthetics)
- [gmx-io/gmx-contracts](https://github.com/gmx-io/gmx-contracts)
- [gmx-synthetics LICENSE (BUSL-1.1)](https://github.com/gmx-io/gmx-synthetics/blob/main/LICENSE)
- [GMX v2 Contracts Docs](https://gmx-docs.io/docs/api/contracts-v2/)
- [perpetual-protocol/perp-curie-contract](https://github.com/perpetual-protocol/perp-curie-contract)
- [Perp v2 Integration Guide](https://docs.perp.com/docs/guides/integration-guide/)
- [Synthetixio/synthetix (v2)](https://github.com/Synthetixio/synthetix)
- [Synthetixio/synthetix-v3](https://github.com/Synthetixio/synthetix-v3)
- [Synthetix Perps Dynamic Funding Rates](https://blog.synthetix.io/synthetix-perps-dynamic-funding-rates/)
- [Perps V3 Features Release Explainer](https://blog.synthetix.io/perps-v3-features-release-explainer/)
- [SIP-285: Pyth Network Oracles for Synthetix Perps](https://sips.synthetix.io/sips/sip-285/)
- [Perps V3 Developer Docs](https://docs.synthetix.io/developer-docs/for-perp-integrators/perps-v3)
- [GainsNetwork/gTrade-v6](https://github.com/GainsNetwork/gTrade-v6)
- [GainsNetwork/gTrade-v6.1](https://github.com/GainsNetwork/gTrade-v6.1)
- [gTrade v6.3.2 — From Funding Fees to Borrowing Fees](https://gainsnetwork-io.medium.com/gtrade-v6-3-2-from-funding-fees-to-borrowing-fees-ee3d747b0b70)
- [Gains Network Oracle Architecture](https://medium.com/gains-network/gains-farm-using-chainlink-to-power-decentralized-leveraged-trading-fe954b37eb97)
- [capofficial/protocol](https://github.com/capofficial/protocol)
- [PikaProtocol/PikaContract](https://github.com/PikaProtocol/PikaContract)
- [Compass Labs — GMX V2 Guide](https://medium.com/@compasslabs/a-guide-to-perpetual-contracts-and-gmx-v2-a4770cbc25e3)
