// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/amm/AMMPair.sol";
import "../../src/token/LPToken.sol";

import "../../src/mocks/MockUSDC.sol";
import "../../src/mocks/MockWETH.sol";

contract AMMPairTest is Test {
    AMMPair pair;

    MockUSDC usdc;
    MockWETH weth;

    LPToken lpToken;

    address owner = address(1);
    address alice = address(2);
    address bob = address(3);

    function setUp() public {
        vm.startPrank(owner);

        usdc = new MockUSDC();
        weth = new MockWETH();

        lpToken = new LPToken(owner);

        pair = new AMMPair(address(usdc), address(weth), address(lpToken));

        lpToken.transferOwnership(address(pair));

        usdc.mint(owner, 1_000_000 ether);
        weth.mint(owner, 1_000_000 ether);

        usdc.transfer(alice, 10_000 ether);
        weth.transfer(alice, 10_000 ether);

        usdc.transfer(bob, 10_000 ether);
        weth.transfer(bob, 10_000 ether);

        vm.stopPrank();
    }

    // =====================================
    // LIQUIDITY TESTS
    // =====================================

    function testAddLiquidity() public {
        vm.startPrank(alice);

        usdc.approve(address(pair), 1000 ether);
        weth.approve(address(pair), 1000 ether);

        pair.addLiquidity(1000 ether, 1000 ether);

        assertEq(pair.reserve0(), 1000 ether);
        assertEq(pair.reserve1(), 1000 ether);

        vm.stopPrank();
    }

    function testLiquidityMintsLP() public {
        vm.startPrank(alice);

        usdc.approve(address(pair), 1000 ether);
        weth.approve(address(pair), 1000 ether);

        pair.addLiquidity(1000 ether, 1000 ether);

        uint256 lpBalance = lpToken.balanceOf(alice);

        assertGt(lpBalance, 0);

        vm.stopPrank();
    }

    function testRemoveLiquidity() public {
        vm.startPrank(alice);

        usdc.approve(address(pair), 1000 ether);
        weth.approve(address(pair), 1000 ether);

        pair.addLiquidity(1000 ether, 1000 ether);

        uint256 lpBalance = lpToken.balanceOf(alice);

        lpToken.approve(address(pair), lpBalance);

        pair.removeLiquidity(lpBalance);

        assertEq(pair.reserve0(), 0);
        assertEq(pair.reserve1(), 0);

        vm.stopPrank();
    }

    function testMultipleLiquidityProviders() public {
        vm.startPrank(alice);

        usdc.approve(address(pair), 1000 ether);
        weth.approve(address(pair), 1000 ether);

        pair.addLiquidity(1000 ether, 1000 ether);

        vm.stopPrank();

        vm.startPrank(bob);

        usdc.approve(address(pair), 500 ether);
        weth.approve(address(pair), 500 ether);

        pair.addLiquidity(500 ether, 500 ether);

        vm.stopPrank();

        assertEq(pair.reserve0(), 1500 ether);
        assertEq(pair.reserve1(), 1500 ether);
    }

    function testCannotAddZeroLiquidity() public {
        vm.startPrank(alice);

        vm.expectRevert();

        pair.addLiquidity(0, 0);

        vm.stopPrank();
    }

    // =====================================
    // SWAP TESTS
    // =====================================

    function testSwapWorks() public {
        vm.startPrank(alice);

        usdc.approve(address(pair), 1000 ether);
        weth.approve(address(pair), 1000 ether);

        pair.addLiquidity(1000 ether, 1000 ether);

        vm.stopPrank();

        vm.startPrank(bob);

        usdc.approve(address(pair), 100 ether);

        pair.swap(address(usdc), 100 ether, 1);

        assertGt(weth.balanceOf(bob), 10_000 ether);

        vm.stopPrank();
    }

    function testSwapUpdatesReserves() public {
        vm.startPrank(alice);

        usdc.approve(address(pair), 1000 ether);
        weth.approve(address(pair), 1000 ether);

        pair.addLiquidity(1000 ether, 1000 ether);

        vm.stopPrank();

        uint256 reserveBefore = pair.reserve0();

        vm.startPrank(bob);

        usdc.approve(address(pair), 100 ether);

        pair.swap(address(usdc), 100 ether, 1);

        vm.stopPrank();

        assertGt(pair.reserve0(), reserveBefore);
    }

    function testSwapRevertsInvalidToken() public {
        vm.startPrank(alice);

        vm.expectRevert();

        pair.swap(address(999), 100 ether, 1);

        vm.stopPrank();
    }

    function testSwapRevertsZeroAmount() public {
        vm.startPrank(alice);

        vm.expectRevert();

        pair.swap(address(usdc), 0, 1);

        vm.stopPrank();
    }

    // =====================================
    // FUZZ TESTS
    // =====================================

    function testFuzzAddLiquidity(uint256 amount0, uint256 amount1) public {
        amount0 = bound(amount0, 1 ether, 1000 ether);
        amount1 = bound(amount1, 1 ether, 1000 ether);

        vm.startPrank(alice);

        usdc.approve(address(pair), amount0);
        weth.approve(address(pair), amount1);

        pair.addLiquidity(amount0, amount1);

        assertEq(pair.reserve0(), amount0);
        assertEq(pair.reserve1(), amount1);

        vm.stopPrank();
    }

    function testFuzzSwap(uint256 amountIn) public {
        amountIn = bound(amountIn, 1 ether, 100 ether);

        vm.startPrank(alice);

        usdc.approve(address(pair), 1000 ether);
        weth.approve(address(pair), 1000 ether);

        pair.addLiquidity(1000 ether, 1000 ether);

        vm.stopPrank();

        vm.startPrank(bob);

        usdc.approve(address(pair), amountIn);

        pair.swap(address(usdc), amountIn, 1);

        assertGt(weth.balanceOf(bob), 10_000 ether);

        vm.stopPrank();
    }

    // =====================================
    // RESERVE TESTS
    // =====================================

    function testReservesIncreaseAfterLiquidity() public {
        vm.startPrank(alice);

        usdc.approve(address(pair), 500 ether);
        weth.approve(address(pair), 500 ether);

        pair.addLiquidity(500 ether, 500 ether);

        assertEq(pair.reserve0(), 500 ether);
        assertEq(pair.reserve1(), 500 ether);

        vm.stopPrank();
    }

    function testLPTokenSupplyIncreases() public {
        vm.startPrank(alice);

        usdc.approve(address(pair), 1000 ether);
        weth.approve(address(pair), 1000 ether);

        pair.addLiquidity(1000 ether, 1000 ether);

        assertGt(lpToken.totalSupply(), 0);

        vm.stopPrank();
    }
}
