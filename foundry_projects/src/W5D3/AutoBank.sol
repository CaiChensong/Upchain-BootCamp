// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
题目#1 基于第三方服务实现合约自动化调用

- 实现一个 Bank 合约， 用户可以通过 deposit() 存款
- 使用 ChainLink Automation 、Gelato 或 OpenZepplin Defender Action 实现一个自动化任务
- 自动化任务实现：当 Bank 合约的存款超过 x (可自定义数量)时， 转移一半的存款到指定的地址（如 Owner）。

请贴出你的代码 github 链接以及在第三方的执行工具中的执行链接。

ChainLink Automation 地址： 
https://automation.chain.link/sepolia/40795798953357201608071828915110389849153678698133803637661776812441318772360
*/

contract AutoBank is AutomationCompatibleInterface, Ownable {
    address public admin;
    mapping(address => uint256) public accounts;
    address[3] public top3Accounts;

    uint256 public automationThreshold;
    address public automationReceiver;

    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event Deposit(address indexed depositor, uint256 amount);
    event Withdraw(address indexed withdrawer, uint256 amount);
    event AutomationTriggered(uint256 contractBalance, uint256 transferredAmount);

    constructor() Ownable(msg.sender) {
        admin = msg.sender;
        automationThreshold = 1 ether;
        automationReceiver = msg.sender;
    }

    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData) {
        if (address(this).balance >= automationThreshold) {
            uint256 transferAmount = address(this).balance / 2;
            performData = abi.encode(transferAmount);

            return (true, performData);
        } else {
            return (false, "");
        }
    }

    function performUpkeep(bytes calldata performData) external {
        uint256 transferAmount = abi.decode(performData, (uint256));
        require(address(this).balance >= transferAmount, "Insufficient balance for automation");
        require(automationReceiver != address(0), "Invalid receiver address");

        payable(automationReceiver).transfer(transferAmount);
        emit AutomationTriggered(address(this).balance + transferAmount, transferAmount);
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        accounts[msg.sender] += msg.value;
        updateTop3(msg.sender);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(msg.sender == admin, "Only admin can withdraw");
        require(address(this).balance >= amount, "contract balance not enough");
        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    function getTop3Accounts() external view returns (address[3] memory, uint256[3] memory) {
        uint256[3] memory amounts;
        for (uint8 i = 0; i < 3; i++) {
            amounts[i] = accounts[top3Accounts[i]];
        }
        return (top3Accounts, amounts);
    }

    function changeAdmin(address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "New admin cannot be zero address");
        admin = newAdmin;
        emit AdminChanged(msg.sender, newAdmin);
    }

    function updateTop3(address addr) private {
        if (accounts[addr] >= accounts[top3Accounts[0]]) {
            top3Accounts[2] = top3Accounts[1];
            top3Accounts[1] = top3Accounts[0];
            top3Accounts[0] = addr;
        } else if (accounts[addr] >= accounts[top3Accounts[1]]) {
            top3Accounts[2] = top3Accounts[1];
            top3Accounts[1] = addr;
        } else if (accounts[addr] >= accounts[top3Accounts[2]]) {
            top3Accounts[2] = addr;
        }
    }

    function setAutomationThreshold(uint256 newThreshold) external onlyOwner {
        automationThreshold = newThreshold;
    }

    function setAutomationReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "Receiver cannot be zero address");
        automationReceiver = newReceiver;
    }
}
