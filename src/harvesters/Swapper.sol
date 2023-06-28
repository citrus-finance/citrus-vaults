// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "solmate/tokens/ERC20.sol";

import "../external/uniswap-v2/IUniswapV2Router02.sol";

contract Swapper {
    function uniswapSwap(
        address router,
        address[] memory path
    ) public {
        uint256 amountIn = ERC20(path[0]).balanceOf(address(this)) - 1;
        ERC20(path[0]).approve(router, amountIn);
        IUniswapV2Router02 honeyswapRouter = IUniswapV2Router02(router);
        honeyswapRouter.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function approveAndCall(
        address exchange,
        bytes calldata data,
        address inputToken
     ) public {
        uint256 amountIn = ERC20(inputToken).balanceOf(address(this));

        ERC20(inputToken).approve(exchange, amountIn);

        (bool success, string memory errorMessage) = address(exchange).call(data);
        if (!success) {
            revert(errorMessage);
        }
    }
}
