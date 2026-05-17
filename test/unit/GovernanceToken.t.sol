// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/token/GovernanceToken.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken token;

    address owner = address(1);
    address alice = address(2);
    address bob = address(3);

    function setUp() public {
        vm.prank(owner);
        token = new GovernanceToken(owner);
    }

    // =====================================
    // BASIC TESTS
    // =====================================

    function testInitialSupply() public {
        assertEq(token.totalSupply(), 1_000_000 ether);
    }

    function testOwnerCanMint() public {
        vm.prank(owner);

        token.mint(alice, 100 ether);

        assertEq(token.balanceOf(alice), 100 ether);
    }

    function testNonOwnerCannotMint() public {
        vm.prank(alice);

        vm.expectRevert();

        token.mint(alice, 100 ether);
    }

    function testMintIncreasesTotalSupply() public {
        uint256 supplyBefore = token.totalSupply();

        vm.prank(owner);

        token.mint(alice, 100 ether);

        assertEq(token.totalSupply(), supplyBefore + 100 ether);
    }

    function testMintToZeroReverts() public {
        vm.prank(owner);

        vm.expectRevert();

        token.mint(address(0), 100 ether);
    }

    // =====================================
    // TRANSFER TESTS
    // =====================================

    function testTransferWorks() public {
        vm.prank(owner);

        token.transfer(alice, 100 ether);

        assertEq(token.balanceOf(alice), 100 ether);
    }

    function testTransferUpdatesBalances() public {
        vm.startPrank(owner);

        token.transfer(alice, 100 ether);
        token.transfer(bob, 50 ether);

        vm.stopPrank();

        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.balanceOf(bob), 50 ether);
    }

    function testTransferToZeroReverts() public {
        vm.prank(owner);

        vm.expectRevert();

        token.transfer(address(0), 1 ether);
    }

    function testCannotTransferMoreThanBalance() public {
        vm.prank(alice);

        vm.expectRevert();

        token.transfer(bob, 100 ether);
    }

    // =====================================
    // GOVERNANCE TESTS
    // =====================================

    function testDelegationWorks() public {
        vm.startPrank(owner);

        token.delegate(owner);

        assertEq(token.getVotes(owner), token.balanceOf(owner));

        vm.stopPrank();
    }

    function testTransferUpdatesVotingPower() public {
        vm.startPrank(owner);

        token.delegate(owner);

        token.transfer(alice, 100 ether);

        assertEq(token.getVotes(owner), token.balanceOf(owner));

        vm.stopPrank();
    }

    function testSelfDelegationWorks() public {
        vm.prank(alice);

        token.delegate(alice);

        assertEq(token.getVotes(alice), 0);
    }

    function testDelegationAfterTransfer() public {
        vm.prank(owner);

        token.transfer(alice, 200 ether);

        vm.prank(alice);

        token.delegate(alice);

        assertEq(token.getVotes(alice), 200 ether);
    }

    function testChangingDelegateUpdatesVotes() public {
        vm.prank(owner);

        token.transfer(alice, 100 ether);

        vm.startPrank(alice);

        token.delegate(alice);

        assertEq(token.getVotes(alice), 100 ether);

        token.delegate(bob);

        assertEq(token.getVotes(alice), 0);
        assertEq(token.getVotes(bob), 100 ether);

        vm.stopPrank();
    }

    // =====================================
    // FUZZ TESTS
    // =====================================

    function testFuzzTransfer(uint256 amount) public {
        amount = bound(amount, 1 ether, 1000 ether);

        vm.prank(owner);

        token.transfer(alice, amount);

        assertEq(token.balanceOf(alice), amount);
    }

    function testFuzzMint(uint256 amount) public {
        amount = bound(amount, 1 ether, 10_000 ether);

        vm.prank(owner);

        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
    }

    function testFuzzDelegation(uint256 amount) public {
        amount = bound(amount, 1 ether, 1000 ether);

        vm.prank(owner);

        token.transfer(alice, amount);

        vm.prank(alice);

        token.delegate(alice);

        assertEq(token.getVotes(alice), amount);
    }
}
