//SPDX-License-Identifier: MIT

/*
题目#1

在 W1D3 的 Bank 合约基础之上，编写 IBank 接口及BigBank 合约，使其满足 Bank 实现 IBank， BigBank 继承自 Bank ， 同时 BigBank 有附加要求：

    - 要求存款金额 >0.001 ether（用modifier权限控制）
    - BigBank 合约支持转移管理员

编写一个 Admin 合约， Admin 合约有自己的 Owner ，同时有一个取款函数 adminWithdraw(IBank bank) , adminWithdraw 中会调用 IBank 接口的 withdraw 方法从而把 bank 合约内的资金转移到 Admin 合约地址。

BigBank 和 Admin 合约 部署后，把 BigBank 的管理员转移给 Admin 合约地址，模拟几个用户的存款，然后 Admin 合约的Owner地址调用 adminWithdraw(IBank bank) 把 BigBank 的资金转移到 Admin 地址。
*/

pragma solidity ^0.8.0;

interface IBank {
    function withdraw(uint amount) external;
}

contract Bank is IBank {

    address[] public allAdmins;
    mapping(address => uint256) public accounts;
    address[3] public top3Accounts;

    constructor(address admin) {
        allAdmins.push(admin);
    }

    receive() external payable {
        accounts[msg.sender] += msg.value;
        updateTop3(msg.sender);
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

    function withdraw(uint amount) virtual external override {
        require(isAdmin(msg.sender), "only Admin can withdraw");
        require(address(this).balance >= amount, "contract balance not enough");
        payable(msg.sender).transfer(amount);
    }

    function addAdmin(address addr) public {
        require(isAdmin(msg.sender), "only Admin can add admin");
        require(allAdmins.length < 10, "limit 10 admins");
        allAdmins.push(addr);
    }

    function isAdmin(address addr) public view returns (bool) {
        for (uint i = 0; i < allAdmins.length; i++){
            if (allAdmins[i] == addr ){
                return true;
            }
        }
        return false;
    }

    function getTop3Accounts() public view returns (address[3] memory) {
        return top3Accounts;
    }
}

contract BigBank is Bank {

    constructor(address admin) Bank(admin) {
        allAdmins.push(admin);
    }

    modifier minBalance(uint amount) {
        require(
            address(this).balance - 0.001 ether >= amount,
            "Contract balance should be over 0.001 ether after deposit."
        );
        _;
    }

    function withdraw(uint amount) public override minBalance(amount) {
        require(isAdmin(msg.sender), "only Admin can withdraw");
        payable(msg.sender).transfer(amount);
    }
}

contract Admin {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    function adminWithdraw(IBank bank, uint amount) public {
        bank.withdraw(amount);
    }
}


