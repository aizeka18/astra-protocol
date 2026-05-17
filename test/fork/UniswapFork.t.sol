// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

contract UniswapForkTest is Test {
    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("arbitrum_sepolia"));
    }

    function testForkBlockExists() public view {
        assertGt(block.number, 0);
    }

    function testForkChainId() public view {
        assertEq(block.chainid, 421614);
    }
}
