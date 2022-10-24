// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./Vault.sol";

abstract contract SimpleVault is Vault {
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) Vault(_asset, _name, _symbol) {}

    /////  Vault hooks  /////

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this)) + getSuppliedToProtocol();
    }

    function onDeposit(uint256 assets) internal override {
        supplyToProtocol(assets);
    }

    function onWithdraw(uint256 assets) internal override {
        redeemFromProtocol(assets);
    }

    function onHarvest() internal override {
        collectHarvest();
    }

    function afterHarvest() internal override {
        uint256 assetBalance = asset.balanceOf(address(this));

        if (assetBalance > 0) {
            supplyToProtocol(assetBalance);
        }
    }

    /////  Hooks  /////

    /**
     * @notice Get amount of assets supplied to the protocol by the vault
     * @return Assets supplied
     */
    function getSuppliedToProtocol() public view virtual returns (uint256);

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
     * @notice Colect rewards token from protocol
     */
    function collectHarvest() internal virtual {}
}
