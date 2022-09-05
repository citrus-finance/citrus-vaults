// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "./Vault.sol";

abstract contract LeveragedLendingVault is Vault {
    uint256 targetCollateralRatio;

    uint256 maxCollateralRatio;

    event TargetCollateralRatioUpdated(uint256 oldTargetCollateralRatio, uint256 newTargetCollateralRatio);

    event MaxCollateralRatioUpdated(uint256 oldMaxCollateralRatio, uint256 newMaxCollateralRatio);

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) Vault(_asset, _name, _symbol) {}

    /////  Leverage logic  /////

    function rebalance(uint256 amountToFreeUp, bool totalRampUp) internal {
        uint256 assetBalance = asset.balanceOf(address(this));

        if (assetBalance > 0) {
            supplyToProtocol(assetBalance);
        }

        uint256 borrowed = getBorrowedFromProtocol();
        uint256 supplied = getSuppliedToProtocol();
        uint256 targetBorrow =  FixedPointMathLib.mulDivDown(targetCollateralRatio, supplied - borrowed - amountToFreeUp, 1e18 - targetCollateralRatio);

        if (borrowed < targetBorrow) {
            // ramp up
            while(borrowed * 1e18 < targetBorrow * 0.995e18) {
                uint256 toBorrow = targetBorrow - borrowed;
                uint256 maxBorrow = FixedPointMathLib.mulDivDown(supplied, maxCollateralRatio, 1e18) - borrowed;

                if (toBorrow > maxBorrow) {
                    toBorrow = maxBorrow;
                }

                borrowFromProtocol(toBorrow);
                supplyToProtocol(toBorrow);

                if (!totalRampUp) {
                    break;
                }

                borrowed = getBorrowedFromProtocol();
                supplied = getSuppliedToProtocol();
            }
        } else if (borrowed > targetBorrow) {
            // ramp down
            while(borrowed * 1e18 > targetBorrow * 1.005e18) {
                uint256 toRepay = borrowed - targetBorrow;
                uint256 maxRepay = ((supplied * maxCollateralRatio) / 1e18) - borrowed;

                if (toRepay > maxRepay) {
                    toRepay = maxRepay;
                }
                
                redeemFromProtocol(toRepay);
                repayToProtocol(toRepay);

                borrowed = getBorrowedFromProtocol();
                supplied = getSuppliedToProtocol();
            }
        }

        if (amountToFreeUp > 0) {
            redeemFromProtocol(amountToFreeUp);
        }
    }

    function rebalance() public {
        rebalance(0, true);
    }

    /////  Vault hooks  /////

    function onDeposit(uint256) internal override {
        rebalance(0, false);
    }

    function onWithdraw(uint256 assets) internal override {
        rebalance(assets, false);
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this)) + getSuppliedToProtocol() - getBorrowedFromProtocol();
    }

    function onHarvest() internal override {
        collectHarvest();
    }

    function afterHarvest() internal override {
        rebalance(0, true);
    }

    /////  Collateral ratios  /////

    function setMaxCollateralRatio(uint256 newMaxCollateralRatio) public onlyManagerOrOwner {
        uint oldMaxCollateralRatio = maxCollateralRatio;

        require(msg.sender == owner || newMaxCollateralRatio < oldMaxCollateralRatio, "Only Owner can raise maxCollateralRatio");

        maxCollateralRatio = newMaxCollateralRatio;
        emit MaxCollateralRatioUpdated(oldMaxCollateralRatio, newMaxCollateralRatio);
    }

    function setTargetCollateralRatio(uint256 newTargetCollateralRatio) public onlyOwner {
        require(newTargetCollateralRatio < maxCollateralRatio, "Cannot set targetCollateralRatio over maxCollateralRatio");
        emit TargetCollateralRatioUpdated(targetCollateralRatio, newTargetCollateralRatio);
        targetCollateralRatio = newTargetCollateralRatio;
    }

    /////  Hooks  /////

    /**
     * @notice Get amount of assets supplied to the protocol by the vault
     * @return Assets supplied
     */
    function getSuppliedToProtocol() public virtual view returns (uint256);

    /**
     * @notice Get amount of assets borrowed from the protocol by the vault
     * @return Assets borrowed
     */
    function getBorrowedFromProtocol() public virtual view returns (uint256);

    /**
     * @notice Supply assets to protocol
     * @param amount Assets to supply to the protocol
     */
    function supplyToProtocol(uint256 amount) internal virtual;

    /**
     * @notice Withdraw assets from protocol
     * @param amount Assets to redeem from the protocol
     */
    function redeemFromProtocol(uint256 amount) internal virtual;

    /**
     * @notice Borrow assets from protocol
     * @param amount Assets to borrow from the protocol
     */
    function borrowFromProtocol(uint256 amount) internal virtual;

    /**
     * @notice Repay debt to protocol
     * @param amount Assets to repay to the protocol
     */
    function repayToProtocol(uint256 amount) internal virtual;

    /**
     * @notice Get liquidity availailable in the protocol
     * @return liquidity The diff
     * @dev ignored on this version
     */
    function getProtocolLiquidity() public virtual view returns (uint256);

    /**
     * @notice Get remaining supply cap in the protocol
     * @return remainingSupplyCap
     * @dev ignored on this version
     * @dev should return 0 if the supply cap is exhausted
     */
    function getRemainingProtocolSupplyCap() public virtual view returns (uint256);

    /**
     * @notice Get remaining borrow cap in the protocol
     * @return remainingBorrowCap
     * @dev ignored on this version
     * @dev should return 0 if the borrow cap is exhausted
     */
    function getRemainingProtocolBorrowCap() public virtual view returns (uint256);

    /**
     * @notice Colect rewards token from protocol
     */
    function collectHarvest() internal virtual {}
}