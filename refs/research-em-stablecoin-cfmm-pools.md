# Emerging Market Stablecoin Pairs on CFMMs: Comprehensive Pool Survey

**Date**: 2026-03-31
**Scope**: All discoverable on-chain CFMM pools for emerging market tokenized currencies across Algebra, Balancer, Uniswap (v2/v3/v4), and specialized stablecoin DEXes.

---

## Executive Summary

Emerging market (EM) stablecoin liquidity on CFMMs is nascent but growing rapidly across three distinct tiers of infrastructure:

1. **Mento Protocol on Celo** -- the dominant issuer of EM stablecoins (15+ local currencies), with trading via both its own virtual AMM (reserve-backed mint/burn) and external Uniswap v3 pools on Celo. Liquidity is thin (sub-$30K per pool) but volume can be surprisingly active due to Mento's reserve acting as backstop.

2. **Stabull Finance** -- a specialized stablecoin DEX on Ethereum, Polygon, and Base supporting 16 stablecoins across 11 national currencies, including BRZ, COPM, MXNE, ZARP, TRYB, and PHPC. Oracle-anchored AMM with proactive rebalancing. Total platform TVL ~$300K but has processed $4M+ in swap volume.

3. **Uniswap / Balancer / Algebra-powered DEXes** -- BRZ is the most liquid EM stablecoin on general-purpose DEXes (Uniswap v3/v4 on Polygon, Balancer on Polygon). Other EM stablecoins have minimal presence outside Celo/Stabull.

**Key finding**: There are essentially no EM stablecoin pools on Algebra-powered DEXes (QuickSwap, Camelot, THENA, Lynex, etc.). This represents a significant gap and potential opportunity for Algebra's adaptive fee model, which is theoretically well-suited for thin, volatile FX pairs.

**Cross-EM pairs** (e.g., cCOP/BRZ, cNGN/MXN) are virtually nonexistent on-chain. All EM stablecoins route through USD stablecoins (USDC, USDT) as the universal numeraire.

---

## Part 1: Token-by-Token Pool Inventory

### 1.1 BRZ (Brazilian Real) -- Transfero

**Issuer**: Transfero (Swiss-based fintech)
**Market cap**: ~$185M (as of early 2026)
**Chains**: Ethereum, Polygon, Arbitrum, Avalanche, Base, Optimism, Celo, Solana, BNB Chain, Moonbeam, Chiliz
**Token address (Polygon)**: `0x4ed141110f6eeeaba9a1df36d8c26f684d2475dc`

BRZ is by far the most liquid EM stablecoin in DeFi. Known pools:

| DEX | Chain | Pair | Pool Address | Fee | TVL | 24h Volume | Notes |
|-----|-------|------|-------------|-----|-----|------------|-------|
| Uniswap v4 | Polygon | BRZ/USDT | `0x18a21938cb1bbdaeb9930a102f4dffe3e663c681fb357b0531638f1f3c2aa1c1` | 0.05% | ~$42K | ~$15.8K | Created ~mid-2025 |
| Uniswap v3 | Ethereum | BRZ/USDC | Check via info.uniswap.org | 0.3% | Low | Low | Ethereum gas makes this uneconomical for small trades |
| Balancer v2 | Polygon | BRZ/jBRL | Gauge approved via BIP-133 | Stable pool | Low | Low | Both tokens track BRL; useful for arb |
| Stabull | Polygon | BRZ/USDC | Via app.stabull.finance | ~0.15% | Part of ~$300K platform TVL | High relative to TVL | Oracle-anchored pricing |
| Stabull | Base | BRZ/USDC | Via app.stabull.finance | ~0.15% | Part of platform TVL | Active | Launched with Base expansion |
| Stabull | Ethereum | BRZ/USDC | Via app.stabull.finance | ~0.15% | Part of platform TVL | Active | Original deployment |

**Note**: jBRL (Jarvis Network) is another BRL stablecoin that has been paired with BRZ on Balancer. The BRZ/jBRL stable pool on Polygon had a Balancer gauge approved with a 2% cap.

---

### 1.2 cCOP (Colombian Peso) -- Mento

**Issuer**: Mento Protocol (Celo Colombia DAO initiative)
**Chain**: Celo
**Mechanism**: Virtual AMM -- minted/burned against Mento Reserve at oracle FX rate

