pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "./LeveragedLendingVault.sol";

contract MockLeveragedLendingVault is LeveragedLendingVault {
    constructor(
        MockERC20 asset
    ) LeveragedLendingVault(asset, "Vault Test", "VTest") {}

    uint256 private supplied;

    uint256 private borrowed;

    uint256 private supplyCap = type(uint256).max;

    uint256 private borrowCap = type(uint256).max;

    function getSuppliedToProtocol() public override view returns (uint256) {
        return supplied;
    }

    function getBorrowedFromProtocol() public override view returns (uint256) {
        return borrowed;
    }

    function supplyToProtocol(uint256 amount) internal override {
        supplied += amount;
        supplyCap -= amount;
        MockERC20(address(asset)).burn(address(this), amount);
    }

    function redeemFromProtocol(uint256 amount) internal override {
        supplied -= amount;
        supplyCap += amount;
        MockERC20(address(asset)).mint(address(this), amount);

        require((borrowed == 0 && supplied == 0) || (borrowed * 1e18) / supplied <= 0.95e18, "redeemed too much");
    }

    function borrowFromProtocol(uint256 amount) internal override {        
        borrowed += amount;
        borrowCap -= amount;
        MockERC20(address(asset)).mint(address(this), amount);

        require(supplied != 0, "not enough supply");
        require((borrowed * 1e18) / supplied <= 0.95e18, "borrowed too much");
    }

    function repayToProtocol(uint256 amount) internal override {
        borrowed -= amount;
        borrowCap += amount;
        MockERC20(address(asset)).burn(address(this), amount);
    }

    function getProtocolLiquidity() public override pure returns (uint256) {
        return type(uint256).max;
    }

    function getRemainingProtocolSupplyCap() public override view returns (uint256) {
        return supplyCap;
    }

    function getRemainingProtocolBorrowCap() public override view returns (uint256) {
        return borrowCap;
    }

    function harvestable() public override view returns (Harvestable[] memory harvestables) {}

    function harnestSetSupplied(uint256 value) public {
        supplied = value;
    }

    function harnestSetBorrowed(uint256 value) public {
        borrowed = value;
    }

    function harnessSetSupplyCap(uint256 value) public {
        supplyCap = value;
    }

    function harnessSetBorrowCap(uint256 value) public {
        borrowCap = value;
    }
}

contract LeveragedLendingVaultTest is Test {
    MockERC20 public token;
    MockLeveragedLendingVault public vault;

    function setUp() public {
        token = new MockERC20("Test", "TST", 18);
        vault = new MockLeveragedLendingVault(
            token
        );

        token.approve(address(vault), type(uint256).max);
        vault.setMaxCollateralRatio(0.95e18);
        vault.setTargetCollateralRatio(0.90e18);
    }

    function testDeposit() public {
        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        assertApproxEqAbs(vault.getSuppliedToProtocol(), 195e18, 1);
        assertApproxEqAbs(vault.getBorrowedFromProtocol(), 95e18, 1);
        assertEq(vault.totalAssets(), 100e18);
    }

    function testRebalance() public {
        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        vault.rebalance();

        assertApproxEqAbs(vault.getSuppliedToProtocol(), 1000e18, 1);
        assertApproxEqAbs(vault.getBorrowedFromProtocol(), 900e18, 1);
        assertEq(vault.totalAssets(), 100e18);
    }

    function testWithdrawal() public {
        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        vault.rebalance();
        
        vault.withdraw(10e18, address(this), address(this));

        assertApproxEqAbs(vault.getSuppliedToProtocol(), 900e18, 1);
        assertApproxEqAbs(vault.getBorrowedFromProtocol(), 810e18, 1);
        assertEq(vault.totalAssets(), 90e18);
    }

    function testTotalWithdrawal() public {
        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));
        
        vault.rebalance();

        vault.withdraw(100e18, address(this), address(this));

        assertEq(vault.getSuppliedToProtocol(), 0);
        assertEq(vault.getBorrowedFromProtocol(), 0);
        assertEq(vault.totalAssets(), 0);
    }

    function _testBorrowCap() public {
        vault.harnessSetBorrowCap(200e18);

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));

        assertEq(vault.getSuppliedToProtocol(), 300e18);
        assertEq(vault.getBorrowedFromProtocol(), 200e18);
        assertEq(vault.totalAssets(), 100e18);

        vault.withdraw(100e18, address(this), address(this));

        assertEq(vault.getSuppliedToProtocol(), 0);
        assertEq(vault.getBorrowedFromProtocol(), 0);
        assertEq(vault.totalAssets(), 0);
    }

    function _testSupplyCap() public {
        vault.harnessSetSupplyCap(200e18);

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));
        
        assertEq(vault.getSuppliedToProtocol(), 200e18);
        assertEq(vault.getBorrowedFromProtocol(), 100e18);
        assertEq(vault.totalAssets(), 100e18);

        vault.withdraw(100e18, address(this), address(this));

        assertEq(vault.getSuppliedToProtocol(), 0);
        assertEq(vault.getBorrowedFromProtocol(), 0);
        assertEq(vault.totalAssets(), 0);
    }

    function _testHitSupplyCapOnDeposit() public {
        vault.harnessSetSupplyCap(50e18);

        token.mint(address(this), 100e18);
        vault.deposit(100e18, address(this));
        
        assertEq(vault.getSuppliedToProtocol(), 50e18);
        assertEq(vault.getBorrowedFromProtocol(), 0);
        assertEq(vault.totalAssets(), 100e18);

        vault.withdraw(100e18, address(this), address(this));

        assertEq(vault.getSuppliedToProtocol(), 0);
        assertEq(vault.getBorrowedFromProtocol(), 0);
        assertEq(vault.totalAssets(), 0);
    }
}
