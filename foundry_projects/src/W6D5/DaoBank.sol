// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DaoBank is Ownable, ReentrancyGuard {
    mapping(address => uint256) public accounts;

    event Deposit(address indexed depositor, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed recipient, uint256 amount);

    // owner 应该是 Timelock 合约
    constructor(address _owner) Ownable(_owner) {}

    receive() external payable {
        deposit();
    }

    function deposit() public payable nonReentrant {
        accounts[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        withdrawTo(amount, msg.sender);
    }

    // 增加一个 withdraw 方法，允许指定接收地址
    function withdrawTo(uint256 amount, address recipient) public onlyOwner nonReentrant {
        require(address(this).balance >= amount, "contract balance not enough");
        require(recipient != address(0), "invalid recipient address");

        payable(recipient).transfer(amount);
        emit Withdraw(msg.sender, recipient, amount);
    }
}