| DEX | Chain | Pair | Pool Address | Fee | TVL | 24h Volume | Notes |
|-----|-------|------|-------------|-----|-----|------------|-------|
| Uniswap v3 | Celo | USDT/cCOP | Check DexScreener | 0.01% | ~$15K | ~$7K | Most active pair |
| Mento Exchange | Celo | cCOP/cUSD | Virtual AMM (no pool address) | Spread-based | Reserve-backed | Variable | Mint/burn mechanism; no pre-provided liquidity |

**COPM (Colombian Peso -- Minteo)**:
A separate fiat-backed COP stablecoin issued by Minteo, supported on Stabull Finance.

| DEX | Chain | Pair | Pool Address | Fee | TVL | Notes |
|-----|-------|------|-------------|-----|-----|-------|
| Stabull | Polygon/Ethereum | COPM/USDC | Via app.stabull.finance | ~0.15% | Part of platform TVL | Fiat-backed, separate from Mento cCOP |

---

### 1.3 cNGN (Nigerian Naira) -- Africa Stablecoin Consortium

**Issuer**: Africa Stablecoin Consortium (regulated)
**Chains**: Ethereum, Polygon, Base, BNB Chain, Bantu Blockchain, AssetChain
**Market cap**: >600M NGN in circulation
**Daily volume**: Peaked at >1B NGN (Aug 2025)

| DEX | Chain | Pair | Notes |
|-----|-------|------|-------|
| AssetChain DEX | AssetChain | cNGN/USDT | Gasless DEX; primary trading venue |
| Mento Exchange | Celo | cNGN/cUSD | Virtual AMM (Mento lists cNGN among its 15 stablecoins) |

**Key observation**: cNGN is primarily traded on centralized/custodial platforms and its native AssetChain DEX. Uniswap/Balancer presence is minimal to nonexistent. The regulated nature of cNGN (KYC requirements) limits open DEX deployment.

---

### 1.4 MXNB / MXNe (Mexican Peso)

**MXNB**: Issued by Juno (Bitso entity). Chains: Ethereum, Arbitrum, Avalanche.
**MXNe**: Supported on Stabull Finance.

| DEX | Chain | Pair | Notes |
|-----|-------|------|-------|
| Uniswap v3 | Ethereum | MXNB/USDC | Listed but liquidity data not readily available |
| Uniswap v3 | Polygon | MXNB/USDC | Listed on CoinGecko as trading venue |
| Stabull | Base | MXNe/USDC | Part of 7-pool Base launch; oracle-anchored |
| Stabull | Polygon | MXNe/USDC | Available on Polygon deployment |

---

### 1.5 cREAL (Brazilian Real) -- Mento/Celo

**Issuer**: Mento Protocol
**Chain**: Celo
**Market cap**: Ranked ~#1476 by market cap

| DEX | Chain | Pair | Pool Address | Fee | TVL | 24h Volume | Notes |
|-----|-------|------|-------------|-----|-----|------------|-------|
| Uniswap v3 | Celo | cREAL/cUSD | `0x72dd8fe09b5b493012e5816068dfc6fb26a2a9e6` | Variable | <$1 | Negligible | Effectively dead pool |
| Carbon DeFi | Celo | cREAL/various | N/A | Variable | Low | Some activity | Alternative DEX on Celo |
| Ubeswap v2 | Celo | cREAL/cUSD | N/A | 0.3% | Low | Low | Legacy Celo DEX |
| Mento Exchange | Celo | cREAL/cUSD | Virtual AMM | Spread-based | Reserve-backed | Variable | Primary trading mechanism |

---

### 1.6 PUSO (Philippine Peso) -- Mento/Celo

**Issuer**: Mento Protocol (Celo Philippines DAO)
**Chain**: Celo
**Status**: First Asian nation with a decentralized local currency stablecoin on Mento

| DEX | Chain | Pair | Notes |
|-----|-------|------|-------|
| Mento Exchange | Celo | PUSO/cUSD | Virtual AMM; primary trading venue |
| Uniswap v3 | Celo | PUSO/USDT | Low liquidity; check GeckoTerminal |

---

### 1.7 PHPC (Philippine Peso) -- Coins.ph

**Issuer**: Coins.ph (BSP-approved)
**Chains**: Ronin, Polygon, expanding to Solana
**Status**: First retail PHP stablecoin; sandbox completed July 2025

