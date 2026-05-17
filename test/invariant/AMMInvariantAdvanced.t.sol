// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/amm/AMMPair.sol";
import "../../src/token/LPToken.sol";
import "../../src/mocks/MockUSDC.sol";
import "../../src/mocks/MockWETH.sol";

contract AMMInvariantAdvancedTest is Test {
    AMMPair pair;

    MockUSDC usdc;
    MockWETH weth;

    LPToken lpToken;

    function setUp() public {
        usdc = new MockUSDC();

        weth = new MockWETH();

        lpToken = new LPToken(address(this));

        pair = new AMMPair(address(usdc), address(weth), address(lpToken));

        lpToken.transferOwnership(address(pair));

        usdc.mint(address(this), 1_000_000 ether);

        weth.mint(address(this), 1_000_000 ether);

        usdc.approve(address(pair), type(uint256).max);

        weth.approve(address(pair), type(uint256).max);

        pair.addLiquidity(1000 ether, 1000 ether);
    }

    function invariant_ReservesStayPositive() public view {
        (uint256 reserve0, uint256 reserve1) = pair.getReserves();

        assertGt(reserve0, 0);

        assertGt(reserve1, 0);
    }

    function invariant_LPTokenSupplyPositive() public view {
        assertGt(lpToken.totalSupply(), 0);
    }
}
