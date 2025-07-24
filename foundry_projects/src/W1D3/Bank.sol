//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1
编写一个 Bank 合约，实现功能：

    - 可以通过 Metamask 等钱包直接给 Bank 合约地址存款
    - 在 Bank 合约记录每个地址的存款金额
    - 编写 withdraw() 方法，仅管理员可以通过该方法提取资金。
    - 用数组记录存款金额的前 3 名用户
*/
contract Bank {
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

    function withdraw(uint256 amount) public {
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
        for (uint256 i = 0; i < allAdmins.length; i++) {
            if (allAdmins[i] == addr) {
                return true;
            }
        }
        return false;
    }

    function getTop3Accounts() public view returns (address[3] memory) {
        return top3Accounts;
    }
}
