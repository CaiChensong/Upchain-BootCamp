// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 实现一个 rebase 型 Token

实现一个通缩的 Token （ERC20）， 用来理解 rebase 型 Token 的实现原理：

- 起始发行量为 1 亿，之后每过一年在上一年的发行量基础上下降 1%
- rebase 方法进行通缩
- balanceOf() 可反应通缩后的用户的正确余额。

需要测试 rebase 后，正确显示用户的余额， 贴出你的 github 代码

参考代码：https://github.com/ampleforth/ampleforth-contracts/blob/master/contracts/UFragments.sol
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RebaseToken is IERC20, Ownable {
    string private _name;
    string private _symbol;
    uint256 private _totalSupply;
    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 public constant INITIAL_SUPPLY = 100000000 * 1e18; // 1亿token
    uint256 public constant ANNUAL_DECREASE_RATE = 99; // 每年递减1%（99%）
    uint256 public constant TOTAL_GONS = type(uint256).max - (type(uint256).max % INITIAL_SUPPLY);

    uint256 public lastRebaseTime; // 上次rebase时间
    uint256 public rebaseInterval = 365 days; // rebase间隔（1年）

    uint256 private _gonsPerFragment; // 转换率
    mapping(address => uint256) private _gonBalances; // gons余额

    event Rebase(uint256 timestamp, uint256 newTotalSupply);

    constructor(address owner) Ownable(owner) {
        _name = "RebaseToken";
        _symbol = "RBT";

        _totalSupply = INITIAL_SUPPLY;
        _gonsPerFragment = TOTAL_GONS / _totalSupply;
        _gonBalances[owner] = TOTAL_GONS;
        lastRebaseTime = block.timestamp;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function scaledTotalSupply() external pure returns (uint256) {
        return TOTAL_GONS;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _gonBalances[account] / _gonsPerFragment;
    }

    function scaledBalanceOf(address account) external view returns (uint256) {
        return _gonBalances[account];
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(to != address(0), "Invalid to");
        require(value > 0, "Invalid value");

        _gonBalances[msg.sender] -= value * _gonsPerFragment;
        _gonBalances[to] += value * _gonsPerFragment;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _allowances[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(from != address(0), "Invalid from");
        require(to != address(0), "Invalid to");
        require(value > 0, "Invalid value");

        _allowances[from][msg.sender] -= value;

        _gonBalances[from] -= value * _gonsPerFragment;
        _gonBalances[to] += value * _gonsPerFragment;

        emit Transfer(from, to, value);
        return true;
    }

    function rebase() external onlyOwner returns (uint256) {
        // 检查是否达到rebase时间
        require(block.timestamp >= lastRebaseTime + rebaseInterval, "Too early to rebase");

        // 计算新的供应量（递减1%）
        uint256 newSupply = _totalSupply * ANNUAL_DECREASE_RATE / 100;

        // 更新状态
        _totalSupply = newSupply;
        _gonsPerFragment = TOTAL_GONS / _totalSupply;
        lastRebaseTime = block.timestamp;

        emit Rebase(block.timestamp, _totalSupply);

        return _totalSupply;
    }
}
