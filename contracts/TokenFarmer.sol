//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
contract TokenFarmer is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. TOKENs to distribute per block.
        uint256 lastRewardBlock; // Last block number that TOKENs distribution occurs.
        uint256 accTOKENPerShare; // Accumulated TOKENs per share, times 1e12. See below.
    }

    // The TOKEN!
    IERC20 public token;

    // Rewards Balance
    uint256 public availableRewards;

    // Block number when bonus TOKEN period ends.
    uint256 public bonusEndBlock;
    // TOKEN tokens created per block.
    uint256 public tokenPerBlock;
    // Bonus muliplier for early liquidity providers.
    uint256 public BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The block number when TOKEN mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    // logged claimed reward amount
    event Claim(address indexed user, uint256 indexed pid, uint256 amount);
    /**
    logged Un-claimed reward amount. 
    This occurs when reward amount in this contract is less then what needs to be distributed
     */
    event InsufficientRewards(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        IERC20 _token,
        uint256 _tokenPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) {
        token = _token;
        tokenPerBlock = _tokenPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function addPool(
        uint256 _allocPoint,
        IERC20 _lpToken
    ) external onlyOwner {
        // Re-calculate reward amount for the pools to make sure of fair reward calculation and distribution
        massUpdatePools();
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accTOKENPerShare: 0
            })
        );
    }

    // Update the given pool's TOKEN allocation point. Can only be called by the owner.
    function editPool(
        uint256 _pid,
        uint256 _allocPoint
    ) external onlyOwner {
        // Re-calculate reward amount for the pools to make sure of fair reward calculation and distribution
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    // View function to see pending TOKENs on frontend.
    function pendingTokens(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTOKENPerShare = pool.accTOKENPerShare;

        uint256 lpSupply;
        if (address(pool.lpToken) != address(token)) {
            lpSupply = pool.lpToken.balanceOf(address(this));
        } else {
            if (token.balanceOf(address(this)) > 0) {
                lpSupply = token.balanceOf(address(this)).sub(availableRewards);
            } else {
                lpSupply = 0;
            }
        }

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 tokenReward = multiplier
                .mul(tokenPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accTOKENPerShare = accTOKENPerShare.add(
                tokenReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accTOKENPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function calculateRoi(uint256 _pid)  external
        view
        returns (uint256 perShareValue){
        PoolInfo storage pool = poolInfo[_pid];

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 lpSupply = token.balanceOf(address(this)).sub(availableRewards);

        uint256 tokenReward = multiplier
            .mul(tokenPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        perShareValue = pool.accTOKENPerShare.add(
            tokenReward.mul(1e12).div(lpSupply)
        );
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply;
        if (address(pool.lpToken) != address(token)) {
            lpSupply = pool.lpToken.balanceOf(address(this));
        } else {
            if (token.balanceOf(address(this)) > 0) {
                lpSupply = token.balanceOf(address(this)).sub(availableRewards);
            } else {
                lpSupply = 0;
            }
        }

        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokenReward = multiplier
            .mul(tokenPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        pool.accTOKENPerShare = pool.accTOKENPerShare.add(
            tokenReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens for TOKEN rewards.
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant{
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accTOKENPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            if (pending > 0) {
               rewardTransfer(msg.sender, _pid, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTOKENPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw tokens.
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant{
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accTOKENPerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            rewardTransfer(msg.sender, _pid, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTOKENPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external nonReentrant{
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    function depositRewards(uint256 _amount) external onlyOwner {
        token.transferFrom(msg.sender, address(this), _amount);
        availableRewards += _amount;
    }

    function withdrawRewards(uint256 _amount) external onlyOwner {
        token.transfer(msg.sender, _amount);
        availableRewards -= _amount;
    }

    function rewardTransfer(address _to, uint256 _pid, uint256 _amount) internal{
        if (_amount > availableRewards) {
            uint256 toWithdraw = availableRewards;
            token.transfer(_to, toWithdraw);
            availableRewards = 0;
            // log claimed reward amount 
            emit Claim(msg.sender, _pid, toWithdraw);
            // log Un-claimed reward amount 
            emit InsufficientRewards(msg.sender, _pid, _amount - toWithdraw);

        } else {
            availableRewards -= _amount;
            token.transfer(_to, _amount);
            // log claimed reward amount 
            emit Claim(msg.sender, _pid, _amount);
        }
    }

    function setBonusMultiplier(uint256 _bonusM) external onlyOwner {
        BONUS_MULTIPLIER = _bonusM;
    }
    function setTokensPerBlock(uint256 _tokensPerBlock) external onlyOwner{
        require(_tokensPerBlock > 0, "TokenFarmer: Bad Input");
        massUpdatePools(); // update reward for each pool to make sure reward per pool is update to date
        tokenPerBlock = _tokensPerBlock;
    }
}
