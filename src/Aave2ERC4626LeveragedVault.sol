// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "BoringSolidity/interfaces/IERC20.sol";

import "./external/aave-v2/ILendingPool.sol";
import "./external/aave-v2/IAaveIncentivesController.sol";
import "./external/erc4626/IERC4626.sol";

import "./mixins/LeveragedLendingVault.sol";

contract Aave2ERC4626LeveragedVault is LeveragedLendingVault {
    ILendingPool lendingPool;

    IAaveIncentivesController incentivesController;

    IERC20 aToken;

    IERC20 debtToken;

    IERC4626 vault;

    constructor(
        ERC20 asset,
        string memory name,
        string memory symbol,
        ILendingPool _lendingPool,
        IAaveIncentivesController _incentivesController,
        IERC4626 _vault
    ) LeveragedLendingVault(asset, name, symbol) {
        lendingPool = _lendingPool;
        incentivesController = _incentivesController;

        DataTypes.ReserveData memory assetData = lendingPool.getReserveData(address(asset));
        DataTypes.ReserveData memory debtData = lendingPool.getReserveData(address(_vault));

        aToken = IERC20(assetData.aTokenAddress);
        debtToken = IERC20(debtData.variableDebtTokenAddress);
        vault = _vault;

        asset.approve(address(lendingPool), type(uint256).max);
        asset.approve(address(vault), type(uint256).max);
        vault.approve(address(lendingPool), type(uint256).max);
    }

    function getSuppliedToProtocol() public override view returns (uint256) {
        return aToken.balanceOf(address(this));
    }

    function getBorrowedFromProtocol() public override view returns (uint256) {
        return vault.previewMint(debtToken.balanceOf(address(this)));
    }

    function supplyToProtocol(uint256 amount) internal override {
        lendingPool.deposit(address(asset), amount, address(this), 0);
    }

    function redeemFromProtocol(uint256 amount) internal override {
        lendingPool.withdraw(address(asset), amount, address(this));
    }

    function borrowFromProtocol(uint256 amount) internal override {
        uint256 shares = vault.previewWithdraw(amount);
        lendingPool.borrow(address(vault), shares, 2, 0, address(this));
        vault.redeem(shares, address(this), address(this));
    }

    function repayToProtocol(uint256 amount) internal override {
        uint256 shares = vault.previewDeposit(amount);
        vault.mint(shares, address(this));
        lendingPool.repay(address(vault), shares, 2, address(this));
    }

    function getProtocolLiquidity() public override view returns (uint256) {
        return aToken.totalSupply() - vault.previewMint(debtToken.totalSupply());
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
