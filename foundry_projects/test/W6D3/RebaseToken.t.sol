// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/W6D3/RebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken public token;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    uint256 public constant INITIAL_SUPPLY = 100000000 * 1e18; // 1亿token
    uint256 public constant ANNUAL_DECREASE_RATE = 99; // 每年递减1%（99%）
    uint256 public constant TOTAL_GONS = type(uint256).max - (type(uint256).max % INITIAL_SUPPLY);

    event Rebase(uint256 timestamp, uint256 newTotalSupply);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        vm.prank(owner);
        token = new RebaseToken(owner);
    }

    function test_InitialState() public view {
        // 测试初始状态
        assertEq(token.name(), "RebaseToken");
        assertEq(token.symbol(), "RBT");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.scaledTotalSupply(), TOTAL_GONS);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.scaledBalanceOf(owner), TOTAL_GONS);
        assertEq(token.lastRebaseTime(), block.timestamp);
        assertEq(token.rebaseInterval(), 365 days);
    }

    function test_Transfer() public {
        uint256 transferAmount = 1000 * 1e18;

        vm.prank(owner);
        token.transfer(user1, transferAmount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(user1), transferAmount);
    }

    function test_TransferFrom() public {
        uint256 approveAmount = 1000 * 1e18;
        uint256 transferAmount = 500 * 1e18;

        vm.prank(owner);
        token.approve(user1, approveAmount);

        vm.prank(user1);
        token.transferFrom(owner, user2, transferAmount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
        assertEq(token.allowance(owner, user1), approveAmount - transferAmount);
    }

    function test_Rebase_TooEarly() public {
        // 尝试在rebase间隔之前调用rebase
        vm.prank(owner);
        vm.expectRevert("Too early to rebase");
        token.rebase();
    }

    function test_Rebase_Success() public {
        // 快进1年
        vm.warp(block.timestamp + 365 days);

        uint256 expectedNewSupply = INITIAL_SUPPLY * ANNUAL_DECREASE_RATE / 100;

        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Rebase(block.timestamp, expectedNewSupply);

        uint256 newSupply = token.rebase();

        assertEq(newSupply, expectedNewSupply);
        assertEq(token.totalSupply(), expectedNewSupply);
        assertEq(token.lastRebaseTime(), block.timestamp);
    }

    function test_Rebase_MultipleTimes() public {
        // 第一次rebase
        vm.warp(block.timestamp + 365 days);
        vm.prank(owner);
        uint256 firstRebaseSupply = token.rebase();

        // 第二次rebase
        vm.warp(block.timestamp + 365 days);
        vm.prank(owner);
        uint256 secondRebaseSupply = token.rebase();

        // 验证递减效果
        assertEq(firstRebaseSupply, INITIAL_SUPPLY * ANNUAL_DECREASE_RATE / 100);
        assertEq(secondRebaseSupply, firstRebaseSupply * ANNUAL_DECREASE_RATE / 100);

        // 验证总供应量
        assertEq(token.totalSupply(), secondRebaseSupply);
    }

    function test_Rebase_BalanceConsistency() public {
        // 先转移一些token给用户
        uint256 transferAmount = 10000 * 1e18;
        vm.prank(owner);
        token.transfer(user1, transferAmount);

        // 记录rebase前的余额
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 user1BalanceBefore = token.balanceOf(user1);

        // 执行rebase
        vm.warp(block.timestamp + 365 days);
        vm.prank(owner);
        token.rebase();

        // 验证余额比例保持不变（因为rebase是等比例调整）
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        uint256 user1BalanceAfter = token.balanceOf(user1);

        // 计算比例应该相等
        uint256 ratioBefore = (ownerBalanceBefore * 1e18) / user1BalanceBefore;
        uint256 ratioAfter = (ownerBalanceAfter * 1e18) / user1BalanceAfter;

        // 允许小的精度误差
        assertApproxEqRel(ratioBefore, ratioAfter, 0.01e18);
    }

    function test_Rebase_OnlyOwner() public {
        vm.warp(block.timestamp + 365 days);

        vm.prank(user1);
        vm.expectRevert();
        token.rebase();
    }

    function test_Rebase_ExactTiming() public {
        // 测试精确的时间间隔
        vm.warp(block.timestamp + 365 days - 1);

        // 尝试rebase应该失败
        vm.prank(owner);
        vm.expectRevert("Too early to rebase");
        token.rebase();

        // 再等一秒应该可以
        vm.warp(block.timestamp + 1);
        vm.prank(owner);
        token.rebase();
    }

    function test_Rebase_SupplyPrecision() public {
        // 测试供应量精度
        vm.warp(block.timestamp + 365 days);

        vm.prank(owner);
        uint256 newSupply = token.rebase();

        // 验证新供应量确实减少了1%
        uint256 expectedDecrease = INITIAL_SUPPLY - (INITIAL_SUPPLY * ANNUAL_DECREASE_RATE / 100);
        uint256 actualDecrease = INITIAL_SUPPLY - newSupply;

        assertEq(actualDecrease, expectedDecrease);
        assertTrue(newSupply < INITIAL_SUPPLY);
    }

    function test_Rebase_TransferAfterRebase() public {
        // 在rebase后测试转账功能
        vm.warp(block.timestamp + 365 days);
        vm.prank(owner);
        token.rebase();

        // 转账应该仍然正常工作
        uint256 transferAmount = 1000 * 1e18;
        vm.prank(owner);
        token.transfer(user1, transferAmount);

        assertEq(token.balanceOf(user1), transferAmount);
        assertEq(token.balanceOf(owner), token.totalSupply() - transferAmount);
    }

    function test_Rebase_EdgeCase_OneDay() public {
        // 测试边界情况：刚好1年后
        vm.warp(block.timestamp + 365 days);

        vm.prank(owner);
        token.rebase();

        // 立即尝试再次rebase应该失败
        vm.prank(owner);
        vm.expectRevert("Too early to rebase");
        token.rebase();
    }

    function test_Rebase_EdgeCase_OneYearPlusOneSecond() public {
        // 测试边界情况：1年零1秒后
        vm.warp(block.timestamp + 365 days + 1);

        vm.prank(owner);
        token.rebase();

        // 应该成功
        assertTrue(token.totalSupply() < INITIAL_SUPPLY);
    }

    function test_Rebase_EventEmission() public {
        vm.warp(block.timestamp + 365 days);

        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Rebase(block.timestamp, INITIAL_SUPPLY * ANNUAL_DECREASE_RATE / 100);

        token.rebase();
    }

    function test_Rebase_SupplyCalculation() public {
        // 手动计算预期的供应量变化
        uint256 expectedSupply = INITIAL_SUPPLY;

        for (uint256 i = 0; i < 5; i++) {
            expectedSupply = expectedSupply * ANNUAL_DECREASE_RATE / 100;
        }

        // 执行5次rebase
        for (uint256 i = 0; i < 5; i++) {
            vm.warp(block.timestamp + 365 days);
            vm.prank(owner);
            token.rebase();
        }

        assertEq(token.totalSupply(), expectedSupply);
    }

    function test_Rebase_ComplexScenario() public {
        // 复杂场景：多次转账和rebase
        uint256 transfer1 = 10000 * 1e18;
        uint256 transfer2 = 5000 * 1e18;

        console.log("=== Starting Complex Scenario Test ===");
        console.log("Initial total supply:", token.totalSupply());
        console.log("Initial owner balance:", token.balanceOf(owner));

        // 第一次转账
        vm.prank(owner);
        token.transfer(user1, transfer1);
        console.log("After first transfer:");
        console.log("  Owner balance:", token.balanceOf(owner));
        console.log("  User1 balance:", token.balanceOf(user1));

        // 第一次rebase
        vm.warp(block.timestamp + 365 days);
        vm.prank(owner);
        uint256 supplyAfterFirstRebase = token.rebase();
        console.log("After first rebase:");
        console.log("  New total supply:", supplyAfterFirstRebase);
        console.log("  Owner balance:", token.balanceOf(owner));
        console.log("  User1 balance:", token.balanceOf(user1));

        // 第二次转账
        vm.prank(user1);
        token.transfer(user2, transfer2);
        console.log("After second transfer:");
        console.log("  Owner balance:", token.balanceOf(owner));
        console.log("  User1 balance:", token.balanceOf(user1));
        console.log("  User2 balance:", token.balanceOf(user2));

        // 第二次rebase
        vm.warp(block.timestamp + 365 days);
        vm.prank(owner);
        uint256 supplyAfterSecondRebase = token.rebase();
        console.log("After second rebase:");
        console.log("  Final total supply:", supplyAfterSecondRebase);
        console.log("  Owner balance:", token.balanceOf(owner));
        console.log("  User1 balance:", token.balanceOf(user1));
        console.log("  User2 balance:", token.balanceOf(user2));

        // 验证总供应量
        assertEq(token.totalSupply(), supplyAfterSecondRebase);

        // 验证最终余额
        uint256 finalOwnerBalance = token.balanceOf(owner);
        uint256 finalUser1Balance = token.balanceOf(user1);
        uint256 finalUser2Balance = token.balanceOf(user2);

        // 验证所有余额都是正数
        assertTrue(finalOwnerBalance > 0);
        assertTrue(finalUser1Balance > 0);
        assertTrue(finalUser2Balance > 0);

        // 验证总余额等于总供应量
        uint256 totalBalances = finalOwnerBalance + finalUser1Balance + finalUser2Balance;
        assertEq(totalBalances, supplyAfterSecondRebase);
        console.log("Validation results:");
        console.log("  Total balances sum:", totalBalances);
        console.log("  Total supply:", supplyAfterSecondRebase);
        console.log("  All balances are positive: PASS");
        console.log("  Total balances equal total supply: PASS");

        // 验证用户2的余额确实收到了转账
        assertTrue(finalUser2Balance > 0);
        console.log("  User2 received transfer: PASS");
        console.log("=== Complex Scenario Test Completed ===");
    }
}
