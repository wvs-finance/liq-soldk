# Angstrom Pair Types Research

## Executive Summary

Angstrom (by Sorella Labs) is a Uniswap V4 hook-based DEX that does **not** introduce a
semantically labeled pair type (i.e., no base/quote, numeraire/volatile, or risky/stable
distinction at the type level). Instead, it uses:

1. **`type Pair is uint256`** -- a user-defined value type (UDVT) wrapping a packed uint256
   that stores a `storeIndex` and references to `asset0`/`asset1`.
2. **`type ConfigEntry is uint256`** -- a UDVT that packs pool parameters like `tickSpacing`
   and `bundleFee` into a single word.
3. **Uniswap V4's `PoolKey`** -- uses the standard `currency0`/`currency1` convention (sorted
   by address) with no semantic role assignment.

Token positions in Angstrom pairs follow the Uniswap convention: **lower address = asset0 /
currency0, higher address = asset1 / currency1**. There is no type-level distinction between
"risky" and "stable" or "base" and "quote" assets.

---

## Detailed Findings

### 1. Repository Structure

**Repository:** [SorellaLabs/angstrom](https://github.com/SorellaLabs/angstrom)
**Deployed Contract:** [0x0000000aa232009084bd71a5797d089aa4edfad4](https://etherscan.io/address/0x0000000aa232009084bd71a5797d089aa4edfad4) (Etherscan-verified)

Key files in the Solidity contracts:

| File Path | Purpose |
|---|---|
| `contracts/src/types/Pair.sol` | Defines `type Pair is uint256`, `PairArray`, and `PairLib` |
| `contracts/src/types/ConfigEntry.sol` | Defines `type ConfigEntry is uint256` and `ConfigEntryLib` |
| `contracts/src/types/Asset.sol` | Defines `type Asset is ...`, `AssetArray`, and `AssetLib` |
| `contracts/src/libraries/PoolConfigStore.sol` | Defines `PoolConfigStore`, `PoolConfigStoreLib`, `StoreKey`, `ConfigBuffer` |
| `contracts/src/_reference/SignedTypes.sol` | Reference structs for order types (user-facing) |
| `contracts/docs/overview.md` | Architecture documentation |

### 2. The `Pair` Type (UDVT)

```
type Pair is uint256
```

This is a Solidity user-defined value type wrapping `uint256`. The `PairLib` library provides
methods to decode the packed data:

- **`PairLib.readFromAndValidate()`** -- reads pair data from calldata and validates it
- **`PairLib.len()`** -- returns number of pairs
- **`PairLib.get(pairIndex)`** -- retrieves a pair by index (used as `pairs.get(pairIndex)`)
- **`PairLib.getPoolInfo()`** -- returns pool configuration for the pair
- **`PairLib.getAssets()`** -- extracts the two asset addresses from the pair
- **`PairLib.getSwapInfo()`** -- returns swap-related parameters

The `Pair` type packs:
- A **store index** (`storeIndex`) pointing into the PoolConfigStore
- References to **asset0** and **asset1** (the two token addresses in the pair)

Usage in bundle execution:
```
uint16 pairIndex = ...; // read from calldata
pairs.get(pairIndex).getPoolInfo(...)
```

**Key observation:** The naming `asset0` / `asset1` follows the Uniswap convention of
address-sorted tokens. There is no semantic label (base, quote, numeraire, volatile, risky,
stable) attached at the type level.

### 3. The `ConfigEntry` Type (UDVT)

```
type ConfigEntry is uint256
```

Packed into a single uint256 word. `ConfigEntryLib` provides:

- **`ConfigEntryLib.init(key, tickSpacing, bundleFee)`** -- creates a new config entry
- **`setTickSpacing(tickSpacing)`** -- modifies tick spacing
- **`setBundleFee(bundleFee)`** -- modifies bundle fee

Config entries track:
- `tickSpacing` (int24) -- the Uniswap V4 tick spacing for the pool
- `bundleFee` -- fee charged on order bundles
- `feeInE6` -- fee expressed in parts per million
- `maxExtraF` -- maximum extra fee

### 4. The PoolConfigStore

The Angstrom contract uses the **SSTORE2 ("code as storage") pattern** to store pool
configuration. Rather than using `mapping(bytes32 => ...)`, config entries are stored as a
packed list in contract bytecode.

From the overview.md:
> "To save gas on batched reads, the 'code as storage' (SSTORE2) pattern is employed, storing
> data as a list in the form of contract bytecode instead of using a normal mapping to keep
> track of enabled pools and their parameters."

Key types in the library:
- `PoolConfigStore` -- the main storage type
- `PoolConfigStoreLib` -- library with read/write methods
- `StoreKey` -- key used to look up entries
- `ConfigBuffer` -- mutable buffer for searching/modifying entries

The `configurePool` function takes parameters including:
- Two token addresses (asset0, asset1 -- address-sorted)
- `tickSpacing`
- `bundleFee`
- `controller` (the authorized node/validator)

### 5. The `Asset` Type

Defined in `contracts/src/types/Asset.sol`:
- `type Asset is ...` (likely uint256 or address-based UDVT)
- `AssetArray` -- array wrapper type
- `AssetLib` -- library with asset manipulation functions

Assets represent individual token positions within the Angstrom system. The `AssetArray` is
used alongside `PairArray` in bundle execution to track token deltas.

### 6. Order Types (SignedTypes.sol)

User orders are defined in `contracts/src/_reference/SignedTypes.sol`. Key order types include:

- **`TopOfBlockOrder`** -- used by arbitrageurs in the per-block English auction
- **`ExactStandingOrder`** -- persistent limit orders with exact amounts
- **`ExactFlashOrder`** -- one-shot exact orders
- **`PartialStandingOrder`** -- persistent orders allowing partial fills
- **`PartialFlashOrder`** -- one-shot orders allowing partial fills

Order structs reference tokens via:
- **`assetIn`** -- the token being sold/spent
- **`assetOut`** -- the token being bought/received

This is a **directional** labeling (input/output) rather than a role-based one (base/quote).
The `buffer.assetIn` and `buffer.assetOut` fields appear in order validation and execution code.

### 7. Relationship to Uniswap V4 PoolKey

Angstrom wraps Uniswap V4 pools. The standard Uniswap V4 `PoolKey` struct is:

```solidity
struct PoolKey {
    Currency currency0;    // lower address
    Currency currency1;    // higher address
    uint24 fee;
    int24 tickSpacing;
    IHooks hooks;          // = Angstrom hook address
}
```

Angstrom's `Pair` type maps to a `PoolKey` where:
- `currency0` = asset0 (lower address token)
- `currency1` = asset1 (higher address token)
- `hooks` = the Angstrom hook contract
- `tickSpacing` and `fee` come from the `ConfigEntry`

### 8. Fee Charging Convention

From the documentation:
> "The total gas fee + referral fee is called the 'extra fee' and is charged in the respective
> **asset0** of the pair."

This is notable -- the extra fee is always denominated in `asset0` (the lower-address token).
This does introduce a mild asymmetry between the two assets in a pair, but it is
address-based, not semantic.

---

## Analysis: Does Angstrom Distinguish Token Roles?

### What Angstrom Does NOT Have

- No `base` / `quote` labeling
- No `numeraire` / `volatile` distinction
- No `risky` / `stable` semantic type
- No enum like `TokenRole { Base, Quote }` or `AssetType { Stable, Volatile }`
- No struct field that identifies which token in a pair is the "reference" asset

### What Angstrom Does Have

1. **Address-sorted ordering:** `asset0` < `asset1` by address (standard Uniswap convention)
2. **Directional order fields:** `assetIn` / `assetOut` on orders (swap direction, not role)
3. **Fee asymmetry:** Extra fees charged in `asset0` specifically
4. **Pair indexing:** `uint16 pairIndex` used to reference pairs in calldata bundles
5. **Packed UDVT types:** `Pair` and `ConfigEntry` as gas-optimized uint256 wrappers

### Implications for Our Project

If we want to build a pair type that semantically labels tokens (e.g., for LP hedging where
we need to know which asset is the "risky" one vs. the "numeraire"), Angstrom does not provide
a precedent for this. The Angstrom type system is optimized purely for gas efficiency and
execution correctness, not for expressing economic role semantics.

The closest pattern Angstrom offers is the `assetIn` / `assetOut` directional labeling on
orders, which is relevant for swap execution but does not capture the static role of a token
within a trading pair.

---

## Key File Paths

| File | Description |
|---|---|
| `contracts/src/types/Pair.sol` | `type Pair is uint256`, `PairLib`, `PairArray` |
| `contracts/src/types/ConfigEntry.sol` | `type ConfigEntry is uint256`, `ConfigEntryLib`, `ONE_E6` |
| `contracts/src/types/Asset.sol` | `type Asset`, `AssetLib`, `AssetArray` |
| `contracts/src/libraries/PoolConfigStore.sol` | `PoolConfigStore`, `PoolConfigStoreLib`, `StoreKey`, `ConfigBuffer` |
| `contracts/src/_reference/SignedTypes.sol` | Order structs with `assetIn`/`assetOut` fields |
| `contracts/docs/overview.md` | Architecture documentation |
| `crates/uniswap-v4/src/uniswap/pool_factory.rs` | Rust-side pool factory with V4 integration |

---

## Sources

- [SorellaLabs/angstrom GitHub Repository](https://github.com/SorellaLabs/angstrom)
- [Angstrom Overview Documentation](https://github.com/SorellaLabs/angstrom/blob/main/contracts/docs/overview.md)
- [Angstrom Hook on Etherscan](https://etherscan.io/address/0x0000000aa232009084bd71a5797d089aa4edfad4)
- [Angstrom on Codeslaw](https://www.codeslaw.app/contracts/ethereum/0x0000000aa232009084bd71a5797d089aa4edfad4?tab=dependencies)
- [Cantina Security Competition](https://cantina.xyz/competitions/84df57a3-0526-49b8-a7c5-334888f43940)
- [Cantina Security Audit Report](https://cantina.xyz/portfolio/c2fe4e46-66a3-416e-ab26-40dd4b437ff6)
- [Angstrom Official Docs](https://docs.angstrom.xyz/)
- [Introducing Angstrom (Mirror blog)](https://mirror.xyz/0x1b6Fc245e8e067060b982094E9a8bbaF1D199497/rvV1Ln7_NtWl3hEmZzWORFHVvg7qCYgdFk1lnFPZ6rE)
- [A New Era of DeFi with ASS (Sorella blog)](https://sorellalabs.xyz/writing/a-new-era-of-defi-with-ass)
- [Uniswap V4 PoolKey.sol](https://github.com/Uniswap/v4-core/blob/main/src/types/PoolKey.sol)
- [Angstrom Pools App](https://app.angstrom.xyz/pools)
