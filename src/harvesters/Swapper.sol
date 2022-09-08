pragma solidity >=0.8.0;

import "solmate/tokens/ERC20.sol";

import "../external/uniswap-v2/IUniswapV2Router02.sol";

contract Swapper {
    function uniswapSwap(
        address router,
        address[] memory path,
        uint256 minAmountOut
    ) public {
        IUniswapV2Router02 honeyswapRouter = IUniswapV2Router02(router);
        honeyswapRouter.swapExactTokensForTokens(
            ERC20(path[0]).balanceOf(address(this)),
            minAmountOut,
            path,
            address(this),
            block.timestamp
        );
    }
}
