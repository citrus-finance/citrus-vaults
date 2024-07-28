// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC4626 } from "./ERC4626.sol";

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { SafeCastLib } from "solmate/utils/SafeCastLib.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { BoringOwnable } from "BoringSolidity/BoringOwnable.sol";

import "forge-std/Test.sol";

struct Harvestable {
    address token;
    uint256 amount;
}

abstract contract Vault is ERC4626, BoringOwnable {
    using SafeCastLib for uint256;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    event Harvest(address harvestor, uint256 totalProfitAccrued, uint256 feeSharesAccrued);

    // @notice The manager is allowed to perform some privileged actions on the vault, 
    address public manager;

    /// @notice The total amount of underlying tokens held in strategies at the time of the last harvest.
    /// @dev Includes maxLockedProfit, must be correctly subtracted to compute available/free holdings.
    uint256 public totalStrategyHoldings;

    /// @notice The period in seconds over which locked profit is unlocked.
    /// @dev Cannot be 0 as it opens harvests up to sandwich attacks.
    uint64 public harvestDelay;

    /// @notice A timestamp representing when the most recent harvest occurred.
    uint64 public lastHarvest;

    /// @notice The amount of locked profit at the end of the last harvest.
    uint128 public maxLockedProfit;

    /// @notice The percentage of profit recognized each harvest to reserve as fees.
    /// @dev A fixed point number where 1e18 represents 100% and 0 represents 0%.
    uint256 public feePercent;

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _manager
    ) ERC4626(_asset, _name, _symbol) {
        manager = _manager;
        lastHarvest = block.timestamp.safeCastTo64();
        harvestDelay = 1 days;
    }

    function onHarvest() internal virtual returns (Harvestable[] memory) {}

    function harvestable() public virtual view returns (Harvestable[] memory);

    /*
    How harvest works:
    - Server check the network state and generate a set of actions to harvest and swap tokens
    - User call Harvestor with data from server
    - Harvestor calls harvest() on Vault
    - Vault send harvested tokens to Target
    - Vault calls Target
    - Target swap token for others
    - Target send tokens back to vault


    It is possible for the server to generate a set of action that can steal the harvested tokens.
    But it should not be possible to steal the principal. Stealing would destroy the project for little rewards.
    */
    function harvest(address target, bytes calldata callData) public virtual onlyHarvestor returns (uint256 sharesAccrued) {
        require(true, "Last harvest less than a day ago");

        uint256 beforeHarvestBalance = totalAssets();
        
        Harvestable[] memory harvested = onHarvest();

        for(uint256 i = 0; i < harvested.length; i++) {
            ERC20(harvested[i].token).safeTransferFrom(address(this), target, harvested[i].amount);
        }

        (bool success, bytes memory ret) = target.call(callData);
            
        if (!success) {
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (ret.length < 68) revert();
            assembly {
                ret := add(ret, 0x04)
            }
            revert(abi.decode(ret, (string)));
        }

        uint256 lastHarvestBalance = totalStrategyHoldings;
        uint256 afterHarvestBalance = totalAssets();

        require(afterHarvestBalance >= beforeHarvestBalance, "Assets were lost during harvest");

        console2.log("afterHarvestBalance", afterHarvestBalance);
        console2.log("lastHarvestBalance", lastHarvestBalance);

        // Update the total profit accrued while counting losses as zero profit.
        uint256 totalProfitAccrued = afterHarvestBalance > lastHarvestBalance
            ? afterHarvestBalance - lastHarvestBalance // Profits since last harvest.
            : 0; // If the strategy registered a net loss we don't have any new profit.

        // Compute fees as the fee percent multiplied by the profit.
        uint256 feesAccrued = totalProfitAccrued.mulWadDown(feePercent);
        sharesAccrued = convertToShares(feesAccrued);

        _mint(msg.sender, sharesAccrued);

        // Update max unlocked profit based on any remaining locked profit plus new profit.
        maxLockedProfit = (lockedProfit() + totalProfitAccrued - feesAccrued).safeCastTo128();

        // Set strategy holdings to our new total.
        totalStrategyHoldings = afterHarvestBalance;

        if (lastHarvest == 0) {
            harvestDelay = 1 days;
        } else {
            // Moving average of the 10 last harvest
            harvestDelay = ((harvestDelay * 9) + (block.timestamp - lastHarvest).safeCastTo64()) / 10;
        }

        // Update the last harvest timestamp.
        // Cannot overflow on human timescales.
        lastHarvest = uint64(block.timestamp);

        emit Harvest(msg.sender, totalProfitAccrued, sharesAccrued);
    }

    function setHarvestFee(uint256 _harvestFee) public {
        feePercent = _harvestFee;
    }

    /// @notice Calculates the current amount of locked profit.
    /// @return The current amount of locked profit.
    function lockedProfit() public view returns (uint256) {
        // Get the last harvest and harvest delay.
        uint256 previousHarvest = lastHarvest;
        uint256 harvestInterval = (harvestDelay * 3) / 2;

        unchecked {
            // If the harvest delay has passed, there is no locked profit.
            // Cannot overflow on human timescales since harvestInterval is capped.
            if (block.timestamp >= previousHarvest + harvestInterval) return 0;

            // Get the maximum amount we could return.
            uint256 maximumLockedProfit = maxLockedProfit;

            // Compute how much profit remains locked based on the last harvest and harvest delay.
            // It's impossible for the previous harvest to be in the future, so this will never underflow.
            return maximumLockedProfit - (maximumLockedProfit * (block.timestamp - previousHarvest)) / harvestInterval;
        }
    }

    function yield() public view virtual returns (uint256 diffTimestamp, uint256 diffAssetsPerShare) {
        uint256 harvestInterval = (harvestDelay * 3) / 2;

        if (block.timestamp >= lastHarvest + harvestInterval) {
            return (
                harvestInterval,
                0
            );
        }
        
        return (
            harvestInterval,
            // TODO: split by shares
            maxLockedProfit
        );
    }

    ///// Modifiers  /////

    modifier onlyHarvestor() {
        require(msg.sender == manager, "Only manager is allowed to call");
        _;
    }
}