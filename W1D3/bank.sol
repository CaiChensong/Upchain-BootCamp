//SPDX-License-Identifier: MIT

/*
题目#1
编写一个 Bank 合约，实现功能：

    - 可以通过 Metamask 等钱包直接给 Bank 合约地址存款
    - 在 Bank 合约记录每个地址的存款金额
    - 编写 withdraw() 方法，仅管理员可以通过该方法提取资金。
    - 用数组记录存款金额的前 3 名用户
*/

pragma solidity ^0.8.0;
contract Bank {
    
    address[] public allAdmins;
    mapping(address => uint256) public accounts;
    address[] public allUsers;
    address[3] public top3Accounts;

    constructor(address admin) {
        allAdmins.push(admin);
    }

    receive() external payable {
        accounts[msg.sender] += msg.value;
        bool exists = false;
        for (uint i = 0; i < allUsers.length; i++) {
            if (allUsers[i] == msg.sender) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            allUsers.push(msg.sender);
        }
        updateTop3();
    }

    function updateTop3() private {
        address[3] memory newTop3;
        for (uint i = 0; i < allUsers.length; i++) {
            address user = allUsers[i];
            uint bal = accounts[user];
            for (uint j = 0; j < 3; j++) {
                if (bal > accounts[newTop3[j]]) {
                    for (uint k = 2; k > j; k--) {
                        newTop3[k] = newTop3[k-1];
                    }
                    newTop3[j] = user;
                    break;
                }
            }
        }
        for (uint i = 0; i < 3; i++) {
            top3Accounts[i] = newTop3[i];
        }
    }

    function withdraw(uint amount) public {
        require(isAdmin(msg.sender), "only Admin can withdraw");
        require(accounts[msg.sender] >= amount, "balance not enough");
        require(address(this).balance >= amount, "contract balance not enough");
        accounts[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        updateTop3();
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

    // 提供获取top3地址的函数
    function getTop3Accounts() public view returns (address[3] memory) {
        return top3Accounts;
    }
}

