- [CHAPTER 3-> Settlements Based On Measures of INcome Rtaher than Price (Pg 38 (56/280))](https://archive.org/details/macromarketscrea0000shil/page/30/mode/2up)

-[RESEARCH ON PERPETUAL FUTUREES ORACLE INTEGRATIONS]()

## Comparison Summary

Here's where the four protocols land for your remittance hedging use case:

### Pairs That Matter

| Protocol | FX Pairs | EM FX Live | NGN/PHP/KES | Pair Listing |
|---|---|---|---|---|
| **Ostium** | 10-12+ | **USD/MXN, USD/BRL live** | Referenced, unverified | Governance |
| **Gains (gTrade)** | G10 only live | MXN/BRL/INR registered but **inactive** | None | Governance |
| **Synthetix v3** | EUR, GBP, AUD only | None | None | Governance (permissionless on roadmap June 2026) |
| **GMX v2** | **None** — crypto only | None | None | Governance |

### Forkability & Open Source

| Protocol | License | Current Code Open? | Fork Viable? |
|---|---|---|---|
| **Synthetix v3** | **MIT** | Yes, full production code + tests + deploy tooling | **Best fork candidate** |
| **Ostium** | Source-available | Partial (contracts public, oracle infra proprietary) | Moderate — oracle is the hard part |
| **Gains** | MIT (v6 only) | **v8/v9/v10 NOT open** — only obsolete v6 | **No** — current architecture is closed |
| **GMX v2** | BUSL-1.1 → GPL Aug 2026 | Readable but not forkable until Aug 2026 | Not yet |

### TVL & Liquidity

| Protocol | TVL | Daily Volume | OI |
|---|---|---|---|
| **GMX v2** | ~$263M | Highest crypto perp volume | Crypto-deep |
| **Ostium** | $56.6M | ~$100-180M/day | $162M, **95%+ in RWA/FX** |
| **Synthetix v3** | Moderate | Growing on Base | Moderate |
| **Gains** | ~$50M+ | $100B+ lifetime | Spread thin across 290+ pairs |

### Verdict

**Ostium is the closest to what you need today** — live EM FX pairs (MXN, BRL), RWA-first focus, institutional backing ($27.8M, General Catalyst + Jump Crypto), and Python/Rust SDKs. The binding constraint is whether NGN/PHP can be added.

**Synthetix v3 is the best fork candidate** — MIT license, full production code open, modular oracle (Pyth). But no EM FX pairs live yet, and the real bottleneck across ALL protocols is the **oracle layer for frontier currencies** (NGN, KES, PHP). You'd need DIA, a custom oracle network, or Mento on-chain rates regardless of which DEX you pick.

Reports saved to `refs/deep-dive-{synthetix-v3,gmx-v2,ostium,gains-network}.md`.
