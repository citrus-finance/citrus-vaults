// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "solmate/tokens/ERC20.sol";

import "../external/uniswap-v2/IUniswapV2Router02.sol";

contract Swapper {
    function uniswapSwap(
        address router,
        address[] memory path,
        uint256 minAmountOut
    ) public {
        uint256 amountIn = ERC20(path[0]).balanceOf(address(this)) - 1;
        ERC20(path[0]).approve(router, amountIn);
        IUniswapV2Router02 honeyswapRouter = IUniswapV2Router02(router);
        honeyswapRouter.swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            address(this),
            block.timestamp
        );
    }
}