| DEX | Chain | Pair | Notes |
|-----|-------|------|-------|
| Katana | Ronin | PHPC/USDC | Live on Ronin's native DEX |
| Katana | Ronin | PHPC/WETH | Live |
| Katana | Ronin | PHPC/PIXEL | Live |
| Katana | Ronin | PHPC/SLP | Live |
| Stabull | Polygon | PHPC/USDC | Part of Stabull's 16-stablecoin portfolio |
| Planned | Solana | PHPC/USDT, PHPC/USDC | Announced; 24/7 FX trading |

---

### 1.8 cKES (Kenyan Shilling) -- Mento

**Issuer**: Mento Protocol (Celo Africa DAO)
**Chain**: Celo

| DEX | Chain | Pair | Pool Address | Fee | TVL | 24h Volume | Notes |
|-----|-------|------|-------------|-----|-----|------------|-------|
| Uniswap v3 | Celo | cKES/CELO | `0xbc83c60e853398d263c1d88899cf5a8b408f9654` | 0.01% | ~$4.8K | ~$617 | |
| Uniswap v3 | Celo | cKES/cUSD | N/A | 0.01% | ~$35.5K | Variable | Most liquid cKES pool |
| Uniswap v3 | Celo | cKES/cREAL | N/A | 0.01% | ~$20.6K | Variable | Cross-EM pair (KES/BRL) |
| Uniswap v3 | Celo | cKES/cEUR | N/A | 0.01% | ~$23.2K | Variable | |
| Uniswap v3 | Celo | cKES/USDT | N/A | Variable | N/A | ~$123.7K | Highest volume pair |
| Mento Exchange | Celo | cKES/cUSD | Virtual AMM | Spread-based | Reserve-backed | Variable | |

**Notable**: cKES has surprisingly deep adoption -- 1M+ cKES disbursed to 114 micro-entrepreneurs in a community credit pilot in Kawangware, Kenya. Integrated by Pretium, Swypt, Valora, Hurupay, Fonbnk, Payd, Kotani Pay, Haraka, Paychant, and Clixpesa.

---

### 1.9 eXOF (CFA Franc) -- Mento/Dunia

**Issuer**: Mento Protocol (Dunia initiative)
**Chain**: Celo
**Peg**: West African CFA Franc (XOF)

| DEX | Chain | Pair | Pool Address | Fee | TVL | 24h Volume | Notes |
|-----|-------|------|-------------|-----|-----|------------|-------|
| Uniswap v3 | Celo | eXOF/CELO | `0xc767c0b2e2e56c455fd29f9ee9b6e6f035c71ed4` | 0.05% | ~$3.4K | ~$5.2K | |
| Uniswap v3 | Celo | eXOF/cUSD | `0xaa97f0689660ea15b7d6f84f2e5250b63f2b381a` | 0.01% | ~$11.8K | ~$3.2K | |
| Uniswap v3 | Celo | eXOF/cEUR | `0x625cb959213d18a9853973c2220df7287f1e5b7d` | 0.01% | ~$26.6K | ~$31K | Strongest pool by both TVL and volume |
| Mento Exchange | Celo | eXOF/cUSD | Virtual AMM | Spread-based | Reserve-backed | Variable | |

**Note**: The eXOF/cEUR pool is the most active -- likely because the CFA Franc is pegged to the Euro (1 EUR = 655.957 XOF), making this a near-stable pair with tight spreads.

---

### 1.10 cGHS (Ghanaian Cedi) -- Mento

**Issuer**: Mento Protocol (Celo Africa DAO)
**Chain**: Celo

| DEX | Chain | Pair | Pool Address | Fee | TVL | 24h Volume | Notes |
|-----|-------|------|-------------|-----|-----|------------|-------|
| Uniswap v3 | Celo | cGHS/CELO | `0xa4bc5aa6229e6f2baa4b8851b19342a1d1217c08` | 0.01% | ~$22.6K | Variable | |
| Uniswap v3 | Celo | cGHS/USDT | N/A | Variable | N/A | ~$25.6K | Most active by volume |
| Mento Exchange | Celo | cGHS/cUSD | Virtual AMM | Spread-based | Reserve-backed | Variable | |

---

### 1.11 cZAR (South African Rand) -- Mento

**Issuer**: Mento Protocol
**Chain**: Celo

| DEX | Chain | Pair | Notes |
|-----|-------|------|-------|
| Uniswap v3 | Celo | cZAR/USDT | ~$224 in 24h volume; very thin |
| Mento Exchange | Celo | cZAR/cUSD | Virtual AMM |

**ZARP (South African Rand)** -- separate fiat-backed stablecoin:
- Issuer: ZARP Stablecoin (reserves managed by Old Mutual Wealth)
- Fully collateralized, crypto-native

