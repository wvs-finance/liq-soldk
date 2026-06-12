# Research: Remittance Stablecoin Pairs and Their On-Chain Liquidity

*Research date: 2026-03-31*

---

## Executive Summary

A growing ecosystem of emerging-market stablecoins exists on EVM chains, but liquidity is thin and fragmented. The most mature cluster lives on Celo/Mento (15 stablecoins, $18.5B DEX volume in 2025). Cross-stablecoin FX perps as perpetual futures are mostly absent — the closest analogue is gTrade's synthetic FX perps (EUR/USD, GBP/USD) with no direct support for NGN, PHP, MXN, etc. Hyperliquid's HIP-3 (live October 2025) opens the door to permissionless perp market creation with custom oracles — the most actionable path for remittance-pair perps. Oracle infrastructure for emerging-market FX is improving (Pyth, RedStone HyperStone) but Chainlink feeds for NGN/PHP/MXN remain unconfirmed.

---

## 1. Remittance Stablecoins on EVM Chains

### 1.1 Nigeria (NGN)

| Token | Issuer | Chain(s) | Contract | Market Cap | Notes |
|-------|--------|----------|----------|------------|-------|
| cNGN (Compliant Naira) | WrappedCBDC Ltd | Ethereum, Base, BSC, Polygon, Asset Chain | `0x17CDB2a01e7a34CbB3DD4b83260B05d0274C8dab` (ETH) | ~$1.7M | Africa's first regulated stablecoin (SEC Nigeria); 1:1 NGN; merchant-mint model |
| NGNm (Mento Nigerian Naira) | Mento / Celo DAO | Celo | See CeloScan | ~$24K | Rebranded from original cNGN on Celo; very low TVL |

**DEX liquidity**: cNGN has 24h volume around $25K–$52K on Ethereum. NGNm on Celo is de minimis (~$24K market cap).

