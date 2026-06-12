// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

import {Strikes, strike} from "./Strikes.sol";

// ─── Rick: a single rounded tick (floor to tickSpacing grid) ───

type Rick is int24;

using {unwrap} for Rick global;

/// @notice Round a tick toward -infinity to the nearest tickSpacing boundary.
function toRick(int24 currentTick, int24 tickSpacing) pure returns (Rick) {
    int24 compressed = currentTick / tickSpacing;
    if (currentTick < 0 && currentTick % tickSpacing != 0) compressed--;
    return Rick.wrap(compressed * tickSpacing);
}

function unwrap(Rick r) pure returns (int24) {
    return Rick.unwrap(r);
}

// ─── Ricks: 4 signed distances x_i packed into bytes12 ───
//
//   x_i = (strike_i - roundedCurrentTick) / tickSpacing
//
// These update on every price move; the strikes themselves are fixed.

type Ricks is bytes12;

using {rick} for Ricks global;

/// @notice Compute signed tick-spacing distances from each strike to the rounded current tick.
function toRicks(Strikes strikes, int24 currentTick, int24 tickSpacing) pure returns (Ricks packed) {
    int24 rounded = Rick.unwrap(toRick(currentTick, tickSpacing));

    int24 x0 = (strikes.strike(0) - rounded) / tickSpacing;
    int24 x1 = (strikes.strike(1) - rounded) / tickSpacing;
    int24 x2 = (strikes.strike(2) - rounded) / tickSpacing;
    int24 x3 = (strikes.strike(3) - rounded) / tickSpacing;

    assembly {
        packed := or(
            or(shl(232, and(x0, 0xFFFFFF)), shl(208, and(x1, 0xFFFFFF))),
            or(shl(184, and(x2, 0xFFFFFF)), shl(160, and(x3, 0xFFFFFF)))
        )
    }
}

/// @notice Extract the i-th distance (0 <= i <= 3).
function rick(Ricks packed, uint256 i) pure returns (int24 x) {
    assembly {
        x := signextend(2, shr(sub(232, mul(i, 24)), packed))
    }
}
