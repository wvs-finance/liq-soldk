// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IAlgebraFactory} from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol";
import {IVolatilityOracle} from "@cryptoalgebra/integral-base-plugin/contracts/interfaces/plugins/IVolatilityOracle.sol";
import {Pair, TickRange, getOracle, getPool, getStrikeByAvg, getTickRangeSymmetric} from "../../src/libraries/AlgebraVolatilityLens.sol";

contract AlgebraVolatilityLensHarness {
    function getVolOracle(Pair memory pair, IAlgebraFactory factory)
        external
        view
        returns (IVolatilityOracle oracle)
    {
        return getOracle(pair, factory);
    }

    function getVolPool(Pair memory pair, IAlgebraFactory factory)
        external
        view
        returns (address pool)
    {
        return getPool(pair, factory);
    }

    function getVolStrikeByAvg(Pair memory pair, IAlgebraFactory factory, uint32 window)
        external
        view
        returns (int24 strikeTick)
    {
        return getStrikeByAvg(pair, factory, window);
    }

    function getVolTickRangeSymmetric(Pair memory pair, IAlgebraFactory factory, uint32 window)
        external
        view
        returns (TickRange memory tickRange)
    {
        return getTickRangeSymmetric(pair, factory, window);
    }
}
