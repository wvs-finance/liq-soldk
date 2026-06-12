# Cross-Chain Relay/Bridge Protocols for Connecting DeFi Pools

**Date:** 2026-03-31
**Purpose:** Evaluate cross-chain messaging protocols for relaying pool observables (price, volatility, liquidity depth) between Polygon and Celo, with focus on connecting QuickSwap V3 (Algebra) pools on Polygon with cCOP/stablecoin pools on Celo.

---

## Executive Summary

This report evaluates five cross-chain messaging protocols (LayerZero, Axelar, Chainlink CCIP, Wormhole, Hyperlane) and one streaming protocol (Superfluid) for the specific use case of relaying DeFi pool observables between Polygon and Celo. The primary recommendation is **Chainlink CCIP** for production-grade relay of pool state data, with **LayerZero lzRead** as a strong alternative once Celo is added as a supported data chain. LayerZero's lzRead is architecturally the most elegant fit (pull-based cross-chain data queries), but currently lacks Celo as a data source. Superfluid is relevant not as a bridge but as a complementary primitive for continuous-time measure updates on individual chains.

---

## 1. LayerZero

### Architecture

LayerZero V2 is an omnichain interoperability protocol built on immutable, permissionless Endpoint contracts deployed on each supported chain. The architecture decouples verification from execution:

- **Endpoints**: Immutable on-chain contracts on each chain (source and destination) that handle message routing, fee management, and application settings enforcement.
- **Decentralized Verifier Networks (DVNs)**: Independent entities that validate cross-chain messages. Applications can choose which DVNs and how many verify their messages -- this is a key differentiator (configurable security).
- **Executor**: Off-chain service that executes messages on the destination chain after DVN verification.
- **MessageLibraries**: Modular libraries that applications can select for their specific security/performance tradeoffs.

V2 improvements over V1 include the Omnichain Messaging Protocol (OMP) which decoupled verification and execution layers, 50-90% gas cost reduction, and horizontal composability via `sendCompose` / `lzCompose`.

### Supported Chains

LayerZero supports 130+ chains. Both **Polygon** and **Celo** are confirmed supported with dedicated V2 deployment pages:
- Polygon Mainnet: https://docs.layerzero.network/v2/deployments/chains/polygon
- Celo Mainnet: https://docs.layerzero.network/v2/deployments/chains/celo
- Ethereum Mainnet: supported

### OFT Standard

The Omnichain Fungible Token (OFT) standard enables fungible tokens to transfer across chains without wrapping, middlechains, or liquidity pools:
- **New tokens**: Burn on source chain, mint on destination (unified supply).
- **Existing tokens**: OFT Adapter locks on source, mints on destination.
- Non-custodial; developers retain control of token contracts.

### Messaging Capabilities

LayerZero supports arbitrary message passing between any two supported chains. A smart contract on Chain A can send encoded bytes to a contract on Chain B, which decodes and executes logic.

### lzRead -- Cross-Chain Data Reading (Critical for Our Use Case)

**lzRead** is LayerZero's data primitive that allows smart contracts to query on-chain state from other blockchains in a single function call. This is architecturally the best fit for relaying pool observables because:

- It implements a **request-response pattern** (pull model) rather than push-based messaging.
- Uses a **Blockchain Query Language (BQL)** for standardized cross-chain data requests.
- Can call any `view` or `pure` function on a target chain and return data to the source chain.
- Explicitly designed for use cases like **permissionless asset pricing by retrieving prices from deepest liquidity pools on any chain** and **aggregating pricing data using lzMap and lzReduce**.

**Current limitation**: lzRead data source chains are currently limited to **Ethereum, Base, Polygon, Avalanche, BNB Chain, Optimism, and Arbitrum**. **Celo is NOT currently a supported data source for lzRead.** Standard LayerZero messaging (send/receive) works on Celo, but the pull-based data reading does not yet.

### Assessment for Our Use Case

| Capability | Status |
|---|---|
| Polygon -> Celo messaging | Supported |
| Celo -> Polygon messaging | Supported |
| Read Polygon pool state from Celo | NOT supported via lzRead (Celo not a read-enabled source) |
| Read Celo pool state from Polygon | NOT supported via lzRead (Celo not a data chain) |
| Push-based relay (emit on source, receive on dest) | Fully supported both directions |

