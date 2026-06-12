
// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.26;

// --- typed-uniswap-v4 ---
import {TickRange} from "@typed-v4/types/TickRangeV2Mod.sol";
import {PRECISION_FLAG, toBool} from "@typed-v4/libraries/PrecisionLib.sol";
import {
    sortSqrtPriceX96Range,
    inRange,
    fromRayToSqrtPriceX96,
    fromWadToSqrtPriceX96,
    divX96
} from "@typed-v4/libraries/SqrtPriceX96Lib.sol";
import {fromTickRangeToSqrtPriceX96Range} from "@typed-v4/libraries/TickRangeSqrtPriceX96Lib.sol";

// --- panoptic ---
import {Math as PanopticMath} from "@libraries/Math.sol";
import {LeftRightSigned, LeftRightUnsigned} from "@types/LeftRight.sol";

// --- math ---
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";


// right slot (low 128 bits)  = token0 amounts  <-> UIL^R (call-replicable)
// left slot  (high 128 bits) = token1 amounts  <-> UIL^L (put-replicable)


// Deng-Zong-Wang (2022), Eq. 2 — Right-side IL per liquidity:
//
//   IL^R/dL = (2*sqrt(Pt) - Pt/sqrt(Pl) - sqrt(Pl)) * 1_{Pl <= Pt <= Pu}
//           + (sqrt(Pu) - sqrt(Pl) - (1/sqrt(Pl) - 1/sqrt(Pu))*Pt) * 1_{Pt >= Pu}
//
// In range: rightIL = 2*sqrt(P) - P/sqrt(Pl) - sqrt(Pl)
// Above range: rightIL = spread - P*spread/(sqrt(Pl)*sqrt(Pu))
// Below range (Pt < Pl): IL^R = 0.
function rightIlXLiq(
    uint160 refSqrtPriceX96,
    uint160 sqrtPriceLowX96,
    uint160 sqrtPriceUpX96
) pure returns (int256) {
    (uint160 _low, uint160 _up) = sortSqrtPriceX96Range(sqrtPriceLowX96, sqrtPriceUpX96);

    if (inRange(refSqrtPriceX96, _low, _up)) {
        uint256 twoSqrtPX96 = uint256(refSqrtPriceX96) << 1;

        // P_t / sqrt(P_l) in X96
        uint256 ratioX96 = divX96(refSqrtPriceX96, _low);
        uint256 ptOverSqrtPlX96 = FixedPointMathLib.fullMulDiv(
            uint256(refSqrtPriceX96), ratioX96, 1 << 96
        );

        // rightIL_X96 = 2*sqrt(P_t) - P_t/sqrt(P_l) - sqrt(P_l)
        return int256(twoSqrtPX96) - int256(ptOverSqrtPlX96) - int256(uint256(_low));

    } else if (refSqrtPriceX96 >= _up) {
        // Above range: rightIL = spread - P*spread/(sqrt(Pl)*sqrt(Pu))
        // Split: step1 = sqrt(P)*(sqrt(Pu)-sqrt(Pl))/sqrt(Pl)
        //        val   = step1 * sqrt(P) / sqrt(Pu)
        uint256 spreadX96 = uint256(_up) - uint256(_low);

        uint256 step1X96 = FixedPointMathLib.fullMulDiv(
            uint256(refSqrtPriceX96), spreadX96, uint256(_low)
        );
        uint256 valX96 = FixedPointMathLib.fullMulDiv(
            step1X96, uint256(refSqrtPriceX96), uint256(_up)
        );

        return int256(spreadX96) - int256(valX96);
    }

    return int256(0);
}

