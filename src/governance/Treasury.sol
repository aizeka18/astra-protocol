// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Treasury is Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();

    event FundsTransferred(address indexed token, address indexed to, uint256 amount);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function transferFunds(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) {
            revert ZeroAddress();
        }

        if (amount == 0) {
            revert ZeroAmount();
        }

        IERC20(token).safeTransfer(to, amount);

        emit FundsTransferred(token, to, amount);
    }

    function getBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
