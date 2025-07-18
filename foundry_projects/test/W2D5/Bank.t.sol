// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
题目#1
使用 Foundry 测试 Bank 合约

测试 Case 包含：

- 断言检查存款前后用户在 Bank 合约中的存款额更新是否正确。
- 检查存款金额的前 3 名用户是否正确，分别检查有1个、2个、3个、4个用户，以及同一个用户多次存款的情况。
- 检查只有管理员可取款，其他人不可以取款。

请提交 github 仓库，仓库中需包含运行 case 通过的日志。
*/

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../../src/W1D3/Bank.sol";

contract BankTest is Test {
    Bank public bank;

    function setUp() public {
        bank = new Bank(address(this));
        bank.addAdmin(address(0x11));
    }

    function deposit(address addr, uint256 amount) public {
        vm.deal(addr, amount);
        vm.prank(addr);
        (bool isDeposit, ) = address(bank).call{value: amount}("");
        require(isDeposit, "deposit failed");
    }

    function test_Deposit() public {
        address user = address(0x1);

        assertEq(bank.accounts(user), 0);
        deposit(user, 1 ether);
        assertEq(bank.accounts(user), 1 ether);
    }

    function test_Top3Accounts_OneUser() public {
        address user = address(0x1);

        deposit(user, 2 ether);
        assertEq(bank.getTop3Accounts()[0], user);
    }

    function test_Top3Accounts_TwoUsers() public {
        address user1 = address(0x1);
        address user2 = address(0x2);

        deposit(user1, 2 ether);
        deposit(user2, 3 ether);

        assertEq(bank.getTop3Accounts()[0], user2);
        assertEq(bank.getTop3Accounts()[1], user1);
    }

    function test_Top3Accounts_ThreeUsers() public {
        address user1 = address(0x1);
        address user2 = address(0x2);
        address user3 = address(0x3);

        deposit(user1, 2 ether);
        deposit(user2, 3 ether);
        deposit(user3, 1 ether);

        assertEq(bank.getTop3Accounts()[0], user2);
        assertEq(bank.getTop3Accounts()[1], user1);
        assertEq(bank.getTop3Accounts()[2], user3);
    }

    function test_Top3Accounts_FourUsers() public {
        address user1 = address(0x1);
        address user2 = address(0x2);
        address user3 = address(0x3);
        address user4 = address(0x4);

        deposit(user1, 2 ether);
        deposit(user2, 3 ether);
        deposit(user3, 1 ether);
        deposit(user4, 4 ether);

        assertEq(bank.getTop3Accounts()[0], user4);
        assertEq(bank.getTop3Accounts()[1], user2);
        assertEq(bank.getTop3Accounts()[2], user1);
    }

    function test_Top3Accounts_SameUserMultipleDeposits() public {
        address user1 = address(0x1);
        address user2 = address(0x2);

        deposit(user1, 2 ether);
        deposit(user2, 3 ether);
        deposit(user1, 2 ether);

        assertEq(bank.getTop3Accounts()[0], user1);
        assertEq(bank.getTop3Accounts()[1], user2);
    }

    function test_AdminCanWithdraw() public {
        vm.deal(address(bank), 3 ether);
        uint256 before = address(bank).balance; 

        address admin = address(0x11);
        vm.startPrank(admin);
        bank.withdraw(1 ether);
        assertEq(before - address(bank).balance, 1 ether);
        vm.stopPrank();
    }

    function test_UserCanNotWithdraw() public {
        address user1 = address(0x1);
        vm.deal(address(bank), 1 ether);
        vm.prank(user1);
        vm.expectRevert("only Admin can withdraw");
        bank.withdraw(0.1 ether);
    }
}