**Key resource**: [cNGN official](https://cngn.co), [Ethplorer token page](https://ethplorer.io/address/0x17cdb2a01e7a34cbb3dd4b83260b05d0274c8dab)

---

### 1.2 Philippines (PHP)

| Token | Issuer | Chain(s) | Contract | Market Cap | Notes |
|-------|--------|----------|----------|------------|-------|
| PUSO | Mento / Celo Philippines DAO | Celo | See CeloScan | Low | Decentralized, over-collateralized; governed by Celo Philippines DAO |
| PHPC | Coins.ph | Ronin (EVM-compatible) | Not published | Regulated | BSP-regulated; 1:1 PHP; full reserve backing; primarily for payments/remittance; Ronin is EVM-compatible but not a major DeFi chain |

**Note**: PHPC is on Ronin — EVM-compatible (Sky Mavis chain) but lacks significant DeFi perp infrastructure. PUSO on Celo has DEX access via Mento AMM.

**Key resource**: [Mento PUSO announcement](https://www.mento.org/blog/introducing-puso-the-first-decentralized-philippine-peso-stablecoin), [PHPC whitepaper](https://coins.ph/phpc-whitepaper)

---

### 1.3 Mexico (MXN)

| Token | Issuer | Chain(s) | Contract | Market Cap | Notes |
|-------|--------|----------|----------|------------|-------|
| MXNB | Bitso / Juno | Arbitrum One | `0xf197ffc28c23e0309b5559e7a166f2c6164c80aa` | Growing | Launched May 2025; 1:1 MXN; targeting LatAm cross-border payments |
| MXNT | Tether | Ethereum, Polygon, Tron | Not confirmed | Moderate | Launched 2022; established but lower DeFi integration |
| MXNe | Brale | Solana, Stellar | N/A (not EVM) | Low | Not EVM |
| MXNC | MXNC | EVM (details sparse) | See mxnc.mx | Unknown | Smaller player |

**Best liquidity**: MXNB on Arbitrum — best positioned for DeFi integration given chain. MXNT on Polygon has some Uniswap presence. Stabull Finance lists MXNE on Ethereum/Polygon/Base.

**Key resource**: [MXNB on Arbiscan](https://arbiscan.io/token/0xf197ffc28c23e0309b5559e7a166f2c6164c80aa), [RWA.xyz MXNB page](https://app.rwa.xyz/assets/MXNB)

---

### 1.4 India (INR)

| Token | Issuer | Chain(s) | Contract | Market Cap | Notes |
|-------|--------|----------|----------|------------|-------|
| TrueINR | TrueINR | Ethereum (ERC-20), BSC (BEP-20), Tron (TRC-20) | See trueinr.io | Low | 1:1 INR redemption at parity |
| ARC | Anq / Polygon | Polygon PoS / L2 | In development | Pre-launch | Debt-backed (Indian govt securities); Uniswap v4 hooks with whitelisted swap addresses; aimed at institutional use; targeted Q1 2026 debut |

**Context**: India's regulatory stance restricts broad DeFi participation. ARC uses Uniswap v4 hooks to restrict trades to whitelisted addresses — not permissionless. TrueINR has minimal on-chain liquidity.

**Key resource**: [ARC stablecoin overview](https://wazirx.com/blog/what-is-arc-india-first-regulated-rupee-stablecoin/)

---

### 1.5 Kenya, Ghana, and Other African Nations

All Mento-issued, all on Celo. Market caps from October 2025:

| Token | Currency | Chain | Contract (CeloScan) | Market Cap |
|-------|----------|-------|---------------------|------------|
| cKES | Kenyan Shilling | Celo | `0x456a3D042C0DbD3db53D5489e98dFb038553B0d0` | ~$216K |
| cGHS | Ghanaian Cedi | Celo | See CeloScan | ~$22K |
| cZAR | South African Rand | Celo | See CeloScan | ~$36K |
| eXOF | West African CFA Franc | Celo | See CeloScan | ~$34K |

**Integrations for cKES**: Pretium, Swypt, Valora, Hurupay, Fonbnk, Payd, Kotani Pay, Haraka, Paychant, Clixpesa — strong M-Pesa-adjacent usage in Kenya. M-Pesa Africa announced blockchain infrastructure partnership covering Kenya, DRC, Egypt, Ethiopia, Ghana, Lesotho, Mozambique, Tanzania in early 2026.

**Key resource**: [cKES on CeloScan](https://celoscan.io/address/0x456a3D042C0DbD3db53D5489e98dFb038553B0d0), [Mento Q3 2025 magazine](https://www.mento.org/blog/mento-magazine-q3-2025)

---

### 1.6 Latin America (BRL, ARS, COP)

| Token | Currency | Issuer | Chain(s) | Contract | Market Cap |
|-------|----------|--------|----------|----------|------------|
| BRZ | Brazilian Real | Transfero | Ethereum, Polygon | `0x4ed141110f6eeeaba9a1df36d8c26f684d2475dc` (Polygon) | ~$88M FDV |
| BRL1 | Brazilian Real | MB/Foxbit/Bitso consortium | EVM (details sparse) | See brl1.io | Launched 2025 |
| ARZ | Argentine Peso | Transfero | EVM (details sparse) | See transfero.com | Low |
| COPW | Colombian Peso | Bancolombia / Wenia | Polygon | Not confirmed | Low |
| cCOP | Colombian Peso | Mento / Celo Colombia DAO | Celo | See CeloScan | Low |

**Best liquidity**: BRZ is the largest non-USD stablecoin by TVL in LatAm. Most active pair: BRZ/USDT on Uniswap v3 (Polygon), ~$165K/day volume. Stabull Finance lists COPM (Colombian Peso) and BRZ across Ethereum/Polygon/Base.

**Key resource**: [BRZ on Stabull](https://stabull.finance/supported-stablecoins/brz/), [COPW announcement](https://cointelegraph.com/news/bancolombia-group-wenia-crypto-exchange-copw-stablecoin)

---

## 2. Perpetual Futures Pairs on EVM Perp DEXes

### 2.1 Summary Matrix

| DEX | Chains | FX Perps | Emerging Market FX | Custom Markets | Notes |
|-----|--------|----------|--------------------|----------------|-------|
| gTrade (Gains Network) | Arbitrum, Polygon, Base | Yes — EUR/USD, GBP/USD, JPY/USD, etc. up to 1000x | No | No (permissioned listing) | 270+ synthetic markets; oracle-based; stablecoin pairs as synthetic exposure only |
| Synthetix / Kwenta | Optimism, Base | Yes — EUR/USD, AUD/USD, GBP/USD | No | No (governance-gated) | 81+ markets post multi-collateral upgrade; sUSD collateral |
| GMX v2 | Arbitrum, Avalanche, BNB | Crypto only (100+ pairs) | No | No | No FX perps; expanded to 100+ crypto pairs in 2025 |
| Hyperliquid (HIP-3) | HyperChain (EVM) | Crypto focus currently | Potentially yes — custom oracle support | Yes (permissionless since Oct 2025) | Requires staking 500K–1M HYPE; builders control oracle, collateral, fees |
| Vertex Protocol | Arbitrum (acquired by Ink, Jul 2025) | No confirmed FX perps | No | No | Originally conceived for FX; pivoted after UST collapse; 10x max leverage |
| dYdX v4 | Cosmos (not EVM) | No | No | N/A | Cosmos-based; not EVM |

### 2.2 gTrade (Gains Network) — Most Relevant for FX

gTrade is the primary EVM venue supporting FX perpetuals:
- **Chains**: Arbitrum, Polygon, Base
- **FX pairs**: EUR/USD, GBP/USD, USD/JPY, AUD/USD, and others from the standard G10 set
- **Leverage**: Up to 1000x for FX
- **Mechanism**: Oracle-based synthetic (no real underlying asset); collateral is DAI/USDC
- **Emerging market FX**: Not listed; no NGN, PHP, MXN pairs
- **Custom market creation**: Not permissionless — governance-gated listing

**Key resource**: [gTrade pair list](https://gains-network.gitbook.io/docs-home/gtrade-leveraged-trading/pair-list), [gTrade on Arbitrum](https://blog.arbitrum.io/gtrade-on-arbitrum-a-new-era-for-onchain-trading/)

### 2.3 Synthetix / Kwenta — FX Perps on Optimism

- **FX pairs**: EUR/USD, AUD/USD, GBP/USD (confirmed since Feb 2023)
- **Chain**: Optimism (primary), Base (expanding)
- **Mechanism**: sUSD collateral, Chainlink oracles
- **Emerging market FX**: Not supported
- **81 new markets** added with multi-collateral perps upgrade

**Key resource**: [Synthetix multi-collateral perps announcement](https://blog.synthetix.io/synthetix-multi-collateral-perps-with-81-new-markets-on-kwenta/)

### 2.4 Hyperliquid HIP-3 — Permissionless Perp Creation (Most Actionable Path)

Activated October 13, 2025:
- **Mechanism**: Builders stake 500K–1M HYPE tokens to deploy custom perp markets
- **Custom oracle**: Full builder control — can integrate Pyth, RedStone HyperStone, or custom feeds
- **Custom collateral**: Builder-defined
- **Custom fee/leverage**: Builder-defined
- **Asset support**: Explicitly designed for RWAs, equities, emerging assets
- **Oracle infrastructure**: RedStone launched HyperStone specifically to power HIP-3 markets
- **USDH**: Native Hyperliquid stablecoin in development (backed by US Treasuries via Stripe Bridge / BlackRock)

**Verdict**: HIP-3 is the most realistic path to a cNGN/USDC perp or PUSO/USDC perp today, subject to the HYPE staking cost.

**Key resource**: [HIP-3 docs](https://hyperliquid.gitbook.io/hyperliquid-docs/hyperliquid-improvement-proposals-hips/hip-3-builder-deployed-perpetuals), [RedStone HyperStone](https://www.theblock.co/post/377776/redstone-launches-hyperstone-oracle-to-power-permissionless-markets-on-hyperliquid)

---

## 3. Cross-Stablecoin Spread Trading Infrastructure

### 3.1 Spot DEX — Stabull Finance (Most Directly Relevant)

Stabull Finance is a DEX purpose-built for FX stablecoin swaps, positioned as an on-chain alternative to SWIFT/CME:
- **Chains**: Ethereum, Polygon, Base
- **Mechanism**: AMM with off-chain oracle pricing for low slippage
- **Funded**: $2.5M from Bolts Capital (2025)
- **Supported stablecoins** (16 total across 11 currencies):
  - EUR: EURC, EURS
  - BRL: BRZ
  - COP: COPM
  - JPY: GYEN
  - MXN: MXNE
  - NZD: NZDS
  - PHP: PHPC
  - SGD: XSGD
  - ZAR: ZARP
  - CHF: ZCHF
  - TRY: TRYB
  - USD: USDC, OFD, DAI, USDT
- **Missing**: NGN stablecoins (cNGN not listed as of research date)
- **No perp functionality** — spot swaps only

**Key resource**: [Stabull Finance](https://stabull.finance/), [Stabull on Base announcement](https://www.investing.com/news/cryptocurrency-news/stabull-dex-launches-on-base-new-chain-new-token-7-stablecoin-pools-and-expanded-liquidity-mining-program-4173266)

### 3.2 Mento AMM — On-Chain FX on Celo

Mento processed **$18.5B in decentralized stablecoin trading volume in 2025**. This is the deepest venue for emerging-market stablecoin swaps:
- **Pairs**: Any combination of cUSD, cEUR, cREAL, cKES, cGHS, cNGN, PUSO, cCOP, eXOF, cZAR, cJPY, cGBP, cAUD, cCAD, cCHF (15 stablecoins)
- **Mechanism**: On-chain AMM with Chainlink oracle pricing
- **Multichain expansion**: Wormhole bridge integration in progress
- **FX forum discussion**: Active governance discussion on [creating the next FX market on Celo](https://forum.celo.org/t/creating-the-next-fx-market-a-strategy-to-attract-liquidity-to-celo/11840/17)
- **No perp functionality** — spot only

**Key resource**: [Mento Protocol](https://www.mento.org/), [DefiLlama Mento page](https://defillama.com/protocol/mento)

### 3.3 Oracle Infrastructure for Emerging Market FX

#### Chainlink
- Standard feeds cover G10 FX (EUR/USD, GBP/USD, JPY/USD, etc.)
- Mento adopted Chainlink Data Standard for its stablecoins
- **Specific NGN/PHP/MXN feeds**: Not confirmed in available data — check [data.chain.link](https://data.chain.link) directly
- **Key resource**: [Chainlink data feeds](https://docs.chain.link/data-feeds)

#### Pyth Network
- 380+ feeds across crypto, equities, ETFs, FX, commodities
- **Confirmed emerging market FX**: Indian Rupee (INR), Indonesian Rupiah (IDR), South Korean Won (KRW), Chilean Peso (CLP), Taiwan Dollar (TWD)
- **Institutional FX partnership**: Integral (serves Mizuho, Raiffeisen, Pictet) publishing FX data directly to Pyth since May 2025
- **NGN/PHP/MXN**: Not explicitly confirmed — expanding coverage, check [pyth.network/price-feeds](https://www.pyth.network/price-feeds)
- **Key resource**: [Pyth price feeds](https://www.pyth.network/price-feeds), [Messari State of Pyth Q2 2025](https://messari.io/report/state-of-pyth-q2-2025)

#### RedStone HyperStone
- Purpose-built for Hyperliquid HIP-3 markets
- Can support any asset class — designed for custom/exotic markets
- **Key resource**: [The Block announcement](https://www.theblock.co/post/377776/redstone-launches-hyperstone-oracle-to-power-permissionless-markets-on-hyperliquid)

---

## 4. Chain-Specific Opportunities

### 4.1 Celo Ecosystem

**Status**: Celo migrated to Ethereum L2 (OP Stack / Superchain) in 2024, EVM-compatible.

**Strengths**:
- Home of Mento — the richest emerging-market stablecoin ecosystem
- 15 stablecoins live; $18.5B DEX volume in 2025
- DeFi integrations added in 2025: Aave v3, Velodrome, Uniswap v4, Curve, Chainlink
- cKES has real-world M-Pesa-adjacent adoption in Kenya
- Active governance discussion on FX market creation

**Perp DEXes on Celo**: No major perp DEX natively on Celo as of research date. Velodrome and Uniswap v4 integration provides spot liquidity depth.

**Gap**: No perp infrastructure for cKES, cNGN, PUSO on Celo itself.

**Key resource**: [Celo 2025 year in review](https://medium.com/@celoorg/2025-year-in-review-while-crypto-talked-celo-delivered-1f2472952abf), [Mento on Celo docs](https://docs.mento.org/mento/use-mento/getting-mento-stables/on-celo)

### 4.2 Base / Optimism

**Base**:
- Stabull DEX launched on Base with 7 stablecoin pools (PHP, MXN, EUR, etc.)
- Synthetix perps expanding to Base (14 new markets announced)
- gTrade on Base
- Best for: PHPC (if bridged), MXNE swaps via Stabull; FX perps via gTrade/Synthetix on G10 only

**Optimism**:
- Synthetix / Kwenta primary chain — EUR/USD, GBP/USD, AUD/USD perps
- OP rewards program for perp traders
- No emerging-market stablecoin liquidity of note

### 4.3 Arbitrum

**Strongest overall for perp DEXes**:
- gTrade (Gains Network) — FX perps, 270+ markets
- GMX v2 — crypto only, deepest liquidity
- Vertex Protocol — being absorbed by Ink Foundation (Jul 2025); uncertain future
- MXNB (Bitso/Juno) native chain — best MXN stablecoin liquidity in DeFi
- Deepest USDT stablecoin liquidity of any L2

**Gap**: No NGN or PHP perps; FX perps limited to G10 currencies.

---

## 5. Key Gaps and Actionable Observations

### What Exists
1. Spot stablecoin swaps for NGN, PHP, MXN, KES, GHS, BRL, COP, ARS — via Mento (Celo) and Stabull (Ethereum/Polygon/Base)
2. G10 FX perpetuals — via gTrade (Arbitrum/Polygon/Base) and Synthetix/Kwenta (Optimism/Base)
3. Permissionless perp creation — Hyperliquid HIP-3 (live since Oct 2025)

### What Does Not Exist
1. Perpetual futures for cNGN/USDC, PUSO/USDC, MXNB/USDC, cKES/USDC anywhere on-chain
2. On-chain oracle feeds confirmed for NGN or PHP on Chainlink or Pyth (coverage expanding, not confirmed)
3. Deep AMM liquidity for most EM stablecoins — market caps range from $22K (cGHS) to $1.7M (cNGN) — well below viable perp market thresholds

### Most Actionable Paths
1. **Hyperliquid HIP-3**: Deploy custom cNGN/USDC or MXNB/USDC perp using RedStone HyperStone oracle for price feed. Requires HYPE stake (500K–1M tokens). Oracle feed construction is the primary technical risk.
2. **Stabull Finance**: Integration for spot cNGN/USDC as a DEX pool — NGN is the most notable gap in their current 16-stablecoin lineup.
3. **Mento multichain + Wormhole**: As Mento stablecoins bridge to Arbitrum/Base via Wormhole, they become accessible to gTrade/Synthetix oracle infrastructure — though listing is still governance-gated.
4. **Pyth feed construction**: Contact Pyth to publish NGN/USD and PHP/USD feeds via their institutional FX data pipeline (Integral partnership). This unblocks both gTrade and Hyperliquid market creation.

---

## Sources

- [Coinbase — Mento Nigerian Naira (CNGN)](https://www.coinbase.com/price/celo-nigerian-naira)
- [CoinGecko — Mento Nigerian Naira](https://www.coingecko.com/en/coins/mento-nigerian-naira)
- [CoinMarketCap — Compliant Naira (cNGN)](https://coinmarketcap.com/currencies/consortium-naira/)
- [Ethplorer — cNGN contract](https://ethplorer.io/address/0x17cdb2a01e7a34cbb3dd4b83260b05d0274c8dab)
- [WrappedCBDC / cNGN explainer — TechCabal](https://techcabal.com/2025/12/12/wrappedcbdc-is-building-a-rail-to-move-naira-faster/)
- [Mento — Introducing PUSO](https://www.mento.org/blog/introducing-puso-the-first-decentralized-philippine-peso-stablecoin)
- [Coins.ph — PHPC on Ronin](https://cryptonews.com/news/coins-ph-launches-first-philippine-peso-stablecoin-phpc-on-ronin-blockchain/)
- [Coins.ph — PHPC whitepaper](https://coins.ph/phpc-whitepaper)
- [CoinTelegraph — MXNB launch on Arbitrum](https://cointelegraph.com/news/bitso-launching-mexican-peso-pegged-stablecoin-on-arbitrum)
- [Arbiscan — MXNB token](https://arbiscan.io/token/0xf197ffc28c23e0309b5559e7a166f2c6164c80aa)
- [RWA.xyz — MXNB](https://app.rwa.xyz/assets/MXNB)
- [Tether / MXN₮ — The Defiant](https://thedefiant.io/news/markets/tether-launches-stablecoin-for-mexican-peso)
- [MXNB official](https://mxnb.mx/en-US)
- [ARC stablecoin — WazirX](https://wazirx.com/blog/what-is-arc-india-first-regulated-rupee-stablecoin/)
- [TrueINR](https://trueinr.io/)
- [Transfero BRZ](https://transfero.com/stablecoins/brz/)
- [PolygonScan — BRZ](https://polygonscan.com/token/0x4ed141110f6eeeaba9a1df36d8c26f684d2475dc)
- [Transfero ARZ](https://transfero.com/stablecoins/arz/)
- [Bancolombia COPW — CoinTelegraph](https://cointelegraph.com/news/bancolombia-group-wenia-crypto-exchange-copw-stablecoin)
- [Mento — Launch of cCOP](https://www.mento.org/blog/announcing-the-launch-of-ccop---celo-colombia-peso-decentralized-stablecoin-on-the-mento-platform)
- [Mento — 3 new stablecoins](https://www.mento.org/blog/mento-expands-global-onchain-fx-access-with-three-new-decentralized-stablecoins)
- [Mento — Q3 2025 magazine](https://www.mento.org/blog/mento-magazine-q3-2025)
- [CeloScan — cKES](https://celoscan.io/address/0x456a3D042C0DbD3db53D5489e98dFb038553B0d0)
- [Celo token addresses docs](https://docs.celo.org/token-addresses)
- [Mento on DefiLlama](https://defillama.com/protocol/mento)
- [Celo 2025 year in review](https://medium.com/@celoorg/2025-year-in-review-while-crypto-talked-celo-delivered-1f2472952abf)
- [Mento — Wormhole multichain](https://www.mento.org/blog/mento-selects-wormhole-as-its-official-interoperability-provider-to-power-multichain-fx)
- [Mento — FX market strategy (Celo Forum)](https://forum.celo.org/t/creating-the-next-fx-market-a-strategy-to-attract-liquidity-to-celo/11840/17)
- [Stabull Finance](https://stabull.finance/)
- [Stabull on Base](https://www.investing.com/news/cryptocurrency-news/stabull-dex-launches-on-base-new-chain-new-token-7-stablecoin-pools-and-expanded-liquidity-mining-program-4173266)
- [Stabull $2.5M raise](https://stabull.finance/defi-blog/stabull-secures-2-5-million-commitment-from-bolts-capital-to-scale-global-stablecoin-and-rwa-liquidity/)
- [Stabull launch on Ethereum/Polygon — CryptoSlate](https://cryptoslate.com/press-releases/stabull-finance-launches-stablecoin-and-real-world-assets-dex-on-ethereum-and-polygonprospera-honduras-december-13th-2024-chainwire-stabull-finance-a-decentralized-platform-providing-an-alterna/)
- [gTrade pair list](https://gains-network.gitbook.io/docs-home/gtrade-leveraged-trading/pair-list)
- [gTrade on Arbitrum](https://blog.arbitrum.io/gtrade-on-arbitrum-a-new-era-for-onchain-trading/)
- [gTrade review — CoinCodeCap](https://coincodecap.com/trade-by-gains-network-review)
- [Synthetix multi-collateral perps + 81 markets](https://blog.synthetix.io/synthetix-multi-collateral-perps-with-81-new-markets-on-kwenta/)
- [Synthetix perps on Base](https://blog.synthetix.io/synthetix-perps-launches-14-new-perpetual-futures-markets-on-base/)
- [Hyperliquid HIP-3 docs](https://hyperliquid.gitbook.io/hyperliquid-docs/hyperliquid-improvement-proposals-hips/hip-3-builder-deployed-perpetuals)
- [HIP-3 activation — CoinDesk](https://www.coindesk.com/business/2025/10/13/hyperliquid-s-hip-3-upgrade-to-unlock-permissionless-perp-market-creation)
- [RedStone HyperStone — The Block](https://www.theblock.co/post/377776/redstone-launches-hyperstone-oracle-to-power-permissionless-markets-on-hyperliquid)
- [HIP-3 transformational potential — FalconX](https://www.falconx.io/newsroom/the-transformational-potential-of-hyperliquids-hip-3)
- [Pyth price feeds](https://www.pyth.network/price-feeds)
- [Pyth — Messari Q2 2025](https://messari.io/report/state-of-pyth-q2-2025)
- [Chainlink data feeds](https://docs.chain.link/data-feeds)
- [Chainlink — Mento adoption](https://www.mento.org/blog/mento-adopts-the-chainlink-data-standard-to-power-decentralized-stablecoins)
- [Bitwage — State of stablecoins Philippines](https://bitwage.com/en-us/blog/state-of-stablecoins-in-philippines-september-2025)
- [Bitwage — State of stablecoins Colombia](https://bitwage.com/en-us/blog/state-of-stablecoins-in-colombia---september-2025)
- [Brazil stablecoin market — Plasma](https://www.plasma.to/blog/brazil-stablecoin-market)
- [African crypto legislation — African Business](https://african.business/2025/11/technology-information/africa-gets-to-grips-with-crypto-as-kenya-and-ghana-legislate)
- [M-Pesa blockchain — Pan African Visions](https://panafricanvisions.com/2026/01/m-pesa-goes-blockchain-inside-kenyas-stablecoin-revolution)
