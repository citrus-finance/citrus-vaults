// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "BoringSolidity/interfaces/IERC20.sol";

import "../external/saddle/ISwap.sol";

contract SaddlePoolManager {
    function addLiquidity(
        address swap,
        uint256 amountIn,
        uint8 pooledTokensNum,
        uint8 tokenIndexFrom
    ) public returns (uint256 LPTokens) {
        ISwap hopSwap = ISwap(swap);
        IERC20 tokenFrom = IERC20(hopSwap.getToken(tokenIndexFrom));
        uint256 tokensIn = amountIn;

        if (amountIn == 0) {
            tokensIn = tokenFrom.balanceOf(address(this)) - 1;
        }

        uint256[] memory amounts = new uint256[](pooledTokensNum);
        amounts[tokenIndexFrom] = tokensIn;

        tokenFrom.approve(swap, tokensIn);

        LPTokens = hopSwap.addLiquidity(amounts, 0, block.timestamp);
    }

    function swapAndAddLiquidity(
        address swap,
        uint256 amountIn,
        uint8 pooledTokensNum,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo
    ) public returns (uint256 LPTokens) {
        ISwap hopSwap = ISwap(swap);
        IERC20 tokenFrom = IERC20(hopSwap.getToken(tokenIndexFrom));
        uint256 tokensIn = amountIn;

        if (amountIn == 0) {
            tokensIn = tokenFrom.balanceOf(address(this)) - 1;
        }

        tokenFrom.approve(swap, tokensIn);

        uint256 hTokens = hopSwap.swap(
            tokenIndexFrom,
            tokenIndexTo,
            tokensIn,
            0,
            block.timestamp
        );

        LPTokens = addLiquidity(swap, hTokens, pooledTokensNum, tokenIndexTo);
    }
}
