// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/oracle/MockAggregatorV3.sol";

contract MockAggregatorV3Test is Test {
    MockAggregatorV3 feed;

    function setUp() public {
        feed = new MockAggregatorV3(2000e8);
    }

    function testLatestRoundData() public view {
        (uint80 roundId, int256 answer,,,) = feed.latestRoundData();

        assertGt(roundId, 0);

        assertEq(answer, 2000e8);
    }

    function testPricePositive() public view {
        (, int256 answer,,,) = feed.latestRoundData();

        assertGt(answer, 0);
    }
}

