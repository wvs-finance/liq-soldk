// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;


type Strikes is bytes12;

using {strike, distances} for Strikes global;

/// @dev strike_k = tickLower + (k * n / 5) * tickSpacing,  k in {1,2,3,4}
function wrap(int24 tickLower, int24 tickUpper, uint24 tickSpacing) pure returns (Strikes packed) {
    uint256 n = uint256(int256(tickUpper - tickLower)) / uint256(tickSpacing);

    int24 ts = int24(tickSpacing);
    int24 s0 = tickLower + int24(uint24(n / 5)) * ts;
    int24 s1 = tickLower + int24(uint24(2 * n / 5)) * ts;
    int24 s2 = tickLower + int24(uint24(3 * n / 5)) * ts;
    int24 s3 = tickLower + int24(uint24(4 * n / 5)) * ts;

    assembly {
        packed := or(
            or(shl(232, and(s0, 0xFFFFFF)), shl(208, and(s1, 0xFFFFFF))),
            or(shl(184, and(s2, 0xFFFFFF)), shl(160, and(s3, 0xFFFFFF)))
        )
    }
}

/// @notice Extract the i-th strike (0 <= i <= 3).
function strike(Strikes packed, uint256 i) pure returns (int24 s) {
    assembly {
        s := signextend(2, shr(sub(232, mul(i, 24)), packed))
    }
}

/// @notice x_i = (strike_i - currentTick) / tickSpacing for all 4 strikes.
function distances(Strikes packed, int24 currentTick, int24 tickSpacing)
    pure
    returns (int24 x0, int24 x1, int24 x2, int24 x3)
{
    x0 = (packed.strike(0) - currentTick) / tickSpacing;
    x1 = (packed.strike(1) - currentTick) / tickSpacing;
    x2 = (packed.strike(2) - currentTick) / tickSpacing;
    x3 = (packed.strike(3) - currentTick) / tickSpacing;
}

/**********************************************************************************************************************************************************************************************************************************************/
/* The strikes are the **fixed grid** derived from the LP position being hedged. They don't move with price.																      */
/* 																													      */
/* ```																													      */
/* LP position: [tickLower, tickUpper]																									      */
/* n = (tickUpper - tickLower) / tickSpacing    (total rounded ticks)																					      */
/* 																													      */
/* 4 evenly spaced strikes within the LP range:																								      */
/* 																													      */
/* strike_0 = tickLower + (1 · n/5) · tickSpacing																							      */
/* strike_1 = tickLower + (2 · n/5) · tickSpacing																							      */
/* strike_2 = tickLower + (3 · n/5) · tickSpacing																							      */
/* strike_3 = tickLower + (4 · n/5) · tickSpacing																							      */
/* ```																													      */
/* 																													      */
/* They're set once when the LP position is created. What changes on each price update is:																		      */
/* 																													      */
/* | Fixed at LP creation | Updates on price move |																							      */
/* |---|---|																												      */
/* | `strike[4]` — where the legs are | `positionSize` — how much hedge (from IL oracle) |																		      */
/* | `width` per leg | `optionRatio[4]` — how weight distributes (from α^x distance) |																			      */
/* | `tokenType` — calls vs puts | `x_i = (strike_i - newTick) / ts` — distance recalculation |																		      */
/* 																													      */
/* The strikes are the quadrature points of the Prop 3.5 integral. The integral bounds `[P_l, P_u]` are your LP range — those don't change. What changes is the **integrand** (the IL magnitude and the weighting relative to current price). */
/**********************************************************************************************************************************************************************************************************************************************/
