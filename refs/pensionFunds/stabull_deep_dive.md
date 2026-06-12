# Stabull Finance: Deep Technical Investigation

**Date:** 2026-03-29
**Author:** Papa Bear Analysis

---

## Executive Summary

Stabull Finance is a "4th generation" AMM (Automated Market Maker) optimized for non-USD stablecoin and real-world asset (RWA) swaps. It descends from the Shell Protocol -> DFX Finance lineage, using a hybrid constant-product / constant-sum invariant that dynamically concentrates liquidity around Chainlink oracle prices. The protocol is deployed on Ethereum, Polygon, and Base, supports 16 stablecoins across 11 national currencies, and has accumulated over $5M in cumulative swap volume with roughly $300K TVL as of late 2025. The STABUL governance token (10M supply, ERC-20/ERC-677) powers a buyback-and-distribute model where ~95% of protocol fees are recycled to token holders. Building Panoptic-style options on top of Stabull pools would face fundamental structural barriers: oracle-driven pricing (not purely market-driven), pairwise (not concentrated-tick) pools, and a bonding curve shape that does not map cleanly to option payoffs.

---

## 1. Smart Contract Architecture

### 1.1 AMM Model: Hybrid Invariant

Stabull uses a **hybrid of constant-product and constant-sum invariants**. When visualized on a token-balance axis, the resulting curve is "flattened" compared to a pure xy=k curve -- providing low slippage for trades near the oracle price, similar to Curve's StableSwap but parameterized differently.

The key innovation over pure StableSwap is that **the curve dynamically re-centers around an off-chain Chainlink FX oracle price**, rather than assuming a 1:1 peg. This makes it suitable for non-USD stablecoins (EUR, BRL, TRY, NZD, SGD, JPY, etc.) where the "fair" exchange rate fluctuates.

### 1.2 Lineage: Shell Protocol -> DFX Finance -> Stabull

The ancestry is clear and documented:

1. **Shell Protocol** (commit `48dac1c`): Original AMM for baskets of like-valued pairs
2. **DFX Finance v0.5**: Fork of Shell Protocol. Renamed `Shell.sol` to `Curve.sol`, `ShellFactory.sol` to `CurveFactory.sol`, etc. Added Chainlink oracle integration through Assimilators for FX pairs.
3. **DFX Finance v2**: Generalized pool creation (permissionless), added protocol fees, flashloan support, invariant check fixes.
4. **DFX Finance v3**: Further decentralization, support for arbitrary ERC-20 tokens, improved mathematical accuracy.
5. **Stabull Finance**: Builds on the DFX v2/v3 architecture with its own modifications. Not a direct rebrand -- Stabull was founded by Fran Strajnar (Techemy Capital, previously did tokenomics for Bancor, Chainlink, Salt Lending) through Stabull Labs LLC in 2023 after discussions with stablecoin issuers.

Stabull is **not** a rebrand of DFX Finance. It is a distinct protocol that adopted and extended the DFX/Shell codebase. The DFX Finance protocol itself still exists separately (see DeFiLlama: DFX Finance).

### 1.3 Two-Component Architecture: Assimilators and Curves

The contract architecture has two major subsystems:

**Assimilators:**
- Convert all token amounts to a common "numeraire" (base unit, denominated in USD)
- Pipe in Chainlink oracle price feeds to determine numeraire values
- Handle tokens with different decimals and values
- Each supported token has its own Assimilator contract
- Example: A EUR stablecoin Assimilator fetches the EUR/USD Chainlink feed and converts EUR amounts to USD-equivalent numeraire values

**Curves (Pools):**
- Each Curve is a pairwise pool managing reserves of two fiat-backed stablecoins (quoted in USDC)
- Custom parameterization of the bonding curve including:
  - Dynamic fees
  - Halting boundaries (safety limits that pause trading if reserves become too imbalanced)
  - Oracle-anchored liquidity concentration
- The Curve contract itself is the LP token minter (ERC-20)

### 1.4 Oracle Integration

- **Provider:** Chainlink price feeds
- **Mechanism:** Assimilator contracts fetch real-time FX rates (e.g., EUR/USD, TRY/USD, NZD/USD)
- **Pricing:** The exchange rate output by Stabull is a **combination** of the Chainlink oracle price and the internal pool balance ratio. The pool dynamically adjusts swap pricing based on reserves relative to the oracle rate.
- **Capital Efficiency:** Instead of waiting for arbitrageurs to correct prices (reactive), Stabull proactively concentrates liquidity around the oracle price (proactive AMM)

