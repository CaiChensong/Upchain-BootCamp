// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/W3D3/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet wallet;
    address[] owners;
    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);
    address recipient = address(0x4);

    function setUp() public {
        owners = new address[](3);
        owners[0] = alice;
        owners[1] = bob;
        owners[2] = carol;
        wallet = new MultiSigWallet(owners, 2);

        // 给钱包合约转入10 ether
        vm.deal(address(this), 10 ether);
        payable(address(wallet)).transfer(10 ether);
    }

    function testOwnersAndThreshold() public {
        assertEq(wallet.getOwners().length, 3);
        assertEq(wallet.minConfirmationsRequired(), 2);
    }

    function testSubmitTransaction() public {
        vm.prank(alice);
        wallet.submitTransaction(recipient, 1 ether, "");
        assertEq(wallet.getTransactionCount(), 1);
    }

    function testConfirmAndExecuteTransaction() public {
        // Alice 提交交易
        vm.prank(alice);
        wallet.submitTransaction(recipient, 1 ether, "");

        // Bob 确认
        vm.prank(bob);
        wallet.confirmTransaction(0);

        // Alice 确认
        vm.prank(alice);
        wallet.confirmTransaction(0);

        // 执行前余额
        uint256 before = recipient.balance;

        // 执行交易
        vm.prank(alice);
        wallet.executeTransaction(0);

        // 检查执行后余额
        assertEq(recipient.balance, before + 1 ether);

        // 检查executed标志
        (,,, bool executed,) = wallet.transactions(0);
        assertTrue(executed);
    }

    function testCannotExecuteWithoutEnoughConfirmations() public {
        vm.prank(alice);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(alice);
        wallet.confirmTransaction(0);

        vm.prank(alice);
        vm.expectRevert("Not enough confirmations");
        wallet.executeTransaction(0);
    }

    function testCancelConfirmation() public {
        vm.prank(alice);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(alice);
        wallet.confirmTransaction(0);

        vm.prank(alice);
        wallet.cancelConfirmation(0);

        // 再次确认
        vm.prank(alice);
        wallet.confirmTransaction(0);
    }

    function testOnlyOwnerCanSubmit() public {
        vm.prank(address(0x5));
        vm.expectRevert("Not an owner");
        wallet.submitTransaction(recipient, 1 ether, "");
    }

    function testOnlyOwnerCanConfirm() public {
        vm.prank(alice);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(address(0x5));
        vm.expectRevert("Not an owner");
        wallet.confirmTransaction(0);
    }

    function testCannotDoubleConfirm() public {
        vm.prank(alice);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(alice);
        wallet.confirmTransaction(0);

        vm.prank(alice);
        vm.expectRevert("Already confirmed");
        wallet.confirmTransaction(0);
    }

    function testCannotExecuteTwice() public {
        vm.prank(alice);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(alice);
        wallet.confirmTransaction(0);
        vm.prank(bob);
        wallet.confirmTransaction(0);

        vm.prank(alice);
        wallet.executeTransaction(0);

        vm.prank(alice);
        vm.expectRevert("Transaction already executed");
        wallet.executeTransaction(0);
    }
}
