// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 请填写下方合约中 owner 状态变量的存储插槽位置 slot 值：2

分析：
- name (string) 占用 slot 0
- approved (mapping) 占用 slot 1
- owner (address) 占用 slot 2

原始合约代码：
contract MyWallet { 
    public string name;
    private mapping (address => bool) approved;
    public address owner;

    modifier auth {
        require (msg.sender == owner, "Not authorized");
        _;
    }

    constructor(string _name) {
        name = _name;
        owner = msg.sender;
    } 

    function transferOwernship(address _addr) auth {
        require(_addr!=address(0), "New owner is the zero address");
        require(owner != _addr, "New owner is the same as the old owner");
        owner = _addr;
    }
}
*/

/*
题目#2

重新修改 MyWallet 合约的 transferOwernship 和 auth 逻辑，使用内联汇编方式来 set 和 get owner 地址。
*/

contract MyWallet {
    string public name;
    mapping(address => bool) private approved;
    address public owner;

    modifier auth() {
        address _owner;
        assembly {
            _owner := sload(2)
        }
        require(msg.sender == _owner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        assembly {
            sstore(2, caller())
        }
    }

    function transferOwernship(address _addr) public auth {
        require(_addr != address(0), "New owner is the zero address");
        address _owner;
        assembly {
            _owner := sload(2)
        }
        require(_owner != _addr, "New owner is the same as the old owner");
        assembly {
            sstore(2, _addr)
        }
    }
}
