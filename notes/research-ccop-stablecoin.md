# CCOP / cCOP Colombian Peso Stablecoin Research

Date: 2026-03-31

---

## 1. What Is cCOP and Who Issues It?

There are two distinct Colombian Peso stablecoins with similar names. They should not be confused.

### cCOP (Mento / Celo Colombia DAO)

- **Full name**: Mento Colombian Peso (ticker: CCOP)
- **Issuer**: Launched by Celo Colombia DAO with technical infrastructure from Mento Labs
- **Governance**: Community-governed, decentralized; governed through Mento Protocol governance
- **Mechanism**: Decentralized, overcollateralized, fully smart-contract-based. Uses a virtual AMM (vAMM) that combines Constant Product and Constant Sum curves. Liquidity is not pre-provided by LPs; tokens are minted or burned on swap, with the Mento Reserve acting as the implicit liquidity provider. No traditional LP pool required for the primary issuance mechanism.
- **Oracle**: Chainlink Data Standard (Mento adopted Chainlink in 2024)
- **Launched**: Announced October 2024, part of Mento's 15-stablecoin suite (alongside cUSD, cEUR, cKES, cREAL, cGHS, cNGN, cZAR, eXOF, PUSO, cAUD, cCAD, cCHF, cGBP, cJPY)
- **Reserve position**: As of mid-2025, cCOP represents approximately 0.25% of Mento's total reserve value — a small but live position

### COPW (Wenia / Bancolombia)

