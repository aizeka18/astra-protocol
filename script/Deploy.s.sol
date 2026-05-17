// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import "../src/token/GovernanceToken.sol";

import "../src/governance/ProtocolTimelock.sol";

import "../src/governance/ProtocolGovernor.sol";

import "../src/governance/Treasury.sol";

import "../src/amm/AMMFactory.sol";

import "../src/oracle/ChainlinkOracle.sol";

import "../src/vault/YieldVault.sol";

import "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // ===== DEPLOY GOVERNANCE TOKEN =====

        GovernanceToken governanceToken = new GovernanceToken(msg.sender);

        // ===== TIMELOCK CONFIG =====

        address[] memory proposers = new address[](1);

        address[] memory executors = new address[](1);

        proposers[0] = msg.sender;
        executors[0] = msg.sender;

        // ===== DEPLOY TIMELOCK =====

        ProtocolTimelock timelock = new ProtocolTimelock(proposers, executors, msg.sender);

        // ===== DEPLOY GOVERNOR =====

        ProtocolGovernor governor = new ProtocolGovernor(governanceToken, timelock);

        // ===== DEPLOY TREASURY =====

        Treasury treasury = new Treasury(msg.sender);

        // ===== TRANSFER TREASURY OWNERSHIP =====

        treasury.transferOwnership(address(timelock));

        // ===== DEPLOY AMM FACTORY =====

        AMMFactory factory = new AMMFactory();

        // ===== DEPLOY ORACLE =====

        // Replace with real Chainlink feed later
        ChainlinkOracle oracle = new ChainlinkOracle(address(0x123));

        // ===== DEPLOY VAULT IMPLEMENTATION =====

        YieldVault vaultImplementation = new YieldVault();

        // ===== ENCODE INITIALIZER =====

        bytes memory initData =
            abi.encodeWithSelector(YieldVault.initialize.selector, IERC20(address(governanceToken)), msg.sender);

        // ===== DEPLOY PROXY =====

        ERC1967Proxy proxy = new ERC1967Proxy(address(vaultImplementation), initData);

        YieldVault vault = YieldVault(address(proxy));

        vm.stopBroadcast();
    }
}
