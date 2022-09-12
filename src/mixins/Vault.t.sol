// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "./Vault.sol";

contract MockVault is Vault {
    constructor(
        MockERC20 asset
    ) Vault(asset, "Vault Test", "VTest") {}

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function harvestable() public override view returns (Harvestable[] memory harvestables) {}
}

contract VaultTest is Test {
    MockERC20 public token;
    Vault public vault;
    address public feeTaker = makeAddr("fee taker");

    function setUp() public {
        token = new MockERC20("Test", "TST", 18);
        vault = new MockVault(
            token
        );

        vault.setManager(address(this));

        token.approve(address(vault), type(uint256).max);

        vault.setFeeTaker(feeTaker);
        
        vault.allowHarvestCall(address(token), 0x40c10f19, true);
    }

    function testFeeOnWithdrawal() public {
        vault.setWithdrawalFee(0.01e18); // 1%

        token.mint(address(this), 1000e18);

        assertEq(vault.balanceOf(address(this)), 0);

        vault.deposit(900e18, makeAddr("user 1"));
        vault.deposit(100e18, address(this));

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(this)), 100e18);

        vault.withdraw(99e18, address(this), address(this));

        assertEq(token.balanceOf(address(this)), 99e18);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(feeTaker), 1e18);
    }

    function testFeeOnRedeem() public {
        vault.setWithdrawalFee(0.01e18); // 1%

        token.mint(address(this), 1000e18);

        assertEq(vault.balanceOf(address(this)), 0);

        vault.deposit(900e18, makeAddr("user 1"));
        vault.deposit(100e18, address(this));

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(this)), 100e18);

        vault.redeem(100e18, address(this), address(this));

        assertEq(token.balanceOf(address(this)), 99e18);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(vault)), 901e18);
        assertEq(vault.balanceOf(feeTaker), 1e18);
    }

    function testExcludedFromFeeOnWithdrawal() public {
        vault.setWithdrawalFee(0.01e18); // 1%
        vault.excludeFromFees(address(this), true);

        token.mint(address(this), 1000e18);

        assertEq(vault.balanceOf(address(this)), 0);

        vault.deposit(900e18, makeAddr("user 1"));
        vault.deposit(100e18, address(this));

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(this)), 100e18);

        vault.withdraw(100e18, address(this), address(this));

        assertEq(token.balanceOf(address(this)), 100e18);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(feeTaker), 0);
    }

    function testExcludedFromFeeOnRedeem() public {
        vault.setWithdrawalFee(0.01e18); // 1%
        vault.excludeFromFees(address(this), true);

        token.mint(address(this), 1000e18);

        assertEq(vault.balanceOf(address(this)), 0);

        vault.deposit(900e18, makeAddr("user 1"));
        vault.deposit(100e18, address(this));

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(this)), 100e18);

        vault.redeem(100e18, address(this), address(this));

        assertEq(token.balanceOf(address(this)), 100e18);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(vault)), 900e18);
        assertEq(vault.balanceOf(feeTaker), 0);
    } 

    function testPreviewWithdraw() public {
        vault.setWithdrawalFee(0.01e18); // 1%

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));
        token.mint(address(vault), 100e18);

        assertEq(vault.previewWithdraw(198e18), 100e18);
    }

    function testPreviewRedeem() public {
        vault.setWithdrawalFee(0.01e18); // 1%

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));
        token.mint(address(vault), 100e18);

        assertEq(vault.previewRedeem(100e18), 198e18);
    }

    function testConvertToShares() public {
        vault.setWithdrawalFee(0.01e18); // 1%

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));
        token.mint(address(vault), 100e18);

        assertEq(vault.convertToShares(200e18), 100e18);
    }

    function testConvertToAssets() public {
        vault.setWithdrawalFee(0.01e18); // 1%

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));
        token.mint(address(vault), 100e18);

        assertEq(vault.convertToAssets(100e18), 200e18);
    }

    function testHarvest() public {
        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 100e18);

        HarvestCall[] memory calls = new HarvestCall[](0);
        token.mint(address(vault), 1e18);
        vault.harvest(calls);

        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 101e18);
    }

    function testHarvestWithFees() public {
        vault.setHarvestFee(0.1e18); // 10%

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 100e18);

        HarvestCall[] memory calls = new HarvestCall[](0);
        token.mint(address(vault), 9e18);
        vault.harvest(calls);

        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 109e18);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 109e18);
    }

    function testNotOnHarvestWhitelist() public {
        vault.allowHarvestCall(address(token), 0x40c10f19, false);

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 100e18);

        HarvestCall[] memory calls = new HarvestCall[](1);
        calls[0] = HarvestCall({
            target: address(token),
            callData: abi.encodeWithSignature("mint(address,uint256)", address(vault), 1e18)
        });
        vm.expectRevert(bytes("method not whitelisted"));
        vault.harvest(calls);

        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 100e18);
    }

    function testCheckpoints() public {
        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        assertEq(vault.convertToAssets(1e18), 1e18);

        skip(999);

        HarvestCall[] memory calls = new HarvestCall[](0);
        token.mint(address(vault), 10e18);
        vault.harvest(calls);

        assertEq(vault.convertToAssets(1e18), 1.1e18);

        assertEq(vault.harvestCheckpointsLength(), 2);
        
        HarvestCheckpoint[] memory checkpoints = vault.selectHarvestCheckpoints(0, 1);
        
        assertEq(checkpoints.length, 2);
        assertEq(checkpoints[0].blockTimestamp, 1);
        assertEq(checkpoints[0].assetsPerShare, 1e18);
        assertEq(checkpoints[1].blockTimestamp, 1000);
        assertEq(checkpoints[1].assetsPerShare, 1.1e18);

        HarvestCheckpoint[] memory invertedCheckpoints = vault.selectInvertedHarvestCheckpoints(0, 1);

        assertEq(invertedCheckpoints.length, 2);
        assertEq(invertedCheckpoints[0].blockTimestamp, 1000);
        assertEq(invertedCheckpoints[0].assetsPerShare, 1.1e18);
        assertEq(invertedCheckpoints[1].blockTimestamp, 1);
        assertEq(invertedCheckpoints[1].assetsPerShare, 1e18);
    }

    function testYield() public {
        HarvestCall[] memory calls = new HarvestCall[](0);

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        skip(1 days);

        token.mint(address(vault), 0.04e18);
        
        vault.harvest(calls);

        (uint256 diffTimestamp, int256 diffAssetsPerShare) = vault.yield();

        assertEq(diffTimestamp, 1 days);
        assertEq(diffAssetsPerShare, 0.0004e18);
    }

    function testYieldWithRollingTimestamp() public {
        HarvestCall[] memory calls = new HarvestCall[](0);

        token.mint(address(this), 90e18);
        vault.deposit(90e18, address(this));

        skip(type(uint32).max - 50);

        token.mint(address(vault), 10e18);

        vault.harvest(calls);

        skip(1 days);

        token.mint(address(vault), 0.04e18);

        vault.harvest(calls);


        (uint256 diffTimestamp, int256 diffAssetsPerShare) = vault.yield();

        assertEq(diffTimestamp, 1 days);
        assertApproxEqAbs(diffAssetsPerShare, 0.0004e18, 1);
    }

    function testNegativeYield() public {
        HarvestCall[] memory calls = new HarvestCall[](0);

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        token.burn(address(vault), 0.04e18);

        skip(1 days);

        token.mint(address(vault), 1);

        vault.harvest(calls);

        (uint256 diffTimestamp, int256 diffAssetsPerShare) = vault.yield();

        assertEq(diffTimestamp, 1 days);
        assertApproxEqAbs(diffAssetsPerShare, -0.0004e18, 1);
    }
}
