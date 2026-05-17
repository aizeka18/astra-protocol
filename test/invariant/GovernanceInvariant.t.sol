// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/token/GovernanceToken.sol";

contract GovernanceInvariantTest is Test {
    GovernanceToken token;

    address owner = address(this);
    address alice = address(1);

    function setUp() public {
        token = new GovernanceToken(owner);

        token.mint(alice, 100000 ether);
    }

    function invariant_TotalSupplyAlwaysPositive() public view {
        assertGt(token.totalSupply(), 0);
    }

    function invariant_UserBalanceNeverNegative() public view {
        assertGe(token.balanceOf(alice), 0);
    }
}
