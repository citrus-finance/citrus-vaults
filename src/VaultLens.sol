// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./mixins/Vault.sol";

import "./utils/LogExpMath.sol";

contract VaultLens {
    struct VaultMetadata {
        address vault;
        address asset;
        int256 apy;
        uint8 decimals;
        uint256 totalAssets;
        Harvestable[] harvestable;
    }

    struct UserVaultMetadata {
        address vault;
        address asset;
        int apy;
        uint8 decimals;
        uint balance;
        uint assetBalance;
    }

    function getVaultMetadata(Vault vault) public view returns (VaultMetadata memory) {
        uint8 decimals = vault.decimals();

        (uint256 diffTimestamp, int256 diffAssetsPerShare) = vault.yield();
        int256 apy = (int256(LogExpMath.pow(uint256(diffAssetsPerShare + 1e18), (365 days / diffTimestamp) * 1e18)) - 1e18) * 100;

        return VaultMetadata({
            vault: address(vault),
            asset: address(vault.asset()),
            apy: apy,
            decimals: decimals,
            totalAssets: vault.totalAssets(),
            harvestable: vault.harvestable()
        });
    }

    function getVaultsMetadata(Vault[] calldata vaults) public view returns (VaultMetadata[] memory) {
        VaultMetadata[] memory arr = new VaultMetadata[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            arr[i] = getVaultMetadata(vaults[i]);
        }
        return arr;
    }

    function getUserVaultMetadata(address user, Vault vault) public view returns (UserVaultMetadata memory) {
        uint8 decimals = vault.decimals();
        uint balance = vault.convertToAssets(vault.balanceOf(user));
        uint assetBalance = vault.asset().balanceOf(user);

        (uint256 diffTimestamp, int256 diffAssetsPerShare) = vault.yield();
        int256 apy = (int256(LogExpMath.pow(uint256(diffAssetsPerShare + 1e18), (365 days / diffTimestamp) * 1e18)) - 1e18) * 100;

        return UserVaultMetadata({
            vault: address(vault),
            asset: address(vault.asset()),
            apy: apy,
            decimals: decimals,
            balance: balance,
            assetBalance: assetBalance
        });
    }

    function getUserVaultsMetadata(address user, Vault[] calldata vaults) public view returns (UserVaultMetadata[] memory) {
        UserVaultMetadata[] memory arr = new UserVaultMetadata[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            arr[i] = getUserVaultMetadata(user, vaults[i]);
        }
        return arr;
    }
}
