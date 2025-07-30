// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/W4D3/Assembly.sol";

contract AssemblyTest is Test {
    MyWallet public wallet;
    address public owner = address(0x123);
    address public newOwner = address(0x456);

    function setUp() public {
        vm.startPrank(owner);
        wallet = new MyWallet("TestWallet");
        vm.stopPrank();
    }

    function testInlineAssemblyWorks() public {
        // 测试构造函数中的内联汇编是否生效
        // 如果内联汇编生效，owner 应该是 caller() 即 address(0x123)
        assertEq(wallet.owner(), owner);

        console.log("Original owner:", wallet.owner());
        console.log("Expected owner:", owner);
        console.log("Constructor inline assembly works");
    }

    function testTransferOwnershipWithAssembly() public {
        // 测试 transferOwnership 中的内联汇编是否生效
        vm.startPrank(owner);
        wallet.transferOwernship(newOwner);
        vm.stopPrank();

        assertEq(wallet.owner(), newOwner);

        console.log("New owner after transfer:", wallet.owner());
        console.log("Expected new owner:", newOwner);
        console.log("TransferOwnership inline assembly works");
    }

    function testAuthModifierWithAssembly() public {
        // 测试 auth modifier 中的内联汇编是否生效
        // 如果内联汇编生效，非 owner 调用应该被拒绝
        vm.startPrank(address(0x999)); // 非 owner 地址

        vm.expectRevert("Not authorized");
        wallet.transferOwernship(newOwner);

        console.log("Auth modifier inline assembly works - non-owner correctly rejected");
    }
}
