// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";

import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract YieldVault is Initializable, ERC20Upgradeable, ERC4626Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    error ZeroAddress();

    constructor() {
        _disableInitializers();
    }

    function initialize(IERC20 asset_, address initialOwner) external initializer {
        if (initialOwner == address(0)) {
            revert ZeroAddress();
        }

        __ERC20_init("Astra Yield Vault Share", "avTOKEN");

        __ERC4626_init(asset_);

        __Ownable_init(initialOwner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    function decimals() public view override(ERC20Upgradeable, ERC4626Upgradeable) returns (uint8) {
        return super.decimals();
    }
}
