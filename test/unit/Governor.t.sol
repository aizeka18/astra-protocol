// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/token/GovernanceToken.sol";
import "../../src/governance/ProtocolGovernor.sol";
import "../../src/governance/ProtocolTimelock.sol";

contract GovernorTest is Test {
    GovernanceToken token;
    ProtocolTimelock timelock;
    ProtocolGovernor governor;

    address owner = address(1);
    address alice = address(2);

    function setUp() public {
        vm.startPrank(owner);

        token = new GovernanceToken(owner);

        address[] memory proposers = new address[](1);
        proposers[0] = owner;

        address[] memory executors = new address[](1);
        executors[0] = owner;

        timelock = new ProtocolTimelock(proposers, executors, owner);

        governor = new ProtocolGovernor(token, timelock);

        token.delegate(owner);

        vm.roll(block.number + 1);

        vm.stopPrank();
    }

    function testVotingPowerExists() public {
        assertGt(token.getVotes(owner), 0);
    }

    function testProposalCreation() public {
        address[] memory targets = new address[](1);
        targets[0] = address(token);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("mint(address,uint256)", alice, 100 ether);

        vm.prank(owner);

        uint256 proposalId = governor.propose(targets, values, calldatas, "Mint tokens to alice");

        assertGt(proposalId, 0);
    }

    function testCannotProposeWithoutVotes() public {
        vm.startPrank(alice);

        address[] memory targets = new address[](1);
        targets[0] = address(token);

        uint256[] memory values = new uint256[](1);

        bytes[] memory calldatas = new bytes[](1);

        vm.expectRevert();

        governor.propose(targets, values, calldatas, "Invalid proposal");

        vm.stopPrank();
    }

    function testProposalStateAfterCreation() public {
        address[] memory targets = new address[](1);
        targets[0] = address(token);

        uint256[] memory values = new uint256[](1);

        bytes[] memory calldatas = new bytes[](1);

        vm.prank(owner);

        uint256 proposalId = governor.propose(targets, values, calldatas, "Test proposal");

        uint8 state = uint8(governor.state(proposalId));

        assertEq(state, 0);
    }

    function testCastVote() public {
        address[] memory targets = new address[](1);
        targets[0] = address(token);

        uint256[] memory values = new uint256[](1);

        bytes[] memory calldatas = new bytes[](1);

        vm.prank(owner);

        uint256 proposalId = governor.propose(targets, values, calldatas, "Vote proposal");

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(owner);

        governor.castVote(proposalId, 1);

        assertEq(governor.hasVoted(proposalId, owner), true);
    }

    function testCannotVoteTwice() public {
        address[] memory targets = new address[](1);
        targets[0] = address(token);

        uint256[] memory values = new uint256[](1);

        bytes[] memory calldatas = new bytes[](1);

        vm.prank(owner);

        uint256 proposalId = governor.propose(targets, values, calldatas, "Double vote");

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(owner);

        governor.castVote(proposalId, 1);

        vm.expectRevert();

        vm.prank(owner);

        governor.castVote(proposalId, 1);
    }

    function testFuzzVotingPower(uint256 amount) public {
        amount = bound(amount, 1 ether, 1000 ether);

        vm.prank(owner);

        token.transfer(alice, amount);

        vm.prank(alice);

        token.delegate(alice);

        vm.roll(block.number + 1);

        assertEq(token.getVotes(alice), amount);
    }

    function testProposalThresholdValue() public view {
        assertEq(governor.proposalThreshold(), 10_000 ether);
    }

    function testQuorumValue() public view {
        uint256 q = governor.quorum(block.number - 1);

        assertGt(q, 0);
    }

    function testGovernorName() public view {
        assertEq(governor.name(), "Astra Governor");
    }

    function testVotingDelayValue() public view {
        assertEq(governor.votingDelay(), 7200);
    }

    function testVotingPeriodValue() public view {
        assertEq(governor.votingPeriod(), 50400);
    }
}