---

## 2. Contract Addresses

### 2.1 STABUL Token Addresses

| Chain    | Address                                      |
|----------|----------------------------------------------|
| Ethereum | `0x6A43795941113c2F58EB487001f4f8eE74b6938A` |
| Polygon  | `0xc4420347a4791832bb7b16bf070d5c017d9fabc4` |
| Base     | `0x6722F882cc3A1B1034893eFA9764397C88897892` |

Token standard: ERC-677 (superset of ERC-20), 18 decimals, non-upgradeable, non-pausable, non-restrictable.

### 2.2 Core Infrastructure Contracts

Detailed contract addresses for Router, CurveFactoryV2, AssimilatorFactory, Config, and individual pool/assimilator contracts are maintained at:
- **Docs:** https://docs.stabull.finance/amm/contracts

The docs page lists separate sections for:
- Pool Addresses (per chain)
- Token & Assimilator Addresses (per chain)
- Other Contract Addresses (Router, Factory, Config per chain)

### 2.3 Staking Contracts

| Chain    | Contract Type   |
|----------|----------------|
| Ethereum | StakingFactory, StakingPool (EURS) |
| Polygon  | StakingFactory, StakingPool (EURS) |

---

## 3. Pool Mechanics

### 3.1 Pool Structure

- **Pairwise pools only:** Each pool contains exactly two tokens -- a non-USD stablecoin paired with USDC as the quote asset
- **Not multi-asset:** Unlike Curve's 3pool or Balancer's weighted pools, Stabull pools are strictly two-token
- **Parameterized curves:** Each pool has custom bonding curve parameters set at deployment
- **Oracle-anchored:** The pool's "center" price tracks the Chainlink FX oracle rather than being fixed at 1:1

### 3.2 Fee Model

| Parameter | Value |
|-----------|-------|
| Current swap fee | 0.15% (promotional: 0.015% on some pools) |
| LP share of fees | 70% (distributed in specie, i.e., in the output token) |
| Protocol share | 30% |
| Fee realization | Fees accrue to LP positions and are realized upon liquidity withdrawal |
| Future governance | Per-pool swap fees will be adjustable via governance proposals |

The protocol's 30% share feeds the buyback-and-distribute mechanism for STABUL holders.

In celebration of passing $5M swap volume, Stabull ran a 90% fee reduction promotion across the DEX.

### 3.3 Oracle-Based Pricing vs. Constant-Product

| Feature | Constant-Product (Uniswap v2) | Stabull |
|---------|-------------------------------|---------|
| Price discovery | Purely endogenous (arbitrage-driven) | Exogenous (oracle) + endogenous (reserve ratio) |
| Slippage near fair value | High (hyperbolic curve) | Low (flattened curve around oracle price) |
| Capital efficiency | Low for stablecoin pairs | High for stablecoin/FX pairs |
| Impermanent loss profile | Standard IL from price divergence | Reduced IL due to oracle anchoring |
| Arbitrage dependency | Required for price accuracy | Reduced (oracle provides price reference) |
| Risk | Oracle failure = no external risk | Oracle failure/manipulation = systemic risk |

### 3.4 Halting Boundaries

The curves implement halting boundaries -- safety parameters that pause trading if pool reserves become excessively imbalanced. This prevents the pool from being drained in one direction during extreme market conditions or oracle failures.

---

## 4. Composability

### 4.1 LP Tokens

- **Standard:** LP tokens are ERC-20 compatible
- **Minting:** The Curve (pool) contract itself is the LP token minter
- **Transferability:** LP tokens are freely transferrable
- **Staking:** LP tokens can be staked in Stabull's Vaults to earn STABUL rewards

### 4.2 External Protocol Integration

- **Aggregator integration:** Stabull is routed through by DeFi aggregators; transactions flow through alongside Morpho, Balancer, Uniswap, Curve, DFX, and Binance DEX
- **Chainlink CCIP:** STABUL token uses Chainlink's Cross-Chain Interoperability Protocol for cross-chain bridging (burn-and-mint)
- **Merkl distribution:** Stabull expanded liquidity mining distribution via Merkl (by Angle Protocol)
- **Router contract:** External contracts can interact with Stabull pools through the Router

### 4.3 Building on Top of Stabull Pools

