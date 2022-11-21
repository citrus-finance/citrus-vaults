// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "BoringSolidity/interfaces/IERC20.sol";

import "./external/uniswap-v1/IStakingRewards.sol";

import "./mixins/SimpleVault.sol";

contract HopVault is SimpleVault {
    IStakingRewards stakingRewards;

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        IStakingRewards _stakingRewards
    ) SimpleVault(_asset, _name, _symbol) {
        stakingRewards = _stakingRewards;

        _asset.approve(address(_stakingRewards), type(uint256).max);
    }

    function getSuppliedToProtocol() public view override returns (uint256) {
        return stakingRewards.balanceOf(address(this));
    }

    function supplyToProtocol(uint256 amount) internal override {
        stakingRewards.stake(amount);
    }

    function redeemFromProtocol(uint256 amount) internal override {
        stakingRewards.withdraw(amount);
    }

    function collectHarvest() internal override {
        stakingRewards.getReward();
    }

    function harvestable() public view override returns (Harvestable[] memory) {
        address rewardToken = stakingRewards.rewardsToken();

        Harvestable[] memory harvestables = new Harvestable[](1);
        harvestables[0] = Harvestable({
            token: rewardToken,
            amount: stakingRewards.earned(address(this))
        });

        return harvestables;
    }
}
