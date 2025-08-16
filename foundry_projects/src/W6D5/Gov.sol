// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./VoteToken.sol";
import "./DaoBank.sol";
import "./Timelock.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Gov - 治理合约
 * @dev 实现基于代币投票的去中心化治理系统
 * @dev 支持提案创建、投票、执行等完整的治理流程
 * @dev 集成时间锁机制，确保治理决策的安全性
 */
contract Gov is Ownable, ReentrancyGuard {
    // 核心合约地址
    Timelock public timelock; // 时间锁合约
    VoteToken public voteToken; // 投票代币合约
    address public daoBank; // DAO 银行合约

    // 提案计数器
    uint256 public proposalCount;

    // 治理参数常量
    uint256 public constant quorumVotes = 400000e18; // 法定票数：400,000 代币
    uint256 public constant proposalThreshold = 100000e18; // 提案门槛：100,000 代币
    uint256 public constant proposalMaxOperations = 10; // 最大操作数：10
    uint256 public constant votingDelay = 1; // 投票延迟：1 区块
    uint256 public constant votingPeriod = 17280; // 投票周期：~3 天

    // 提案结构体，存储提案的完整信息
    struct Proposal {
        uint256 id; // 提案唯一标识符
        address proposer; // 提案发起人地址
        uint256 eta; // 提案执行时间戳
        string description; // 提案描述
        address target; // 提款目标地址
        uint256 amount; // 提款金额
        uint256 startBlock; // 投票开始区块
        uint256 endBlock; // 投票结束区块
        uint256 forVotes; // 赞成票数
        uint256 againstVotes; // 反对票数
        bool canceled; // 是否被取消
        bool executed; // 是否已执行
        mapping(address => Receipt) receipts; // 投票结果
    }

    // 投票收据结构体，记录单个投票者的投票信息
    struct Receipt {
        bool hasVoted; // 是否已投票
        bool support; // 是否支持提案
        uint256 votes; // 投票权重
    }

    // 提案状态枚举，定义提案的完整生命周期
    enum ProposalState {
        Pending, // 等待中：提案已创建，但投票尚未开始
        Active, // 活跃中：提案正在接受投票
        Canceled, // 已取消：提案被取消
        Defeated, // 已失败：投票未通过或未达到法定人数
        Succeeded, // 已成功：投票通过
        Queued, // 已排队：提案已排队等待执行
        Expired, // 已过期：提案执行时间已过
        Executed // 已执行：提案已执行完成

    }

    // 提案存储映射：提案ID => 提案详情
    mapping(uint256 => Proposal) public proposals;
    // 提案者最新提案映射：提案者地址 => 最新提案ID
    mapping(address => uint256) public latestProposalIds;

    // 治理事件定义
    event ProposalCreated(
        uint256 id,
        address proposer,
        address target,
        uint256 amount,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    event VoteCast(address voter, uint256 proposalId, bool support, uint256 votes);
    event ProposalCanceled(uint256 id);
    event ProposalQueued(uint256 id, uint256 eta);
    event ProposalExecuted(uint256 id);

    /**
     * @dev 构造函数，初始化治理合约
     * @param timelock_ 时间锁合约地址
     * @param voteToken_ 投票代币合约地址
     * @param daoBank_ DAO银行合约地址
     * @param owner 合约所有者地址
     */
    constructor(address payable timelock_, address voteToken_, address daoBank_, address owner) Ownable(owner) {
        timelock = Timelock(timelock_);
        voteToken = VoteToken(voteToken_);
        daoBank = daoBank_;
    }

    /**
     * @dev 接收 ETH 的回退函数
     */
    receive() external payable {}

    /**
     * @dev 创建新的治理提案
     * @param target 提款目标地址（通常是 DaoBank 合约）
     * @param amount 提款金额
     * @param description 提案描述
     * @return 提案ID
     * @notice 只有持有足够投票权重的地址才能创建提案
     */
    function propose(address target, uint256 amount, string memory description) public returns (uint256) {
        // 检查提案者是否持有足够的投票权重
        require(
            voteToken.getPriorVotes(msg.sender, block.number - 1) > proposalThreshold,
            "Gov::propose: proposer votes below proposal threshold"
        );

        // 检查提案者是否已有活跃提案
        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = getProposalState(latestProposalId);
            require(
                proposersLatestProposalState != ProposalState.Active,
                "Gov::propose: one live proposal per proposer, found an already active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "Gov::propose: one live proposal per proposer, found an already pending proposal"
            );
        }

        // 计算投票开始和结束时间
        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;

        // 创建新提案
        proposalCount++;
        uint256 proposalId = proposalCount;
        Proposal storage newProposal = proposals[proposalId];

        // 防止提案ID冲突（理论上不会发生）
        require(newProposal.id == 0, "Gov::propose: ProposalID collsion");

        // 初始化提案数据
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.eta = 0;
        newProposal.target = target;
        newProposal.amount = amount;
        newProposal.description = description;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.canceled = false;
        newProposal.executed = false;

        // 更新提案者的最新提案ID
        latestProposalIds[newProposal.proposer] = newProposal.id;

        // 发出提案创建事件
        emit ProposalCreated(newProposal.id, msg.sender, target, amount, startBlock, endBlock, description);
        return newProposal.id;
    }

    /**
     * @dev 将成功的提案排队等待执行
     * @param proposalId 提案ID
     * @notice 只有成功的提案才能排队，排队后会进入时间锁延迟期
     */
    function queue(uint256 proposalId) public {
        require(
            getProposalState(proposalId) == ProposalState.Succeeded,
            "Gov::queue: proposal can only be queued if it is succeeded"
        );
        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + timelock.delay();

        // 检查提案是否已在队列中
        require(
            !timelock.queuedTransactions(keccak256(abi.encode(proposal.target, proposal.amount, eta))),
            "Gov::queue: proposal action already queued at eta"
        );

        // 将提案操作排队到时间锁
        timelock.queueTransaction(proposal.target, proposal.amount, eta);

        // 更新提案的执行时间
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    /**
     * @dev 执行已排队的提案
     * @param proposalId 提案ID
     * @notice 只有已排队的提案才能执行，执行后会从 DaoBank 提取资金
     */
    function execute(uint256 proposalId) public payable {
        require(
            getProposalState(proposalId) == ProposalState.Queued,
            "Gov::execute: proposal can only be executed if it is queued"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        // 通过时间锁执行提案
        timelock.executeTransaction(daoBank, proposal.target, proposal.amount, proposal.eta);
        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev 取消提案
     * @param proposalId 提案ID
     * @notice 只有合约所有者或投票权重不足的提案者可以取消提案
     */
    function cancel(uint256 proposalId) public {
        require(getProposalState(proposalId) != ProposalState.Executed, "Gov::cancel: cannot cancel executed proposal");

        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == owner() || voteToken.getPriorVotes(proposal.proposer, block.number - 1) < proposalThreshold,
            "Gov::cancel: proposer above threshold"
        );
        proposal.canceled = true;

        // 取消时间锁中的交易
        timelock.cancelTransaction(proposal.target, proposal.amount, proposal.eta);
        emit ProposalCanceled(proposalId);
    }

    /**
     * @dev 对提案进行投票
     * @param proposalId 提案ID
     * @param support 是否支持提案
     * @notice 每个地址只能对同一提案投票一次，投票权重基于提案开始时的余额
     */
    function castVote(uint256 proposalId, bool support) public {
        require(getProposalState(proposalId) == ProposalState.Active, "Gov::castVote: voting is closed");

        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[msg.sender];
        require(!receipt.hasVoted, "Gov::castVote: voter already voted");

        // 获取投票权重（基于提案开始时的余额）
        uint256 votes = voteToken.getPriorVotes(msg.sender, proposal.startBlock);

        // 更新投票计数
        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        // 记录投票信息
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    /**
     * @dev 获取提案的当前状态
     * @param proposalId 提案ID
     * @return 提案状态
     * @notice 根据当前区块和投票结果确定提案状态
     */
    function getProposalState(uint256 proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > 0, "Gov::getProposalState: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + timelock.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * @dev 获取提案的操作信息
     * @param proposalId 提案ID
     * @return target 目标地址
     * @return amount 操作金额
     */
    function getActions(uint256 proposalId) public view returns (address target, uint256 amount) {
        Proposal storage p = proposals[proposalId];
        return (p.target, p.amount);
    }

    /**
     * @dev 获取指定投票者的投票记录
     * @param proposalId 提案ID
     * @param voter 投票者地址
     * @return 投票记录
     */
    function getReceipt(uint256 proposalId, address voter) public view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    /**
     * @dev 查询 DaoBank 合约的余额
     * @return DaoBank 合约的 ETH 余额
     */
    function getBankBalance() public view returns (uint256) {
        return address(daoBank).balance;
    }

    /**
     * @dev 查询 Gov 合约的余额
     * @return Gov 合约的 ETH 余额
     */
    function getGovBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev 获取提案的投票计数
     * @param proposalId 提案ID
     * @return forVotes 赞成票数
     * @return againstVotes 反对票数
     * @notice 用于测试和查询提案的投票结果
     */
    function getProposalVoteCounts(uint256 proposalId) public view returns (uint256 forVotes, uint256 againstVotes) {
        require(proposalCount >= proposalId && proposalId > 0, "Gov::getProposalVoteCounts: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        return (proposal.forVotes, proposal.againstVotes);
    }
}
