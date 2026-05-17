// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract ChainlinkOracle {
    AggregatorV3Interface public immutable priceFeed;

    uint256 public constant STALENESS_THRESHOLD = 1 days;

    error InvalidPrice();
    error StalePrice();

    constructor(address feed) {
        priceFeed = AggregatorV3Interface(feed);
    }

    function getLatestPrice() external view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();

        if (answer <= 0) {
            revert InvalidPrice();
        }

        if (block.timestamp - updatedAt > STALENESS_THRESHOLD) {
            revert StalePrice();
        }

        return uint256(answer);
    }
}
