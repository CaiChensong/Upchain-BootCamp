// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 用 Solidity 编写 ETH 质押挖矿合约

编写 StakingPool 合约，实现 Stake 和 Unstake 方法，允许任何人质押 ETH 来赚钱 KK Token。
其中 KK Token 是每一个区块产出 10 个，产出的 KK Token 需要根据质押时长和质押数量来公平分配。

（加分项）用户质押的 ETH 可存入一个借贷市场赚取利息.

参考思路：找到 借贷市场 进行一笔存款，然后查看调用的方法，在 Stake 中集成该方法

使用 Aave 市场，参考 Docs: https://aave.com/docs/developers/smart-contracts/pool
*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./StakingPoolInterfaces.sol";

contract StakingPool is IStaking, Ownable {
    address public immutable kkToken;
    address public immutable aavePool;
    address public immutable weth;
    uint256 private _totalStaked;
    uint256 private _lastRewardBlockNumber;
    uint256 private _rewardPerToken;

    uint256 public constant REWARD_AMOUNT_PER_BLOCK = 10 * 1e18;
    uint256 private constant PRECISION = 1e9;

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 reward;
        uint256 rewardPerToken;
    }

    mapping(address account => StakeInfo) private _stakes;

    constructor(address _kkToken, address _aavePool, address _weth) Ownable(msg.sender) {
        kkToken = _kkToken;
        aavePool = _aavePool;
        weth = _weth;
    }

    receive() external payable {}

    // 质押 ETH 到合约
    function stake() external payable {
        require(msg.value > 0, "StakingPool: staked amount must be greater than 0");

        _updateReward(msg.sender);

        StakeInfo storage stakeInfo = _stakes[msg.sender];
        if (stakeInfo.amount == 0) {
            _stakes[msg.sender].startTime = block.timestamp;
        }

        stakeInfo.amount += msg.value;
        _totalStaked += msg.value;

        // 存入 Aave 借贷市场
        WETH(weth).deposit{value: msg.value}();
        WETH(weth).approve(aavePool, msg.value);
        IPool(aavePool).supply(weth, msg.value, address(this), 0);
    }

    // 赎回质押的 ETH
    function unstake(uint256 amount) external {
        require(amount > 0, "StakingPool: unstaked amount must be greater than 0");

        _updateReward(msg.sender);

        StakeInfo storage stakeInfo = _stakes[msg.sender];
        require(stakeInfo.amount >= amount, "StakingPool: insufficient balance");

        stakeInfo.amount -= amount;
        _totalStaked -= amount;

        // 从 Aave 借贷市场赎回
        IPool(aavePool).withdraw(weth, amount, address(this));
        WETH(weth).withdraw(amount);

        payable(msg.sender).transfer(amount);
    }

    // 领取 KK Token 收益
    function claim() external {
        _updateReward(msg.sender);
        uint256 reward = _stakes[msg.sender].reward;
        if (reward > 0) {
            IToken(kkToken).mint(msg.sender, reward);
            _stakes[msg.sender].reward = 0;
        }
    }

    // 获取质押的 ETH 数量
    function balanceOf(address account) external view returns (uint256) {
        return _stakes[account].amount;
    }

    // 获取待领取的 KK Token 收益
    function earned(address account) external view returns (uint256) {
        return _getReward(account);
    }

    // 更新奖励
    function _getReward(address account) internal view returns (uint256) {
        StakeInfo storage stakeInfo = _stakes[account];
        return
            stakeInfo.reward + stakeInfo.amount * (_calculateRewardPerToken() - stakeInfo.rewardPerToken) / (PRECISION);
    }

    // 更新奖励
    function _updateReward(address account) internal {
        _rewardPerToken = _calculateRewardPerToken();
        _lastRewardBlockNumber = block.number;

        if (account != address(0)) {
            _stakes[account].reward = _getReward(account);
            _stakes[account].rewardPerToken = _rewardPerToken;
        }
    }

    // 计算每份质押品的奖励
    function _calculateRewardPerToken() internal view returns (uint256) {
        if (_totalStaked == 0) {
            return _rewardPerToken;
        }

        return _rewardPerToken
            + (block.number - _lastRewardBlockNumber) * REWARD_AMOUNT_PER_BLOCK * PRECISION / _totalStaked;
    }

    function getTotalStaked() external view onlyOwner returns (uint256) {
        return _totalStaked;
    }
}

contract KKToken is IToken, ERC20, Ownable {
    constructor(address _owner) ERC20("KKToken", "KKT") Ownable(_owner) {}

    function mint(address to, uint256 amount) external override onlyOwner {
        _mint(to, amount);
    }
}
