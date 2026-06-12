# Mento Protocol & On-Chain Emerging Market FX: Research Report

Date: 2026-03-29

---

## 1. Mento Protocol Stablecoins

Mento is a decentralized stablecoin platform built on Celo. As of early 2026, it has launched **15 local currency stablecoins**, all collateralized 1:1 with prime stablecoins (USDC, USDT, DAI). The full roster:

| Token | Currency | Region |
|-------|----------|--------|
| cUSD | US Dollar | Global |
| cEUR | Euro | Europe |
| cREAL | Brazilian Real | Latin America |
| cKES | Kenyan Shilling | Africa |
| eXOF | West African CFA Franc | Africa (WAEMU) |
| cCOP | Colombian Peso | Latin America |
| PUSO | Philippine Peso | Southeast Asia |
| cGHS | Ghanaian Cedi | Africa |
| cNGN | Nigerian Naira | Africa |
| cZAR | South African Rand | Africa |
| cAUD | Australian Dollar | Global |
| cCAD | Canadian Dollar | Global |
| cGBP | British Pound | Europe |
| cCHF | Swiss Franc | Europe |
| cJPY | Japanese Yen | Asia |

Mento processed over $18.5 billion in decentralized stablecoin trading volume in 2025 across all its stablecoins. The platform is positioned explicitly as "the place for on-chain FX."

---

## 2. Mento Stablecoins on Uniswap

Mento stablecoins are traded primarily on **Uniswap v3 on the Celo network**. Uniswap v3 deployed on Celo in 2022. The following pools have been confirmed active:

| Pool | Fee Tier | Chain | Approximate Liquidity (last known) |
|------|----------|-------|-------------------------------------|
| eXOF/cUSD | 0.01% | Celo | ~$12,000 |
| eXOF/CELO | 0.05% | Celo | ~$3,400 |
| cKES/CELO | 0.01% | Celo | ~$4,800 |
| cKES/cEUR | — | Celo | ~$230 |
| cREAL/USDC | various | Celo/Polygon | thin, sub-$100k |

**Key caveat:** Liquidity in individual Uniswap v3 pools for these long-tail Mento stables is shallow — pools are individually in the $200–$12,000 range. The primary liquidity for Mento stablecoins routes through the **Mento Exchange itself** (an on-chain AMM that uses its reserve as counterparty), not through Uniswap third-party LPs. Uniswap pools serve as secondary venues.

Mento has been actively incentivizing liquidity through a "Credit Collective" initiative (Aave, Uniswap, Carbon DeFi integration) and via Merkl for LP rewards. As of mid-2024 the protocol's aggregate TVL stood near $61M (down ~51% QoQ from its peak), but Mento's own exchange mechanism holds the bulk of reserve collateral.

---

## 3. Liquidity Assessment

### Mento Native Exchange
The canonical liquidity source is the Mento Protocol exchange contract itself. Users mint/redeem any Mento stable directly against the reserve. This creates effectively unlimited liquidity within reserve bounds but at prices set by the internal AMM (CPMM + spread).

### Uniswap v3 on Celo (Secondary)
Pools exist but are thin. Most pairs are in the $1k–$15k TVL range, suitable for small retail transactions but not institutional size. Slippage would be material on any trade above ~$5,000.

### Other DEX Venues on Celo
- **Ubeswap** (Celo-native AMM) hosts additional cREAL, cKES, eXOF pairs.
- **Carbon DeFi** (Bancor/Carbon) is being integrated as a concentrated liquidity venue for Mento stables.
- **Aerodrome** (Base) does not currently list Mento stables.

---

## 4. Other On-Chain FX Instruments for Emerging Market Currencies

### Latin America

| Token | Currency | Issuer | Primary DEX Venue | Chain |
|-------|----------|--------|-------------------|-------|
| BRLA | Brazilian Real | BRLA Digital | Uniswap (Polygon) | Polygon |
| BRZ | Brazilian Real | Transfero | Uniswap (Polygon) | Polygon |
| MXNB | Mexican Peso | Bitso/Juno | Uniswap | Polygon / Base |
| MXNe | Mexican Peso | Etherfuse | Aerodrome, Uniswap | Base |
| COPM | Colombian Peso | Stabull partner | Stabull DEX | Ethereum / Base |

BRL-pegged stablecoins processed ~$906M in 2025 (Jan–Jul), tracking toward $1.5B annualized — a 660% YoY increase. Brazil leads all emerging markets in local stablecoin activity. Mexico's MXNe hit 637.7M pesos in transfer value in July 2025 alone.

### Africa

