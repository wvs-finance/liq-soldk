// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IAlgebraFactory} from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol";
import {IVolatilityOracle} from "@cryptoalgebra/integral-base-plugin/contracts/interfaces/plugins/IVolatilityOracle.sol";
import {Pair, TickRange} from "../../src/libraries/AlgebraVolatilityLens.sol";
import {AlgebraVolatilityLensHarness} from "../harness/AlgebraVolatilityLensHarness.sol";

contract AlgebraVolatilityLensForkTest is Test {
    AlgebraVolatilityLensHarness harness;

    // Camelot V4 on Arbitrum
    IAlgebraFactory constant FACTORY = IAlgebraFactory(0xBefC4b405041c5833f53412fF997ed2f697a2f37);

    // Arbitrum tokens
    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    uint256 fork;
    bool forkAvailable;

    function setUp() public {
        try vm.createFork("arbitrum") returns (uint256 forkId) {
            fork = forkId;
            forkAvailable = true;
            vm.selectFork(fork);
            harness = new AlgebraVolatilityLensHarness();
        } catch {
            forkAvailable = false;
        }
    }

    modifier onlyFork() {
        if (!forkAvailable) {
            return;
        }
        _;
    }

    function test__fork__VolOracleFull() public onlyFork {
        Pair memory pair = Pair(WETH, USDC);
        IVolatilityOracle oracle = harness.getVolOracle(pair, FACTORY);
        assertTrue(address(oracle) != address(0), "oracle should be non-zero");
        assertTrue(oracle.isInitialized(), "oracle should be initialized");
        (int56 tickCumulative, uint88 volatilityCumulative) = oracle.getSingleTimepoint(0);
        assertTrue(tickCumulative != 0 || volatilityCumulative != 0, "timepoint should have data");
    }

    function test__fork__getStrikeByAvg_1h() public onlyFork {
        Pair memory pair = Pair(WETH, USDC);
        int24 strike = harness.getVolStrikeByAvg(pair, FACTORY, 1 hours);
        // WETH/USDC tick should be in a reasonable range (negative for typical ETH prices)
        assertTrue(strike != 0, "strike should be non-zero");
        emit log_named_int("strike_1h", strike);
    }

    function test__fork__getTickRangeSymmetric_1h() public onlyFork {
        Pair memory pair = Pair(WETH, USDC);
        TickRange memory range = harness.getVolTickRangeSymmetric(pair, FACTORY, 1 hours);

        assertTrue(range.tickLower < range.tickUpper, "lower < upper");
        assertTrue(range.center >= range.tickLower, "center >= lower");
        assertTrue(range.center <= range.tickUpper, "center <= upper");
        // symmetric: distance from center should be equal
        assertEq(range.center - range.tickLower, range.tickUpper - range.center, "symmetric");

        emit log_named_int("center", range.center);
        emit log_named_int("tickLower", range.tickLower);
        emit log_named_int("tickUpper", range.tickUpper);
        emit log_named_int("halfWidth", range.tickUpper - range.center);
    }

    function test__fork__getTickRangeSymmetric_24h() public onlyFork {
        Pair memory pair = Pair(WETH, USDC);
        TickRange memory range24h = harness.getVolTickRangeSymmetric(pair, FACTORY, 24 hours);
        TickRange memory range1h = harness.getVolTickRangeSymmetric(pair, FACTORY, 1 hours);

        int24 width24h = range24h.tickUpper - range24h.tickLower;
        int24 width1h = range1h.tickUpper - range1h.tickLower;
        // 24h range should be wider than 1h range (more variance accumulated)
        assertTrue(width24h >= width1h, "24h range should be >= 1h range");

        emit log_named_int("width_1h", width1h);
        emit log_named_int("width_24h", width24h);
    }
}
