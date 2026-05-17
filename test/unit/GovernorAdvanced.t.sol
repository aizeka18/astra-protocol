// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/governance/ProtocolGovernor.sol";
import "../../src/governance/ProtocolTimelock.sol";
import "../../src/token/GovernanceToken.sol";

contract GovernorAdvancedTest is Test {
    GovernanceToken token;

    ProtocolGovernor governor;

    ProtocolTimelock timelock;

    address owner = address(this);

    function setUp() public {
        token = new GovernanceToken(owner);

        address[] memory proposers = new address[](1);

        proposers[0] = owner;

        address[] memory executors = new address[](1);

        executors[0] = owner;

        timelock = new ProtocolTimelock(proposers, executors, owner);
        governor = new ProtocolGovernor(token, timelock);

        token.mint(owner, 100000 ether);

        token.delegate(owner);
        vm.roll(block.number + 1);
    }

    function testVotingDelay() public view {
        assertGt(governor.votingDelay(), 0);
    }

    function testVotingPeriod() public view {
        assertGt(governor.votingPeriod(), 0);
    }

    function testProposalThreshold() public view {
        assertGt(governor.proposalThreshold(), 0);
    }

    function testQuorum() public view {
        uint256 quorumValue = governor.quorum(block.number - 1);

        assertGe(quorumValue, 0);
    }

    function testTimelockAddress() public view {
        assertEq(address(governor.timelock()), address(timelock));
    }

    function testProposalLifecycle() public {
        address[] memory targets = new address[](1);

        targets[0] = address(token);

        uint256[] memory values = new uint256[](1);

        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", address(1), 1 ether);

        string memory description = "Test proposal";

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + governor.votingDelay() + 1);

        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);

        assertTrue(uint256(governor.state(proposalId)) > 0);
    }
}
