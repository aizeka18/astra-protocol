// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/governance/Treasury.sol";
import "../../src/mocks/MockUSDC.sol";

contract TreasuryInvariantTest is Test {
    Treasury treasury;
    MockUSDC token;

    address owner = address(1);

    function setUp() public {
        treasury = new Treasury(owner);

        token = new MockUSDC();

        token.mint(address(treasury), 100000 ether);
    }

    function invariant_TreasuryBalanceNeverNegative() public view {
        assertGe(token.balanceOf(address(treasury)), 0);
    }

    function invariant_TotalSupplyConsistent() public view {
        assertGe(token.totalSupply(), token.balanceOf(address(treasury)));
    }
}
