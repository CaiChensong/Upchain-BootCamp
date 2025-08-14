// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";

// 基于 vAMM 的机制实现一个简单的杠杆 DEX
contract SimpleLeverageDEX {
    using SignedMath for int256;

    // uint256 private constant PRECISION = 1e9;

    uint256 public vK;
    uint256 public vETHAmount; // 基础资产数量 baseAmount
    uint256 public vUSDCAmount; // 报价资产数量 quoteAmount

    IERC20 public USDC; // 自己创建一个币来模拟 USDC

    // 事件定义
    event PositionOpened(address indexed user, uint256 margin, uint256 leverage, bool isLong, uint256 timestamp);

    event PositionClosed(address indexed user, uint256 margin, int256 pnl, uint256 timestamp);

    event PositionLiquidated(
        address indexed user, address indexed liquidator, uint256 margin, int256 pnl, uint256 timestamp
    );

    struct PositionInfo {
        uint256 margin; // 保证金，真实的资金，如 USDC
        uint256 borrowed; // 借入的资金
        int256 position; // 虚拟 ETH 持仓
    }

    mapping(address => PositionInfo) public positions;

    constructor(uint256 vEth, uint256 vUSDC, address token) {
        USDC = IERC20(token);
        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC;
    }

    // 开启杠杆头寸
    function openPosition(uint256 _margin, uint256 _leverage, bool _long) external {
        require(positions[msg.sender].position == 0, "Position already open");

        // 计算虚拟资产数量
        uint256 vQuoteAmount = _margin * _leverage;

        uint256 quoteReserveAfter = _long ? vUSDCAmount + vQuoteAmount : vUSDCAmount - vQuoteAmount;
        require(quoteReserveAfter > 0, "Insufficient quote reserve");

        uint256 baseReserveAfter = vK / quoteReserveAfter;

        // 记录用户头寸
        positions[msg.sender] = PositionInfo({
            margin: _margin,
            borrowed: vQuoteAmount - _margin,
            position: int256(vETHAmount) - int256(baseReserveAfter)
        });

        // 更新虚拟资产池
        vUSDCAmount = quoteReserveAfter;
        vETHAmount = baseReserveAfter;

        // 用户提供保证金
        USDC.transferFrom(msg.sender, address(this), _margin);

        // 触发开仓事件
        emit PositionOpened(msg.sender, _margin, _leverage, _long, block.timestamp);
    }

    // 关闭头寸并结算, 不考虑协议亏损
    function closePosition() external {
        PositionInfo memory position = positions[msg.sender];
        require(position.position != 0, "No open position");

        // 计算盈亏
        int256 totalReturn = int256(position.margin) + calculatePnL(msg.sender);

        if (totalReturn > 0) {
            USDC.transfer(msg.sender, totalReturn.abs());
        }

        // 更新虚拟资产池
        int256 baseAmount = int256(vETHAmount) + int256(position.position);
        uint256 quoteAmount = vK / baseAmount.abs();
        vUSDCAmount = quoteAmount;
        vETHAmount = baseAmount.abs();

        // 删除头寸
        delete positions[msg.sender];

        // 触发平仓事件
        emit PositionClosed(msg.sender, position.margin, calculatePnL(msg.sender), block.timestamp);
    }

    // 清算头寸，清算的逻辑和关闭头寸类似，不过利润由清算用户获取
    // 注意：清算人不能是自己，同时设置一个清算条件，例如亏损大于保证金的 80%
    function liquidatePosition(address _user) external {
        require(_user != msg.sender, "Cannot liquidate self");

        PositionInfo memory position = positions[_user];
        require(position.position != 0, "No open position");

        int256 pnl = calculatePnL(_user);
        if (pnl < 0 && pnl.abs() > position.margin * 80 / 100) {
            int256 totalReturn = int256(position.margin) + pnl;
            if (totalReturn > 0) {
                USDC.transfer(msg.sender, totalReturn.abs());
            }
        }

        // 更新虚拟资产池
        int256 baseAmount = int256(vETHAmount) + int256(position.position);
        uint256 quoteAmount = vK / baseAmount.abs();
        vUSDCAmount = quoteAmount;
        vETHAmount = baseAmount.abs();

        delete positions[_user];

        // 触发清算事件
        emit PositionLiquidated(_user, msg.sender, position.margin, pnl, block.timestamp);
    }

    // 计算盈亏：对比当前的仓位和借的 vUSDC
    function calculatePnL(address user) public view returns (int256) {
        PositionInfo memory position = positions[user];
        if (position.position == 0) return 0;

        uint256 currentETHPrice = vUSDCAmount / vETHAmount;
        uint256 currentPositionValue = position.position.abs() * currentETHPrice;

        return int256(currentPositionValue) - int256(position.borrowed) - int256(position.margin);
    }

    function getPositionInfo(address user) public view returns (uint256 margin, uint256 borrowed, int256 position) {
        return (positions[user].margin, positions[user].borrowed, positions[user].position);
    }
}
