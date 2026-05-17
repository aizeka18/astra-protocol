// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import "../src/token/GovernanceToken.sol";

import "../src/governance/ProtocolTimelock.sol";

import "../src/governance/ProtocolGovernor.sol";

import "../src/governance/Treasury.sol";

import "../src/vault/YieldVault.sol";

contract VerifyDeployment is Script {
    function run() external view {
        // ===== REPLACE AFTER REAL DEPLOY =====

        address governanceTokenAddr = address(0x111);

        address timelockAddr = address(0x222);

        address governorAddr = address(0x333);

        address treasuryAddr = address(0x444);

        address vaultAddr = address(0x555);

        GovernanceToken governanceToken = GovernanceToken(governanceTokenAddr);

        ProtocolTimelock timelock = ProtocolTimelock(payable(timelockAddr));

        ProtocolGovernor governor = ProtocolGovernor(payable(governorAddr));
        Treasury treasury = Treasury(treasuryAddr);

        YieldVault vault = YieldVault(vaultAddr);

        // ===== BASIC ADDRESS CHECKS =====

        require(governanceTokenAddr != address(0), "Governance token zero");

        require(timelockAddr != address(0), "Timelock zero");

        require(governorAddr != address(0), "Governor zero");

        require(treasuryAddr != address(0), "Treasury zero");

        require(vaultAddr != address(0), "Vault zero");

        // ===== TREASURY OWNER =====

        require(treasury.owner() == address(timelock), "Treasury owner invalid");

        // ===== TIMELOCK DELAY =====

        require(timelock.getMinDelay() == 2 days, "Timelock delay invalid");

        // ===== GOVERNOR SETTINGS =====

        require(governor.votingDelay() == 7200, "Voting delay invalid");

        require(governor.votingPeriod() == 50400, "Voting period invalid");

        require(governor.proposalThreshold() == 10_000 ether, "Proposal threshold invalid");

        // ===== VAULT ASSET =====

        require(vault.asset() == address(governanceToken), "Vault asset invalid");
    }
}