| Token | Currency | Issuer | Primary DEX Venue | Chain |
|-------|----------|--------|-------------------|-------|
| cKES | Kenyan Shilling | Mento | Uniswap v3 (Celo) | Celo |
| eXOF | West African CFA Franc | Mento/Lemonade | Uniswap v3 (Celo) | Celo |
| cGHS | Ghanaian Cedi | Mento | Uniswap v3 (Celo) | Celo |
| cNGN | Nigerian Naira | Mento | Uniswap v3 (Celo) | Celo |
| cZAR | South African Rand | Mento | Uniswap v3 (Celo) | Celo |
| ZARP | South African Rand | ZARP Stablecoin | Uniswap, Aerodrome, Orca | Base / Ethereum |

ZARP has notable institutional backing — Old Mutual (a major South African insurer) pumped liquidity into ZARP in 2025. ZARP is also listed on Stabull DEX with a USDC/ZARP pool on Base.

### Southeast Asia

| Token | Currency | Issuer | Primary DEX Venue | Chain |
|-------|----------|--------|-------------------|-------|
| PUSO | Philippine Peso | Mento | Uniswap v3 (Celo) | Celo |
| PHPC | Philippine Peso | — | Ronin/Katana DEX | Ronin |
| IDRX | Indonesian Rupiah | IDRX.co | Uniswap, Aerodrome, PancakeSwap | Multiple |
| XIDR | Indonesian Rupiah | StraitsX | — | Ethereum / Zilliqa |
| XSGD | Singapore Dollar | StraitsX | Aerodrome (Base), Uniswap | Base / Ethereum |

XSGD is a standout: MAS-regulated, Coinbase-listed, and integrated into Grab's payment network (Nov 2025). StraitsX is launching XSGD + XUSD on Solana in early 2026. IDRX is the most DEX-active IDR stablecoin, though 24h volumes are small (~$48k as of last check).

---

## 5. Other Protocols Offering Emerging Market Stablecoins on DEXes

### Stabull Finance
The most purpose-built DEX for non-USD stablecoins. Deployed on Ethereum, Polygon, and Base. Uses oracle-based AMM (not constant-product) for tighter FX peg tracking.

Supported emerging market stablecoins:
- BRZ (Brazilian Real)
- COPM (Colombian Peso)
- GYEN (Japanese Yen, by GMO)
- MXNe (Mexican Peso)
- PHPC (Philippine Peso)
- XSGD (Singapore Dollar)
- ZARP (South African Rand)
- TRYB (Turkish Lira, by BiLira)

Raised $2.5M from Bolts Capital (Oct 2025). Currently the deepest venue for non-USD stablecoin pairs outside of Mento's own exchange.

### StraitsX (Southeast Asia)
Issues XSGD (SGD) and XIDR (IDR). Both are fully reserved and regulated. XSGD has Uniswap pools and Aerodrome (Base) incentivized pools. Expanding to Solana in 2026.

### BiLira (Turkey)
Issues TRYB, Turkish Lira stablecoin. Listed on Stabull and several CEXs. Uniswap pools exist but are thin.

### Transfero / BRLA Digital (Brazil)
Both issue BRL stablecoins (BRZ and BRLA respectively) on Polygon with active Uniswap pools. Brazil-focused but growing.

### Bitso/Juno (Mexico/Brazil)
Issues MXNB (Mexican Peso) and BRL1 (Brazilian Real). Primarily a payment rails play but MXNB has Uniswap pools and a growing on-chain footprint.

---

## 6. Summary Assessment

**What is usable for LP hedging / structured positions:**

1. **cUSD, cEUR, cREAL on Celo via Mento** — the most liquid Mento stables for DeFi integration. cREAL has Uniswap v3 pools but primary liquidity is via Mento's own AMM.

2. **XSGD on Base (Aerodrome + Uniswap)** — regulated, growing, incentivized pools, integrating with Solana. Best-in-class for SEA exposure.

3. **ZARP on Base (Uniswap + Stabull)** — institutional backing (Old Mutual), dual-venue liquidity.

4. **BRLA/BRZ on Polygon (Uniswap)** — highest volume emerging market non-USD stablecoins, active Uniswap pools.

5. **MXNe on Base (Aerodrome)** — fast-growing, dominant in Mexico, strong DEX activity.

6. **Stabull Finance** — the specialist venue if multi-currency FX pool exposure is needed. Lower liquidity than Uniswap overall but specifically optimized for non-USD pairs.

**Gaps / limitations:**
- African currency pools (cKES, eXOF, cGHS, cNGN) remain extremely thin on Uniswap — meaningful size would need to route through Mento's exchange contract directly.
- cCOP and cGHS are new (2025) and do not yet have notable Uniswap pool depth.
- No emerging market stablecoins have meaningful presence on Ethereum mainnet Uniswap v3 — activity is concentrated on Celo, Polygon, and Base.
- Indonesian rupiah (IDRX, XIDR) has minimal DEX liquidity despite being the 4th most populous country.

