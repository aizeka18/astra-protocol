// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGovernanceToken {
    function mint(address to, uint256 amount) external;

    function delegate(address delegatee) external;

    function getVotes(
        address account
    ) external view returns (uint256);

    function balanceOf(
        address account
    ) external view returns (uint256);
}