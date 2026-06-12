# Academic Literature: CFMMs as Macro Oracles

*Date: 2026-03-31*
*Project: liq-soldk-dev — Macro Risk Hedging via On-Chain Instruments*

---

## Key Finding

**No existing paper extracts macro variables from CFMM pool-level observables on EM stablecoin pairs.** The literature exists in three disconnected clusters that this project bridges.

---

## Cluster 1: CFMMs as Price Oracles (Microstructure)

### Foundational

- **Angeris & Chitra (2020), "Improved Price Oracles: Constant Function Market Makers"**
  - arxiv:2003.10001
  - Proves agents are incentivized to correctly report prices through CFMM arbitrage
  - Foundation: CFMMs are reliable oracles, not just trading venues

- **Lehar & Parlour (2025), "Decentralized Exchange: The Uniswap AMM"**
  - Journal of Finance, Dec 2024
  - 95.8M Uniswap interactions analyzed
  - Absence of long-lived arbitrage → price efficiency approaching CEXs
  - URL: https://onlinelibrary.wiley.com/doi/10.1111/jofi.13405

- **Alexander et al. (2025), "Price Discovery and Efficiency in Uniswap Liquidity Pools"**
  - Journal of Futures Markets
  - Some Uniswap v3 pools EXCEED Bitstamp in price efficiency
  - Uses VECM for information transmission analysis
  - URL: https://onlinelibrary.wiley.com/doi/10.1002/fut.22593

### Oracle Security

- **Adams, Wan, Zinsmeister (2023), "Uniswap v3 TWAP Oracles in PoS"**
  - SSRN: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4384409
  - Manipulation costs for TWAP oracles under Proof of Stake

- **Mackinga (2022), "TWAP Oracle Attacks: Easier Done than Said?"**
  - IACR eprint 2022/445
  - Feasibility and costs of TWAP manipulation

- **Ormer (2025), "A Manipulation-resistant and Gas-efficient Blockchain Pricing Oracle"**
  - arxiv:2410.07893
  - Median-based on-chain pricing oracle

### AMM Theory

- **"All AMMs are CFMMs. All DeFi markets have invariants."**
  - arxiv:2310.09782
  - Unifying framework

- **"A Dynamic Equilibrium Model for Automated Market Makers"**
  - arxiv:2603.08603 (March 2026)
  - Heterogeneous participants, LP-fee dynamics

**Gap in Cluster 1**: All work treats CFMMs as micro oracles (asset price). None extends to macro inference.

---

## Cluster 2: LP Income & Adverse Selection as Information Signals

### Core Papers

- **BIS Working Paper 1227, "Decentralised Dealers"** (Aquilina, Foley, Gambacorta, Krekel, 2024)
  - 80% of TVL/fees to sophisticated LPs (7% of total)
  - During high vol, these LPs extract more profit without more adverse selection → behavior signals information asymmetry
  - URL: https://www.bis.org/publ/work1227.pdf

- **Milionis, Moallemi, Roughgarden, Zhang (2022), "Loss-Versus-Rebalancing"**
  - LVR formalizes adverse selection cost to LPs
  - LVR IS the price of information flowing into the pool
  - URL: https://anthonyleezhang.github.io/pdfs/lvr.pdf

- **"Impermanent Loss in Cryptocurrency"** (ScienceDirect, 2025)
  - IL risk predicts LP returns cross-sectionally → it's a risk factor, not just a cost
  - URL: https://www.sciencedirect.com/science/article/abs/pii/S0261560625002116

- **"Pricing and Hedging for LP in CFMMs"** (arxiv:2603.01344, March 2026)
  - LP position = short convex payoff
  - Mathematical bridge to Panoptic options work

### Fee Mechanics

- **"Optimal Fees for Liquidity Provision in AMMs"** (arxiv:2508.08152)
  - Dynamic fee schedules protect LPs in high vol
  - Threshold-type dynamic fee is robust and improves LP outcomes

- **"A theoretical framework for fees in AMMs"** (arxiv:2404.03976)
  - Economic theory of optimal fee mechanisms

- **"Measuring Arbitrage Losses and Profitability of AMM Liquidity"** (arxiv:2404.05803)
  - LP performance vs rebalancing portfolio

**Gap in Cluster 2**: Papers study LP income as micro risk. None maps LP fee dynamics to macro variables.

---

## Cluster 3: Stablecoins as Macro Indicators

### IMF / BIS / Central Bank Research

- **IMF (March 2026), "Stablecoin Inflows and Spillovers to FX Markets"**
  - Published 4 days before this research date
  - Documents CAUSAL spillovers from stablecoin FX to traditional FX markets
  - Shows gaps between stablecoin-dollar cost and spot FX
  - URL: https://www.imf.org/en/publications/wp/issues/2026/03/27/stablecoin-inflows-and-spillovers-to-fx-markets-575046
  - PDF saved: refs/macro-risk/imf-stablecoin-spillovers-fx-2026.pdf

