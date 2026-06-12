// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IAlgebraFactory} from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol";
import {IAlgebraPoolState} from "@cryptoalgebra/integral-core/contracts/interfaces/pool/IAlgebraPoolState.sol";
import {IVolatilityOracle} from "@cryptoalgebra/integral-base-plugin/contracts/interfaces/plugins/IVolatilityOracle.sol";
import {OracleLibrary} from "@cryptoalgebra/integral-base-plugin/contracts/libraries/integration/OracleLibrary.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";


// note: Import from angstrom Pair.sol
// import {Pair} from "angstrom/contracts/src/types/Pair.sol";

struct Pair{
    address token0;
    address token1;
}

struct TickRange {
    int24 tickLower;
    int24 tickUpper;
    int24 center;
}

function getPoolInfo(Pair memory pair) pure returns(address, address){
    return (pair.token0, pair.token1);
}

error PoolNotFound();
error OracleNotInitialized();


function getPool(Pair memory pair, IAlgebraFactory factory) view returns(address pool){
    (address asset0, address asset1) = getPoolInfo(pair);

    pool = factory.poolByPair(asset0, asset1);
    if (pool == address(0)) revert PoolNotFound();

}    
function getOracle(Pair memory pair, IAlgebraFactory factory) view returns (IVolatilityOracle oracle) {
    address pool = getPool(pair, factory);
    address plugin = IAlgebraPoolState(pool).plugin();
    oracle = IVolatilityOracle(plugin);

    if (!oracle.isInitialized()) revert OracleNotInitialized();
}


function getStrikeByAvg(
	  Pair memory pair,
	  IAlgebraFactory factory,
	  uint32 window
) view returns (int24 strikeTick) {
    IVolatilityOracle oracle = getOracle(pair, factory);
    strikeTick = OracleLibrary.consult(address(oracle), window);
}

function getTickRangeSymmetric(
			 Pair memory pair,
			 IAlgebraFactory factory,
			 uint32 window
) view returns(TickRange memory tickRange){
    IVolatilityOracle oracle = getOracle(pair, factory);

    // center = TWAP tick over window (via OracleLibrary, rounds toward negative infinity)
    int24 center = OracleLibrary.consult(address(oracle), window);

    // diff volatilityCumulative over window → σ²·T baked in, no √T needed
    (, uint88 volCumNow)   = oracle.getSingleTimepoint(0);
    (, uint88 volCumThen)  = oracle.getSingleTimepoint(window);

    // varianceOverWindow = Σ(tick - TWAP)² accumulated over `window` seconds
    // this is σ²·T directly — time scaling is embedded in the accumulator diff
    uint256 varianceOverWindow = uint256(volCumNow - volCumThen);

    // halfWidth = sqrt(varianceOverWindow) — one sqrt, no √T
    int24 halfWidth = int24(int256(FixedPointMathLib.sqrt(varianceOverWindow)));

    tickRange = TickRange({
        tickLower: center - halfWidth,
        tickUpper: center + halfWidth,
        center: center
    });
}



