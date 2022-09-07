pragma solidity >=0.8.0;

interface IBalancerV2WeightedPool {
    function getPoolId() external view returns (bytes32);
    function getVault() external view returns (address);
    function getNormalizedWeights() external view returns (uint256[] memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}