- **IMF (2025), "How to Estimate International Stablecoin Flows"**
  - $2T in 2024 stablecoin txns
  - LatAm 7.7% of GDP, Africa/ME 6.7%
  - Establishes methodology for on-chain flow data as balance-of-payments proxies
  - URL: https://www.imf.org/-/media/files/publications/wp/2025/english/wpiea2025141-source-pdf.pdf
  - PDF saved: refs/macro-risk/imf-estimating-stablecoin-flows-2025.pdf

- **IMF (2025), "Understanding Stablecoins"**
  - Warns stablecoins accelerate currency substitution in EMDEs
  - URL: https://www.imf.org/-/media/files/publications/dp/2025/english/usea.pdf

- **BIS, "Stablecoin Growth: Policy Challenges"**
  - Capital flow volatility amplification
  - URL: https://www.bis.org/publ/bisbull108.pdf

- **NY Fed, "Runs and Flights to Safety"**
  - Stablecoin flight-to-quality during SVB crisis parallels money market fund runs
  - URL: https://www.newyorkfed.org/medialibrary/media/research/staff_reports/sr1073.pdf

### Stablecoin Depegging Research

- **"Stablecoin depegging risk prediction"** (ScienceDirect, 2024)
  - ML models predict depegging from on-chain data
  - URL: https://www.sciencedirect.com/science/article/abs/pii/S0927538X24003925

- **"Stablecoin devaluation risk"** (2025)
  - USDC sensitive to SOFR; Tether to broader macro indicators
  - URL: https://www.tandfonline.com/doi/full/10.1080/1351847X.2025.2505757

- **NBER Working Paper 34475, "Stablecoins"**
  - URL: https://www.nber.org/system/files/working_papers/w34475/w34475.pdf

**Gap in Cluster 3**: Uses aggregate stablecoin flow data. None uses CFMM pool-level primitives (TWAP, fees, liquidity distribution) as the signal source.

---

## The Shiller Bridge

- **Shiller (1993), "Aggregate Income Risks and Hedging Mechanisms"**
  - NBER WP 4396
  - Original proposal for perpetual claims on national income indices
  - PDF saved: refs/macro-risk/shiller-aggregate-income-risks-hedging-1993.pdf

- **He, Manela, Ross (2022), "Fundamentals of Perpetual Futures"**
  - arxiv:2212.06888
  - Formalizes perp futures mathematically, connecting Shiller's vision to modern DeFi perps

- **Athanasoulis & Shiller (1999), "Macro Markets and Financial Security"**
  - NY Fed Economic Policy Review
  - The policy case for macro markets
  - URL: https://www.newyorkfed.org/medialibrary/media/research/epr/99v05n1/9904atha.pdf

---

## The Novel Contribution of This Project

```
Cluster 1: CFMM = reliable price oracle          (Angeris 2020)
Cluster 2: LP income/IL = information signal      (BIS 2024, LVR 2022)
Cluster 3: Stablecoin flows = macro indicator     (IMF 2025-2026)

THIS PROJECT: CFMM pool primitives ON EM stablecoin pairs
              = real-time macro oracles
              → settlement layer for Shiller-type claims
```

No existing paper bridges these three clusters. The IMF work uses aggregate flow data. The CFMM literature focuses on microstructure. The Shiller framework provides the economic motivation. This project operationalizes the bridge.

---

## Additional References (Market Microstructure)

- Kyle (1985), "Continuous Auctions and Insider Trading" — price impact coefficient (lambda)
- Glosten & Milgrom (1985), "Bid, Ask and Transaction Prices" — adverse selection and spreads
- Easley & O'Hara (1992), "Time and the Process of Security Price Adjustment" — trade intensity carries information
- Diamond & Dybvig (1983), "Bank Runs, Deposit Insurance, and Liquidity" — run dynamics applied to currency
- Kaminsky, Lizondo, Reinhart (1998), "Leading Indicators of Currency Crises" — KLR framework, FX vol as crisis signal
- Kiguel & O'Connell (1995), "Parallel Exchange Rates in Developing Countries" — parallel market premium as macro indicator
- Reinhart & Rogoff (2004), "The Modern History of Exchange Rate Arrangements" — premium predicts official devaluation
- Lambert (2021), "On-Chain Volatility and Uniswap v3" — fee-vol relationship

## Additional References (OECD / Institutional)

- OECD (2024), "Concentration of DeFi's Liquidity" — concentration risks in AMM markets
  - URL: https://www.oecd.org/content/dam/oecd/en/publications/reports/2024/04/concentration-of-defi-s-liquidity_5df1e8f9/4ed08440-en.pdf
