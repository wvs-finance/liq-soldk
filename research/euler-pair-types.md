# Euler Finance: Token Pair Type System and Base/Quote Distinction

## Executive Summary

Euler V2 (the Euler Vault Kit / EVK) does **not** use a single unified struct like `PairConfig` or `TokenPair` to label tokens as "numeraire vs volatile" or "base vs quote." Instead, the distinction emerges from a **layered architecture** across three repositories:

1. **euler-vault-kit** -- Each vault stores an immutable `unitOfAccount` address at deployment. This is the "numeraire" or "quote" reference asset. The vault's underlying asset is implicitly the "risky" or "base" asset.
2. **euler-price-oracle** -- The `IPriceOracle` interface uses explicit `base` and `quote` parameters on every call. The `EulerRouter` sorts pairs before storage to be direction-agnostic.
3. **evk-periphery** / **euler-swap** -- Lens contracts expose structs with fields like `collateralValue` and `liabilityValue`. EulerSwap uses `asset0`/`asset1` and `vault0`/`vault1` naming.

There is **no enum like `Role.NUMERAIRE` or `Role.VOLATILE`**. The role assignment is implicit: the vault's `unitOfAccount` is the numeraire; everything else is priced relative to it.

---

## Detailed Findings

### 1. euler-vault-kit: The `unitOfAccount` Immutable

**Repository:** `euler-xyz/euler-vault-kit`
**Key files:**
- `src/EVault/IEVault.sol` (interface)
- `src/EVault/shared/Base.sol` (storage/immutable declarations)
- `src/EVault/modules/Liquidation.sol` (oracle usage)
- `src/EVault/modules/RiskManager.sol` (liquidity checks)

#### How it works

Each EVault proxy stores three critical immutable values at deployment time via `GenericFactory.createProxy()`:

- **`asset`** -- The underlying ERC-20 token the vault holds (the "risky" asset from a pricing perspective)
- **`oracle`** -- The IPriceOracle address used for pricing
- **`unitOfAccount`** -- The reference asset address for all value computations (the "numeraire")

The `unitOfAccount` is **immutable after deployment** -- it cannot be changed, even by the vault governor. This is a deliberate security decision.

#### IEVault Interface

The IEVault interface exposes:

```solidity
function unitOfAccount() external view returns (address);
```

This returns the address of the reference asset. It can be:
- A real ERC-20 token address (e.g., WETH, USDC)
- An ISO 4217 currency code cast to an address (e.g., `address(840)` = `0x0000000000000000000000000000000000000348` for USD)

#### Oracle Calls in Liquidation

In `Liquidation.sol`, the oracle is called as:

```solidity
vaultCache.oracle.getQuote(collateralBalance, liqCache.collateral, vaultCache.unitOfAccount)
```

Here:
- `base` = the collateral asset (the token being priced)
- `quote` = the vault's `unitOfAccount` (the numeraire everything is measured in)

For liability valuation, similarly:
- `base` = the vault's own underlying asset
- `quote` = the vault's `unitOfAccount`

#### Bid/Ask Pricing

For new loan origination (checkLiquidity), the system uses `getQuotes()` which returns both `bidOutAmount` and `askOutAmount`:
- **Bid** prices are used for collateral estimation (conservative: what you could actually sell for)
- **Ask** prices are used for liability estimation (conservative: what you would actually have to pay)
- **Mid-point** (via `getQuote()`) is used for liquidation calculations to avoid liquidations triggered by temporarily-wide spreads

#### Custom Value Types

The vault kit defines custom Solidity types for internal accounting, but these are for amount precision, not token role labeling:
- `AmountCap` -- 16-bit decimal floating point for supply/borrow caps
- `ConfigAmount` -- uint16 encoding a `[0..1]` fraction scaled by 10,000 (used for LTV ratios)
- Various wrapped integer types to catch conversion bugs at the compiler level

---

### 2. euler-price-oracle: The `IPriceOracle` Interface (ERC-7726)

**Repository:** `euler-xyz/euler-price-oracle`
**Key files:**
- `src/interfaces/IPriceOracle.sol` (the core interface)
- `src/EulerRouter.sol` (dispatcher/router)
- `src/adapter/uniswap/UniswapV3Oracle.sol` (Uniswap TWAP adapter)
- Various adapters in `src/adapter/`

#### IPriceOracle Interface (ERC-7726 Compatible)

