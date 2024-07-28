// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "./Vault.sol";

contract MockVault is Vault {
    constructor(
        MockERC20 asset,
        address manager
    ) Vault(asset, "Vault Test", "VTest", manager) {}

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function harvestable() public override view returns (Harvestable[] memory harvestables) {}
}

contract VaultTest is Test {
    MockERC20 public token;
    Vault public vault;

    function setUp() public {
        token = new MockERC20("Test", "TST", 18);
        vault = new MockVault(
            token,
            address(this)
        );

        token.approve(address(vault), type(uint256).max);
    }

    function testHarvest() public {
        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 100e18);

        token.mint(address(vault), 1e18);
        vault.harvest(address(0), bytes(""));

        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 101e18);
    }

    function testHarvestWithFees() public {
        vault.setHarvestFee(0.1e18); // 10%

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 100e18);

        token.mint(address(vault), 9e18);
        vault.harvest(address(0), bytes(""));

        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 109e18);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 109e18);
    }

    // event UpdateHarvestFee(uint256 oldFee, uint256 newFee);

    function testHarvestFeeEvent() public {
        vm.expectEmit(false, false, false, true, address(vault));
        // emit UpdateHarvestFee(0, 0.1e18);
        vault.setHarvestFee(0.1e18); // 10%
    }

    function testYield() public {
        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        skip(1 days);

        token.mint(address(vault), 0.04e18);
        
        vault.harvest(address(0), bytes(""));

        (uint256 diffTimestamp, uint256 diffAssetsPerShare) = vault.yield();

        assertEq(diffTimestamp, 1 days);
        assertEq(diffAssetsPerShare, 0.0004e18);
    }

    function testNegativeYield() public {
        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        token.burn(address(vault), 0.04e18);

        skip(1 days);

        token.burn(address(vault), 1);

        vault.harvest(address(0), bytes(""));

        (uint256 diffTimestamp, uint256 diffAssetsPerShare) = vault.yield();

        assertEq(diffTimestamp, 1.5 days);
        assertEq(diffAssetsPerShare, 0);
    }

    function testExpiredYield() public {
        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        skip(1 days);

        token.mint(address(vault), 0.04e18);
        
        vault.harvest(address(0), bytes(""));

        skip(2 days);

        (uint256 diffTimestamp, uint256 diffAssetsPerShare) = vault.yield();

        assertEq(diffTimestamp, 1.5 days);
        assertEq(diffAssetsPerShare, 0);
    }
}
