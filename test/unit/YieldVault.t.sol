// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/vault/YieldVault.sol";
import "../../src/mocks/MockUSDC.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract YieldVaultTest is Test {
    YieldVault implementation;
    YieldVault vault;

    MockUSDC asset;

    address owner = address(1);
    address alice = address(2);
    address bob = address(3);

    function setUp() public {
        vm.startPrank(owner);

        asset = new MockUSDC();

        implementation = new YieldVault();

        bytes memory data = abi.encodeWithSelector(YieldVault.initialize.selector, address(asset), owner);

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);

        vault = YieldVault(address(proxy));

        asset.mint(alice, 10_000 ether);
        asset.mint(bob, 10_000 ether);

        vm.stopPrank();
    }

    function testDepositWorks() public {
        vm.startPrank(alice);

        asset.approve(address(vault), 1000 ether);

        vault.deposit(1000 ether, alice);

        assertEq(vault.balanceOf(alice), 1000 ether);

        vm.stopPrank();
    }

    function testDepositIncreasesTotalAssets() public {
        vm.startPrank(alice);

        asset.approve(address(vault), 1000 ether);

        vault.deposit(1000 ether, alice);

        assertEq(vault.totalAssets(), 1000 ether);

        vm.stopPrank();
    }

    function testDepositMintsShares() public {
        vm.startPrank(alice);

        asset.approve(address(vault), 500 ether);

        vault.deposit(500 ether, alice);

        assertEq(vault.balanceOf(alice), 500 ether);

        vm.stopPrank();
    }

    function testWithdrawWorks() public {
        vm.startPrank(alice);

        asset.approve(address(vault), 1000 ether);

        vault.deposit(1000 ether, alice);

        vault.withdraw(500 ether, alice, alice);

        assertEq(asset.balanceOf(alice), 9500 ether);

        vm.stopPrank();
    }

    function testWithdrawReducesShares() public {
        vm.startPrank(alice);

        asset.approve(address(vault), 1000 ether);

        vault.deposit(1000 ether, alice);

        vault.withdraw(500 ether, alice, alice);

        assertEq(vault.balanceOf(alice), 500 ether);

        vm.stopPrank();
    }

    function testCannotWithdrawTooMuch() public {
        vm.startPrank(alice);

        asset.approve(address(vault), 1000 ether);

        vault.deposit(1000 ether, alice);

        vm.expectRevert();

        vault.withdraw(2000 ether, alice, alice);

        vm.stopPrank();
    }

    function testRedeemWorks() public {
        vm.startPrank(alice);

        asset.approve(address(vault), 1000 ether);

        vault.deposit(1000 ether, alice);

        vault.redeem(500 ether, alice, alice);

        assertEq(vault.balanceOf(alice), 500 ether);

        vm.stopPrank();
    }

    function testTotalAssetsTracksDeposits() public {
        vm.startPrank(alice);

        asset.approve(address(vault), 1000 ether);

        vault.deposit(1000 ether, alice);

        vm.stopPrank();

        vm.startPrank(bob);

        asset.approve(address(vault), 500 ether);

        vault.deposit(500 ether, bob);

        vm.stopPrank();

        assertEq(vault.totalAssets(), 1500 ether);
    }

    function testShareAccounting() public {
        vm.startPrank(alice);

        asset.approve(address(vault), 1000 ether);

        vault.deposit(1000 ether, alice);

        assertEq(vault.totalSupply(), 1000 ether);

        vm.stopPrank();
    }

    function testFuzzDeposit(uint256 amount) public {
        amount = bound(amount, 1 ether, 1000 ether);

        vm.startPrank(alice);

        asset.approve(address(vault), amount);

        vault.deposit(amount, alice);

        assertEq(vault.balanceOf(alice), amount);

        vm.stopPrank();
    }

    function testFuzzWithdraw(uint256 amount) public {
        amount = bound(amount, 1 ether, 1000 ether);

        vm.startPrank(alice);

        asset.approve(address(vault), 1000 ether);

        vault.deposit(1000 ether, alice);

        vault.withdraw(amount, alice, alice);

        assertEq(vault.balanceOf(alice), 1000 ether - amount);

        vm.stopPrank();
    }

    function testPreviewDeposit() public {
        uint256 shares = vault.previewDeposit(100 ether);

        assertEq(shares, 100 ether);
    }

    function testPreviewRedeem() public {
        uint256 assets = vault.previewRedeem(100 ether);

        assertEq(assets, 100 ether);
    }

    function testDepositZero() public {
        uint256 shares = vault.deposit(0, address(this));

        assertEq(shares, 0);
    }

    function testRedeemZero() public {
        uint256 assets = vault.redeem(0, address(this), address(this));

        assertEq(assets, 0);
    }

    function testWithdrawZero() public {
        uint256 shares = vault.withdraw(0, address(this), address(this));

        assertEq(shares, 0);
    }

    function testDepositReturnsShares() public {
        asset.mint(address(this), 100 ether);

        asset.approve(address(vault), type(uint256).max);

        uint256 shares = vault.deposit(100 ether, address(this));

        assertGt(shares, 0);
    }

    function testWithdrawReturnsShares() public {
        asset.mint(address(this), 100 ether);

        asset.approve(address(vault), type(uint256).max);

        vault.deposit(100 ether, address(this));

        uint256 shares = vault.withdraw(50 ether, address(this), address(this));

        assertGt(shares, 0);
    }

    function testRedeemReturnsAssets() public {
        asset.mint(address(this), 100 ether);

        asset.approve(address(vault), type(uint256).max);

        uint256 shares = vault.deposit(100 ether, address(this));

        uint256 assets = vault.redeem(shares, address(this), address(this));

        assertGt(assets, 0);
    }
}
