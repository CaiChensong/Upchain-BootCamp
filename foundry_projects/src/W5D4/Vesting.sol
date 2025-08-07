// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 编写一个线性解锁（ Vesting） 合约

编写一个 Vesting 合约（可参考 OpenZepplin Vesting 相关合约）， 相关的参数有：

- beneficiary： 受益人
- 锁定的 ERC20 地址
- Cliff：12 个月
- 线性释放：接下来的 24 个月，从 第 13 个月起开始每月解锁 1/24 的 ERC20

Vesting 合约包含的方法 release() 用来释放当前解锁的 ERC20 给受益人，Vesting 合约部署后，开始计算 Cliff ，并转入 100 万 ERC20 资产。

要求在 Foundry 包含时间模拟测试，请贴出你的 github 代码库。

相关 ERC20 Token 合约：foundry_projects/src/W2D4/MyToken.sol
*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Vesting is Ownable {
    address public _token;

    uint256 public _cliff;
    uint256 public _duration;
    uint256 public _start;

    uint256 public _releasedAmount;

    event Released(uint256 amount);

    constructor(address beneficiary, address token, uint256 cliffMonth, uint256 durationMonth) Ownable(beneficiary) {
        _token = token;
        _start = block.timestamp;
        _duration = durationMonth * 30 days;

        require(cliffMonth <= durationMonth, "Cliff can not be greater than duration");
        _cliff = cliffMonth * 30 days;

        _releasedAmount = 0;
    }

    function release() public onlyOwner {
        uint256 vestedAmount = releasableAmount();
        _releasedAmount += vestedAmount;
        IERC20(_token).transfer(owner(), vestedAmount);
        emit Released(vestedAmount);
    }

    function releasableAmount() private view returns (uint256) {
        return getVestedAmount() - _releasedAmount;
    }

    function getVestedAmount() private view returns (uint256) {
        uint256 currentTime = block.timestamp;
        uint256 currentBalance = IERC20(_token).balanceOf(address(this));

        if (currentTime < _start + _cliff) {
            return 0;
        }

        if (currentTime > _start + _duration) {
            return currentBalance;
        }

        uint256 totalAmount = currentBalance + _releasedAmount;
        return (totalAmount * (currentTime - _start - _cliff)) / _duration;
    }
}
