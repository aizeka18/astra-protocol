// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/token/GovernanceToken.sol";
import "../../src/amm/AMMFactory.sol";
import "../../src/amm/AMMPair.sol";
import "../../src/vault/YieldVault.sol";
import "../../src/mocks/MockUSDC.sol";
import "../../src/mocks/MockWETH.sol";

contract BaseTest is Test {
    GovernanceToken internal governanceToken;

    MockUSDC internal usdc;
    MockWETH internal weth;

    AMMFactory internal factory;
    AMMPair internal pair;

    address internal alice = address(1);
    address internal bob = address(2);
    address internal charlie = address(3);

    function setUp() public virtual {
        governanceToken = new GovernanceToken(address(this));

        usdc = new MockUSDC();
        weth = new MockWETH();

        factory = new AMMFactory();

        address pairAddress = factory.createPair(address(usdc), address(weth));

        pair = AMMPair(pairAddress);

        usdc.mint(alice, 1_000_000 ether);
        weth.mint(alice, 1_000_000 ether);

        usdc.mint(bob, 1_000_000 ether);
        weth.mint(bob, 1_000_000 ether);
    }
}
