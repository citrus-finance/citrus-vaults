// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "BoringSolidity/interfaces/IERC20.sol";

import "./external/aave-v2/IAToken.sol";
import "./external/aave-v2/ILendingPool.sol";
import "./external/aave-v2/IAaveIncentivesController.sol";

import "./mixins/LeveragedLendingVault.sol";


contract Aave2LeveragedVault is LeveragedLendingVault {
    ILendingPool lendingPool;
    
    IAaveIncentivesController incentivesController;

    IERC20 aToken;
    
    IERC20 debtToken;
    
    constructor(
        ERC20 asset,
        string memory name,
        string memory symbol,
        ILendingPool _lendingPool,
        IAaveIncentivesController _incentivesController
    ) LeveragedLendingVault(asset, name, symbol) {
        lendingPool = _lendingPool;
        incentivesController = _incentivesController;

        DataTypes.ReserveData memory data = lendingPool.getReserveData(address(asset));

        aToken = IERC20(data.aTokenAddress);
        debtToken = IERC20(data.variableDebtTokenAddress);

        asset.approve(address(lendingPool), type(uint256).max);
    }

    function getSuppliedToProtocol() public override view returns (uint256) {
        return aToken.balanceOf(address(this));
    }

    function getBorrowedFromProtocol() public override view returns (uint256) {
        return debtToken.balanceOf(address(this));
    }

    function supplyToProtocol(uint256 amount) internal override {
        lendingPool.deposit(address(asset), amount, address(this), 0);
    }

    function redeemFromProtocol(uint256 amount) internal override {
        lendingPool.withdraw(address(asset), amount, address(this));
    }

    function borrowFromProtocol(uint256 amount) internal override {
        lendingPool.borrow(address(asset), amount, 2, 0, address(this));
    }

    function repayToProtocol(uint256 amount) internal override {
        lendingPool.repay(address(asset), amount, 2, address(this));
    }

    function getProtocolLiquidity() public override view returns (uint256) {
        return aToken.totalSupply() - debtToken.totalSupply();
    }

    function getRemainingProtocolSupplyCap() public override pure returns (uint256) {
        return type(uint256).max;
    }

    function getRemainingProtocolBorrowCap() public override pure returns (uint256) {
        return type(uint256).max;
    }

    function collectHarvest() internal override {
        address[] memory assets = new address[](2);
        assets[0] = address(aToken);
        assets[1] = address(debtToken);

        incentivesController.claimRewards(
            assets,
            incentivesController.getRewardsBalance(assets, address(this)),
            address(this)
        );
    }

    function harvestable() public override view returns (Harvestable[] memory) {
        address[] memory assets = new address[](2);
        assets[0] = address(aToken);
        assets[1] = address(debtToken);

        address rewardToken = incentivesController.REWARD_TOKEN();
        uint256 amount = incentivesController.getRewardsBalance(assets, address(this));

        Harvestable[] memory arr = new Harvestable[](1);
        arr[0] = Harvestable({
            token: rewardToken,
            amount: amount
        });
        return arr;
    }
}