**Verdict**: LayerZero is viable for push-based relay of pool observables (contract on Polygon reads local pool state, sends encoded message to Celo). lzRead would be ideal but requires Celo support. Monitor for lzRead Celo enablement.

---

## 2. Axelar

### Architecture

Axelar is a decentralized network acting as a routing layer for arbitrary message passing and asset transfers across chains:

- **Proof-of-Stake validator network** that collectively secures cross-chain transactions (more decentralized than multisig bridges, but relies on a single validator set -- unlike LayerZero's configurable DVNs).
- **Gateway contracts** deployed on each chain serve as entry/exit points.
- **General Message Passing (GMP)**: Enables calling any function on any connected chain by invoking `callContract` or `callContractWithToken` on the source Gateway.

### GMP (General Message Passing) Flow

1. Source contract calls `callContract(destinationChain, destinationAddress, payload)` on the Axelar Gateway.
2. Gas is prepaid for Axelar consensus and destination execution.
3. Axelar validators reach consensus by voting; signatures are relayed to the destination Gateway.
4. Destination Gateway approves the call; the payload is delivered to the destination contract's `_execute` function.

### Supported Chains

Axelar supports Ethereum, Polygon, Avalanche, Fantom, Arbitrum, Optimism, Cosmos, BNB Chain, **Celo**, Moonbeam, Base, and many more. Both **Polygon and Celo are confirmed supported**.

### Comparison to LayerZero

| Dimension | LayerZero | Axelar |
|---|---|---|
| Security model | Configurable DVNs per application | Single PoS validator set |
| Messaging | Arbitrary bytes, plus lzRead for pull-based queries | GMP arbitrary function calls |
| Chain support | 130+ chains | 60+ chains |
| Gas efficiency | 50-90% cheaper in V2 | Higher gas due to validator consensus overhead |
| Customizability | Application-level security configuration | Network-level security (less customizable) |
| Maturity | Dominant (75% bridge volume) | Strong but smaller market share |
| Cosmos interop | Limited | Native (Axelar is a Cosmos chain) |

### Assessment for Our Use Case

Axelar can relay pool observables between Polygon and Celo via GMP. The main advantage is simplicity -- straightforward `callContract` interface. The main disadvantage is less flexible security (single validator set vs. LayerZero's per-app DVN selection) and no equivalent to lzRead for pull-based data queries.

---

## 3. Other Protocols: Brief Comparison

### Wormhole

- **Architecture**: 19 Guardian validator nodes (including Figment, Staked, Everstake) observe all supported chains. Messages are attested via Verifiable Action Approvals (VAAs) requiring 2/3+ Guardian signatures.
- **Supported chains**: 45+ including both **Polygon and Celo**.
- **Messaging**: Arbitrary message passing via Core Contracts. Publish message -> Guardian observation -> VAA creation -> destination verification.
- **Strengths**: Institutional backing, MultiGov governance framework, intent-based settlement.
- **Weaknesses**: Fixed 19-Guardian set (less customizable security than LayerZero), smaller chain coverage than LayerZero.
- **For our use case**: Viable but no specific advantage over LayerZero or CCIP for data relay.

### Chainlink CCIP

- **Architecture**: Leverages Chainlink's decentralized oracle network infrastructure. Messaging Router on each chain routes outgoing messages through a decentralized node set. Separates risk management from execution.
- **Supported chains**: 60+ including both **Polygon and Celo** (Celo integrated CCIP as canonical cross-chain infra).
- **Messaging**: Three modes -- arbitrary messaging (encoded bytes), token transfers, programmable token transfers (tokens + data). Can encode multiple instructions in a single message for complex multi-step cross-chain tasks.
- **Strengths**:
  - Builds on Chainlink's battle-tested oracle infrastructure (trillions in transaction value secured).
  - Both Polygon and Celo are explicitly supported with active lanes.
  - Celo specifically adopted CCIP as its canonical cross-chain protocol.
  - Natural synergy with Chainlink Data Feeds for price/oracle data.
  - CCIP 2.0 (late 2025/early 2026) adds configurable risk levels.
  - Institutional adoption (Swift integration, Coinbase's $7B wrapped token bridge).
- **Weaknesses**: Higher cost per message than LayerZero, more centralized around Chainlink's node operator set.
- **For our use case**: Strong candidate. Arbitrary messaging can relay pool observables. Chainlink oracle synergy means price data infrastructure is already available on both chains.

### Hyperlane

- **Architecture**: Permissionless interoperability protocol with Interchain Security Modules (ISMs) allowing customizable security per application. Supports EVM, SVM, CosmWasm.
- **Supported chains**: 150+ including both **Polygon and Celo**.
- **Key differentiator**: Anyone can deploy Hyperlane on any chain without permission. Modular ISMs allow mixing economic security, multisig, optimistic, and ZK verification.
- **Strengths**: Most permissionless option, broadest chain support, highly customizable security via ISMs.
- **Weaknesses**: Newer protocol, smaller adoption/TVL than LayerZero or CCIP, HYPER token launched April 2025 (younger ecosystem).
- **For our use case**: Viable and technically flexible. The permissionless deployment model is attractive for rapid prototyping. ISM customization parallels LayerZero's DVN model.

### Protocol Comparison Matrix

| Protocol | Polygon | Celo | Arbitrary Msg | Pull-Based Data | Customizable Security | Maturity |
|---|---|---|---|---|---|---|
| LayerZero | Yes | Yes | Yes | lzRead (no Celo) | DVNs per app | Highest (75% volume) |
| Axelar | Yes | Yes | GMP | No | PoS validator set | High |
| Wormhole | Yes | Yes | VAAs | No | Fixed Guardians | High |
| Chainlink CCIP | Yes | Yes | Yes | No (but oracle synergy) | Node operator set | Very High (institutional) |
| Hyperlane | Yes | Yes | Yes | No | ISMs per app | Medium (newer) |

---

## 4. Specific Use Case: Connecting Our Target Pools

### QuickSwap V3 (Algebra) USDC/DAI Pool on Polygon

- **Status**: Active and liquid. QuickSwap V3 uses Algebra's concentrated liquidity engine (licensed in June 2022).
- **Pool**: USDC/DAI on Polygon, current price ~0.9999 USD, ~$905K 24h volume, 1,129 daily transactions.
- **Data available on-chain**: tick state, sqrtPriceX96, liquidity, fee growth, TWAP accumulator (Algebra's volatility oracle), tick bitmap.
- **Contract address on CoinMarketCap**: `0xe7e0eb9f6bcccfe847fdf62a3628319a092f11a2`
- **Observable extraction**: A reader contract on Polygon can call `pool.globalState()` to get current price/tick/fee, and `pool.timepoints()` for TWAP/volatility oracle data.

### Balancer V3 Pools -- Celo Status

- **Balancer V3 is NOT currently deployed on Celo.** V3 launched on Ethereum, Arbitrum, Base (January 2025), Avalanche (June 2025), HyperEVM (July 2025).
- **Balancer V2** was available on Polygon (with the vault at `0xBA12222222228d8Ba445958a75a0704d566BF2C8`), but no confirmed Celo deployment.
- **Celo DeFi ecosystem** includes Uniswap V3/V4, Aave V3, Velodrome, Curve, and Mento -- but not Balancer.
- **Implication**: If we need Balancer-style weighted pools on Celo, we would need to look at alternatives (Uniswap V3 on Celo, or custom pool contracts).

### cCOP (Colombian Peso Stablecoin) -- Where It Trades

- **Chain**: cCOP is native to **Celo**, built on the **Mento Platform**.
- **Nature**: Decentralized stablecoin pegged to the Colombian Peso (COP), backed by the Mento Reserve.
- **Trading venues**:
  - **Mento Asset Exchange** (Celo) -- primary venue, virtual AMM with Mento Reserve as liquidity provider. Trades cCOP against USDT, USDC, cUSD, cEUR at FX rates.
  - **Uniswap V3 on Celo** -- most active DEX pair is USDT/cCOP (~$7K 24h volume).
  - **Coinbase** lists cCOP for price tracking.
- **Liquidity**: Relatively thin. The Celo Forum has active governance discussions about liquidity strategies for cCOP and building an FX market on Celo.
- **Other chains**: cCOP does NOT appear to trade on Polygon, Ethereum, or any chain outside Celo. It is Celo-native.

### Pool Connection Architecture

Given these findings, the cross-chain data flow we need is:

```
Polygon                                          Celo
+---------------------------+                    +---------------------------+
| QuickSwap V3 (Algebra)    |                    | Uniswap V3 / Mento       |
| USDC/DAI Pool             |                    | cCOP/USDC Pool            |
| - sqrtPriceX96            |  cross-chain msg   | - sqrtPriceX96            |
| - tick, liquidity         | =================> | - tick, liquidity         |
| - TWAP accumulator        |                    | - cCOP/COP FX rate        |
| - volatility oracle       | <================= | - Mento reserve state     |
+---------------------------+                    +---------------------------+
         |                                                |
         v                                                v
   PoolStateRelay contract                     PoolStateRelay contract
   (reads local pool,                          (reads local pool,
    sends to Celo)                              sends to Polygon)
```

**No Balancer V3 on Celo** -- we would use Uniswap V3 (Celo) or Mento's virtual AMM for the Celo-side pool data.

---

## 5. Superfluid Protocol

### Overview

Superfluid is a real-time token streaming protocol that enables continuous, per-second token transfers without repeated transactions. Core primitives:

- **Super Tokens**: ERC-20 tokens wrapped with streaming capabilities.
- **Constant Flow Agreement (CFA)**: Establishes continuous per-second flow from sender to receiver. Only requires gas to open/close/update a stream -- zero gas while streaming.
- **Instant Distribution Agreement (IDA)**: Scalable one-to-many distributions based on unit shares.

### Deployment

Superfluid is deployed on **both Polygon and Celo** (plus Ethereum, Gnosis, Arbitrum, Optimism, Avalanche, BSC).

### Relevance to Continuous Measure Updates

Superfluid is NOT a cross-chain messaging protocol. It does not relay data between chains. However, it has conceptual relevance to our system:

**Where Superfluid fits**: If our system needs to distribute hedging premiums, option payoffs, or LP compensation as continuous flows rather than discrete settlements, Superfluid provides the primitive. Consider these scenarios:

1. **Continuous premium streaming**: An LP hedging position could stream premium payments per-second to a counterparty, rather than paying upfront or at discrete intervals. This maps naturally to continuous-time option pricing where premium accrues dt-by-dt.

2. **Streaming yield from cross-chain positions**: If a vault on Polygon earns yield from the USDC/DAI pool, Superfluid could stream that yield continuously to participants on Polygon (same-chain streaming, not cross-chain).

3. **Real-time measure updates via CFA flow rate adjustments**: The flow rate of a Superfluid stream can be updated at any time. A controller contract could adjust flow rates based on incoming cross-chain pool state data, creating a feedback loop:
   - Cross-chain protocol delivers updated pool observables (price, vol, liquidity).
   - Controller contract on the local chain recalculates hedge parameters.
   - Superfluid flow rates are adjusted to reflect new hedge costs/payoffs.
   - This gives continuous measure updates **on-chain** in response to discrete cross-chain data pushes.

4. **Dollar-cost averaging across FX pairs**: Superfluid's Token Cost Averaging (TCA) feature enables streaming swaps. A user could stream USDC into a cCOP position continuously, implementing DCA at the COP/USD FX rate.

**Limitation**: Superfluid does NOT currently support native cross-chain streaming. Cross-chain bridges are listed as a future feature. Each chain's Superfluid deployment is independent.

### Architectural Synthesis: Superfluid + Cross-Chain Messaging

The most powerful architecture combines both:

```
Cross-chain protocol (CCIP/LayerZero)     Superfluid (same-chain)
===========================================  ==========================
Polygon pool state ----[message]----> Celo   Celo: stream(premium, LP)
                                             Celo: stream(yield, vault)
Celo pool state ------[message]----> Polygon Polygon: stream(hedge, cpty)
```

Cross-chain messaging handles the **inter-chain data relay** (discrete pushes of pool observables). Superfluid handles the **intra-chain continuous flows** (streaming payments/yields/premiums that update in response to cross-chain data).

---

## 6. Recommendation

### Primary Recommendation: Chainlink CCIP

For relaying pool observables between Polygon and Celo, **Chainlink CCIP** is the best-suited protocol today:

**Reasons:**

1. **Both Polygon and Celo are actively supported** with live mainnet lanes. Celo specifically adopted CCIP as its canonical cross-chain infrastructure.

2. **Arbitrary messaging** enables sending encoded pool state (price, tick, liquidity, volatility metrics) as bytes payloads between chains.

3. **Oracle infrastructure synergy**: Chainlink Data Feeds already provide price data on both chains. CCIP messages can complement on-chain oracle data, and future integration with Chainlink Data Streams could provide low-latency price updates.

4. **Institutional-grade security**: Battle-tested infrastructure securing trillions in value. For a system that will handle real hedging positions and LP risk, security is paramount.

5. **Active development**: CCIP 2.0 adds configurable risk/speed tradeoffs, Cross-Chain Token (CCT) standard simplifies token integration.

6. **Cost**: Messages are more expensive than LayerZero, but for periodic pool state relay (not high-frequency trading), cost is manageable.

### Secondary Recommendation: LayerZero (with lzRead -- future)

LayerZero's **lzRead** is architecturally the most elegant solution -- it would allow a contract on Celo to directly query Polygon pool state (or vice versa) via view function calls. This is exactly the "cross-chain oracle" pattern we need. However:

- **lzRead does not currently support Celo as a data source chain.** Supported chains are Ethereum, Base, Polygon, Avalanche, BNB Chain, Optimism, Arbitrum.
- Standard LayerZero messaging (push-based) works on both Polygon and Celo today and is a viable alternative to CCIP.
- **Monitor lzRead chain expansion.** If Celo is added, LayerZero becomes the top recommendation.

### Tertiary Option: Hyperlane

For rapid prototyping or if permissionless deployment is valued, Hyperlane's ISM-based security model and broad chain support (150+ including Polygon and Celo) make it attractive. The modular security via Interchain Security Modules mirrors LayerZero's DVN approach. However, the ecosystem is younger and less battle-tested.

### Implementation Architecture

```
Phase 1: Push-based relay via Chainlink CCIP
=============================================

Polygon Side:
  PoolStateReader.sol
    - Reads QuickSwap V3 (Algebra) pool: globalState(), timepoints()
    - Encodes: (sqrtPriceX96, tick, liquidity, volatility, timestamp)
    - Calls CCIP Router.ccipSend() to Celo

Celo Side:
  PoolStateReceiver.sol (implements CCIPReceiver)
    - Receives CCIP message in _ccipReceive()
    - Decodes pool observables
    - Stores in CrossChainOracle mapping
    - Emits PoolStateUpdated event

  PoolStateReader.sol (for Celo -> Polygon direction)
    - Reads Uniswap V3 (Celo) cCOP/USDC pool or Mento exchange rate
    - Encodes and sends via CCIP to Polygon

Trigger: Keeper/automation (Chainlink Automation or Gelato)
  - Triggers PoolStateReader at configurable intervals (e.g., every 5 min)
  - Or on deviation threshold (e.g., price moves > 0.5%)

Phase 2: Superfluid streaming layer (same-chain)
=================================================

  HedgePremiumStreamer.sol (Superfluid CFA)
    - Adjusts streaming flow rates based on CrossChainOracle data
    - Streams hedge premiums between LPs and counterparties

Phase 3: lzRead migration (when Celo supported)
================================================

  OmnichainPoolReader.sol (LayerZero lzRead)
    - Pull-based: query remote pool state on demand
    - Lower latency, more gas efficient than push model
    - Use lzMap/lzReduce for aggregating multi-pool data
```

### Cost Considerations

| Protocol | Estimated cost per message (Polygon <-> Celo) | Notes |
|---|---|---|
| Chainlink CCIP | ~$0.50-2.00 | Higher base cost, includes risk management |
| LayerZero | ~$0.05-0.30 | Cheaper, depends on DVN selection |
| Axelar | ~$0.20-1.00 | Includes validator consensus overhead |
| Hyperlane | ~$0.05-0.20 | Cheapest, newer infrastructure |
| Wormhole | ~$0.10-0.50 | Guardian consensus overhead |

For pool state relay at 5-minute intervals: ~288 messages/day = ~$144-576/day with CCIP, or ~$14-86/day with LayerZero. Deviation-based triggers would reduce this significantly.

---

## Appendix A: Protocol Chain Support Summary

| Protocol | Polygon | Celo | Ethereum | Messaging | Data Pull |
|---|---|---|---|---|---|
| LayerZero V2 | Yes | Yes | Yes | Yes | lzRead (no Celo) |
| Chainlink CCIP | Yes | Yes | Yes | Yes | No (oracle synergy) |
| Axelar GMP | Yes | Yes | Yes | Yes | No |
| Wormhole | Yes | Yes | Yes | Yes | No |
| Hyperlane | Yes | Yes | Yes | Yes | No |
| Superfluid | Yes | Yes | Yes | N/A (streaming) | N/A |

## Appendix B: cCOP Ecosystem Map

```
Celo Chain
|
+-- Mento Platform
|   +-- cCOP (Colombian Peso stablecoin)
|   +-- cUSD (Celo Dollar)
|   +-- cEUR (Celo Euro)
|   +-- cREAL (Celo Brazilian Real)
|   +-- Mento Reserve (collateral backing)
|   +-- Mento Asset Exchange (virtual AMM, FX rates)
|
+-- Uniswap V3 (Celo)
|   +-- USDT/cCOP pool (~$7K daily volume)
|   +-- Other cCOP pairs
|
+-- Governance
    +-- Celo Colombia DAO
    +-- Liquidity strategy proposals (forum.celo.org)
```

cCOP is exclusively on Celo. No Polygon, Ethereum, or other chain presence. Cross-chain relay is the only way to connect cCOP pool data with Polygon pools.

## Appendix C: Key Links and Sources

- [LayerZero V2 Overview](https://docs.layerzero.network/v2/concepts/v2-overview)
- [LayerZero Protocol Overview](https://docs.layerzero.network/v2/concepts/protocol/protocol-overview)
- [LayerZero lzRead Overview](https://docs.layerzero.network/v2/developers/evm/lzread/overview)
- [LayerZero lzRead Deep Dive](https://layerzero.network/blog/the-lzread-deep-dive)
- [LayerZero Polygon Deployment](https://docs.layerzero.network/v2/deployments/chains/polygon)
- [LayerZero Celo Deployment](https://docs.layerzero.network/v2/deployments/chains/celo)
- [LayerZero OFT Standard](https://docs.layerzero.network/v2/home/token-standards/oft-standard)
- [Axelar GMP Overview](https://docs.axelar.dev/dev/general-message-passing/overview/)
- [Axelar GMP Messages](https://docs.axelar.dev/dev/general-message-passing/gmp-messages/)
- [Chainlink CCIP Documentation](https://docs.chain.link/ccip)
- [Chainlink CCIP Architecture](https://docs.chain.link/ccip/concepts/architecture)
- [Chainlink CCIP Celo Network](https://docs.chain.link/ccip/directory/mainnet/chain/celo-mainnet)
- [Chainlink CCIP Polygon Network](https://docs.chain.link/ccip/directory/mainnet/chain/matic-mainnet)
- [Chainlink CCIP Send Arbitrary Data Tutorial](https://docs.chain.link/ccip/tutorials/send-arbitrary-data)
- [Wormhole Architecture](https://wormhole.com/docs/protocol/architecture/)
- [Wormhole Supported Blockchains](https://wormhole.com/platform/blockchains)
- [Hyperlane Documentation](https://www.hyperlane.xyz/)
- [Superfluid Documentation](https://docs.superfluid.org/docs/concepts/superfluid)
- [Superfluid Money Streaming](https://docs.superfluid.org/docs/protocol/money-streaming/overview)
- [Superfluid on Celo](https://www.celopg.eco/ecosystem/superfluid)
- [Mento cCOP Launch Announcement](https://www.mento.org/blog/announcing-the-launch-of-ccop---celo-colombia-peso-decentralized-stablecoin-on-the-mento-platform)
- [cCOP Celo Forum Proposal](https://forum.celo.org/t/launch-of-ccop-colombia-s-first-decentralized-stablecoin/9211)
- [QuickSwap V3 USDC/DAI Pool (CoinMarketCap)](https://coinmarketcap.com/dexscan/polygon/0xe7e0eb9f6bcccfe847fdf62a3628319a092f11a2/)
- [LayerZero 2025 Market Dominance](https://www.stablecoininsider.com/layerzero/)
- [Chainlink CCIP and Swift Integration](https://blockeden.xyz/blog/2026/01/12/chainlink-ccip-cross-chain-interoperability-tradfi-bridge/)
- [Coinbase CCIP Bridge](https://www.coindesk.com/web3/2025/12/11/coinbase-taps-chainlink-ccip-as-sole-bridge-for-usd7b-in-wrapped-tokens-across-chains)
