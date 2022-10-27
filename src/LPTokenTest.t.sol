// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "BoringSolidity/interfaces/IERC20.sol";
import "solmate/tokens/ERC20.sol";

import "./external/saddle/ISwap.sol";

contract LPTokenTest is Test {
    ERC20 usdc = ERC20(0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83);
    ISwap swap = ISwap(0x5C32143C8B198F392d01f8446b754c181224ac26);
    ERC20 HopLpUsdc = ERC20(0x9D373d22FD091d7f9A6649EB067557cc12Fb1A0A);

    function setUp() public {
        vm.createSelectFork(vm.envString("GNOSIS_RPC"));
    }

    function testWithHToken() public {
        deal(address(usdc), address(this), 1000e6);
        IERC20 token0 = swap.getToken(0);
        IERC20 token1 = swap.getToken(1);

        console.log("token0 balance", swap.getTokenBalance(0));
        console.log("token1 balance", swap.getTokenBalance(1));

        token0.approve(address(swap), type(uint256).max);
        token1.approve(address(swap), type(uint256).max);

        swap.swap(0, 1, 100e6, 0, block.timestamp + 1 days);

        uint256 amount1 = token1.balanceOf(address(this));

        uint256[] memory amounts = new uint256[](2);

        amounts[0] = 0;
        amounts[1] = amount1;

        swap.addLiquidity(amounts, 0, block.timestamp + 1 days);

        uint256 LPTokenAmount = HopLpUsdc.balanceOf(address(this));

        console.log("block.number", block.number);
        console.log("LPToken amount:", LPTokenAmount);
    }

    function testWithoutHToken() public {
        deal(address(usdc), address(this), 1000e6);
        IERC20 token0 = swap.getToken(0);
        IERC20 token1 = swap.getToken(1);

        console.log("token0 balance", swap.getTokenBalance(0));
        console.log("token1 balance", swap.getTokenBalance(1));

        token0.approve(address(swap), type(uint256).max);
        token1.approve(address(swap), type(uint256).max);

        uint256[] memory amounts = new uint256[](2);

        amounts[0] = 100e6;
        amounts[1] = 0;

        swap.addLiquidity(amounts, 0, block.timestamp + 1 days);

        uint256 LPTokenAmount = HopLpUsdc.balanceOf(address(this));

        console.log("block.number", block.number);
        console.log("LPToken amount:", LPTokenAmount);
    }
}
