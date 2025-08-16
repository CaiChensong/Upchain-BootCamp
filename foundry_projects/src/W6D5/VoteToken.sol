// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VoteToken - 治理投票代币合约
 * @dev 这是一个支持委托投票的 ERC20 代币合约，实现了类似 Compound 的治理机制
 * @dev 支持代币铸造、销毁和委托投票功能
 */
contract VoteToken is ERC20, Ownable {
    // 委托关系映射：用户地址 => 委托的投票者地址
    mapping(address => address) public delegates;

    /**
     * @dev 检查点结构体，用于记录特定区块的投票权重
     * @param fromBlock 检查点创建的区块号
     * @param votes 该区块的投票权重
     */
    struct Checkpoint {
        uint256 fromBlock;
        uint256 votes;
    }

    // 检查点存储：委托者地址 => 检查点索引 => 检查点数据
    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;
    // 每个委托者的检查点数量
    mapping(address => uint256) public numCheckpoints;

    // 委托关系变更事件
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    // 委托投票权重变更事件
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    /**
     * @dev 构造函数，初始化代币
     * @param _owner 合约所有者地址，将获得所有初始代币
     */
    constructor(address _owner) ERC20("VoteToken", "VT") Ownable(_owner) {
        _mint(_owner, 10000000 * 10 ** decimals()); // 铸造 1000 万代币给所有者
    }

    /**
     * @dev 委托投票权给指定地址
     * @param delegatee 被委托投票权的地址
     * @notice 用户可以将自己的投票权委托给其他地址，委托后该地址可以代表用户进行投票
     */
    function delegate(address delegatee) public {
        address currentDelegate = delegates[msg.sender]; // 获取当前委托者
        uint256 delegatorBalance = balanceOf(msg.sender); // 获取委托人的代币余额
        delegates[msg.sender] = delegatee; // 设置新的委托关系

        emit DelegateChanged(msg.sender, currentDelegate, delegatee); // 发出委托变更事件

        _moveDelegates(currentDelegate, delegatee, delegatorBalance); // 移动委托权重
    }

    /**
     * @dev 获取账户当前的投票权重
     * @param account 要查询的账户地址
     * @return 该账户当前的投票权重
     * @notice 返回账户在最新检查点的投票权重
     */
    function getCurrentVotes(address account) public view returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @dev 获取账户在指定区块的投票权重
     * @param account 要查询的账户地址
     * @param blockNumber 要查询的区块号
     * @return 该账户在指定区块的投票权重
     * @notice 使用二分查找算法高效查询历史投票权重，防止投票操纵
     */
    function getPriorVotes(address account, uint256 blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "VoteToken: not yet determined");

        uint256 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0; // 没有检查点，返回 0
        }

        // 如果最新检查点在目标区块之前，返回最新权重
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // 如果最早检查点在目标区块之后，返回 0
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        // 使用二分查找找到最接近的检查点
        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // 计算中间位置，避免溢出
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes; // 找到精确匹配
            } else if (cp.fromBlock < blockNumber) {
                lower = center; // 目标区块在右侧
            } else {
                upper = center - 1; // 目标区块在左侧
            }
        }
        return checkpoints[account][lower].votes; // 返回最接近的检查点权重
    }

    /**
     * @dev 重写 ERC20 的 _update 方法，处理委托权重的更新
     * @param from 发送方地址
     * @param to 接收方地址
     * @param value 转账金额
     * @notice 在代币转移时自动更新相关的委托投票权重
     */
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value); // 调用父类的 _update 方法

        if (from == address(0)) {
            // 新代币被铸造
            address delegatee = delegates[to];
            if (delegatee != address(0)) {
                // 如果接收者有委托者，更新委托者的检查点
                uint256 currentVotes = getCurrentVotes(delegatee);
                _writeCheckpoint(delegatee, numCheckpoints[delegatee], currentVotes, currentVotes + value);
            }
            return;
        }

        if (to == address(0)) {
            // 代币被销毁
            address delegatee = delegates[from];
            if (delegatee != address(0)) {
                // 如果发送者有委托者，更新委托者的检查点
                uint256 currentVotes = getCurrentVotes(delegatee);
                _writeCheckpoint(delegatee, numCheckpoints[delegatee], currentVotes, currentVotes - value);
            }
            return;
        }

        // 普通转账，移动委托权重
        _moveDelegates(delegates[from], delegates[to], value);
    }

    /**
     * @dev 在委托者之间移动投票权重
     * @param srcRep 源委托者地址
     * @param dstRep 目标委托者地址
     * @param amount 移动的权重数量
     * @notice 当用户转移代币时，相应的委托投票权重也会在委托者之间转移
     */
    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            // 只有当源和目标不同且金额大于 0 时才处理
            if (srcRep != address(0)) {
                // 处理源委托者：减少投票权重
                uint256 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld - amount; // 计算新的权重
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew); // 写入检查点
            }

            if (dstRep != address(0)) {
                // 处理目标委托者：增加投票权重
                uint256 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld + amount; // 计算新的权重
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew); // 写入检查点
            }
        }
    }

    /**
     * @dev 写入或更新检查点
     * @param delegatee 委托者地址
     * @param nCheckpoints 当前检查点数量
     * @param oldVotes 旧的投票权重
     * @param newVotes 新的投票权重
     * @notice 如果同一区块内多次更新，则覆盖现有检查点；否则创建新检查点
     */
    function _writeCheckpoint(address delegatee, uint256 nCheckpoints, uint256 oldVotes, uint256 newVotes) internal {
        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == block.number) {
            // 同一区块内更新现有检查点，节省 gas
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            // 创建新的检查点
            checkpoints[delegatee][nCheckpoints] = Checkpoint(block.number, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1; // 增加检查点计数
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes); // 发出权重变更事件
    }

    /**
     * @dev 铸造新代币（仅所有者可调用）
     * @param to 接收代币的地址
     * @param amount 铸造的代币数量
     * @notice 只有合约所有者可以铸造新代币，增加总供应量
     */
    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "VoteToken: cannot mint to zero address"); // 不能铸造到零地址
        _mint(to, amount);
    }

    /**
     * @dev 销毁代币（仅所有者可调用）
     * @param from 销毁代币的地址
     * @param amount 销毁的代币数量
     * @notice 只有合约所有者可以销毁代币，减少总供应量
     */
    function burn(address from, uint256 amount) public onlyOwner {
        require(from != address(0), "VoteToken: cannot burn from zero address"); // 不能从零地址销毁
        require(balanceOf(from) >= amount, "VoteToken: burn amount exceeds balance"); // 销毁数量不能超过余额
        _burn(from, amount);
    }
}