```solidity
interface IPriceOracle {
    function getQuote(
        uint256 inAmount,
        address base,
        address quote
    ) external view returns (uint256 outAmount);

    function getQuotes(
        uint256 inAmount,
        address base,
        address quote
    ) external view returns (uint256 bidOutAmount, uint256 askOutAmount);
}
```

This is the reference implementation for the "Common Quote Oracle" defined in **ERC-7726**. Key design decisions:

- **Quote-based, not price-based**: Instead of returning a price ratio, it returns the equivalent amount. This handles decimal precision internally and reduces precision loss in extreme cases.
- **Both directions supported**: Adapters can handle both `base/quote` and `quote/base` queries.
- **No implicit token ordering**: The caller explicitly specifies which token is `base` and which is `quote`.

#### EulerRouter: Pair-to-Oracle Mapping

The EulerRouter is a dispatcher contract that maintains a mapping from token pairs to oracle adapters.

**Critical implementation detail -- pair sorting:**

```solidity
// In govSetConfig:
(address asset0, address asset1) = _sort(base, quote);
oracles[asset0][asset1] = oracle;
```

The router **sorts** the two asset addresses before storing the oracle configuration. This means:
- A single mapping entry covers both `A/B` and `B/A` queries
- The `_resolveOracle()` function also sorts internally before lookup
- `getConfiguredOracle()` performs this sorting to expose the correct oracle

This was introduced as a fix after an Omniscia audit finding (EulerRouter-ERR) that identified incorrect oracle path resolution.

**Resolution algorithm** (when `getQuote`/`getQuotes` is called):
1. If `base == quote`, return `inAmount` directly
2. If `base` is a configured ERC-4626 vault, convert shares to assets via `convertToAssets()`, then re-resolve
3. Look up the sorted pair in the `oracles` mapping
4. If found, delegate to the configured adapter
5. If not found, try the `fallbackOracle`

#### UniswapV3Oracle Adapter

**File:** `src/adapter/uniswap/UniswapV3Oracle.sol`

Constructor parameters:
```solidity
constructor(
    address _tokenA,
    address _tokenB,
    uint24 _fee,
    uint32 _twapWindow,
    address _uniswapV3Factory
)
```