In principle, because LP tokens are ERC-20, external protocols could:
- Accept Stabull LP tokens as collateral
- Build yield strategies on top of LP positions
- Integrate with lending protocols

However, the AMM architecture presents significant differences from Uniswap v3 that affect composability for derivatives (see Section 9).

---

## 5. Supported Stablecoins and Pool Data

### 5.1 Supported Assets (16 stablecoins, 11 currencies)

| Currency | Token(s) | Pair |
|----------|----------|------|
| US Dollar | USDC, OFD, DAI, USDT | Quote asset |
| Euro | EURC, EURS | EURC/USDC, EURS/USDC |
| Brazilian Real | BRZ | BRZ/USDC |
| Turkish Lira | TRYB | TRYB/USDC |
| New Zealand Dollar | NZDS | NZDS/USDC |
| Singapore Dollar | XSGD | XSGD/USDC |
| Japanese Yen | GYEN | GYEN/USDC |
| Swiss Franc | ZCHF | ZCHF/USDC |
| Australian Dollar | AUDD | AUDD/USDC |
| Colombian Peso | COPM | COPM/USDC |
| Mexican Peso | MXNE | MXNE/USDC |
| Philippine Peso | PHPC | PHPC/USDC |
| South African Rand | ZARP | ZARP/USDC |

### 5.2 Chain Deployment

| Chain | Status | Notable |
|-------|--------|---------|
| Ethereum | Live | Original deployment, staking vaults |
| Polygon | Live | Original deployment, staking vaults, OFD/ZCHF pools |
| Base | Live (2025) | 7 stablecoin pools launched, STABUL token on Base |

### 5.3 TVL and Volume

| Metric | Value | As Of |
|--------|-------|-------|
| TVL | ~$300,000 | September 2025 |
| TVL growth | 338% since August 2025 start | September 2025 |
| Cumulative swap volume | >$5,000,000 | Late 2025 |
| Capital efficiency example | $31K liquidity pool -> $4.05M in 30-day volume | 2025 |

- **DeFiLlama:** https://defillama.com/protocol/stabull-finance
- **Dune Dashboard:** https://dune.com/stabull_finance/dashboard

The TVL is modest but the capital efficiency ratio (volume/TVL) is extremely high, which is characteristic of oracle-anchored FX AMMs where the tight spread attracts flow without requiring deep reserves.

### 5.4 Funding

- **$2.5M commitment from Bolts Capital** (October 2025) for deepening cross-chain liquidity, expanding integrations, and accelerating product rollouts.

---

## 6. Token and Governance

### 6.1 STABUL Token

| Parameter | Value |
|-----------|-------|
| Standard | ERC-677 (ERC-20 superset) |
| Total supply | 10,000,000 STABUL |
| Decimals | 18 |
| Upgradeability | Non-upgradeable |
| Pausability | Non-pausable |
| Restrictability | Non-restrictable |

### 6.2 Token Allocation

| Category | Allocation | Vesting |
|----------|-----------|---------|
| Liquidity Mining | 30% (3,000,000) | 10-year exponential decay |
| Pre-sale | 17.5% (1,750,000) | 33% TGE, 1-month cliff, 2-year linear vest |
| Public Sale | 5% (500,000) | 40% TGE, 1-month cliff, 1-year linear vest |
| Remaining | 47.5% (4,750,000) | Team, treasury, ecosystem (details in docs) |

### 6.3 Revenue Model: Buyback-and-Distribute

- ~95% of protocol fee revenue is used to buy back STABUL from the open market
- Bought-back tokens are distributed to stakers/LPs
- This creates a non-inflationary yield stream -- rewards come from real protocol revenue, not emissions
- Remaining ~5% funds protocol operations

### 6.4 Governance

| Parameter | Detail |
|-----------|--------|
| Platform | Snapshot (off-chain, gasless voting) |
| Voting power | 1 STABUL = 1 vote |
| Supported chains | Ethereum, Base |
| Nature | Advisory -- outcomes guide the core team, who implement feasible proposals |
| Scope (current) | Protocol-level decisions |
| Future scope | Per-pool swap fees, deeper parameter governance |

---

## 7. Technical Documentation and Resources

### 7.1 Documentation

