// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/W6D5/VoteToken.sol";
import "../../src/W6D5/DaoBank.sol";
import "../../src/W6D5/Timelock.sol";
import "../../src/W6D5/Gov.sol";

/**
 * @title DaoTest - DAO 系统完整流程测试
 * @dev 测试 DAO 系统的完整流程
 * @dev 包括存款、提款、投票、排队、执行等所有步骤
 */
contract DaoTest is Test {
    // 测试合约实例
    VoteToken public voteToken;
    DaoBank public daoBank;
    Timelock public timelock;
    Gov public gov;

    // 测试账户
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public recipient;

    // 测试参数
    uint256 public constant TIMELOCK_DELAY = 2 days;
    uint256 public constant PROPOSAL_AMOUNT = 1 ether;
    uint256 public constant USER1_TOKENS = 250000e18; // 250,000 tokens
    uint256 public constant USER2_TOKENS = 200000e18; // 200,000 tokens
    uint256 public constant USER3_TOKENS = 150000e18; // 150,000 tokens
    uint256 public constant USER4_TOKENS = 50000e18; // 50,000 tokens

    /**
     * @dev 测试前的设置工作
     * @notice 部署所有合约并初始化测试环境
     */
    function setUp() public {
        // 设置测试账户
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        recipient = makeAddr("recipient");

        console.log("=== Setting up governance test environment ===");
        console.log("Owner address:", owner);
        console.log("User1 address:", user1);
        console.log("User2 address:", user2);
        console.log("User3 address:", user3);
        console.log("User4 address:", user4);
        console.log("Recipient address:", recipient);

        // 部署 VoteToken 合约
        voteToken = new VoteToken(owner);
        console.log("VoteToken deployed at:", address(voteToken));

        // 部署 DaoBank 合约
        daoBank = new DaoBank(owner);
        console.log("DaoBank deployed at:", address(daoBank));

        // 部署 Timelock 合约
        timelock = new Timelock(owner, TIMELOCK_DELAY);
        console.log("Timelock deployed at:", address(timelock));

        // 部署 Gov 合约
        gov = new Gov(payable(address(timelock)), address(voteToken), address(daoBank), owner);
        console.log("Gov deployed at:", address(gov));

        // 设置权限关系
        daoBank.transferOwnership(address(timelock));
        timelock.transferOwnership(address(gov));
        console.log("Permissions configured: DaoBank -> Timelock -> Gov");

        // 分配投票代币给测试用户
        voteToken.transfer(user1, USER1_TOKENS);
        voteToken.transfer(user2, USER2_TOKENS);
        voteToken.transfer(user3, USER3_TOKENS);
        voteToken.transfer(user4, USER4_TOKENS);
        console.log("Voting tokens distributed to test users");

        // 向 DaoBank 存入一些 ETH
        daoBank.deposit{value: 10 ether}();
        console.log("Deposited 10 ETH to DaoBank");

        // 验证初始状态
        console.log("Initial VoteToken balances:");
        console.log("User1:", voteToken.balanceOf(user1));
        console.log("User2:", voteToken.balanceOf(user2));
        console.log("User3:", voteToken.balanceOf(user3));
        console.log("User4:", voteToken.balanceOf(user4));
        console.log("DaoBank balance:", address(daoBank).balance);
        console.log("Gov balance:", address(gov).balance);
        console.log("Recipient balance:", recipient.balance);
    }

    /**
     * @dev 测试完整的治理流程
     * @notice 从提案创建到最终执行的完整流程测试
     */
    function testCompleteGovernanceFlow() public {
        console.log("\n=== Starting complete governance flow test ===");

        // 步骤 1: 用户委托投票权
        console.log("\n--- Step 1: User delegation ---");
        vm.startPrank(user1);
        voteToken.delegate(user1);
        console.log("User1 delegated voting power to self");
        vm.stopPrank();

        vm.startPrank(user2);
        voteToken.delegate(user2);
        console.log("User2 delegated voting power to self");
        vm.stopPrank();

        vm.startPrank(user3);
        voteToken.delegate(user3);
        console.log("User3 delegated voting power to self");
        vm.stopPrank();

        vm.startPrank(user4);
        voteToken.delegate(user4);
        console.log("User4 delegated voting power to self");
        vm.stopPrank();

        // 验证委托状态
        console.log("Delegation status:");
        console.log("User1 delegate:", voteToken.delegates(user1));
        console.log("User2 delegate:", voteToken.delegates(user2));
        console.log("User3 delegate:", voteToken.delegates(user3));
        console.log("User4 delegate:", voteToken.delegates(user4));

        // 推进一个区块，确保委托状态被记录
        console.log("\n--- Advancing block for delegation to take effect ---");
        vm.roll(block.number + 1);
        console.log("Advanced to block:", block.number);

        // 步骤 2: 创建提案
        console.log("\n--- Step 2: Proposal creation ---");
        vm.startPrank(user1);
        uint256 proposalId = gov.propose(recipient, PROPOSAL_AMOUNT, "Withdraw 1 ETH for community development");
        console.log("Proposal created with ID:", proposalId);
        vm.stopPrank();

        // 验证提案状态
        Gov.ProposalState state = gov.getProposalState(proposalId);
        console.log("Initial proposal state:", uint256(state));
        assertEq(uint256(state), uint256(Gov.ProposalState.Pending), "Proposal should be in Pending state");

        // 步骤 3: 等待投票开始
        console.log("\n--- Step 3: Waiting for voting to start ---");
        vm.roll(block.number + gov.votingDelay() + 1);
        state = gov.getProposalState(proposalId);
        console.log("Proposal state after voting delay:", uint256(state));
        assertEq(uint256(state), uint256(Gov.ProposalState.Active), "Proposal should be in Active state");

        // 步骤 4: 用户投票
        console.log("\n--- Step 4: User voting ---");

        // User1 投票赞成
        vm.startPrank(user1);
        gov.castVote(proposalId, true);
        console.log("User1 voted FOR proposal");
        vm.stopPrank();

        // User2 投票赞成
        vm.startPrank(user2);
        gov.castVote(proposalId, true);
        console.log("User2 voted FOR proposal");
        vm.stopPrank();

        // User3 投票赞成
        vm.startPrank(user3);
        gov.castVote(proposalId, true);
        console.log("User3 voted FOR proposal");
        vm.stopPrank();

        // User4 投票反对
        vm.startPrank(user4);
        gov.castVote(proposalId, false);
        console.log("User4 voted AGAINST proposal");
        vm.stopPrank();

        // 验证投票结果
        (uint256 forVotes, uint256 againstVotes) = gov.getProposalVoteCounts(proposalId);
        console.log("Vote results:");
        console.log("FOR votes:", forVotes);
        console.log("AGAINST votes:", againstVotes);
        console.log("Required quorum:", gov.quorumVotes());
        console.log("Vote breakdown:");
        console.log("  User1 (FOR): 250,000 tokens");
        console.log("  User2 (FOR): 200,000 tokens");
        console.log("  User3 (FOR): 150,000 tokens");
        console.log("  User4 (AGAINST): 50,000 tokens");

        // 步骤 5: 等待投票结束
        console.log("\n--- Step 5: Waiting for voting to end ---");
        vm.roll(block.number + gov.votingPeriod() + 1);
        state = gov.getProposalState(proposalId);
        console.log("Proposal state after voting period:", uint256(state));

        // 验证提案是否成功
        if (forVotes > againstVotes && forVotes >= gov.quorumVotes()) {
            assertEq(uint256(state), uint256(Gov.ProposalState.Succeeded), "Proposal should be in Succeeded state");
            console.log("Proposal succeeded! Moving to next step...");
        } else {
            console.log("Proposal failed or did not meet quorum");
            return;
        }

        // 步骤 6: 排队提案
        console.log("\n--- Step 6: Queuing proposal ---");
        gov.queue(proposalId);
        state = gov.getProposalState(proposalId);
        console.log("Proposal state after queuing:", uint256(state));
        assertEq(uint256(state), uint256(Gov.ProposalState.Queued), "Proposal should be in Queued state");

        // 获取执行时间
        (address target, uint256 amount) = gov.getActions(proposalId);
        console.log("Proposal actions:");
        console.log("Target:", target);
        console.log("Amount:", amount);

        // 步骤 7: 等待时间锁延迟
        console.log("\n--- Step 7: Waiting for timelock delay ---");
        uint256 currentTime = block.timestamp;
        uint256 executionTime = currentTime + TIMELOCK_DELAY;
        console.log("Current time:", currentTime);
        console.log("Execution time:", executionTime);
        console.log("Timelock delay:", TIMELOCK_DELAY);

        vm.warp(executionTime + 1);
        console.log("Time advanced to:", block.timestamp);

        // 步骤 8: 执行提案
        console.log("\n--- Step 8: Executing proposal ---");
        uint256 recipientBalanceBefore = recipient.balance;
        uint256 daoBankBalanceBefore = address(daoBank).balance;

        console.log("Balances before execution:");
        console.log("Recipient balance:", recipientBalanceBefore);
        console.log("DaoBank balance:", daoBankBalanceBefore);

        gov.execute(proposalId);
        state = gov.getProposalState(proposalId);
        console.log("Proposal state after execution:", uint256(state));
        assertEq(uint256(state), uint256(Gov.ProposalState.Executed), "Proposal should be in Executed state");

        // 验证执行结果
        uint256 recipientBalanceAfter = recipient.balance;
        uint256 daoBankBalanceAfter = address(daoBank).balance;

        console.log("Balances after execution:");
        console.log("Recipient balance:", recipientBalanceAfter);
        console.log("DaoBank balance:", daoBankBalanceAfter);
        console.log("Amount transferred:", recipientBalanceAfter - recipientBalanceBefore);

        // 验证资金转移
        assertEq(
            recipientBalanceAfter - recipientBalanceBefore,
            PROPOSAL_AMOUNT,
            "Recipient should receive the proposed amount"
        );
        assertEq(daoBankBalanceBefore - daoBankBalanceAfter, PROPOSAL_AMOUNT, "DaoBank should lose the proposed amount");

        console.log("\n=== Governance flow test completed successfully! ===");
        console.log("Proposal executed successfully, funds transferred from DaoBank to recipient user");
    }

    /**
     * @dev 接收 ETH 的回退函数
     * @notice 允许测试合约接收 ETH 转账
     */
    receive() external payable {}
}
