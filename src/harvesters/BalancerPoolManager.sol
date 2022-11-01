// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "../external/balancer-v2/IBalancerV2Vault.sol";
import "../external/balancer-v2/IBalancerV2WeightedPool.sol";

contract BalancerPoolManager {
    function exitPool(address pool) public {
        IBalancerV2WeightedPool balancerPool = IBalancerV2WeightedPool(pool);
        IBalancerV2Vault balancerVault = IBalancerV2Vault(
            balancerPool.getVault()
        );
        bytes32 poolId = balancerPool.getPoolId();

        (address[] memory tokens, , ) = balancerVault.getPoolTokens(poolId);
        uint256[] memory minAmountsOut = new uint256[](tokens.length);

        IBalancerV2Vault.ExitPoolRequest memory request = IBalancerV2Vault
            .ExitPoolRequest({
                assets: tokens,
                minAmountsOut: minAmountsOut,
                userData: abi.encode(1, balancerPool.balanceOf(address(this)) - 1),
                toInternalBalance: false
            });

        balancerVault.exitPool(
            poolId,
            address(this),
            payable(address(this)),
            request
        );
    }
}
