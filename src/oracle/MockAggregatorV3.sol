// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockAggregatorV3 {
    int256 private price;

    uint256 private updatedAt;

    uint80 private roundId;

    constructor(int256 initialPrice) {
        price = initialPrice;

        updatedAt = block.timestamp;

        roundId = 1;
    }

    function setPrice(int256 newPrice) external {
        price = newPrice;

        updatedAt = block.timestamp;

        roundId++;
    }

    function setUpdatedAt(uint256 timestamp) external {
        updatedAt = timestamp;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, price, updatedAt, updatedAt, roundId);
    }
}
