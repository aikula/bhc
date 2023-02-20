// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title Staking of **Token** tokens
 * @notice You can use this contract for pos
 */
contract Staking is AccessControl, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant ONE_DAY = 3600;

    struct StakeData {
        uint256 id;
        address account;
        uint256 amount;
        uint256 reward;
        uint256 startsAt;
        uint256 endAt;
        bool closed;
    }

    IERC20 public immutable stakingToken;
    uint256 private _revenuePercent;
    uint256 private _rewardPool;
    uint256 private _totalStaked;
    uint256 private _totalStakesCount;
    uint256 private _totalReward;
    address[] private _allAccounts;

    mapping(address => bool) private _hasStake;
    mapping(address => StakeData[]) private _stakedInformation;

    /**
        @notice Returns Revenue percent number
    */
    function revenuePercent() public view returns (uint256) {
        return _revenuePercent;
    }

    /**
        @notice Returns Reward pool amount
    */
    function rewardPool() public view returns (uint256) {
        return _rewardPool;
    }

    /**
        @notice Returns Total staked amount
    */
    function totalStaked() public view returns (uint256) {
        return _totalStaked;
    }

    /**
        @notice Returns Total staked count
    */
    function totalStakesCount() public view returns (uint256) {
        return _totalStakesCount;
    }

    /**
        @notice Returns Total reward amount
    */
    function totalReward() public view returns (uint256) {
        return _totalReward;
    }

    /**
        @notice Returns all accounts in stake
    */
    function allAccounts() public view returns (address[] memory) {
        return _allAccounts;
    }

    /**
        @notice Returns true if account in stake
        @param account the address of the user
    */
    function hasStake(address account) public view returns (bool) {
        return _hasStake[account];
    }

    /**
        @notice Return reward and unstakeAmount(reward + stake amount) by account and id
        @param account the address of the user whose reward and amount we want to see
        @param id the number of stake
    */
    function getRewards(
        address account,
        uint256 id
    ) public view returns (uint256 rewardsSubValue, uint256 unstakeAmount) {
        StakeData memory stake_ = _getStake(account, id);
        uint256 timestamp = getTimestamp();
        uint256 durationInStaking = timestamp - stake_.startsAt;
        uint256 dailyReward = rewardCalculation(stake_.amount);
        rewardsSubValue = (durationInStaking / ONE_DAY) * dailyReward;
        unstakeAmount = stake_.amount + rewardsSubValue;
    }

    /**
        @notice Return stake by account and id stake
        @param account the address of the user whose stake we want to see
        @param id the number of stake
    */
    function getStake(address account, uint256 id) public view returns (StakeData memory) {
        return _getStake(account, id);
    }

    /**
        @notice Return stake count by account
        @param account the address of the user whose stake count we want to see
    */
    function getStakesCount(address account) public view returns (uint256) {
        return _stakedInformation[account].length;
    }

    /**
        @notice Returns array stakes by offset and limit
        @param account the address of the user whose all stake we want to see
        @param offset number from which the output will be
        @param limit the number of lots to be taken
    */
    function getStakesByAccount(
        address account,
        uint256 offset,
        uint256 limit
    ) public view returns (StakeData[] memory stakeData) {
        StakeData[] memory stakedInformation = _stakedInformation[account];
        uint256 stakedInformationLength = stakedInformation.length;
        if (offset > stakedInformationLength) return new StakeData[](0);
        uint256 to = offset + limit;
        if (stakedInformationLength < to) to = stakedInformationLength;
        stakeData = new StakeData[](to - offset);
        for (uint256 i = 0; i < stakeData.length; i++) {
            stakeData[i] = stakedInformation[offset + i];
        }
    }

    /**
        @notice Returns array all ative stakes by account, offset and limit and reward which can be withdraw
        @param account the address of the user whose all stake we want to see
        @param offset number from which the output will be
        @param limit the number of lots to be taken
    */
    function getActiveStakesByAccount(
        address account,
        uint256 offset,
        uint256 limit
    ) public view returns (StakeData[] memory stakeData, uint256 rewardCanBeWithdraw) {
        StakeData[] memory stakedInformation = _stakedInformation[account];
        
        uint256 stakedInformationLength;

        for (uint256 i = 0; i < stakedInformation.length; i++) {
            if(stakedInformation[i].closed == false){
                stakedInformationLength++;
            }
        }
        StakeData[] memory allActiveStakes = new StakeData[](stakedInformationLength);
        
        uint256 counterForPush;
        for (uint256 i = 0; i < stakedInformation.length; i++) {
            if(stakedInformation[i].closed == false){
                (uint256 reward, ) = getRewards(account, i); 
                stakedInformation[i].reward = reward;
                allActiveStakes[counterForPush] = stakedInformation[i];
                rewardCanBeWithdraw+=reward;
                counterForPush++;
            }
        }

        if (offset > stakedInformationLength) return (new StakeData[](0), 0);
        uint256 to = offset + limit;
        if (stakedInformationLength < to) to = stakedInformationLength;
        stakeData = new StakeData[](to - offset);
        for (uint256 i = 0; i < stakeData.length; i++) {
            stakeData[i] = allActiveStakes[offset + i];
        }
    }

    /**
        @notice Returns array all stakes by offset and limit
        @param offset number from which the output will be
        @param limit the number of lots to be taken
    */
    function getAllStakes(uint256 offset, uint256 limit) public view returns (StakeData[] memory paginationStakes) {
        uint256 countAllStakes;

        for (uint256 i = 0; i < _allAccounts.length; i++) {
            countAllStakes += getStakesCount(_allAccounts[i]);
        }

        StakeData[] memory allStakeData = new StakeData[](countAllStakes);
        uint256 counterForPush;

        for (uint256 i = 0; i < _allAccounts.length; i++) {
            uint256 countStake = getStakesCount(_allAccounts[i]);
            for (uint256 j = 0; j < countStake; j++) {
                StakeData memory stakeByAccount = getStake(_allAccounts[i], j);
                allStakeData[counterForPush] = stakeByAccount;
                counterForPush++;
            }
        }

        if (offset > countAllStakes) return new StakeData[](0);
        uint256 to = offset + limit;
        if (countAllStakes < to) to = countAllStakes;
        paginationStakes = new StakeData[](to - offset);
        for (uint256 i = 0; i < paginationStakes.length; i++) {
            paginationStakes[i] = allStakeData[offset + i];
        }
    }

    /**
        @notice Returns forecast reward by days
        @param daysForForecast number of days for how long you need to make a forecast
    */
    function getForecast(uint256 daysForForecast) public view returns (uint256 amountOfAllRewards) {
        for (uint256 i = 0; i < _allAccounts.length; i++) {
            StakeData[] memory stakedInformation = _stakedInformation[_allAccounts[i]];
            for (uint256 j = 0; j < stakedInformation.length; j++) {
                if(stakedInformation[j].closed == false) {
                    (uint256 reward, ) = getRewards(_allAccounts[i], j);
                    uint256 dailyReward = rewardCalculation(stakedInformation[j].amount);
                    amountOfAllRewards += reward + (dailyReward * daysForForecast);
                }
            }
        }
    }

    /**
        @notice Reward pool increase event
        @param caller who increased reward pool
        @param amount amount by which it was increased reward pool
    */
    event RewardPoolIncreased(address indexed caller, uint256 amount);

    /**
        @notice Reward pool decreased event
        @param caller who decreased reward pool
        @param amount amount by which it was decreased reward pool
    */
    event RewardPoolDecreased(address indexed caller, uint256 amount);

    /**
        @notice Staked event
        @param caller who made a stake
        @param stakeId id stake
        @param amount the amount that was staked
    */
    event Staked(address indexed caller, uint256 stakeId, uint256 amount);

    /**
        @notice Claimed event
        @param caller who unstaked 
        @param stakeId id stake
        @param amount that was claimed, including the reward and the initial amount
    */
    event Claimed(address indexed caller, uint256 stakeId, uint256 amount);

    /**
        @notice Initializes Staking
        @dev Initializes a new Staking instance
        @param stakingToken_ the address of the staking token that is should be bound to the interface IERC20
        @param revenuePercent_ the percentage that users will receive from the stake if it is completed
        @dev percentages must be specified with 100 increments to maintain accuracy.
        @dev for example 10% = 1000, 4.5% = 450
    */
    constructor(address stakingToken_, uint256 revenuePercent_) {
        require(stakingToken_ != address(0), "StakingToken is zero address");
        require(revenuePercent_ > 0, "Revenue not positive");
        stakingToken = IERC20(stakingToken_);
        _revenuePercent = revenuePercent_;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
        @notice Method for pause contract
        @dev call only admin role
        @return boolean value indicating whether the operation succeededs
    */
    function pause() external onlyRole(ADMIN_ROLE) whenNotPaused returns (bool) {
        _pause();
        return true;
    }

    /**
        @notice Method for unpause contract
        @dev call only admin role
        @return boolean value indicating whether the operation succeeded
    */
    function unpause() external onlyRole(ADMIN_ROLE) whenPaused returns (bool) {
        _unpause();
        return true;
    }

    /**
        @notice Method increase reward pool
        @dev Transfers `amount` to the contract for rewards
        For success works:
        - The amount should be positive
        - Caller should be admin contract
        Emits a {RewardPoolIncreased} event
        @param amount by which will be increased reward pool
        @return boolean value indicating whether the operation succeeded
    */
    function increaseRewardPool(
        uint256 amount
    ) external onlyPositiveAmount(amount) onlyRole(ADMIN_ROLE) whenNotPaused returns (bool) {
        address caller = msg.sender;
        stakingToken.safeTransferFrom(caller, address(this), amount);
        _rewardPool += amount;
        emit RewardPoolIncreased(caller, amount);
        return true;
    }

    /**
        @notice Method decrease reward pool
        @dev Transfers `amount` to the admin from rewardPool
        For success works:
        - The amount should be positive
        - Caller should be admin contract
        Emits a {RewardPoolDecreased} event
        @param amount by which will be decreased reward pool
        @return boolean value indicating whether the operation succeeded
    */
    function decreaseRewardPool(
        uint256 amount
    ) external onlyPositiveAmount(amount) onlyRole(ADMIN_ROLE) whenNotPaused returns (bool) {
        address caller = msg.sender;
        stakingToken.safeTransfer(caller, amount);
        _rewardPool -= amount;
        emit RewardPoolDecreased(caller, amount);
        return true;
    }

    /**
        @notice Method for return all stakes to users
        @dev Transfers all `amount` stake to the users
        For success works:
        - Caller should be admin contract
        @return boolean value indicating whether the operation succeeded
    */
    function returnAllStakes() external onlyRole(ADMIN_ROLE) whenPaused returns (bool) {
        for (uint256 i = 0; i < _allAccounts.length; i++) {
            address account = _allAccounts[i];
            StakeData[] storage stakedInformation = _stakedInformation[account];
            for (uint256 j = 0; j < stakedInformation.length; j++) {
                if(stakedInformation[j].closed == false) {
                    stakingToken.safeTransfer(account, stakedInformation[j].amount);
                    _totalStaked -= stakedInformation[j].amount;
                    stakedInformation[j].endAt = getTimestamp();
                    stakedInformation[j].closed = true;
                }
            }
        }
        return true;
    }

    /**
        @notice Method for set revenue percent
        @param revenuePercent_ new revenue percent
        @dev percentages must be specified with 100 increments to maintain accuracy.
        @dev for example 10% = 1000, 4.5% = 450
        @return boolean value indicating whether the operation succeeded
    */
    function setRevenuePercent(
        uint256 revenuePercent_
    ) external onlyRole(ADMIN_ROLE) onlyPositiveAmount(revenuePercent_) whenNotPaused returns (bool) {
        _revenuePercent = revenuePercent_;
        return true;
    }

    /**
        @notice Method create a new stake
        @dev Transfers tokens to the contract
        For success works:
        - The amount should be positive
        Emits a {Staked} event
        @param amount the number of tokens that are put into a new stake
        @return boolean value indicating whether the operation succeeded
    */
    function stake(uint256 amount) external onlyPositiveAmount(amount) whenNotPaused returns (bool) {
        address caller = msg.sender;
        uint256 stakeId = _stakedInformation[caller].length;
        if (_hasStake[caller] == false) {
            _allAccounts.push(caller);
            _hasStake[caller] = true;
        }
        _totalStaked += amount;
        _stakedInformation[caller].push();
        StakeData storage stake_ = _stakedInformation[caller][stakeId];
        stake_.id = stakeId;
        stake_.account = caller;
        stake_.amount = amount;
        stake_.startsAt = getTimestamp();
        stakingToken.safeTransferFrom(caller, address(this), amount);
        _totalStakesCount++;
        emit Staked(caller, stakeId, amount);
        return true;
    }

    /**
        @notice Method make unstake by id
        @dev Transfers tokens to the caller with rewards
        For success works:
        - Id token should be correct
        - The stake is not yet to be claimed
        - When contract not paused
        Emits a {Withdrawn} event
        @param id stake id for withdraw
        @return boolean value indicating whether the operation succeeded
    */
    function claim(uint256 id) external whenNotPaused returns (bool) {
        _claim(id);
        return true;
    }

    /**
        @notice Method make unstake all stake
        @dev Transfers tokens to the caller with rewards
        For success works:
        - The stake is not yet to be claimed
        - When contract not paused
        Emits a {Withdrawn} event
        @return boolean value indicating whether the operation succeeded
    */
    function claimAll() external whenNotPaused returns (bool) {
        address caller = msg.sender;
        uint256 countStakes = getStakesCount(caller);
        for (uint256 i = 0; i < countStakes; i++) {
            StakeData storage stake_ = _stakedInformation[caller][i];
            if(stake_.closed == false) {
                _claim(i);
            }
        }
        return true;
    }

    /**
        @notice The internal method for reward calculation. Call in external method
        @param amount for calculation reward
    */
    function rewardCalculation(uint256 amount) internal view returns (uint256) {
        return (amount * _revenuePercent) / 10000;
    }

    /**
        @notice The internal method for get stake by account and id. Call in external method
        @param account the address of the user whose stake we want to see
        @param id the number of stake
    */
    function _getStake(address account, uint256 id) internal view returns (StakeData memory) {
        require(id < _stakedInformation[account].length, "Invalid stake id");
        return _stakedInformation[account][id];
    }

    /**
        @notice The internal method for claim stake by id. Call in external method
        @param id stake id for withdraw
    */
    function _claim(uint256 id) internal {
        address caller = msg.sender;
        require(id < _stakedInformation[caller].length, "Invalid stake id");
        StakeData storage stake_ = _stakedInformation[caller][id];
        require(!stake_.closed, "Stake has withdraw");
        (uint256 rewardsSubValue, uint256 unstakeAmount) = getRewards(caller, id);
        stakingToken.safeTransfer(caller, unstakeAmount);
        _totalStaked -= stake_.amount;
        _rewardPool -= rewardsSubValue;
        _totalReward += rewardsSubValue;
        stake_.reward = rewardsSubValue;
        stake_.endAt = getTimestamp();
        stake_.closed = true;
        emit Claimed(caller, id, unstakeAmount);
    }

    /**
        @notice The internal method for returned block.timestamp. Call in external method
    */
    function getTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    /**
        @notice Modifier to require if a amount is positive
        @param amount amount for require
    */
    modifier onlyPositiveAmount(uint256 amount) {
        require(amount > 0, "Amount not positive");
        _;
    }
}
