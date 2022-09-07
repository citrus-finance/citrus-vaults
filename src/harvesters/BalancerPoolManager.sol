pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "solmate/tokens/ERC20.sol";

import "../external/balancer-v2/IBalancerV2Vault.sol";
import "../external/balancer-v2/IBalancerV2WeightedPool.sol";

contract BalancerPoolManager {
    function exitPool(address pool, uint256[] memory minAmountsOut) public {
        IBalancerV2WeightedPool balancerPool = IBalancerV2WeightedPool(pool);
        IBalancerV2Vault balancerVault = IBalancerV2Vault(
            balancerPool.getVault()
        );
        bytes32 poolId = balancerPool.getPoolId();

        (address[] memory tokens, , ) = balancerVault.getPoolTokens(poolId);

        IBalancerV2Vault.ExitPoolRequest memory request = IBalancerV2Vault
            .ExitPoolRequest({
                assets: tokens,
                minAmountsOut: minAmountsOut,
                userData: abi.encode(1, ERC20(pool).balanceOf(address(this))),
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
