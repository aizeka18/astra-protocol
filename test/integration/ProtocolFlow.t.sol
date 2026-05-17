// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/token/GovernanceToken.sol";
import "../../src/amm/AMMPair.sol";
import "../../src/token/LPToken.sol";
import "../../src/mocks/MockUSDC.sol";
import "../../src/mocks/MockWETH.sol";
import "../../src/vault/YieldVault.sol";

contract ProtocolFlowTest is Test {
    GovernanceToken gov;
    MockUSDC usdc;
    MockWETH weth;

    LPToken lpToken;
    AMMPair pair;

    YieldVault vault;

    address alice = address(1);

    function setUp() public {
        gov = new GovernanceToken(address(this));

        usdc = new MockUSDC();
        weth = new MockWETH();

        lpToken = new LPToken(address(this));

        pair = new AMMPair(address(usdc), address(weth), address(lpToken));

        lpToken.transferOwnership(address(pair));

        vault = new YieldVault();

        usdc.mint(alice, 1_000_000 ether);
        weth.mint(alice, 1_000_000 ether);

        vm.startPrank(alice);

        usdc.approve(address(pair), type(uint256).max);
        weth.approve(address(pair), type(uint256).max);

        usdc.approve(address(vault), type(uint256).max);

        vm.stopPrank();
    }

    function testFullProtocolFlow() public {
        vm.startPrank(alice);

        pair.addLiquidity(1000 ether, 1000 ether);

        pair.swap(address(usdc), 100 ether, 1);

        pair.removeLiquidity(lpToken.balanceOf(alice) / 2);

        vm.stopPrank();

        (uint256 reserve0, uint256 reserve1) = pair.getReserves();

        assertGt(reserve0, 0);

        assertGt(reserve1, 0);
    }
}
