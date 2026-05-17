// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/vault/YieldVaultV2.sol";

contract YieldVaultV2Test is Test {
    YieldVaultV2 vault;

    function setUp() public {
        vault = new YieldVaultV2();
    }

    function testVersion() public view {
        assertTrue(bytes(vault.version()).length > 0);
    }

    function testVersionNotEmpty() public view {
        string memory version = vault.version();

        assertGt(bytes(version).length, 0);
    }

    function testMultipleCalls() public view {
        vault.version();

        vault.version();

        vault.version();

        assertTrue(true);
    }
}