| DEX | Chain | Pair | Pool Address | Notes |
|-----|-------|------|-------------|-------|
| Stabull | Base | ZARP/USDC | `0xb755506531786C8aC63B756BaB1ac387bACB0C04` | Oracle-anchored |

---

### 1.12 wARS (Argentine Peso) -- Ripio

**Issuer**: Ripio (Latin American exchange)
**Chains**: Ethereum, Base, World Chain
**Status**: Launched November 2025

| DEX | Chain | Pair | Notes |
|-----|-------|------|-------|
| Uniswap | Base | wARS/USDC | Live; specific address not indexed |
| Uniswap | WorldChain | wARS/USDC | Live |

**Other ARS stablecoins**:
- **ARZ** (Transfero): ARS-pegged, issued by same company as BRZ
- **ARST**: 1:1 fiat-backed, reserves in Argentine bank accounts

---

### 1.13 INR Stablecoins (Indian Rupee)

**ARC (Asset Reserve Certificate)**:
- Issuer: Polygon + Anq (India-based fintech)
- Status: Targeted Q1 2026 launch; backed 1:1 by INR
- **Notable**: Will use Uniswap v4 hooks to restrict swaps to whitelisted addresses only
- Only business accounts can mint; designed to prevent capital flight to USD stablecoins
- No live pools yet as of March 2026

**ArbiRupee**:
- Rupee-backed stablecoin on Arbitrum
- INR deposits via Razorpay, 1:1 arbINR minting
- Connected to Uniswap liquidity on Arbitrum
- Hackathon project; unclear production status

---

### 1.14 TRYB (Turkish Lira) -- BiLira

**Issuer**: BiLira
**Chains**: Ethereum, Avalanche, Solana, and others (6 chains total)
**Significance**: Second-largest non-USD stablecoin by market cap globally

| DEX | Chain | Pair | Notes |
|-----|-------|------|-------|
| Stabull | Polygon/Base | TRYB/USDC | Oracle-anchored; part of Stabull's 16-stablecoin portfolio |

---

## Part 2: AMPL and Inflation-Indexed Tokens

### 2.1 AMPL (Ampleforth)

**Type**: Rebasing token; supply adjusts daily to target 2019 USD purchasing power
**Not a stablecoin**: Price floats but supply adjusts to create a unit of account

| DEX | Chain | Pair | Pool Address | Fee | TVL | 24h Volume | Notes |
|-----|-------|------|-------------|-----|-----|------------|-------|
| Uniswap v3 | Ethereum | AMPL/USDC | `0xc837fe2e91cc7210eeb6e054ec9dfb9fdc4a26dc` | 0.3% | ~$4.9K | Low | Very thin |
| Uniswap v2 | Ethereum | AMPL/WETH | `0xc5be99a02c6857f9eac67bbce58df5572498f40c` | 0.3% | ~$1.3M | ~$16.5K | Legacy pool; most liquid |
| Balancer v1 | Ethereum | AMPL/USDC Smart Pool | Via Balancer Smart Pool Factory | Dynamic ratio | Low | Low | First rebasing smart pool; auto-adjusts AMPL ratio during rebases to prevent IL |

### 2.2 SPOT (Ampleforth Flatcoin)

**Type**: Derivative of AMPL; dampened volatility flatcoin
**Chains**: Ethereum, Base
**Mechanism**: Created by tranching AMPL into senior (SPOT) and junior tranches

| DEX | Chain | Pair | Notes |
|-----|-------|------|-------|
| Uniswap v3 | Ethereum | SPOT/USDC | Mean-reverting asset; high arb-driven trading fees |
| Aerodrome | Base | SPOT/various | Launched on Base with Coinbase Ventures backing |

**Relevance**: SPOT is a "flatcoin" -- inflation-resistant by design. Unlike stablecoins pegged to depreciating fiat, SPOT targets constant purchasing power. Potential pairing with EM stablecoins would create inflation-hedged EM exposure.

### 2.3 Nuon (Inflation-Indexed Flatcoin)

**Type**: Inflation-indexed stablecoin powered by Truflation oracle
**Chain**: Arbitrum
**Status**: Deployed on Arbitrum mainnet Feb 2023; v2 whitepaper published

Nuon tracks a daily inflation adjustment using the Truflation algorithm (10M+ items tracked). No specific EM stablecoin pools found. Primarily USD-denominated.

### 2.4 PRAOS

