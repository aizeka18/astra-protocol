// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAMM {
    function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 liquidity);

    function removeLiquidity(uint256 liquidity) external returns (uint256 amount0, uint256 amount1);

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut);

    function getReserves() external view returns (uint256 reserve0, uint256 reserve1);
}
