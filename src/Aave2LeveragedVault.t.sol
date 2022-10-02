// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";

import "./external/aave-v2/IAToken.sol";
import "./external/aave-v2/ILendingPool.sol";
import "./external/aave-v2/IAaveIncentivesController.sol";
import "./external/balancer-v2/IBalancerV2WeightedPool.sol";
import "./external/balancer-v2/IBalancerV2Vault.sol";
import "./external/uniswap-v2/IUniswapV2Router02.sol";

import "./harvesters/BalancerPoolManager.sol";
import "./harvesters/Swapper.sol";

import "./Aave2LeveragedVault.sol";

contract Aave2LeveragedVaultTest is Test {
    ERC20 wxdai = ERC20(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);

    Aave2LeveragedVault vault;
    BalancerPoolManager balancerPoolManager;
    Swapper swapper;

    function setUp() public {
        vm.createSelectFork(vm.envString("GNOSIS_RPC"));
        vault = new Aave2LeveragedVault(
            ERC20(wxdai),
            "Agave xDai",
            "AXDAI",
            ILendingPool(0x5E15d5E33d318dCEd84Bfe3F4EACe07909bE6d9c),
            IAaveIncentivesController(0xfa255f5104f129B78f477e9a6D050a02f31A5D86)
        );
        balancerPoolManager = new BalancerPoolManager();
        swapper = new Swapper();
        vault.setMaxCollateralRatio(0.8e18);
        vault.setTargetCollateralRatio(0.78e18);
        vault.setManager(address(this));
        wxdai.approve(address(vault), type(uint256).max);
        vault.setHarvestFee(0.05e18);
    }

    function testAgave() public {
        deal(address(wxdai), address(this), 100e18);
        vault.deposit(100e18, address(this));
        vault.rebalance();

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 17280);

        Harvestable[] memory harvestables = vault.harvestable();

        IBalancerV2WeightedPool balancerPool = IBalancerV2WeightedPool(harvestables[0].token);
        IBalancerV2Vault balancerVault = IBalancerV2Vault(balancerPool.getVault());
        (
            address[] memory tokens, ,
        ) = balancerVault.getPoolTokens(balancerPool.getPoolId());

        IUniswapV2Router02 honeyswapRouter = IUniswapV2Router02(0x1C232F01118CB8B424793ae03F870aa7D0ac7f77);

        address[] memory agveSwapPath = new address[](3);
        agveSwapPath[0] = tokens[0];
        agveSwapPath[1] = address(0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1);
        agveSwapPath[2] = address(wxdai);

        address[] memory gnoSwapPath = new address[](2);
        gnoSwapPath[0] = tokens[1];
        gnoSwapPath[1] = address(wxdai);

        vault.allowHarvester(address(balancerPoolManager), true);
        vault.allowHarvester(address(swapper), true);

        uint256[] memory minAmountsOut = new uint256[](2);

        HarvestCall[] memory calls = new HarvestCall[](3);
        calls[0] = HarvestCall({
            target: address(balancerPoolManager),
            callData: abi.encodeWithSelector(
                balancerPoolManager.exitPool.selector,
                address(balancerPool),
                minAmountsOut
            )
        });
        calls[1] = HarvestCall({
            target: address(swapper),
            callData: abi.encodeWithSelector(
                swapper.uniswapSwap.selector,
                honeyswapRouter,
                agveSwapPath,
                minAmountsOut[0]
            )
        });
        calls[2] = HarvestCall({
            target: address(swapper),
            callData: abi.encodeWithSelector(
                swapper.uniswapSwap.selector,
                honeyswapRouter,
                gnoSwapPath,
                minAmountsOut[0]
            )
        });
        vault.harvest(calls);

        console.log("profit", vault.totalAssets());
    }
}