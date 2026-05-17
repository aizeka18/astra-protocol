// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./AMMPair.sol";
import "../token/LPToken.sol";

contract AMMFactory {
    mapping(address => mapping(address => address)) public getPair;

    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, address lpToken);

    error IdenticalAddresses();
    error ZeroAddress();
    error PairAlreadyExists();

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        if (tokenA == tokenB) {
            revert IdenticalAddresses();
        }

        if (tokenA == address(0) || tokenB == address(0)) {
            revert ZeroAddress();
        }

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        if (getPair[token0][token1] != address(0)) {
            revert PairAlreadyExists();
        }

        LPToken lpToken = new LPToken(address(this));

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        pair = address(new AMMPair{salt: salt}(token0, token1, address(lpToken)));

        // FIX S-01: CEI — state variables updated BEFORE external call
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, address(lpToken));

        // External call LAST
        lpToken.transferOwnership(pair);
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function predictPairAddress(address tokenA, address tokenB) external view returns (bytes32 salt) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        salt = keccak256(abi.encodePacked(token0, token1));
    }
}
