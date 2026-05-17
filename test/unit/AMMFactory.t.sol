// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/amm/AMMFactory.sol";
import "../../src/token/LPToken.sol";

contract AMMFactoryTest is Test {
    AMMFactory factory;

    address tokenA = address(1);
    address tokenB = address(2);

    function setUp() public {
        factory = new AMMFactory();
    }

    function testCreatePair() public {
        address pair = factory.createPair(tokenA, tokenB);

        assertTrue(pair != address(0));
    }

    function testGetPair() public {
        address pair = factory.createPair(tokenA, tokenB);

        assertEq(factory.getPair(tokenA, tokenB), pair);
    }

    function testCannotCreateDuplicatePair() public {
        factory.createPair(tokenA, tokenB);

        vm.expectRevert();

        factory.createPair(tokenA, tokenB);
    }

    function testCannotUseIdenticalTokens() public {
        vm.expectRevert();

        factory.createPair(tokenA, tokenA);
    }

    function testAllPairsLength() public {
        factory.createPair(tokenA, tokenB);

        assertEq(factory.allPairsLength(), 1);
    }

    function testPredictPairAddress() public {
        bytes32 salt = factory.predictPairAddress(tokenA, tokenB);

        assertTrue(salt != bytes32(0));
    }
}
