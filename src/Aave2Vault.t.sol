// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";

import "./Aave2Vault.sol";

contract Aave2VaultTest is Test {
    ERC20 wxdai = ERC20(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);

    Aave2Vault vault;

    function setUp() public {
        vm.createSelectFork(vm.envString("GNOSIS_RPC"));
        vault = new Aave2Vault(
            ERC20(wxdai),
            "RMM xDai",
            "AXDAI",
            ILendingPool(0x5B8D36De471880Ee21936f328AAB2383a280CB2A),
            IAaveIncentivesController(address(0))
        );
        vault.setManager(address(this));
        wxdai.approve(address(vault), type(uint256).max);
        vault.setHarvestFee(0);
    }

    function testRMM() public {
        deal(address(wxdai), address(this), 100e18);
        vault.deposit(100e18, address(this));

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 17280);

        HarvestCall[] memory calls = new HarvestCall[](0);
        vault.harvest(calls, 0);

        console.log("profit", vault.totalAssets());
    }
}
