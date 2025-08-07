// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/W5D4/Vesting.sol";
import "../../src/W2D4/MyToken.sol";

contract VestingTest is Test {
    Vesting public vesting;
    MyToken public token;

    address public beneficiary = address(0x123);
    address public deployer = address(this);

    uint256 public constant CLIFF_MONTHS = 12;
    uint256 public constant DURATION_MONTHS = 24;
    uint256 public constant MONTH = 30 days;
    uint256 public constant TOTAL_AMOUNT = 1_000_000 * 1e18; // 100万token

    function setUp() public {
        // 部署ERC20 token
        token = new MyToken("TestToken", "TT");

        // 部署Vesting合约
        vesting = new Vesting(beneficiary, address(token), CLIFF_MONTHS, DURATION_MONTHS);

        // 转入100万token到Vesting合约
        token.transfer(address(vesting), TOTAL_AMOUNT);

        // 切换到受益人账户
        vm.startPrank(beneficiary);
    }

    function test_Constructor() public {
        assertEq(vesting.owner(), beneficiary);
        assertEq(vesting._token(), address(token));
        assertEq(vesting._cliff(), CLIFF_MONTHS * MONTH);
        assertEq(vesting._duration(), DURATION_MONTHS * MONTH);
        assertEq(vesting._releasedAmount(), 0);
        assertEq(token.balanceOf(address(vesting)), TOTAL_AMOUNT);
    }

    function test_ReleaseBeforeCliff() public {
        // 在cliff期间尝试释放
        uint256 initialBalance = token.balanceOf(beneficiary);
        vesting.release();
        uint256 finalBalance = token.balanceOf(beneficiary);

        // 应该没有释放任何token
        assertEq(finalBalance, initialBalance);
        assertEq(vesting._releasedAmount(), 0);
    }

    function test_ReleaseAfterCliff() public {
        // 快进到cliff结束后1个月
        vm.warp(block.timestamp + CLIFF_MONTHS * MONTH + MONTH);

        uint256 initialBalance = token.balanceOf(beneficiary);
        vesting.release();
        uint256 finalBalance = token.balanceOf(beneficiary);

        // 应该释放 1/24 的总金额
        uint256 expectedRelease = TOTAL_AMOUNT / 24;
        assertEq(finalBalance - initialBalance, expectedRelease);
        assertEq(vesting._releasedAmount(), expectedRelease);
    }

    function test_ReleaseMultipleTimes() public {
        // 快进到cliff结束后2个月
        vm.warp(block.timestamp + CLIFF_MONTHS * MONTH + 2 * MONTH);

        uint256 initialBalance = token.balanceOf(beneficiary);
        vesting.release();
        uint256 balanceAfterFirst = token.balanceOf(beneficiary);

        // 再次释放
        vesting.release();
        uint256 finalBalance = token.balanceOf(beneficiary);

        // 第一次应该释放 2/24 的总金额
        uint256 expectedFirstRelease = TOTAL_AMOUNT * 2 / 24;
        assertEq(balanceAfterFirst - initialBalance, expectedFirstRelease);

        // 第二次应该没有释放（因为已经释放过了）
        assertEq(finalBalance, balanceAfterFirst);
        assertEq(vesting._releasedAmount(), expectedFirstRelease);
    }

    function test_ReleaseAtEnd() public {
        // 快进到总周期结束
        vm.warp(block.timestamp + DURATION_MONTHS * MONTH);

        uint256 initialBalance = token.balanceOf(beneficiary);
        vesting.release();
        uint256 finalBalance = token.balanceOf(beneficiary);

        // 应该释放一半的token
        assertEq(finalBalance - initialBalance, TOTAL_AMOUNT / 2);
        assertEq(vesting._releasedAmount(), TOTAL_AMOUNT / 2);
        assertEq(token.balanceOf(address(vesting)), TOTAL_AMOUNT / 2);
    }

    function test_ReleaseAfterEnd() public {
        // 快进到总周期结束后
        vm.warp(block.timestamp + DURATION_MONTHS * MONTH + MONTH);

        uint256 initialBalance = token.balanceOf(beneficiary);
        vesting.release();
        uint256 finalBalance = token.balanceOf(beneficiary);

        // 应该释放所有剩余token
        assertEq(finalBalance - initialBalance, TOTAL_AMOUNT);
        assertEq(vesting._releasedAmount(), TOTAL_AMOUNT);
        assertEq(token.balanceOf(address(vesting)), 0);
    }

    function test_LinearVesting() public {
        uint256 totalReleased = 0;
        uint256 startTime = block.timestamp;

        // 测试每个月的释放情况
        for (uint256 month = 1; month <= 12; month++) {
            // 快进到cliff结束后第month个月
            vm.warp(startTime + CLIFF_MONTHS * MONTH + month * MONTH);

            uint256 initialBalance = token.balanceOf(beneficiary);
            vesting.release();
            uint256 finalBalance = token.balanceOf(beneficiary);

            uint256 released = finalBalance - initialBalance;
            totalReleased += released;

            uint256 expectedIncrementalRelease = TOTAL_AMOUNT / 24;
            assertApproxEqRel(released, expectedIncrementalRelease, 1e15);
        }

        // 验证总共释放了1/2的总金额
        assertEq(totalReleased, TOTAL_AMOUNT / 2);
    }

    function test_OnlyOwnerCanRelease() public {
        // 切换到非受益人账户
        vm.stopPrank();
        vm.startPrank(address(0x456));

        // 快进到cliff结束后
        vm.warp(block.timestamp + CLIFF_MONTHS * MONTH + MONTH);

        // 非受益人应该无法释放
        vm.expectRevert();
        vesting.release();
    }

    function test_CliffGreaterThanDuration() public {
        // 测试cliff大于duration的情况
        vm.expectRevert("Cliff can not be greater than duration");
        new Vesting(beneficiary, address(token), 25, 24);
    }
}