**Finding**: PRAOS is not a token or stablecoin. "Ouroboros Praos" is a proof-of-stake consensus mechanism used by Cardano. No token called PRAOS exists. The USDAO protocol references Ouroboros Praos in its documentation but does not issue a token by that name.

---

## Part 3: Algebra Protocol Deep Dive

### 3.1 Algebra Deployment Map

Algebra's concentrated liquidity + adaptive fee engine powers 45+ DEXes across chains:

| DEX | Chain | Status |
|-----|-------|--------|
| QuickSwap v3 | Polygon | Live (exclusive Algebra license since June 2022) |
| Camelot | Arbitrum | Live (Algebra V2 codebase) |
| THENA (Fusion) | BNB Chain, opBNB | Live (Algebra V3 CLAMM, April 2023) |
| Lynex | Linea | Live (ve(3,3) + Algebra) |
| KIM | Mode Network | Live (Algebra Integral/V4) |
| StellaSwap | Moonbeam | Live |
| SwapX | Sonic | Live |
| Fenix Finance | Blast | Live |
| Swapsicle | Avalanche | Live |
| Synthswap | Base | Live |
| Hercules | Metis | Live |
| Swapr | Gnosis Chain | Live |
| BladeSwap | Blast | Live |
| Ocelex | Various | Live |
| Hydrex | Various | Live (2025) |
| TrebleSwap | Various | Live |
| MAIN DEX | Various | Live |
| TONCO | TON | Live |

### 3.2 EM Stablecoin Pools on Algebra DEXes

**Finding: NONE discovered.**

After searching QuickSwap v3 (Polygon), Camelot (Arbitrum), THENA (BNB Chain), and other Algebra-powered DEXes, no dedicated EM stablecoin pools (BRZ, cCOP, MXNB, cNGN, TRYB, etc.) were found. These DEXes focus on major pairs (ETH/USDC, BTC/USDT, native token pairs) and DeFi governance tokens.

### 3.3 Why Algebra's Architecture Suits EM Pairs

Despite the absence of EM pools, Algebra's features are theoretically ideal for thin EM FX pairs:

1. **Adaptive/Dynamic Fees**: Algebra's volatility-based fee formula automatically charges lower fees for stable pairs and higher fees for volatile ones. For EM stablecoin pairs that exhibit periodic depegging (e.g., during local currency crises), fees would automatically increase to compensate LPs for higher IL risk.

2. **Concentrated Liquidity**: EM stablecoin pairs (e.g., BRZ/USDC at ~0.19) have predictable price ranges most of the time. LPs can concentrate capital in narrow bands for capital efficiency up to 20x vs. V2-style full-range.

