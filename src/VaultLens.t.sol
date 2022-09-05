pragma solidity >= 0.8.0;

import "forge-std/Test.sol";

import "solmate/test/utils/mocks/MockERC20.sol";

import "./mixins/Vault.sol";
import "./VaultLens.sol";

contract MockVault is Vault {
    using stdStorage for StdStorage;

    constructor(
        MockERC20 asset
    ) Vault(asset, "Vault Test", "VTest") {}

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function harvestable() public override view returns (Harvestable[] memory harvestables) {}
}

contract VaultLensTest is Test {
    using stdStorage for StdStorage;

    MockERC20 public token;
    Vault public vault;
    VaultLens public lens = new VaultLens();

    function setUp() public {
        token = new MockERC20("Test", "TST", 18);
        vault = new MockVault(
            token
        );

        vault.setManager(address(this));

        token.approve(address(vault), type(uint256).max);
        vault.allowHarvestCall(address(token), 0x40c10f19, true);
    }

    function testVaultMetadata() public {
        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        VaultLens.VaultMetadata memory metadata = lens.getVaultMetadata(vault);

        assertEq(metadata.vault, address(vault));
        assertEq(metadata.asset, address(token));
        assertEq(metadata.apy, 0);
    }

    function testAPY() public {
        HarvestCall[] memory calls = new HarvestCall[](1);

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        skip(1 days);

        calls[0] = HarvestCall({
            target: address(token),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(vault), 0.04e18)
        });
        vault.harvest(calls);

        VaultLens.VaultMetadata memory metadata = lens.getVaultMetadata(vault);

        assertApproxEqAbs(metadata.apy, 15.7e18, 0.1e18);
    }

    function testAPYWithRollingTimestamp() public {
        HarvestCall[] memory calls = new HarvestCall[](1);

        token.mint(address(this), 90e18);
        vault.deposit(90e18, address(this));

        skip(type(uint32).max - 50);

        calls[0] = HarvestCall({
            target: address(token),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(vault), 10e18)
        });
        vault.harvest(calls);

        skip(1 days);

        calls[0] = HarvestCall({
            target: address(token),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(vault), 0.04e18)
        });
        vault.harvest(calls);

        VaultLens.VaultMetadata memory metadata = lens.getVaultMetadata(vault);

        assertApproxEqAbs(metadata.apy, 15.7e18, 0.1e18);
    }

    function testNegativeAPY() public {
        HarvestCall[] memory calls = new HarvestCall[](1);

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        token.burn(address(vault), 0.04e18);

        skip(1 days);

        calls[0] = HarvestCall({
            target: address(token),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(vault), 1)
        });
        vault.harvest(calls);

        VaultLens.VaultMetadata memory metadata = lens.getVaultMetadata(vault);

        assertApproxEqAbs(metadata.apy, -13.6e18, 0.1e18);
    }

    function testVaultsMetadata() public {
        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        Vault[] memory vaults = new Vault[](1);
        vaults[0] = vault;
        VaultLens.VaultMetadata[] memory metadataArr = lens.getVaultsMetadata(vaults);

        assertEq(metadataArr[0].vault, address(vault));
        assertEq(metadataArr[0].asset, address(token));
        assertEq(metadataArr[0].apy, 0);
    }
}

