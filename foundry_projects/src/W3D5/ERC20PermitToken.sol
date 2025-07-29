// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
使用 EIP2612 标准（可基于 Openzepplin 库）编写一个自己名称的 Token 合约。
*/

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ERC20PermitToken is ERC20Permit {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {
        _mint(msg.sender, 10000 ether);
    }
}