---

## Sources

- [Mento Protocol — The place for on-chain FX](https://www.mento.org/)
- [Mento Stablecoins page](https://www.mento.org/stablecoins)
- [Mento — Expanding global on-chain FX with three new stablecoins](https://www.mento.org/blog/mento-expands-global-onchain-fx-access-with-three-new-decentralized-stablecoins)
- [Mento on DefiLlama](https://defillama.com/protocol/mento)
- [Mento Protocol Docs — What, why, who Mento](https://docs.mento.org/mento/mento-protocol/what-why-who-mento)
- [cCOP launch announcement](https://www.mento.org/blog/announcing-the-launch-of-ccop---celo-colombia-peso-decentralized-stablecoin-on-the-mento-platform)
- [Mento on-chain FX use case](https://www.mento.org/use-cases/onchain-fx-trading-liquidity)
- [Mento stablecoin factory (Mirror)](https://mirror.xyz/mentoprotocol.eth/IRWZPWtlCgsIx1KtW3fJliEcJTSPqgyV-TPm59VzbMY)
- [eXOF/cUSD pool on GeckoTerminal](https://www.geckoterminal.com/celo/pools/0xaa97f0689660ea15b7d6f84f2e5250b63f2b381a)
- [cKES/CELO pool on GeckoTerminal](https://www.geckoterminal.com/celo/pools/0xbc83c60e853398d263c1d88899cf5a8b408f9654)
- [cKES/cEUR pool on WhatToFarm](https://whattofarm.io/pairs/celo-uniswap-ckes-ceur-created-2024-07-02)
- [Creating the Next FX Market — Celo Forum](https://forum.celo.org/t/creating-the-next-fx-market-a-strategy-to-attract-liquidity-to-celo/11840)
- [Messari State of Celo Q2 2024](https://messari.io/report/state-of-celo-q2-2024)
- [Stabull Finance](https://stabull.finance/)
- [Stabull supported stablecoins](https://stabull.finance/supported-stablecoins/)
- [Stabull $2.5M raise from Bolts Capital](https://stabull.finance/defi-blog/stabull-secures-2-5-million-commitment-from-bolts-capital-to-scale-global-stablecoin-and-rwa-liquidity/)
- [Stabull launches on Base](https://blockchainmagazine.com/press-release/stabull-dex-launches-on-base-new-chain-new-token-7-stablecoin-pools-and-expanded-liquidity-mining-program/)
- [ZARP Stablecoin](https://www.zarpstablecoin.com/)
- [Old Mutual pumps liquidity into ZARP](https://techcentral.co.za/old-mutual-liquidity-rand-stablecoin-zarp/234357/)
- [ZARP on Stabull DEX](https://stabull.finance/defi-blog/introducing-zarp-on-stabull-dex-usdc-zarp-liquidity-pool-now-live-on-base/)
- [IDRX stablecoin (Indonesian Rupiah)](https://home.idrx.co/en)
- [IDRX on CoinGecko](https://www.coingecko.com/en/coins/idrx)
- [StraitsX XSGD](https://www.straitsx.com/xsgd)
- [Coinbase + StraitsX XSGD listing](https://www.financemagnates.com/cryptocurrency/coinbase-to-list-first-singapore-dollar-stablecoin-in-collaboration-with-straitsx/)
- [StraitsX to launch on Solana 2026](https://www.coindesk.com/markets/2025/12/16/straitx-to-debut-singapore-and-u-s-dollar-stablecoins-on-solana-for-quick-sgd-usd-swaps)
- [PHPC on Ronin/Katana DEX](https://bitpinas.com/cryptocurrency/phpc-katana-liquidity/)
- [BRLA on Uniswap (Polygon)](https://app.uniswap.org/explore/tokens/polygon/0xe6a537a407488807f0bbeb0038b79004f19dddfb)
- [BRZ on DefiLlama](https://defillama.com/stablecoin/brazilian-digital)
- [Dune LATAM Crypto 2025 Report](https://dune.com/blog/latam-crypto-2025-report)
- [Latin American stablecoin market analysis — PANews](https://www.panewslab.com/en/articles/897adef2-63c7-4796-9b57-47042399313a)
- [Lumx — Stablecoins and On-Chain FX](https://lumx.io/blog-posts/stablecoins-and-on-chain-fx-new-structures-for-liquidity-and-efficiency)
- [Mento Labs $10M fundraise and roadmap](https://mento-labs-landing-git-feature-edits-mentolabs.vercel.app/blog/mento-labs-fundraise)
