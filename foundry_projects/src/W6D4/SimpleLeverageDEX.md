## 题目#1 实现一个极简的杠杆 DEX

基于 vAMM 的机制实现一个简单的杠杆 DEX，包含方法：

- 开启杠杆头寸： openPosition(uint256 \_margin, uint level, bool long)
- 关闭头寸并结算, 不考虑协议亏损 closePosition()
- 清算头寸 liquidatePosition(address \_user)

可参考这个框架代码，并把 TODO 部分补充完整。

完整实现：foundry_projects/src/W6D4/SimpleLeverageDEX.sol

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 极简的杠杆 DEX 实现， 完成 TODO 代码部分
contract SimpleLeverageDEX {
    uint256 public vK; // 100000
    uint256 public vETHAmount;
    uint256 public vUSDCAmount;

    IERC20 public USDC; // 自己创建一个币来模拟 USDC

    struct PositionInfo {
        uint256 margin; // 保证金    // 真实的资金， 如 USDC
        uint256 borrowed; // 借入的资金
        int256 position; // 虚拟 eth 持仓
    }

    mapping(address => PositionInfo) public positions;

    constructor(uint256 vEth, uint256 vUSDC) {
        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC;
    }

    // 开启杠杆头寸
    function openPosition(uint256 _margin, uint256 level, bool long) external {
        require(positions[msg.sender].position == 0, "Position already open");

        PositionInfo storage pos = positions[msg.sender];

        USDC.transferFrom(msg.sender, address(this), _margin); // 用户提供保证金
        uint256 amount = _margin * level;
        uint256 borrowAmount = amount - _margin;

        pos.margin = _margin;
        pos.borrowed = borrowAmount;

        // TODO:
        if (long) {
            pos.position =
        } else {
            pos.position =
        }
    }

    // 关闭头寸并结算, 不考虑协议亏损
    function closePosition() external {
        // TODO:
    }

    // 清算头寸， 清算的逻辑和关闭头寸类似，不过利润由清算用户获取
    // 注意： 清算人不能是自己，同时设置一个清算条件，例如亏损大于保证金的 80%
    function liquidatePosition(address _user) external {
        PositionInfo memory position = positions[_user];
        require(position.position != 0, "No open position");
        int256 pnl = calculatePnL(_user);

        // TODO:

        delete positions[_user];
    }

    // 计算盈亏： 对比当前的仓位和借的 vUSDC
    function calculatePnL(address user) public view returns (int256) {
        // TODO:
    }
}
```
