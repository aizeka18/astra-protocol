// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint8);
}

contract USDCForkTest is Test {
    IERC20 usdc;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("arbitrum_sepolia"));

        usdc = IERC20(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d);
    }

    function testUSDCDecimals() public {
        assertEq(usdc.decimals(), 6);
    }

    function testUSDCSupplyExists() public {
        assertGt(usdc.totalSupply(), 0);
    }
}
