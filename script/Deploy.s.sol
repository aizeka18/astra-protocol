// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import "../src/token/GovernanceToken.sol";

import "../src/governance/ProtocolTimelock.sol";

import "../src/governance/ProtocolGovernor.sol";

import "../src/governance/Treasury.sol";

import "../src/amm/AMMFactory.sol";

import "../src/oracle/ChainlinkOracle.sol";

import "../src/oracle/MockAggregatorV3.sol";

import "../src/vault/YieldVault.sol";

import "../src/mocks/MockUSDC.sol";

import "../src/mocks/MockWETH.sol";

import "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey =
            vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(
            deployerPrivateKey
        );

        address deployer =
            vm.addr(deployerPrivateKey);

        // ===== DEPLOY GOVERNANCE TOKEN =====

        GovernanceToken governanceToken =
            new GovernanceToken(
                deployer
            );

        // ===== TIMELOCK CONFIG =====

        address[] memory proposers =
            new address[](1);

        address[] memory executors =
            new address[](1);

        proposers[0] = deployer;
        executors[0] = deployer;

        // ===== DEPLOY TIMELOCK =====

        ProtocolTimelock timelock =
            new ProtocolTimelock(
                proposers,
                executors,
                deployer
            );

        // ===== DEPLOY GOVERNOR =====

        ProtocolGovernor governor =
            new ProtocolGovernor(
                governanceToken,
                timelock
            );

        // ===== DEPLOY TREASURY =====

        Treasury treasury =
            new Treasury(deployer);

        // ===== TRANSFER TREASURY OWNERSHIP =====

        treasury.transferOwnership(
            address(timelock)
        );

        // ===== DEPLOY MOCK TOKENS =====

        MockUSDC usdc =
            new MockUSDC();

        MockWETH weth =
            new MockWETH();

        // ===== DEPLOY AMM FACTORY =====

        AMMFactory factory =
            new AMMFactory();

        // ===== CREATE AMM PAIR =====

        factory.createPair(
            address(usdc),
            address(weth)
        );

        // ===== DEPLOY MOCK CHAINLINK FEED =====

        MockAggregatorV3 mockFeed =
            new MockAggregatorV3(
                2000e8
            );

        // ===== DEPLOY ORACLE =====

        ChainlinkOracle oracle =
            new ChainlinkOracle(
                address(mockFeed)
            );

        // ===== DEPLOY VAULT IMPLEMENTATION =====

        YieldVault vaultImplementation =
            new YieldVault();

        // ===== ENCODE INITIALIZER =====

        bytes memory initData =
            abi.encodeWithSelector(
                YieldVault.initialize.selector,
                IERC20(address(usdc)),
                deployer
            );

        // ===== DEPLOY PROXY =====

        ERC1967Proxy proxy =
            new ERC1967Proxy(
                address(vaultImplementation),
                initData
            );

        YieldVault vault =
            YieldVault(address(proxy));

        vm.stopBroadcast();
    }
}