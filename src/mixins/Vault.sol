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
    event UpdateHarvestCallAuthorisation(address target, bytes4 sig, bool allowed);
    event Harvest(uint assetsPerShare, uint sharesToHarvester);

    // @notice The manager is allowed to perform some privileged actions on the vault, 
    address public manager;

    // @notice This address receive all fees captured by this vault
    address public feeTaker;

    // @notice Percentage the user has to pay to withdraw. 1e18 is 100%
    uint256 public withdrawalFee;

    // @notice Harvesting generate . 1e18 is 100%
    uint256 public harvestFee;

    HarvestCheckpoint[] public harvestCheckpoints;

    mapping(address => bool) public excludedFromFees;

    mapping(address=> mapping(bytes4 => bool)) harvesAllowedCalls;

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
    function harvest(HarvestCall[] memory calls) public virtual onlyManager returns (bytes[] memory returnData) {
        uint256 balanceBefore = totalAssets();

        onHarvest();

        returnData = new bytes[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            require(harvesAllowedCalls[calls[i].target][bytes4(calls[i].callData)], "method not whitelisted");

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

    function allowHarvestCall(address target, bytes4 sig, bool allowed) public onlyOwner {
        harvesAllowedCalls[target][sig] = allowed;
        emit UpdateHarvestCallAuthorisation(target, sig, allowed);
    }

    function increaseAllowance(ERC20 token, address spender) public onlyOwner returns (bool) {
        return token.approve(spender, type(uint256).max);
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
        withdrawalFee = _withdrawalFee;
    }

    function setHarvestFee(uint256 _harvestFee) public onlyOwner {
        harvestFee = _harvestFee;
    }

    /////  ERC4626 hooks  /////

    function afterDeposit(uint256 assets, uint256) internal override {
        onDeposit(assets);
    }

    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        if (!excludedFromFees[msg.sender]) {
            _mint(feeTaker, shares.mulDivDown(withdrawalFee, 1e18));
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