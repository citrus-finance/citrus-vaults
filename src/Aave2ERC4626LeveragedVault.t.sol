// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";

import "./external/aave-v2/IAToken.sol";
import "./external/aave-v2/ILendingPool.sol";
import "./external/aave-v2/IAaveIncentivesController.sol";
import "./external/balancer-v2/IBalancerV2WeightedPool.sol";
import "./external/balancer-v2/IBalancerV2Vault.sol";
import "./external/uniswap-v2/IUniswapV2Router02.sol";
import "./external/erc4626/IERC4626.sol";

import "./harvesters/BalancerPoolManager.sol";
import "./harvesters/Swapper.sol";

import "./Aave2ERC4626LeveragedVault.sol";

contract Aave2ERC4626LeveragedVaultTest is Test {
    ERC20 wxdai = ERC20(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);

    Aave2ERC4626LeveragedVault vault;
    BalancerPoolManager balancerPoolManager;
    Swapper swapper;

    function setUp() public {
        vm.createSelectFork(vm.envString("GNOSIS_RPC"));
        vault = new Aave2ERC4626LeveragedVault(
            ERC20(wxdai),
            "Agave xDai",
            "AXDAI",
            ILendingPool(0x5E15d5E33d318dCEd84Bfe3F4EACe07909bE6d9c),
            IAaveIncentivesController(0xfa255f5104f129B78f477e9a6D050a02f31A5D86),
            IERC4626(0xaf204776c7245bF4147c2612BF6e5972Ee483701)
        );
        vault.setMaxCollateralRatio(0.75e18);
        vault.setTargetCollateralRatio(0.74e18);
        vault.setManager(address(this));
        vault.setWithdrawalFee(0.001e18);
        wxdai.approve(address(vault), type(uint256).max);
    }

    function testAgaveSDai() public {
        deal(address(wxdai), address(this), 100e18);
        vault.deposit(100e18, address(this));

        vault.rebalance();

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 17280);

        HarvestCall[] memory calls = new HarvestCall[](0);
        vault.harvest(calls, 0);

        console.log("profit", vault.totalAssets());

        vault.redeem(vault.balanceOf(address(this)), address(this), address(this));
    }
}