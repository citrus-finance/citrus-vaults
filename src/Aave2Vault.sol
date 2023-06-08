// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "BoringSolidity/interfaces/IERC20.sol";

import "./external/aave-v2/ILendingPool.sol";
import "./external/aave-v2/IAaveIncentivesController.sol";

import "./mixins/SimpleVault.sol";

contract Aave2Vault is SimpleVault {
    ILendingPool lendingPool;

    IAaveIncentivesController incentivesController;

    IERC20 aToken;

    constructor(
        ERC20 asset,
        string memory name,
        string memory symbol,
        ILendingPool _lendingPool,
        IAaveIncentivesController _incentivesController
    ) SimpleVault(asset, name, symbol) {
        lendingPool = _lendingPool;
        incentivesController = _incentivesController;

        DataTypes.ReserveData memory data = lendingPool.getReserveData(
            address(asset)
        );

        aToken = IERC20(data.aTokenAddress);

        asset.approve(address(lendingPool), type(uint256).max);
    }

    function getSuppliedToProtocol() public view override returns (uint256) {
        return aToken.balanceOf(address(this));
    }

    function supplyToProtocol(uint256 amount) internal override {
        lendingPool.deposit(address(asset), amount, address(this), 0);
    }

    function redeemFromProtocol(uint256 amount) internal override {
        lendingPool.withdraw(address(asset), amount, address(this));
    }

    function getRemainingProtocolSupplyCap()
        public
        pure
        override
        returns (uint256)
    {
        return type(uint256).max;
    }

    function collectHarvest() internal override {
        if (address(incentivesController) == address(0)) {
            return;
        }

        address[] memory assets = new address[](1);
        assets[0] = address(aToken);

        incentivesController.claimRewards(
            assets,
            incentivesController.getRewardsBalance(assets, address(this)),
            address(this)
        );
    }

    function harvestable() public view override returns (Harvestable[] memory) {
        if (address(incentivesController) == address(0)) {
            return new Harvestable[](0);
        }

        address[] memory assets = new address[](1);
        assets[0] = address(aToken);

        address rewardToken = incentivesController.REWARD_TOKEN();
        uint256 amount = incentivesController.getRewardsBalance(
            assets,
            address(this)
        );

        Harvestable[] memory arr = new Harvestable[](1);
        arr[0] = Harvestable({token: rewardToken, amount: amount});
        return arr;
    }
}
