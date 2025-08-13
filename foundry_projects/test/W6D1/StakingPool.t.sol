// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/W6D1/StakingPool.sol";
import "../../src/W6D1/StakingPoolInterfaces.sol";

// Mock Aave Pool 合约
contract MockAavePool is IPool {
    mapping(address => uint256) public userBalances;

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external override {
        userBalances[onBehalfOf] += amount;
    }

    function withdraw(address asset, uint256 amount, address to) external override returns (uint256) {
        require(userBalances[msg.sender] >= amount, "Insufficient balance");
        userBalances[msg.sender] -= amount;
        return amount;
    }
}

contract StakingPoolTest is Test {
    StakingPool public stakingPool;
    KKToken public kkToken;
    MockAavePool public mockAavePool;
    WETH public weth;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public owner = makeAddr("owner");

    uint256 public constant STAKE_AMOUNT = 1 ether;
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18;

    function setUp() public {
        vm.startPrank(owner);

        // 部署合约
        kkToken = new KKToken(owner);
        mockAavePool = new MockAavePool();
        weth = new WETH();
        stakingPool = new StakingPool(address(kkToken), address(mockAavePool), address(weth));
        kkToken.transferOwnership(address(stakingPool));

        vm.stopPrank();

        // 给用户一些 ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        // 给 WETH 合约一些 ETH
        vm.deal(address(weth), 100 ether);
    }

    function test_Constructor() public {
        assertEq(stakingPool.kkToken(), address(kkToken));
        assertEq(stakingPool.aavePool(), address(mockAavePool));
        assertEq(stakingPool.weth(), address(weth));
        assertEq(stakingPool.owner(), owner);
    }

    function test_Stake() public {
        vm.startPrank(user1);

        uint256 initialBalance = user1.balance;

        stakingPool.stake{value: STAKE_AMOUNT}();

        assertEq(stakingPool.balanceOf(user1), STAKE_AMOUNT);
        assertEq(user1.balance, initialBalance - STAKE_AMOUNT);
        vm.stopPrank();

        vm.prank(owner);
        assertEq(stakingPool.getTotalStaked(), STAKE_AMOUNT);
    }

    function test_StakeZeroAmount() public {
        vm.startPrank(user1);

        vm.expectRevert("StakingPool: staked amount must be greater than 0");
        stakingPool.stake{value: 0}();

        vm.stopPrank();
    }

    function test_Unstake() public {
        vm.startPrank(user1);

        // 先质押
        stakingPool.stake{value: STAKE_AMOUNT}();

        uint256 unstakeAmount = 0.5 ether;
        uint256 initialBalance = user1.balance;

        stakingPool.unstake(unstakeAmount);

        assertEq(stakingPool.balanceOf(user1), STAKE_AMOUNT - unstakeAmount);
        assertEq(user1.balance, initialBalance + unstakeAmount);

        vm.stopPrank();

        vm.prank(owner);
        assertEq(stakingPool.getTotalStaked(), STAKE_AMOUNT - unstakeAmount);
    }

    function test_UnstakeInsufficientBalance() public {
        vm.startPrank(user1);

        vm.expectRevert("StakingPool: insufficient balance");
        stakingPool.unstake(STAKE_AMOUNT);

        vm.stopPrank();
    }

    function test_UnstakeZeroAmount() public {
        vm.startPrank(user1);

        vm.expectRevert("StakingPool: unstaked amount must be greater than 0");
        stakingPool.unstake(0);

        vm.stopPrank();
    }

    function test_ClaimRewards() public {
        // 质押 ETH
        vm.prank(user1);
        stakingPool.stake{value: STAKE_AMOUNT}();

        // 跳过几个区块来产生奖励
        vm.roll(block.number + 10);

        vm.startPrank(user1);
        uint256 initialKKBalance = kkToken.balanceOf(user1);

        stakingPool.claim();

        uint256 finalKKBalance = kkToken.balanceOf(user1);
        assertGt(finalKKBalance, initialKKBalance);

        vm.stopPrank();
    }

    function test_RewardCalculation() public {
        // 用户1质押 1 ETH
        vm.prank(user1);
        stakingPool.stake{value: STAKE_AMOUNT}();

        // 跳过 5 个区块
        vm.roll(block.number + 5);

        // 计算预期奖励：5 个区块 * 10 KK = 50 KK
        uint256 earnedReward = stakingPool.earned(user1);
        assertGt(earnedReward, 0);
    }

    function test_MultipleUsersRewardDistribution() public {
        // 用户1质押 1 ETH
        vm.prank(user1);
        stakingPool.stake{value: STAKE_AMOUNT}();

        // 跳过 5 个区块
        vm.roll(block.number + 5);

        // 用户2质押 1 ETH
        vm.prank(user2);
        stakingPool.stake{value: STAKE_AMOUNT}();

        // 再跳过 5 个区块
        vm.roll(block.number + 5);

        // 用户1应该获得更多奖励（质押时间更长）
        uint256 user1Reward = stakingPool.earned(user1);
        uint256 user2Reward = stakingPool.earned(user2);

        assertGt(user1Reward, user2Reward);
    }

    function test_StakeUnstakeStake() public {
        vm.startPrank(user1);

        // 第一次质押
        stakingPool.stake{value: STAKE_AMOUNT}();
        assertEq(stakingPool.balanceOf(user1), STAKE_AMOUNT);

        // 赎回一半
        stakingPool.unstake(STAKE_AMOUNT / 2);
        assertEq(stakingPool.balanceOf(user1), STAKE_AMOUNT / 2);

        // 再次质押
        stakingPool.stake{value: STAKE_AMOUNT / 2}();
        assertEq(stakingPool.balanceOf(user1), STAKE_AMOUNT);

        vm.stopPrank();
    }

    function test_TotalStakedOnlyOwner() public {
        // 非所有者调用应该失败
        vm.prank(user1);
        vm.expectRevert();
        stakingPool.getTotalStaked();

        // 所有者调用应该成功
        vm.prank(owner);
        uint256 totalStaked = stakingPool.getTotalStaked();
        assertEq(totalStaked, 0);
    }

    function test_KKTokenMint() public {
        uint256 mintAmount = 100 * 1e18;

        vm.prank(address(stakingPool));
        kkToken.mint(user1, mintAmount);

        assertEq(kkToken.balanceOf(user1), mintAmount);
    }

    function test_KKTokenTransfer() public {
        uint256 mintAmount = 100 * 1e18;

        vm.prank(address(stakingPool));
        kkToken.mint(user1, mintAmount);

        vm.prank(user1);
        kkToken.transfer(user2, 50 * 1e18);

        assertEq(kkToken.balanceOf(user1), 50 * 1e18);
        assertEq(kkToken.balanceOf(user2), 50 * 1e18);
    }

    function test_RewardPerTokenCalculation() public {
        // 测试当没有质押时的奖励计算
        uint256 rewardPerToken = stakingPool.earned(user1);
        assertEq(rewardPerToken, 0);

        // 质押后计算奖励
        vm.prank(user1);
        stakingPool.stake{value: STAKE_AMOUNT}();

        vm.roll(block.number + 1);
        uint256 newReward = stakingPool.earned(user1);
        assertGt(newReward, 0);
    }

    function test_StakeInfoStructure() public {
        vm.prank(user1);
        stakingPool.stake{value: STAKE_AMOUNT}();

        // 验证质押信息
        assertEq(stakingPool.balanceOf(user1), STAKE_AMOUNT);

        // 跳过几个区块来产生奖励
        vm.roll(block.number + 5);
        assertGt(stakingPool.earned(user1), 0);
    }

    function test_ComplexStakingScenario() public {
        console.log("=== Starting Complex Staking Scenario Test ===");

        // 用户1质押 1 ETH
        console.log("Phase 1: User1 stakes 1 ETH");
        vm.prank(user1);
        stakingPool.stake{value: STAKE_AMOUNT}();
        console.log("User1 staked amount:", stakingPool.balanceOf(user1) / 1e18, "ETH");
        vm.prank(owner);
        console.log("Total staked in pool:", stakingPool.getTotalStaked() / 1e18, "ETH");

        // 跳过 10 个区块
        console.log("Phase 2: Advancing 10 blocks to generate rewards");
        vm.roll(block.number + 10);
        console.log("Current block number:", block.number);
        console.log("User1 earned rewards:", stakingPool.earned(user1) / 1e18, "KK tokens");

        // 用户2质押 2 ETH
        console.log("Phase 3: User2 stakes 2 ETH");
        vm.prank(user2);
        stakingPool.stake{value: 2 * STAKE_AMOUNT}();
        console.log("User2 staked amount:", stakingPool.balanceOf(user2) / 1e18, "ETH");
        vm.prank(owner);
        console.log("Total staked in pool:", stakingPool.getTotalStaked() / 1e18, "ETH");

        // 跳过 5 个区块
        console.log("Phase 4: Advancing 5 more blocks");
        vm.roll(block.number + 5);
        console.log("Current block number:", block.number);
        console.log("User1 earned rewards:", stakingPool.earned(user1) / 1e18, "KK tokens");
        console.log("User2 earned rewards:", stakingPool.earned(user2) / 1e18, "KK tokens");

        // 用户1赎回 0.5 ETH
        console.log("Phase 5: User1 unstakes 0.5 ETH");
        vm.prank(user1);
        stakingPool.unstake(0.5 ether);
        console.log("User1 remaining stake:", stakingPool.balanceOf(user1) / 1e18, "ETH");

        // 跳过 5 个区块
        console.log("Phase 6: Advancing 5 more blocks");
        vm.roll(block.number + 5);
        console.log("Current block number:", block.number);

        // 验证最终状态
        console.log("Phase 7: Verifying final state");
        assertEq(stakingPool.balanceOf(user1), 0.5 ether);
        console.log("User1 balance verified: 0.5 ETH");
        assertEq(stakingPool.balanceOf(user2), 2 ether);
        console.log("User2 balance verified: 2 ETH");

        vm.prank(owner);
        assertEq(stakingPool.getTotalStaked(), 2.5 ether);
        console.log("Total staked verified: 2.5 ETH");

        // 验证奖励
        console.log("Phase 8: Verifying reward distribution");
        uint256 user1Reward = stakingPool.earned(user1);
        uint256 user2Reward = stakingPool.earned(user2);

        assertGt(user1Reward, 0);
        console.log("User1 rewards verified:", user1Reward / 1e18, "KK tokens");
        assertGt(user2Reward, 0);
        console.log("User2 rewards verified:", user2Reward / 1e18, "KK tokens");

        console.log("=== Complex Staking Scenario Test Completed Successfully ===");
    }
}
