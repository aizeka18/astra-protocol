// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/oracle/ChainlinkOracle.sol";
import "../../src/oracle/MockAggregatorV3.sol";

contract ChainlinkOracleTest is Test {
    ChainlinkOracle oracle;
    MockAggregatorV3 feed;

    function setUp() public {
        feed = new MockAggregatorV3(2000e8);

        oracle = new ChainlinkOracle(address(feed));
    }

    function testLatestPrice() public {
        uint256 price = oracle.getLatestPrice();

        assertGt(price, 0);
    }

    function testRoundData() public {
        (uint80 roundId, int256 answer,,,) = feed.latestRoundData();

        assertGt(roundId, 0);

        assertGt(answer, 0);
    }

    function testPriceFeedAddress() public {
        assertEq(address(oracle.priceFeed()), address(feed));
    }
}
