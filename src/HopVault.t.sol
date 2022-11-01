// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";

import "./external/uniswap-v1/IStakingRewards.sol";
import "./external/saddle/ISwap.sol";

import "./harvesters/Swapper.sol";
import "./harvesters/SaddlePoolManager.sol";

import "./HopVault.sol";

contract HopVaultTest is Test {
    ERC20 wxdai = ERC20(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
    ERC20 HopLpDai = ERC20(0x5300648b1cFaa951bbC1d56a4457083D92CFa33F);
    IStakingRewards stakingRewards =
        IStakingRewards(0x12a3a66720dD925fa93f7C895bC20Ca9560AdFe7);
    ISwap swap = ISwap(0x24afDcA4653042C6D08fb1A754b2535dAcF6Eb24);

    HopVault vault;
    Swapper swapper;

    function setUp() public {
        vm.createSelectFork(vm.envString("GNOSIS_RPC"));
        vault = new HopVault(
            ERC20(HopLpDai),
            "HOP LP DAI",
            "HOPXDAI",
            stakingRewards
        );

        swapper = new Swapper();
        vault.setManager(address(this));
        wxdai.approve(address(vault), type(uint256).max);
        HopLpDai.approve(address(vault), type(uint256).max);
        vault.setHarvestFee(0.05e18);
    }

    function testHopWithoutSwap() public {
        deal(address(HopLpDai), address(this), 100e18);
        vault.deposit(100e18, address(this));

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 17280);

        IUniswapV2Router02 honeyswapRouter = IUniswapV2Router02(
            0x1C232F01118CB8B424793ae03F870aa7D0ac7f77
        );
        address[] memory path = new address[](2);
        path[0] = address(0x9C58BAcC331c9aa871AFD802DB6379a98e80CEdb);
        path[1] = address(wxdai);

        SaddlePoolManager saddlePoolManager = new SaddlePoolManager();

        vault.allowHarvester(address(swapper), true);
        vault.allowHarvester(address(saddlePoolManager), true);

        HarvestCall[] memory calls = new HarvestCall[](2);

        calls[0] = HarvestCall({
            target: address(swapper),
            callData: abi.encodeWithSelector(
                swapper.uniswapSwap.selector,
                honeyswapRouter,
                path,
                0
            )
        });
        calls[1] = HarvestCall({
            target: address(saddlePoolManager),
            callData: abi.encodeWithSelector(
                saddlePoolManager.addLiquidity.selector,
                address(swap),
                0,
                0
            )
        });

        vault.harvest(calls, 0);

        console.log("profit", vault.totalAssets());
    }

    function testHopWithSwap() public {
        deal(address(HopLpDai), address(this), 100e18);
        vault.deposit(100e18, address(this));

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 17280);

        IUniswapV2Router02 honeyswapRouter = IUniswapV2Router02(
            0x1C232F01118CB8B424793ae03F870aa7D0ac7f77
        );
        address[] memory path = new address[](2);
        path[0] = address(0x9C58BAcC331c9aa871AFD802DB6379a98e80CEdb);
        path[1] = address(wxdai);

        SaddlePoolManager saddlePoolManager = new SaddlePoolManager();

        vault.allowHarvester(address(swapper), true);
        vault.allowHarvester(address(saddlePoolManager), true);

        HarvestCall[] memory calls = new HarvestCall[](2);

        calls[0] = HarvestCall({
            target: address(swapper),
            callData: abi.encodeWithSelector(
                swapper.uniswapSwap.selector,
                honeyswapRouter,
                path,
                0
            )
        });
        calls[1] = HarvestCall({
            target: address(saddlePoolManager),
            callData: abi.encodeWithSelector(
                saddlePoolManager.swapAndAddLiquidity.selector,
                address(swap),
                0,
                0
            )
        });

        vault.harvest(calls, 0);

        console.log("profit", vault.totalAssets());
    }
}
