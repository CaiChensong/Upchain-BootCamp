// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
题目#1
实现⼀个简单的多签合约钱包，合约包含的功能：

- 创建多签钱包时，确定所有的多签持有⼈和签名门槛
- 多签持有⼈可提交提案
- 其他多签持有⼈确认提案（使⽤交易的⽅式确认即可）
- 达到多签⻔槛、任何⼈都可以执⾏交易

提交代码或 github 链接。
 */

contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public minConfirmationsRequired;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    constructor(address[] memory _owners, uint256 _minConfirmationsRequired) {
        require(_owners.length > 0, "Owners array must not be empty");
        require(_minConfirmationsRequired > 0, "M confirmations required must be greater than 0");
        require(
            _minConfirmationsRequired <= _owners.length,
            "Min confirmations required must be less than or equal to the number of owners"
        );
        minConfirmationsRequired = _minConfirmationsRequired;

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Owner address must not be 0");
            require(!isOwner[owner], "Owner address must be unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
    }

    receive() external payable {}

    // 提交交易提案
    function submitTransaction(address to, uint256 value, bytes calldata data) public {
        require(to != address(0), "Invalid address");
        require(value > 0, "Invalid value");
        require(isOwner[msg.sender], "Not an owner");

        transactions.push(Transaction({to: to, value: value, data: data, executed: false, confirmationCount: 0}));
    }

    // 确认交易提案
    function confirmTransaction(uint256 transactionId) public {
        require(transactionId < transactions.length, "Invalid transaction ID");
        require(isOwner[msg.sender], "Not an owner");
        require(!confirmations[transactionId][msg.sender], "Already confirmed");
        require(!transactions[transactionId].executed, "Transaction already executed");

        confirmations[transactionId][msg.sender] = true;
        transactions[transactionId].confirmationCount++;
    }

    // 执行交易
    function executeTransaction(uint256 transactionId) public {
        require(transactionId < transactions.length, "Invalid transaction ID");
        require(isOwner[msg.sender], "Not an owner");
        require(!transactions[transactionId].executed, "Transaction already executed");
        require(transactions[transactionId].confirmationCount >= minConfirmationsRequired, "Not enough confirmations");

        transactions[transactionId].executed = true;
        (bool success,) = transactions[transactionId].to.call{value: transactions[transactionId].value}(
            transactions[transactionId].data
        );
        require(success, "Transaction execution failed");
    }

    // 取消交易提案
    function cancelConfirmation(uint256 transactionId) public {
        require(transactionId < transactions.length, "Invalid transaction ID");
        require(isOwner[msg.sender], "Not an owner");
        require(!transactions[transactionId].executed, "Transaction already executed");
        require(confirmations[transactionId][msg.sender], "Not confirmed");

        confirmations[transactionId][msg.sender] = false;
        transactions[transactionId].confirmationCount--;
    }

    // getters
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 transactionId) public view returns (address, uint256, bytes memory) {
        Transaction storage transaction = transactions[transactionId];
        return (transaction.to, transaction.value, transaction.data);
    }

    function getConfirmations(uint256 transactionId) public view returns (address[] memory) {
        Transaction storage transaction = transactions[transactionId];
        address[] memory confirmations = new address[](transaction.confirmationCount);
        for (uint256 i = 0; i < transaction.confirmationCount; i++) {
            confirmations[i] = owners[i];
        }
        return confirmations;
    }
}
