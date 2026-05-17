// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../token/LPToken.sol";

contract AMMPair is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    LPToken public immutable lpToken;

    uint256 public reserve0;
    uint256 public reserve1;

    constructor(address _token0, address _token1, address _lpToken) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);

        lpToken = LPToken(_lpToken);
    }

    function getReserves() public view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external nonReentrant {
        require(amount0 > 0 && amount1 > 0, "Zero liquidity");
        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        uint256 liquidity;

        if (lpToken.totalSupply() == 0) {
            liquidity = sqrt(amount0 * amount1);
        } else {
            liquidity = min((amount0 * lpToken.totalSupply()) / reserve0, (amount1 * lpToken.totalSupply()) / reserve1);
        }

        reserve0 += amount0;
        reserve1 += amount1;

        lpToken.mint(msg.sender, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external nonReentrant {
        require(liquidity > 0, "Zero liquidity");
        uint256 totalSupply = lpToken.totalSupply();

        uint256 amount0 = (liquidity * reserve0) / totalSupply;
        uint256 amount1 = (liquidity * reserve1) / totalSupply;

        reserve0 -= amount0;
        reserve1 -= amount1;

        lpToken.burn(msg.sender, liquidity);

        token0.safeTransfer(msg.sender, amount0);
        token1.safeTransfer(msg.sender, amount1);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external nonReentrant {
        bool isToken0 = tokenIn == address(token0);

        IERC20 inputToken = isToken0 ? token0 : token1;
        IERC20 outputToken = isToken0 ? token1 : token0;

        uint256 reserveIn = isToken0 ? reserve0 : reserve1;
        uint256 reserveOut = isToken0 ? reserve1 : reserve0;

        inputToken.safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 amountInWithFee = amountIn * 997;
        uint256 amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);

        require(amountOut >= minAmountOut, "Slippage too high");

        if (isToken0) {
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }

        outputToken.safeTransfer(msg.sender, amountOut);
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;

            uint256 x = y / 2 + 1;

            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }
}
