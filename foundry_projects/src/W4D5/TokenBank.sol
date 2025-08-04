// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
ERC20 Token 合约
- 代码：foundry_projects/src/W2D4/MyToken.sol
- 地址：https://sepolia.etherscan.io/address/0xc044905455dbe3ba560ff064304161b9995b1898

TokenBank 合约
- 代码：foundry_projects/src/W4D5/TokenBank.sol
- 地址：https://sepolia.etherscan.io/address/0xDbDDe79DB33e72741A52100f08B12D3603818318
*/
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenBank {
    IERC20 public token;
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address _token) {
        require(_token != address(0), "TokenBank: token address must be non-zero");
        token = IERC20(_token);
    }

    receive() external payable {}

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function withdraw(uint256 amount) public {
        require(amount > 0, "TokenBank: withdraw amount must be greater than zero");
        require(amount <= balances[msg.sender], "TokenBank: balance is not enough");

        balances[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "TokenBank: transfer failed");
        emit Withdraw(msg.sender, amount);
    }

    function deposit(uint256 amount) public payable {
        require(amount > 0, "TokenBank: deposit amount must be greater than zero");
        require(token.balanceOf(msg.sender) >= amount, "TokenBank: balance is not enough");

        require(token.transferFrom(msg.sender, address(this), amount), "TokenBank: transfer failed");
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }
}