- **Full name**: Colombian Peso stablecoin issued by Wenia, the crypto subsidiary of Bancolombia Group (Colombia's largest commercial bank)
- **Issuer**: Wenia (Bancolombia Group)
- **Mechanism**: Custodial, 1:1 fiat-backed by Colombian Pesos. Chainlink Proof of Reserve (PoR) integrated directly into the minting function, with third-party audits by Harris & Trotter.
- **Contract address on Polygon**: `0x55cF6b630d8AE6477DF63e194F0fd80ACFf05f86`
- **Launched**: May 2024

---

## 2. Chain Deployments

### cCOP (Mento)

| Chain | Status |
|-------|--------|
| Celo (mainnet) | Primary deployment. All Mento stablecoins live here. Contract on CeloScan. |
| Polygon | No evidence of deployment |
| Ethereum | No evidence of deployment |

cCOP is exclusively a Celo-native token. It uses the Mento Broker at `0x777a8255ca72412f0d706dc03c9d1987306b4cad` (CeloScan) as the primary exchange contract. Celo is itself now an Ethereum L2, so cCOP benefits from Celo's EVM compatibility and bridge infrastructure, but it has not been bridged to Polygon or Ethereum mainnet in any documented capacity.

### COPW (Wenia / Bancolombia)

| Chain | Status |
|-------|--------|
| Polygon | Primary deployment (`0x55cF6b630d8AE6477DF63e194F0fd80ACFf05f86`) |
| Celo | No evidence of deployment |
| Ethereum | No evidence of deployment |

COPW's Wenia platform currently supports trading of BTC, ETH, MATIC, and USDC on Polygon alongside COPW, but Wenia stated plans to list COPW on other Web3 platforms.

---

## 3. DEX Pools and Where cCOP Actually Trades

### cCOP Primary Liquidity: Mento vAMM (not a traditional pool)

The main venue for cCOP issuance and redemption is the **Mento Asset Exchange** (virtual AMM). This is not a pool in the Uniswap/Curve sense. The Mento Reserve backs all swaps. Users can swap cCOP against:

- cUSD (Celo Dollar)
- cEUR (Celo Euro)
- USDC (bridged onto Celo)
- USDT (bridged onto Celo)

These trades occur at live FX rates with no LP slippage mechanics. This is listed on CoinMarketCap as the "Mento" exchange.

### cCOP Secondary Market: Uniswap V3 on Celo

The most active secondary trading venue is **Uniswap V3 deployed on Celo**. Confirmed pairs:

| Pair | DEX | Chain | Notes |
|------|-----|-------|-------|
| USDT / cCOP | Uniswap V3 (Celo) | Celo | Most active pair. ~$7K/day volume as of late 2025 |
| cUSD / cCOP | Likely exists | Celo | Natural pair given Mento ecosystem |
| CELO / cUSD | Uniswap V3 (Celo) | Celo | Related ecosystem pool tracked on GeckoTerminal |

Secondary market volume for cCOP is low: total 24h volume has been reported around $11,967 at peak activity (representing a 232% spike). This indicates thin, episodic liquidity.

---

## 4. Current Liquidity and TVL

### cCOP (Mento ecosystem)

- **Circulating supply**: Approximately 278-360 million cCOP tokens (sources vary; CoinGecko shows ~278M, Coinbase shows ~360M as of late 2025)
- At ~4,200 COP/USD, this corresponds to roughly **$66K-$86K USD total supply**
- **Market cap rank**: #7197 on CoinGecko — a micro-cap stablecoin
- **Mento Reserve backing**: ~0.25% of total Mento reserve value
- **Secondary pool TVL**: Not reported as a headline figure; given $11K/day peak volume, pool TVL is likely in the low tens of thousands of USD
- **CoinGecko / DexScreener**: cCOP is tracked on both but shows minimal on-chain pool depth

### COPW (Wenia / Bancolombia)

- Primarily custodial within the Wenia exchange, not in open DeFi pools
- No public DeFi pool TVL data found
- Bancolombia targeted 60,000 Wenia users by end 2024; actual DeFi liquidity deployment has not been publicly reported

### Context: Acknowledged Liquidity Gap

A Celo governance proposal submitted July 2025 ("Creating the Next FX Market: A Strategy to Attract Liquidity to Celo") explicitly stated that despite cCOP adoption campaigns in Colombia, **FX markets on Celo remain inefficient** with price gaps between CEXs and Celo DeFi. The proposal requested $3.3M equivalent (300,000 cUSD + ~9.1M CELO over 24 months) to build arbitrage infrastructure and grow liquidity for Mento stablecoins including cCOP. This confirms that as of mid-2025, deep liquidity does not exist.

---

## 5. cCOP/USDC and cCOP/DAI Pools

### cCOP / USDC

- **Mento vAMM**: cCOP can be swapped against USDC directly through the Mento Broker on Celo. This is effectively a protocol-level exchange, not a pool with LP capital.
- **Uniswap V3 on Celo**: No confirmed cCOP/USDC pool found in search results with notable TVL. The most cited pair is USDT/cCOP, not USDC/cCOP.
- **Summary**: Mento provides the functional equivalent of a cCOP/USDC market via its vAMM, but no standalone Uniswap-style cCOP/USDC pool with significant liquidity has been identified.

### cCOP / DAI

- No evidence of a cCOP/DAI pool on any chain or DEX. DAI is not part of the Mento reserve basket, and DAI has minimal presence on Celo compared to USDC and cUSD.

---

## 6. Three-Way Pools Involving cCOP

No three-way pools involving cCOP were found. Given:

- Curve Finance has no documented presence with cCOP
- Celo-based DEX activity is primarily Uniswap V3 (two-asset concentrated liquidity pools)
- cCOP's liquidity model relies on Mento's vAMM as the core mechanism

Multi-asset stable pools (like Curve 3pool equivalents) involving cCOP do not appear to exist at this time. The Celo liquidity governance proposal mentions attracting liquidity providers but has not specified a 3-way pool structure for cCOP specifically.

---

## Summary Table

| Token | Issuer | Chain | Primary Liquidity Venue | USDC Pool | DAI Pool | 3-Way Pool |
|-------|--------|-------|------------------------|-----------|----------|------------|
| cCOP | Mento / Celo Colombia DAO | Celo | Mento vAMM + Uniswap V3 (Celo) | vAMM only (protocol-level) | None | None |
| COPW | Wenia (Bancolombia) | Polygon | Wenia custodial exchange | None (closed ecosystem) | None | None |

---

## Key Takeaways

1. **Two distinct tokens**: cCOP (decentralized, Mento/Celo) and COPW (custodial, Bancolombia/Polygon). They do not interact.
2. **cCOP is real but micro-scale**: ~$70-80K USD circulating supply, with daily DEX volume in the low thousands. Not yet a liquid DeFi asset.
3. **Primary venue is not a pool**: Mento's vAMM is a mint/redeem mechanism, not an LP pool. This makes it unsuitable as a Uniswap/Curve-style LP position.
4. **Secondary market on Uniswap V3 (Celo) is thin**: The USDT/cCOP pair is the most active but has only ~$7K/day volume at best.
5. **Active governance push for liquidity**: The July 2025 Celo governance proposal acknowledges the liquidity gap and proposes capital allocation to deepen it, but this is forward-looking infrastructure work.
6. **No Polygon or Ethereum deployment for cCOP**: Cross-chain expansion has not happened yet.
7. **COPW is a closed system**: Bancolombia's COPW is not in open DeFi pools and is focused on retail banking customers, not DeFi-native users.

---

## Sources

- [Mento Blog: Announcing the Launch of cCOP](https://www.mento.org/blog/announcing-the-launch-of-ccop---celo-colombia-peso-decentralized-stablecoin-on-the-mento-platform)
- [Celo Forum: Launch of cCOP, Colombia's First Decentralized Stablecoin](https://forum.celo.org/t/launch-of-ccop-colombia-s-first-decentralized-stablecoin/9211)
- [Celo Forum: Creating the Next FX Market - Governance Proposal](https://forum.celo.org/t/creating-the-next-fx-market-a-strategy-to-attract-liquidity-to-celo/11840)
- [Celo Forum: Celo Colombia Report 2025 H1](https://forum.celo.org/t/celo-colombia-report-2025-h1/11456/1)
- [CoinGecko: cCOP Price Page](https://www.coingecko.com/en/coins/ccop)
- [Coinbase: CCOP Price](https://www.coinbase.com/price/ccop)
- [CoinMarketCap: Mento Exchange Listings](https://coinmarketcap.com/exchanges/mento/)
- [GeckoTerminal: CELO/cUSD Uniswap V3 Celo Pool](https://www.geckoterminal.com/celo/pools/0x2d70cbabf4d8e61d5317b62cbe912935fd94e0fe)
- [CoinTelegraph: Bancolombia Group Wenia Crypto Exchange COPW Stablecoin](https://cointelegraph.com/news/bancolombia-group-wenia-crypto-exchange-copw-stablecoin)
- [PR Newswire: Wenia Integrates Chainlink PoR for COPW](https://www.prnewswire.com/news-releases/wenia-part-of-bancolombia-group-taps-chainlink-to-increase-transparency-of-its-stablecoin-backed-11-by-the-colombian-peso-302205816.html)
- [MEXC Blog: Mento Decentralized Local Stablecoin Network](https://blog.mexc.com/mento-decentralized-local-stablecoin-network/)
- [CeloScan: Mento Labs Broker Contract](https://celoscan.io/address/0x777a8255ca72412f0d706dc03c9d1987306b4cad)
- [Celo Documentation: Token Addresses](https://docs.celo.org/token-addresses)
