// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "./SimpleVault.sol";

contract MockSimpleVault is SimpleVault {
    constructor(MockERC20 asset) SimpleVault(asset, "Vault Test", "VTest") {}

    uint256 private supplied;

    function getSuppliedToProtocol() public view override returns (uint256) {
        return supplied;
    }

    function supplyToProtocol(uint256 amount) internal override {
        supplied += amount;
        MockERC20(address(asset)).burn(address(this), amount);
    }

    function redeemFromProtocol(uint256 amount) internal override {
        supplied -= amount;
        MockERC20(address(asset)).mint(address(this), amount);
    }

    function getRemainingProtocolSupplyCap()
        public
        pure
        override
        returns (uint256)
    {
        return type(uint256).max;
    }

    function collectHarvest() internal virtual override {}

    function harvestable()
        public
        view
        override
        returns (Harvestable[] memory harvestables)
    {}
}

contract SimpleVaultTest is Test {
    MockERC20 token;
    MockSimpleVault vault;

    function setUp() public {
        token = new MockERC20("Test", "TST", 18);
        vault = new MockSimpleVault(token);

        token.approve(address(vault), type(uint256).max);
    }

    function testTotalAssets() public {
        token.mint(address(this), 1000);
        token.mint(address(vault), 1000);

        vault.deposit(1000, address(this));

        assertEq(vault.totalAssets(), 2000);
    }

    function testDeposit() public {
        token.mint(address(this), 1000);
        vault.deposit(1000, address(this));

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(this)), 1000);
        assertEq(vault.getSuppliedToProtocol(), 1000);
    }

    function testWithdraw() public {
        token.mint(address(this), 1000);
        vault.deposit(1000, address(this));

        vault.withdraw(900, address(this), address(this));

        assertEq(token.balanceOf(address(this)), 900);
        assertEq(vault.balanceOf(address(this)), 100);
        assertEq(vault.getSuppliedToProtocol(), 100);
    }

    function testTotalWithdraw() public {
        token.mint(address(this), 1000);
        vault.deposit(1000, address(this));

        vault.withdraw(1000, address(this), address(this));

        assertEq(token.balanceOf(address(this)), 1000);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.getSuppliedToProtocol(), 0);
    }
}
