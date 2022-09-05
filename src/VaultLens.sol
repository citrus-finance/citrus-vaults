pragma solidity >=0.8.0;

import "./mixins/Vault.sol";

import "./utils/LogExpMath.sol";

contract VaultLens {
    struct VaultMetadata {
        address vault;
        address asset;
        int256 apy;
        Harvestable[] harvestable;
    }

    function getVaultMetadata(Vault vault) public view returns (VaultMetadata memory) {
        (uint256 diffTimestamp, int256 diffAssetsPerShare) = vault.yield();
        int256 apy = (int256(LogExpMath.pow(uint256(diffAssetsPerShare + 1e18), (365.25 days / diffTimestamp) * 1e18)) - 1e18) * 100;

        return VaultMetadata({
            vault: address(vault),
            asset: address(vault.asset()),
            apy: apy,
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
}