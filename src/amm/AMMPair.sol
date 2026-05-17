// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../interfaces/IAMM.sol";
import "../token/LPToken.sol";

contract AMMPair is IAMM, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    LPToken public immutable lpToken;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    error InvalidToken();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();

    constructor(address _token0, address _token1, address _lpToken) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);

        lpToken = LPToken(_lpToken);
    }

    function getReserves() external view override returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external override nonReentrant returns (uint256 liquidity) {
        require(amount0 > 0 && amount1 > 0);

        token0.safeTransferFrom(msg.sender, address(this), amount0);

        token1.safeTransferFrom(msg.sender, address(this), amount1);

        if (reserve0 == 0 && reserve1 == 0) {
            liquidity = _sqrt(amount0 * amount1);
        } else {
            uint256 liquidity0 = (amount0 * lpToken.totalSupply()) / reserve0;

            uint256 liquidity1 = (amount1 * lpToken.totalSupply()) / reserve1;

            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }

        if (liquidity == 0) {
            revert InsufficientLiquidity();
        }

        reserve0 += amount0;
        reserve1 += amount1;

        lpToken.mint(msg.sender, liquidity);
    }

    function removeLiquidity(uint256 liquidity)
        external
        override
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 totalSupply = lpToken.totalSupply();

        amount0 = (liquidity * reserve0) / totalSupply;

        amount1 = (liquidity * reserve1) / totalSupply;

        if (amount0 == 0 || amount1 == 0) {
            revert InsufficientLiquidity();
        }

        lpToken.burn(msg.sender, liquidity);

        reserve0 -= amount0;
        reserve1 -= amount1;

        token0.safeTransfer(msg.sender, amount0);
        token1.safeTransfer(msg.sender, amount1);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut)
        external
        override
        nonReentrant
        returns (uint256 amountOut)
    {
        if (tokenIn != address(token0) && tokenIn != address(token1)) {
            revert InvalidToken();
        }

        bool isToken0 = tokenIn == address(token0);

        (IERC20 inputToken, IERC20 outputToken, uint256 reserveIn, uint256 reserveOut) =
            isToken0 ? (token0, token1, reserve0, reserve1) : (token1, token0, reserve1, reserve0);

        inputToken.safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 amountInWithFee = (amountIn * FEE_NUMERATOR);

        amountOut = (amountInWithFee * reserveOut) / ((reserveIn * FEE_DENOMINATOR) + amountInWithFee);

        if (amountOut < minAmountOut) {
            revert InsufficientOutputAmount();
        }

        if (isToken0) {
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }

        outputToken.safeTransfer(msg.sender, amountOut);
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
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
}