- Uses `tokenA` and `tokenB` (not `token0`/`token1` -- the adapter handles the Uniswap pool's internal ordering)
- Stores these as immutables along with the resolved `pool` address
- Supports pricing in both directions: `tokenA/tokenB` and `tokenB/tokenA`
- The `twapWindow` defines the TWAP observation period

**No base/quote distinction at the adapter level** -- the adapter is symmetric. Direction is determined by the caller (the EulerRouter or vault).

#### Other Adapters

Similar patterns exist for:
- `LidoOracle` (wstETH/stETH)
- `RateProviderOracle` (generic rate providers)
- `PendleOracle` (Pendle PT/YT)

All implement the same `IPriceOracle` interface with `base`/`quote` parameters.

---

### 3. evk-periphery: Lens Structs

**Repository:** `euler-xyz/evk-periphery`
**Key file:** `src/LensTypes.sol` (all struct definitions)

The periphery provides read-only lens contracts for querying vault state. Key structs include:

#### VaultInfoFull

Returned by `VaultLens.getVaultInfoFull(vault)`. Contains comprehensive vault configuration including the `unitOfAccount` and `oracle` addresses, along with all governor-configured parameters.

#### VaultAccountInfo / LiquidityInfo

Contains account-level information including:
- `collateralValueBorrowing` -- collateral value for borrowing LTV checks
- `collateralValueLiquidation` -- collateral value for liquidation LTV checks (uses mid-point pricing)
- `liabilityValue` -- the debt value in `unitOfAccount` terms

These values are **already denominated in the vault's `unitOfAccount`** -- the oracle conversion has already been applied.

---

### 4. euler-swap: EulerSwap AMM

**Repository:** `euler-xyz/euler-swap`
**Key file:** `src/IEulerSwap.sol` (interface with struct definitions)

EulerSwap uses a different naming convention:

#### InitialState Struct

Contains `reserve0`, `reserve1` fields (Uniswap V2-style naming). The struct is used when activating a new swap pair.

**Notable:** EulerSwap intentionally omits `token0()` and `token1()` public getters that Uniswap V2 pairs expose. This breaks compatibility with some flash swap routers and arbitrage bots that assume Uniswap V2 pair behavior.

The swap pairs reference EVK vaults (`vault0`, `vault1`) rather than raw token addresses, integrating the swap functionality with the lending infrastructure.

---

### 5. Euler Vault Scripts: Cluster Configuration

**Repository:** `euler-xyz/euler-vault-scripts`

When deploying a "cluster" (a collection of vaults that accept each other as collateral), the configuration specifies:

- **Unit of account** for the cluster (e.g., USD via `address(840)`)
- **Oracle router** address and governor
- **Per-vault settings**: underlying asset, borrowing LTV, liquidation LTV, supply/borrow caps
- **Collateral relationships**: which vaults accept which other vaults as collateral

The unit of account is set once at cluster creation and applies uniformly to all vaults in the cluster.

---

## How Euler Identifies "Unit of Account" vs "Risky Asset"

The architecture makes this distinction through **structural position** rather than explicit labeling:

| Concept | Euler V2 Implementation |
|---------|------------------------|
| Numeraire / Quote / Unit of Account | `vault.unitOfAccount()` -- immutable address set at deployment |
| Risky / Base / Underlying | `vault.asset()` -- the ERC-20 token the vault holds |
| Collateral asset | Another vault's `asset()`, priced via `oracle.getQuote(balance, collateralAsset, unitOfAccount)` |
| Liability asset | This vault's `asset()`, priced via `oracle.getQuote(debt, asset, unitOfAccount)` |
| Price direction | Always: `getQuote(amount, base=theAsset, quote=unitOfAccount)` |

The oracle always prices **FROM** the risky asset **TO** the unit of account. The `base` parameter is always the thing being valued; the `quote` parameter is always the unit of measurement.

---

## Key Takeaways for Our Design

1. **No explicit token role enum exists in Euler.** The "numeraire vs volatile" distinction is encoded by the vault's `unitOfAccount` immutable. If you want to know which token is the numeraire, you read `vault.unitOfAccount()`.

2. **The oracle interface is direction-explicit.** Every `getQuote`/`getQuotes` call specifies `base` and `quote` as addresses. The EulerRouter sorts pairs internally for storage but preserves directionality at the interface level.

3. **The unit of account can be a virtual asset.** Using ISO 4217 codes (e.g., USD = `address(840)`) means the unit of account does not need to be an actual on-chain token. The oracle chain must resolve down to this virtual asset.

4. **Pair configuration lives in the EulerRouter**, not in individual vaults. The router maps `(sorted_asset0, sorted_asset1) => oracle_adapter`. One oracle adapter serves both price directions for a pair.

5. **Bid/ask separation is a first-class concept.** The `getQuotes()` function returning both `bidOutAmount` and `askOutAmount` enables conservative valuation: bid for collateral, ask for liability, midpoint for liquidation.

---

## Source References

- [euler-xyz/euler-vault-kit](https://github.com/euler-xyz/euler-vault-kit) -- `src/EVault/IEVault.sol`, `src/EVault/shared/Base.sol`, `src/EVault/modules/Liquidation.sol`
- [euler-xyz/euler-price-oracle](https://github.com/euler-xyz/euler-price-oracle) -- `src/interfaces/IPriceOracle.sol`, `src/EulerRouter.sol`, `src/adapter/uniswap/UniswapV3Oracle.sol`
- [euler-xyz/evk-periphery](https://github.com/euler-xyz/evk-periphery) -- `src/LensTypes.sol`
- [euler-xyz/euler-swap](https://github.com/euler-xyz/euler-swap) -- `src/IEulerSwap.sol`
- [Euler Price Oracle Whitepaper](https://github.com/euler-xyz/euler-price-oracle/blob/master/docs/whitepaper.md)
- [Euler Vault Kit Whitepaper](https://github.com/euler-xyz/euler-vault-kit/blob/master/docs/whitepaper.md)
- [Euler Vault Kit Specs](https://github.com/euler-xyz/euler-vault-kit/blob/master/docs/specs.md)
- [IPriceOracle Docs](https://docs.euler.finance/developers/oracle/ipriceOracle/)
- [Omniscia EulerRouter Audit](https://omniscia.io/reports/euler-finance-evk-price-oracles-660812035fc1c30018641b22/manual-review/EulerRouter-ERR/)
- [OpenZeppelin EVK Audit](https://www.openzeppelin.com/news/euler-vault-kit-evk-audit)
- [MixBytes Euler V2 Analysis](https://mixbytes.io/blog/modern-defi-lending-protocols-how-its-made-euler-v2)
- [Certora Formal Verification Fork](https://github.com/Certora/euler-vault-cantina-fv/blob/master/src/EVault/modules/Liquidation.sol)
