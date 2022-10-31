// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "BoringSolidity/interfaces/IERC20.sol";

import "../external/saddle/ISwap.sol";

contract SaddlePoolManager {
    function addLiquidity(
        address swap,
        uint256 amountIn,
        uint256 minToMint
    ) public returns (uint256 LPTokens) {
        ISwap hopSwap = ISwap(swap);
        IERC20 token0 = IERC20(hopSwap.getToken(0));
        uint256 tokensIn = amountIn;

        if (amountIn == 0) {
            tokensIn = token0.balanceOf(address(this)) - 1;
        }

        token0.approve(swap, tokensIn);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = tokensIn;
        amounts[1] = 0;

        LPTokens = hopSwap.addLiquidity(amounts, minToMint, block.timestamp);
    }

    function swapAndAddLiquidity(
        address swap,
        uint256 amountIn,
        uint256 minToMint
    ) public returns (uint256 LPTokens) {
        ISwap hopSwap = ISwap(swap);
        IERC20 token0 = IERC20(hopSwap.getToken(0));
        IERC20 token1 = IERC20(hopSwap.getToken(1));
        uint256 tokensIn = amountIn;

        if (amountIn == 0) {
            tokensIn = token0.balanceOf(address(this)) - 1;
        }

        token0.approve(swap, tokensIn);

        uint256 hTokens = hopSwap.swap(0, 1, tokensIn, 0, block.timestamp);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = hTokens;

        token1.approve(swap, hTokens);

        LPTokens = hopSwap.addLiquidity(amounts, minToMint, block.timestamp);
    }
}