// Deng-Zong-Wang (2022), Eq. 3 — Left-side IL per liquidity:
//
//   IL^L/dL = (2*sqrt(Pt) - Pt/sqrt(Su) - sqrt(Su)) * 1_{Sl <= Pt <= Su}
//           + ((1/sqrt(Sl) - 1/sqrt(Su))*Pt - sqrt(Su) + sqrt(Sl)) * 1_{Pt <= Sl}
//
// where [Sl, Su] = [Pl, Pu] (same range for p2-CLAMM).
// In range: leftIL = 2*sqrt(P) - P/sqrt(Pu) - sqrt(Pu)
// Below range (Pt < Pl): leftIL = P*spread/(sqrt(Pl)*sqrt(Pu)) - spread
// Above range (Pt > Pu): IL^L = 0.
function leftIlXLiq(
    uint160 refSqrtPriceX96,
    uint160 sqrtPriceLowX96,
    uint160 sqrtPriceUpX96
) pure returns (int256 leftIlX96) {
    (uint160 _low, uint160 _up) = sortSqrtPriceX96Range(sqrtPriceLowX96, sqrtPriceUpX96);

    if (inRange(refSqrtPriceX96, _low, _up)) {
        // Pt/sqrt(Pu) in X96 = fullMulDiv(sqrtP, sqrtP, sqrtPu)
        uint256 ptOverSqrtPuX96 = FixedPointMathLib.fullMulDiv(
            uint256(refSqrtPriceX96), uint256(refSqrtPriceX96), uint256(_up)
        );

        leftIlX96 = int256(uint256(refSqrtPriceX96) << 1)
            - int256(ptOverSqrtPuX96)
            - int256(uint256(_up));

    } else if (refSqrtPriceX96 < _low) {
        // Split: step1 = Pt * spread / sqrt(Pl)
        //        val   = step1 * 2^96 / sqrt(Pu)  (compensate Q96 denom)
        uint256 spreadX96 = uint256(_up) - uint256(_low);

        // Pt in X96 = sqrtP * sqrtP / 2^96
        uint256 ptX96 = FixedPointMathLib.fullMulDiv(
            uint256(refSqrtPriceX96), uint256(refSqrtPriceX96), 1 << 96
        );

        uint256 step1 = FixedPointMathLib.fullMulDiv(ptX96, spreadX96, uint256(_low));
        uint256 valX96 = FixedPointMathLib.fullMulDiv(step1, 1 << 96, uint256(_up));

        leftIlX96 = int256(valX96) - int256(spreadX96);
    }
    // Above range (Pt > Pu): IL^L = 0
}

function leftRightIlXLiqRaw(
    uint256 refPrice,
    PRECISION_FLAG precisionFlag,
    TickRange tickRange
) pure returns (int256, int256) {
    (uint160 sqrtPriceLowX96, uint160 sqrtPriceUpX96) = fromTickRangeToSqrtPriceX96Range(tickRange);

    uint160 refSqrtPriceX96 = toBool(precisionFlag)
        ? fromWadToSqrtPriceX96(refPrice)
        : fromRayToSqrtPriceX96(refPrice);

    return (
        rightIlXLiq(refSqrtPriceX96, sqrtPriceLowX96, sqrtPriceUpX96),
        leftIlXLiq(refSqrtPriceX96, sqrtPriceLowX96, sqrtPriceUpX96)
    );
}

function leftRightIlXLiqSigned(
    uint256 refPrice,
    PRECISION_FLAG precisionFlag,
    TickRange tickRange
) pure returns (LeftRightSigned) {
    (int256 rightIlX96, int256 leftIlX96) = leftRightIlXLiqRaw(refPrice, precisionFlag, tickRange);

    return LeftRightSigned.wrap(0)
        .addToRightSlot(PanopticMath.toInt128(rightIlX96))
        .addToLeftSlot(PanopticMath.toInt128(leftIlX96));
}

function leftRightIlXLiqUnsigned(
    uint256 refPrice,
    PRECISION_FLAG precisionFlag,
    TickRange tickRange
) pure returns (LeftRightUnsigned) {
    (int256 rightIlX96, int256 leftIlX96) = leftRightIlXLiqRaw(refPrice, precisionFlag, tickRange);

    // IL is always <= 0 (a loss), negate to get unsigned magnitude
    uint128 rightAbs = PanopticMath.toUint128(uint256(-rightIlX96));
    uint128 leftAbs = PanopticMath.toUint128(uint256(-leftIlX96));

    return LeftRightUnsigned.wrap(0)
        .addToRightSlot(rightAbs)
        .addToLeftSlot(leftAbs);
}

