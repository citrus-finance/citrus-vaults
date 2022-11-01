// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "solmate/mixins/ERC4626.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "BoringSolidity/BoringOwnable.sol";

struct HarvestCall {
    address target;
    bytes callData;
}

struct Harvestable {
    address token;
    uint256 amount;
}

struct HarvestCheckpoint {
    // rolling block timestamp
    uint32 blockTimestamp;

    // rolling amount of assets per share
    uint224 assetsPerShare;
}

abstract contract Vault is ERC4626, BoringOwnable {
    using FixedPointMathLib for uint256;

    event UpdateFeeExclusion(address user, bool excluded);
    event UpdateAllowedHarvester(address target, bool allowed);
    event Harvest(uint assetsPerShare, uint sharesToHarvester);
    event UpdateWithdrawalFee(uint256 oldFee, uint256 newFee);
    event UpdateHarvestFee(uint256 oldFee, uint256 newFee);

    // @notice The manager is allowed to perform some privileged actions on the vault, 
    address public manager;

    // @notice This address receive all fees captured by this vault
    address public feeTaker;

    // @notice Percentage the user has to pay to withdraw. 1e18 is 100%
    uint256 public withdrawalFee;

    // @notice Harvesting generate . 1e18 is 100%
    uint256 public harvestFee;

    // @notice stores assetsPerShare evolution over time
    // @dev used to calculate yield/apy
    HarvestCheckpoint[] public harvestCheckpoints;

    // @notice addresses that are excluded from fees
    mapping(address => bool) public excludedFromFees;

    // @notice address of contracts that could be called during harvest
    mapping(address => bool) public allowedHarvesters;

    // @notice array of contracts that could be called during harvest
    // @dev only use this to check if a contract should be removed, some disabled harvesters can be in this array
    address[] public _allHarvesters;

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset, _name, _symbol) {
        harvestCheckpoints.push(HarvestCheckpoint({
            blockTimestamp: uint32(block.timestamp),
            assetsPerShare: uint224(convertToAssets(10 ** decimals))
        }));
    }

    /////  Harvest  /////

    // modified version of: https://github.com/makerdao/multicall/blob/1e1b44362640820bef92d0ccf5eeee25d9b41474/src/Multicall.sol#L17-L25
    // @dev The caller could steal the harvest but should not be able to steal any of the deposited funds.
    // Stealing the harvest would result in bad PR and users withdrawing their funds without losing their principal.
    function harvest(HarvestCall[] memory calls, uint256 amountOutMin) public virtual onlyManager returns (bytes[] memory returnData) {
        uint256 balanceBefore = totalAssets();

        onHarvest();

        returnData = new bytes[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            require(allowedHarvesters[calls[i].target], "harvestor not allowed");

            bool success;
            bytes memory ret;

            (success, ret) = calls[i].target.delegatecall(calls[i].callData);
            
            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (ret.length < 68) revert();
                assembly {
                    ret := add(ret, 0x04)
                }
                revert(abi.decode(ret, (string)));
            }

            returnData[i] = ret;
        }

        uint256 balanceAfter = totalAssets();

        require(balanceAfter >= balanceBefore, "negative harvest");
        uint256 diffBalance;
        unchecked {
          diffBalance = balanceAfter - balanceBefore;
        }

        require(diffBalance >= amountOutMin, "insufficient output amount");

        uint256 denom = balanceBefore + (diffBalance.mulDivUp(1e18 - harvestFee, 1e18));
        uint256 harveterShares = totalSupply.mulDivDown(balanceAfter, denom) - totalSupply;

        _mint(feeTaker, harveterShares);

        uint256 assetsPerShare = convertToAssets(10 ** decimals);
        harvestCheckpoints.push(HarvestCheckpoint({
            blockTimestamp: uint32(block.timestamp),
            assetsPerShare: uint224(assetsPerShare)
        }));
        emit Harvest(assetsPerShare, harveterShares);

        afterHarvest();
    }

    // @notice approve a contract to be used during harvesting
    function allowHarvester(address target, bool allowed) public onlyOwner {
        if (allowed) {
            _allHarvesters.push(target);
        }
        allowedHarvesters[target] = allowed;
        emit UpdateAllowedHarvester(target, allowed);
    }

    // @notive get array of all contracts ever allowed
    // @dev could contains harvester that are now disabled
    function allHarvesters() public view returns (address[] memory) {
        return _allHarvesters;
    }

    /////  Checkpoints  /////

    function harvestCheckpointsLength() public view returns (uint256) {
        return harvestCheckpoints.length;
    }

    function invertedHarvestCheckpoints(uint256 index) public view returns (HarvestCheckpoint memory) {
        return harvestCheckpoints[harvestCheckpoints.length - 1 - index];
    }

    function selectHarvestCheckpoints(uint256 start, uint256 end) public view returns (HarvestCheckpoint[] memory) {
        uint256 length = end - start + 1;

        HarvestCheckpoint[] memory arr = new HarvestCheckpoint[](length);
        for (uint256 i = 0; i < length; i++) {
            arr[i] = harvestCheckpoints[start + i];
        }
        return arr;
    }

    function selectInvertedHarvestCheckpoints(uint256 start, uint256 end) public view returns (HarvestCheckpoint[] memory) {
        uint256 length = end - start + 1;
        uint256 lastIndex = harvestCheckpoints.length - 1;

        HarvestCheckpoint[] memory arr = new HarvestCheckpoint[](length);
        for (uint256 i = 0; i < length; i++) {
            arr[i] = harvestCheckpoints[lastIndex - i];
        }
        return arr;
    }

    function yield() public view virtual returns (uint256 diffTimestamp, int256 diffAssetsPerShare) {
        uint lastHarvestCheckpointsIndex = harvestCheckpoints.length - 1;

        if (lastHarvestCheckpointsIndex < 1) {
            return (1 days, 0);
        }

        HarvestCheckpoint memory lastCheckpoint = harvestCheckpoints[lastHarvestCheckpointsIndex];
        HarvestCheckpoint memory beforeLastCheckpoint = harvestCheckpoints[lastHarvestCheckpointsIndex - 1];

        unchecked { // timestamp is allowed to overflow
            diffTimestamp = lastCheckpoint.blockTimestamp - beforeLastCheckpoint.blockTimestamp;
        }
        diffAssetsPerShare = int256(((int224(lastCheckpoint.assetsPerShare) - int224(beforeLastCheckpoint.assetsPerShare)) * 1e18) / int224(beforeLastCheckpoint.assetsPerShare));
    }

    /////  Admin  /////

    function setManager(address _manager) public onlyOwner {
        manager = _manager;
    }

    /////  Fees  /////

    function excludeFromFees(address user, bool exclude) public onlyOwner {
        excludedFromFees[user] = exclude;
        emit UpdateFeeExclusion(user, exclude);
    }

    function setFeeTaker(address _feeTaker) public onlyOwner {
        feeTaker = _feeTaker;
    }

    function setWithdrawalFee(uint256 _withdrawalFee) public onlyOwner {
        require(_withdrawalFee <= 0.01e18, "the withdrawal fee can be max 1%");

        uint256 oldFee = withdrawalFee;
        withdrawalFee = _withdrawalFee;

        emit UpdateWithdrawalFee(oldFee, _withdrawalFee);
    }

    function setHarvestFee(uint256 _harvestFee) public onlyOwner {
        uint256 oldFee = harvestFee;
        harvestFee = _harvestFee;

        emit UpdateHarvestFee(oldFee, _harvestFee);
    }

    /////  ERC4626 hooks  /////

    function afterDeposit(uint256 assets, uint256) internal override {
        onDeposit(assets);
    }

    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        if (withdrawalFee != 0 && !excludedFromFees[msg.sender]) {
            _mint(feeTaker, shares.mulDivUp(withdrawalFee, 1e18));
        }
        onWithdraw(assets);
    }

    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 _withdrawalFee = withdrawalFee;

        if (excludedFromFees[msg.sender]) {
            _withdrawalFee = 0;
        } 

        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        uint shares = supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
        return shares.mulDivUp(1e18, 1e18 - _withdrawalFee);
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        uint256 _withdrawalFee = withdrawalFee;

        if (excludedFromFees[msg.sender]) {
            _withdrawalFee = 0;
        }

        return convertToAssets(shares).mulDivDown(1e18 - _withdrawalFee, 1e18);
    }

    ///// Modifiers  /////

    modifier onlyManager() {
        require(msg.sender == manager, "Only manager is allowed to call");
        _;
    }

    modifier onlyManagerOrOwner() {
        require(msg.sender == manager || msg.sender == owner, "Only manager or Owner is allowed to call");
        _;
    }

    /////  Hooks  /////

    function onDeposit(uint256 assets) internal virtual {}

    function onWithdraw(uint256 assets) internal virtual {}

    function onHarvest() internal virtual {}

    function afterHarvest() internal virtual {}

    function harvestable() public virtual view returns (Harvestable[] memory);
}