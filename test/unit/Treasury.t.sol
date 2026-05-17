// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/governance/Treasury.sol";
import "../../src/mocks/MockUSDC.sol";

contract TreasuryTest is Test {
    Treasury treasury;
    MockUSDC token;

    address owner = address(1);
    address alice = address(2);

    function setUp() public {
        vm.startPrank(owner);

        treasury = new Treasury(owner);

        token = new MockUSDC();

        token.mint(owner, 100_000 ether);

        token.transfer(address(treasury), 10_000 ether);

        vm.stopPrank();
    }

    function testTreasuryBalance() public {
        assertEq(token.balanceOf(address(treasury)), 10_000 ether);
    }

    function testGetBalance() public {
        uint256 balance = treasury.getBalance(address(token));

        assertEq(balance, 10_000 ether);
    }

    function testOwnerCanTransferFunds() public {
        vm.prank(owner);

        treasury.transferFunds(address(token), alice, 1000 ether);

        assertEq(token.balanceOf(alice), 1000 ether);
    }

    function testNonOwnerCannotTransferFunds() public {
        vm.prank(alice);

        vm.expectRevert();

        treasury.transferFunds(address(token), alice, 100 ether);
    }

    function testCannotTransferToZeroAddress() public {
        vm.prank(owner);

        vm.expectRevert();

        treasury.transferFunds(address(token), address(0), 100 ether);
    }

    function testCannotTransferZeroAmount() public {
        vm.prank(owner);

        vm.expectRevert();

        treasury.transferFunds(address(token), alice, 0);
    }

    function testTreasuryBalanceDecreases() public {
        vm.prank(owner);

        treasury.transferFunds(address(token), alice, 1000 ether);

        assertEq(token.balanceOf(address(treasury)), 9000 ether);
    }

    function testFuzzTransferFunds(uint256 amount) public {
        amount = bound(amount, 1 ether, 1000 ether);

        vm.prank(owner);

        treasury.transferFunds(address(token), alice, amount);

        assertEq(token.balanceOf(alice), amount);
    }
}