| Resource | URL |
|----------|-----|
| Gitbook (main docs) | https://docs.stabull.finance |
| Concepts | https://docs.stabull.finance/amm/concepts |
| Contracts | https://docs.stabull.finance/amm/contracts |
| Swap mechanics | https://docs.stabull.finance/amm/swap |
| Liquidity | https://docs.stabull.finance/amm/liquidity |
| Tokenomics | https://docs.stabull.finance/ecosystem/tokenomics |
| Whitepaper (PDF) | https://stabull.finance/assets/stabull-whitepaper-v1.pdf |
| Whitepaper (page) | https://stabull.finance/stabull-whitepaper/ |
| Fees page | https://stabull.finance/fees/ |

### 7.2 GitHub

| Resource | URL |
|----------|-----|
| Stabull GitHub org | https://github.com/stabull |
| v1-staking repo | https://github.com/stabull/v1-staking |
| DFX v2 (ancestor) | https://github.com/dfx-finance/protocol-v2 |
| DFX v3 (ancestor) | https://github.com/dfx-finance/protocol-v3 |
| DFX v1 (deprecated ancestor) | https://github.com/dfx-finance/protocol-v1-deprecated |

**Note:** The Stabull GitHub organization appears to have limited public repositories. The core AMM protocol contracts may not be fully open-sourced publicly (only the staking contracts are confirmed public). The DFX Finance repos provide the best available view into the underlying architecture since Stabull builds on that codebase.

### 7.3 Audit Reports

| Audit | Auditor | Date | Scope |
|-------|---------|------|-------|
| AMM Security Audit | RDAuditors | August 2023 | Core AMM contracts |
| Staking Security Audit | RDAuditors | July 2024 | Staking contracts |
| Staking Audit PDF | RDAuditors | July 2024 | https://stabull.finance/assets/Stabull-Smart-Contract-Security-Audit-Jul24.pdf |

### 7.4 Analytics

| Resource | URL |
|----------|-----|
| DeFiLlama | https://defillama.com/protocol/stabull-finance |
| Dune Dashboard | https://dune.com/stabull_finance/dashboard |
| CoinMarketCap | https://coinmarketcap.com/currencies/stabull-finance/ |
| CoinGecko | https://www.coingecko.com/en/coins/stabull-finance |

---

## 8. History and Lineage

### 8.1 Protocol Family Tree

```
Shell Protocol (original)
    |
    v
DFX Finance v0.5 (fork of shellprotocol@48dac1c)
    |-- Renamed Shell.sol -> Curve.sol
    |-- Added Chainlink FX oracle integration
    |-- Added Assimilator pattern
    |
    v
DFX Finance v2
    |-- Permissionless pool creation
    |-- Protocol fees
    |-- Flashloan support
    |
    v
DFX Finance v3
    |-- Arbitrary ERC-20 support
    |-- Improved math precision
    |
    v
Stabull Finance (2023-)
    |-- Gen-4 AMM modifications
    |-- RWA/commodity asset focus
    |-- Multi-chain (ETH, Polygon, Base)
    |-- STABUL governance token
    |-- Buyback-and-distribute model
```

### 8.2 Related Protocols

- **Xave Finance**: Another protocol in the same FX stablecoin AMM space, also builds on DFX-like architecture. Stabull and Xave are **not** the same entity -- they are separate projects that share architectural DNA from DFX/Shell.
- **DFX Finance**: Still operational as a separate protocol. Stabull builds on DFX's open-source code but is a distinct team and entity.

### 8.3 Founding

- **Founded by:** Fran Strajnar (Techemy Capital)
- **Entity:** Stabull Labs LLC
- **Origin:** Discussions with stablecoin issuers in 2023 who lacked a dedicated on-chain venue for their assets
- **Team:** Experienced developers and operations staff, each with 5+ years in crypto

---

## 9. Limitations: Building Panoptic-Style Options on Stabull Pools

This is the critical analysis section for your research. There are **fundamental structural barriers** to building Panoptic-style options on top of Stabull pools.

### 9.1 No Concentrated Liquidity Positions (FATAL)

**Panoptic's core primitive** is the Uniswap v3 concentrated liquidity position -- an LP position bounded by specific tick ranges [tickLower, tickUpper]. This bounded position has an intrinsic payoff structure that maps to a put spread or call spread, enabling the creation of option-like instruments.