3. **Plugin Architecture (Integral)**: Algebra's modular plugin system could enable:
   - Custom oracle plugins for EM FX rates (Chainlink, Mento, Truflation)
   - Dynamic fee plugins tuned to EM currency volatility regimes
   - Whitelisting hooks (similar to ARC's Uniswap v4 approach) for regulated EM stablecoins

4. **Low-fee-tier flexibility**: Algebra supports custom tick spacing per pool, allowing tight spreads for near-stable pairs while maintaining wider ranges for volatile EM currencies.

---

## Part 4: Stabull Finance -- The EM Stablecoin Specialist

### 4.1 Architecture

Stabull is a proactive AMM specifically designed for non-USD stablecoin trading. Key features:

- **Oracle-anchored pricing**: Pools use off-chain FX oracle feeds to maintain peg accuracy, unlike Uniswap which relies purely on arbitrageurs
- **Yield vaults**: Available on Ethereum and Polygon; up to 70% of swap fees + STABUL token rewards, no lockups
- **Multi-chain**: Ethereum, Polygon, Base

### 4.2 Complete Stablecoin Portfolio (16 tokens, 11 currencies)

| Currency | Token | Chains |
|----------|-------|--------|
| US Dollar | USDC, USDT, DAI, OFD | All |
| Euro | EURC, EURS | All |
| Brazilian Real | BRZ | Ethereum, Polygon, Base |
| Colombian Peso | COPM | Ethereum, Polygon |
| Japanese Yen | GYEN | Ethereum, Polygon |
| Mexican Peso | MXNe | Polygon, Base |
| New Zealand Dollar | NZDS | Ethereum, Polygon |
| Philippine Peso | PHPC | Polygon |
| Singapore Dollar | XSGD | Ethereum, Polygon |
| South African Rand | ZARP | Base |
| Swiss Franc | ZCHF | Polygon |
| Turkish Lira | TRYB | Polygon, Base |
| Australian Dollar | AUDD | Ethereum, Base |

### 4.3 Platform Metrics (as of ~March 2026)

- **TVL**: ~$300K across all pools
- **Cumulative swap volume**: >$4M
- **Standout stat**: One pool showed ~$31K liquidity generating $4.05M in 30-day volume -- a 130x volume/TVL ratio, indicating heavy flow through thin liquidity

---

## Part 5: Mento Protocol -- The EM Stablecoin Factory

### 5.1 Complete Mento Stablecoin List (15 tokens on Celo)

| Token | Currency | Region |
|-------|----------|--------|
| cUSD | US Dollar | Global |
| cEUR | Euro | Global |
| cGBP | British Pound | Global |
| cCAD | Canadian Dollar | Global |
| cAUD | Australian Dollar | Global |
| cCHF | Swiss Franc | Global |
| cJPY | Japanese Yen | Global |
| cREAL | Brazilian Real | Latin America |
| cCOP | Colombian Peso | Latin America |
| cNGN | Nigerian Naira | Africa |
| cKES | Kenyan Shilling | Africa |
| cGHS | Ghanaian Cedi | Africa |
| eXOF | CFA Franc (West Africa) | Africa |
| cZAR | South African Rand | Africa |
| PUSO | Philippine Peso | Asia |

### 5.2 How Mento's Virtual AMM Works

Unlike traditional CFMMs, Mento's exchange operates as a virtual AMM:
- **No pre-provided liquidity**: Stablecoins are minted/burned during swaps
- **Mento Reserve** acts as the counterparty (>$150M in diversified crypto assets)
- **Oracle-driven FX rates**: Uses Chainlink data standard for pricing
- **Spread-based fees**: Not a fixed fee tier like Uniswap
- **Overcollateralized**: All Mento assets are backed by exogenous crypto collateral

### 5.3 External DEX Liquidity (Uniswap v3 on Celo)

Mento processed over **$18.5 billion** in decentralized stablecoin trading volume in 2025. However, external DEX liquidity for EM Mento stablecoins is thin:

| Token | Best External Pool | TVL | Observation |
|-------|-------------------|-----|-------------|
| cKES | cKES/cUSD on Uniswap v3 | ~$35.5K | Best-funded EM pool on Celo |
| eXOF | eXOF/cEUR on Uniswap v3 | ~$26.6K | Benefits from EUR/XOF fixed peg |
| cGHS | cGHS/CELO on Uniswap v3 | ~$22.6K | Decent for size |
| cCOP | cCOP/USDT on Uniswap v3 | ~$15K | Growing |
| cZAR | cZAR/USDT on Uniswap v3 | ~$200/day vol | Effectively dormant |
| cREAL | cREAL/cUSD on Uniswap v3 | <$1 | Dead; BRZ on Polygon dominates BRL stablecoin usage |
| PUSO | PUSO/USDT on Uniswap v3 | Low | PHPC (Coins.ph) has more traction |

Merkl incentivizes liquidity provision for Mento's FX pools to deepen markets.

---

## Part 6: Cross-EM Pairs and On-Chain FX

### 6.1 Cross-EM Pair Discovery

| Pair | Status | Where |
|------|--------|-------|
| cKES/cREAL | EXISTS | Uniswap v3 on Celo, ~$20.6K TVL |
| eXOF/cEUR | EXISTS | Uniswap v3 on Celo, ~$26.6K TVL (quasi-stable due to EUR/XOF peg) |
| BRZ/jBRL | EXISTS | Balancer v2 on Polygon (two BRL-pegged tokens) |
| cCOP/MXN | NOT FOUND | No cross-EM pair |
| cNGN/BRZ | NOT FOUND | No cross-EM pair |
| BRZ/TRYB | NOT FOUND | No cross-EM pair |
| wARS/BRZ | NOT FOUND | No LATAM cross pair |

### 6.2 On-Chain FX Strategy (Celo Forum Proposal)

A Celo governance proposal titled "Creating the Next FX Market" proposes a strategy to attract liquidity for on-chain FX trading on Celo, leveraging Mento's stablecoin infrastructure. This would potentially create deeper cross-pair liquidity for EM stablecoins through incentivized Uniswap v3 pools with Merkl rewards.

---

## Part 7: Analysis and Implications

### 7.1 Liquidity Landscape Summary

**Tier 1 -- Liquid (>$100K TVL equivalent)**:
- BRZ on Uniswap/Balancer/Stabull (multi-chain)
- TRYB on specialized venues

**Tier 2 -- Functional ($10K-$100K TVL)**:
- cKES, eXOF, cGHS on Uniswap v3 (Celo)
- cCOP on Uniswap v3 (Celo)
- PHPC on Katana (Ronin)
- ZARP, MXNe, COPM on Stabull

**Tier 3 -- Nascent (<$10K TVL or no external DEX pools)**:
- cZAR, PUSO, cREAL on Uniswap v3 (Celo)
- cNGN (primarily custodial/centralized)
- wARS (newly launched)
- ARC/INR (not yet live)

### 7.2 Structural Observations

1. **USD is the universal routing currency**: Every EM stablecoin pool pairs against USDC, USDT, or cUSD. Direct EM-to-EM swaps require two hops through USD. This creates unnecessary slippage and fee drag for genuine FX use cases.

2. **Mento's virtual AMM is the dominant EM stablecoin exchange**: With $18.5B in 2025 volume, Mento dwarfs all external DEX liquidity combined. The external Uniswap pools serve as secondary price discovery venues and arbitrage targets.

3. **Stabull is the only multi-chain EM stablecoin DEX**: By supporting 16 stablecoins with oracle-anchored pricing across Ethereum, Polygon, and Base, Stabull occupies a unique niche. Its 130x volume/TVL ratio suggests genuine demand exceeding available liquidity.

4. **Algebra-powered DEXes have zero EM stablecoin presence**: This is the single largest gap identified. QuickSwap (Polygon), Camelot (Arbitrum), and THENA (BNB) collectively have billions in TVL but no EM stablecoin pools.

5. **Regulatory constraints shape deployment**: cNGN requires KYC, ARC (INR) will use Uniswap v4 hooks for whitelisting. Permissionless CFMM pools may not be viable for all EM stablecoins.

### 7.3 Relevance to LP Hedging / IL Research

For a project focused on LP risk hedging via options (Panoptic, Bunni):

- **EM stablecoin pools have extreme IL characteristics**: Thin liquidity + periodic depegging events create IL spikes that are poorly served by static hedging. Dynamic hedging strategies are essential.

- **Concentrated liquidity amplifies both yield and risk**: An LP in a cKES/cUSD pool at 0.01% fee with $35K TVL faces significant IL during KES depreciation events, but earns outsized fees during stable periods.

- **Mento's reserve-backed mint/burn creates unique IL dynamics**: Unlike traditional CFMMs where both tokens must be deposited, Mento's virtual AMM means LPs are effectively the Mento Reserve itself. External Uniswap LPs face standard IL but can arbitrage against Mento's oracle price.

- **Cross-EM pairs (e.g., cKES/cREAL) have correlated depreciation risk**: Both currencies may depreciate simultaneously against USD, creating different IL profiles than USD-paired pools.

- **Adaptive fees (Algebra) could serve as a partial IL hedge**: By automatically increasing fees during high-volatility periods, Algebra's engine provides a built-in first-order IL mitigation for EM pairs.

### 7.4 Opportunities

1. **Deploy EM stablecoin pools on Algebra-powered DEXes**: QuickSwap (Polygon) is the natural first target given BRZ's existing Polygon presence and QuickSwap's Algebra adaptive fees.

2. **Create cross-EM concentrated liquidity pools**: cKES/cCOP, BRZ/wARS, eXOF/cGHS -- these pairs would enable direct EM-to-EM FX without USD intermediation.

3. **Build hedging instruments for EM LP positions**: Options on EM stablecoin LP positions would address the unique risks of thin liquidity + periodic depegging.

4. **Leverage Algebra Integral plugins**: Custom fee plugins calibrated to EM FX volatility regimes could optimize LP returns and reduce IL in EM pairs.

---

## Sources

### Token Issuers and Protocols
- [Transfero BRZ](https://transfero.com/stablecoins/brz/)
- [Mento Protocol](https://www.mento.org/)
- [Mento Documentation](https://docs.mento.org/mento/mento-protocol/what-why-who-mento)
- [Stabull Finance](https://stabull.finance/)
- [MXNB (Juno/Bitso)](https://mxnb.mx/en-US)
- [PHPC (Coins.ph)](https://www.coins.ph/en-ph/phpc-whitepaper)
- [ZARP Stablecoin](https://www.zarpstablecoin.com/)
- [BiLira TRYB](https://www.bilira.co/en/product/tryb-stablecoin)
- [Ripio wARS](https://www.ripio.com/en/cryptos/local-stablecoins)
- [Ampleforth SPOT](https://www.spot.cash/)
- [Nuon Flatcoin](https://nuon.fi/)
- [Algebra Finance](https://algebra.finance/)

### Pool Data and Analytics
- [GeckoTerminal -- eXOF/CELO](https://www.geckoterminal.com/celo/pools/0xc767c0b2e2e56c455fd29f9ee9b6e6f035c71ed4)
- [GeckoTerminal -- eXOF/cUSD](https://www.geckoterminal.com/celo/pools/0xaa97f0689660ea15b7d6f84f2e5250b63f2b381a)
- [GeckoTerminal -- eXOF/cEUR](https://www.geckoterminal.com/celo/pools/0x625cb959213d18a9853973c2220df7287f1e5b7d)
- [GeckoTerminal -- cKES/CELO](https://www.geckoterminal.com/celo/pools/0xbc83c60e853398d263c1d88899cf5a8b408f9654)
- [GeckoTerminal -- cGHS/CELO](https://www.geckoterminal.com/celo/pools/0xa4bc5aa6229e6f2baa4b8851b19342a1d1217c08)
- [GeckoTerminal -- BRZ/USDT Uniswap v4 Polygon](https://www.geckoterminal.com/polygon_pos/pools/0x18a21938cb1bbdaeb9930a102f4dffe3e663c681fb357b0531638f1f3c2aa1c1)
- [DexScreener -- cREAL/cUSD](https://dexscreener.com/celo/0x72dd8fe09b5b493012e5816068dfc6fb26a2a9e6)
- [DeFiLlama -- Mento](https://defillama.com/protocol/mento)
- [DeFiLlama -- BRZ](https://defillama.com/stablecoin/brazilian-digital)
- [PolygonScan -- BRZ Token](https://polygonscan.com/token/0x4ed141110f6eeeaba9a1df36d8c26f684d2475dc)

### News and Governance
- [Mento cCOP Launch](https://www.mento.org/blog/announcing-the-launch-of-ccop---celo-colombia-peso-decentralized-stablecoin-on-the-mento-platform)
- [Mento PUSO Launch](https://www.mento.org/blog/introducing-puso-the-first-decentralized-philippine-peso-stablecoin)
- [Celo Forum -- FX Market Strategy](https://forum.celo.org/t/creating-the-next-fx-market-a-strategy-to-attract-liquidity-to-celo/11840/9)
- [Balancer BIP-133 -- BRZ/jBRL Gauge](https://forum.balancer.fi/t/bip-133-enable-brz-jbrl-stable-pool-gauge-with-a-2-cap-polygon/4026)
- [Stabull Base Launch](https://bravenewcoin.com/press-release/stabull-dex-launches-on-base-new-chain-new-token-7-stablecoin-pools-and-expanded-liquidity-mining-program)
- [Stabull Strong Volume](https://en.coin-turk.com/stabull-pools-drive-strong-trading-volumes-despite-modest-liquidity/)
- [CoinDesk -- ARC Stablecoin](https://www.coindesk.com/markets/2025/11/20/india-s-debt-backed-arc-token-eyes-tentative-january-2026-debut-sources-say/)
- [CoinDesk -- Ripio wARS](https://www.coindesk.com/markets/2025/11/01/latin-american-crypto-exchange-ripio-launches-argentine-peso-stablecoin-wars)
- [PHPC Katana Pools](https://bitpinas.com/cryptocurrency/phpc-katana-liquidity/)
- [Algebra Integral vs Uniswap v4](https://medium.com/@crypto_algebra/integral-by-algebra-next-gen-dex-infrastructure-vs-balancer-uniswap-traderjoe-ba72d69b3431)
- [AMPL/USDC Balancer Smart Pool](https://medium.com/ampleforth/ampl-usdc-smart-pool-on-balancer-be8eed9a264a)
- [Coinbase Ventures -- SPOT on Base](https://www.theblock.co/post/303990/coinbase-ventures-ampleforth-flatcoin-spot-base-aerodrome-finance)
- [Stabull ZARP Pool on Base](https://stabull.finance/defi-blog/introducing-zarp-on-stabull-dex-usdc-zarp-liquidity-pool-now-live-on-base/)
- [Stabull MXNe Docs](https://docs.stabull.finance/stablecoins/mxne)
- [cNGN Wikipedia](https://en.wikipedia.org/wiki/CNGN)
