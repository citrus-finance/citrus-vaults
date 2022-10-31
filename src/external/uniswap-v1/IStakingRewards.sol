pragma solidity >=0.4.24;

interface IStakingRewards {
    // Views
    function balanceOf(address account) external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function rewardsToken() external view returns (address);

    // Mutative
    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward() external;
}
