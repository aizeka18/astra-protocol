// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface AggregatorV3Interface {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

contract ChainlinkForkTest is Test {
    AggregatorV3Interface feed;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("arbitrum_sepolia"));

        feed = AggregatorV3Interface(0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165);
    }

    function testReadRealChainlinkPrice() public {
        (, int256 answer,,,) = feed.latestRoundData();

        assertGt(answer, 0);
    }
}