**Stabull pools do not have tick-based concentrated liquidity.** LPs deposit into the full pool and receive fungible ERC-20 LP tokens representing a pro-rata share of the entire reserve. There are no user-defined price ranges, no tick boundaries, no NFT position tokens (like Uniswap v3's ERC-721 positions).

This is the single most fundamental incompatibility. Panoptic's entire mechanism -- minting options by moving liquidity in/out of specific tick ranges -- has no analog in Stabull's architecture.

### 9.2 Oracle-Driven Pricing vs. Market-Driven Pricing

Panoptic derives its option pricing from the actual realized volatility of the underlying AMM pool. The fee accumulation on concentrated LP positions serves as the "premium" mechanism. This works because Uniswap v3 prices are purely endogenous -- driven entirely by supply, demand, and arbitrage.

Stabull's pricing is **exogenously anchored** to Chainlink oracles. The pool proactively concentrates liquidity around the oracle price rather than letting the market determine the price. This means:
- Price volatility within the pool is artificially suppressed
- Arbitrage opportunity (and thus LP fee generation) is reduced
- The "implied volatility" embedded in LP positions would not reflect true market conditions
- Option pricing derived from Stabull pool dynamics would be disconnected from actual FX volatility

### 9.3 Fungible LP Tokens (No Position Granularity)

Panoptic requires the ability to:
1. Mint a specific, bounded liquidity position
2. Track that position's fee accumulation independently
3. Move (burn and re-mint) that specific position in response to option exercise

Stabull's fungible ERC-20 LP tokens provide none of this granularity. All LPs share the same exposure profile. There is no way to create a "short put at strike X" by depositing liquidity in a specific range.

### 9.4 Pairwise Pools Only

All Stabull pools are stablecoin/USDC pairs. The universe of "underlyings" is limited to FX rates of fiat-pegged stablecoins. While FX options are a legitimate derivatives market, the low volatility of these pairs (compared to ETH/USDC or WBTC/USDC) would generate minimal option premiums.

### 9.5 Halting Boundaries

Stabull's halting boundaries -- which pause trading when reserves become too imbalanced -- would interfere with option exercise mechanics. If a large directional move triggers a halt, options could not be exercised or settled, creating counterparty risk.

### 9.6 Oracle Dependency Risk

Any derivatives layer would inherit Stabull's oracle dependency. A Chainlink feed failure or manipulation would simultaneously affect:
- The underlying pool's pricing
- Any options built on top
- Settlement and exercise mechanics

This creates correlated failure modes that are absent in oracle-free systems like Panoptic on Uniswap v3.

### 9.7 Limited TVL and Liquidity

With ~$300K TVL, Stabull pools lack the depth required for a derivatives market. Options require significant underlying liquidity to function efficiently. Even the most active Stabull pool demonstrates high capital efficiency for swaps but would be insufficient for the liquidity demands of an options protocol.

### 9.8 Summary: Feasibility Assessment

| Requirement for Panoptic-Style Options | Stabull Support | Severity |
|---------------------------------------|-----------------|----------|
| Concentrated liquidity with tick ranges | Not supported | FATAL |
| NFT-based position tracking | Not supported (fungible ERC-20 LP) | FATAL |
| Endogenous (market-driven) pricing | Not supported (oracle-anchored) | CRITICAL |
| Sufficient underlying liquidity | Insufficient (~$300K TVL) | HIGH |
| No external halt mechanisms | Halting boundaries exist | MEDIUM |
| Oracle independence | Fully oracle-dependent | MEDIUM |

**Verdict:** Building Panoptic-style options on Stabull pools is **not feasible** with the current architecture. The fundamental incompatibility is structural -- Stabull lacks the concentrated liquidity position primitive that Panoptic requires as its core building block.

### 9.9 Alternative Approaches

If one wanted to build options-like instruments in the Stabull ecosystem, alternative approaches would be required:

1. **Covered call vaults on LP tokens:** Use Stabull LP tokens as the underlying in a separate options protocol (e.g., Opyn, Lyra), similar to how Curve LP tokens are used in structured products. This does not provide the capital efficiency of Panoptic's approach.

2. **Oracle-based options:** Build a traditional options protocol that uses Stabull's Chainlink oracle feeds for pricing/settlement but does not use the AMM pools as the underlying mechanism. This would be a conventional FX options protocol, not an AMM-native one.

3. **Wait for architectural evolution:** If Stabull were to adopt concentrated liquidity (tick-based) positions in a future version, the Panoptic model could become applicable. However, this would be a fundamental redesign of the protocol.

---

## 10. Key Takeaways

1. **Stabull is a well-architected FX stablecoin AMM** with clear lineage from Shell Protocol through DFX Finance, using a proven oracle-anchored hybrid invariant.

2. **The protocol is early-stage** with modest TVL (~$300K) but impressive capital efficiency (volume/TVL ratio), a $2.5M funding commitment, and growing multi-chain presence.

3. **The buyback-and-distribute tokenomics model** is structurally sound -- real revenue funds rewards, not inflation.

4. **For Panoptic-style options, Stabull is fundamentally incompatible.** The absence of concentrated liquidity positions and the oracle-driven pricing model make it impossible to replicate Panoptic's mechanism. Any options strategy on Stabull would need to follow traditional (non-AMM-native) approaches.

5. **The most relevant insight for your research** is that Stabull demonstrates the tradeoffs of oracle-anchored AMMs: excellent capital efficiency for stable swaps but reduced endogenous price discovery, which is precisely what makes AMM-native options possible on Uniswap v3.

---

## Sources

- [Stabull Gitbook - Contracts](https://docs.stabull.finance/amm/contracts)
- [Stabull Gitbook - Concepts](https://docs.stabull.finance/amm/concepts)
- [Stabull Gitbook - Swap](https://docs.stabull.finance/amm/swap)
- [Stabull Gitbook - Liquidity](https://docs.stabull.finance/amm/liquidity)
- [Stabull Gitbook - Tokenomics](https://docs.stabull.finance/ecosystem/tokenomics)
- [Stabull Whitepaper (PDF)](https://stabull.finance/assets/stabull-whitepaper-v1.pdf)
- [Stabull Fees Page](https://stabull.finance/fees/)
- [Stabull STABUL Token Info](https://stabull.finance/stabul-token-official-information/)
- [Stabull Governance Blog Post](https://stabull.finance/defi-blog/introducing-stabull-governance-shaping-the-future-of-the-protocol/)
- [Stabull Supported Stablecoins](https://stabull.finance/supported-stablecoins/)
- [Stabull July 2024 Audit (PDF)](https://stabull.finance/assets/Stabull-Smart-Contract-Security-Audit-Jul24.pdf)
- [Stabull Platform Update September 2025](https://stabull.finance/defi-blog/platform-update-24th-september-2025/)
- [Stabull Platform Update May 2025](https://stabull.finance/defi-blog/platform-update-may-6th-2025/)
- [Stabull Bolts Capital Funding](https://stabull.finance/defi-blog/stabull-secures-2-5-million-commitment-from-bolts-capital-to-scale-global-stablecoin-and-rwa-liquidity/)
- [Stabull $5M Volume Celebration](https://stabull.finance/stabull-project-updates/celebrating-5m-in-swap-volume-90-fee-reduction-across-stabull-dex/)
- [Stabull AUDD Launch](https://stabull.finance/defi-blog/introducing-audd-on-stabull-dex-audd-usdc-liquidity-pool-now-live-on-base-ethereum/)
- [Stabull Oracle Usage (BraveNewCoin)](https://bravenewcoin.com/insights/keeping-it-steady-how-stabull-uses-oracles-to-help-stablecoins-stay-pegged)
- [Stabull GitHub Organization](https://github.com/stabull)
- [DFX Finance Protocol v2 (GitHub)](https://github.com/dfx-finance/protocol-v2)
- [DFX Finance Protocol v3 (GitHub)](https://github.com/dfx-finance/protocol-v3)
- [DFX Finance v2 Curve.sol](https://github.com/dfx-finance/protocol-v2/blob/main/src/Curve.sol)
- [DeFiLlama - Stabull Finance](https://defillama.com/protocol/stabull-finance)
- [Dune Dashboard](https://dune.com/stabull_finance/dashboard)
- [CoinMarketCap - Stabull](https://coinmarketcap.com/currencies/stabull-finance/)
- [CoinGecko - Stabull](https://www.coingecko.com/en/coins/stabull-finance)
- [Stabull on Etherscan (STABUL Token)](https://etherscan.io/token/0x6a43795941113c2f58eb487001f4f8ee74b6938a)
- [Stabull Base Launch (DL News)](https://www.dlnews.com/external/stabull-dex-launches-on-base-new-chain-new-token-7-stablecoin-pools-and-expanded-liquidity-mining-program/)
- [Stabull Capital Efficiency (CoinTurk)](https://en.coin-turk.com/stabull-pools-drive-strong-trading-volumes-despite-modest-liquidity/)
