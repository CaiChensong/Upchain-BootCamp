// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
题目#1
使用 Foundry 测试 Bank 合约

测试 Case 包含：

- 断言检查存款前后用户在 Bank 合约中的存款额更新是否正确。
- 检查存款金额的前 3 名用户是否正确，分别检查有1个、2个、3个、4 个用户， 以及同一个用户多次存款的情况。
- 检查只有管理员可取款，其他人不可以取款。

请提交 github 仓库，仓库中需包含运行 case 通过的日志。
*/

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../../src/W1D3/Bank.sol";

contract BankTest is Test {
    Bank public bank;

    // function setUp() public {
    //     bank = new Bank();
    //     counter.setNumber(0);
    // }

    // function test_Increment() public {
    //     counter.increment();
    //     assertEq(counter.number(), 1);
    // }

    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
