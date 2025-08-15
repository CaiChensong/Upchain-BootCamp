// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 设计一个看涨期权 Token（ERC20）：

- 创建期权 Token 时，确认标的的价格与行权日期；
- 发行方法（项目方角色）：根据转入的标的（ETH）发行期权 Token；
- 行权方法（用户角色）：在到期日当天，可通过指定的价格兑换出标的资产，并销毁期权 Token；
- 过期销毁（项目方角色）：销毁所有期权 Token 赎回标的。
- （可选）：可以用期权 Token 与 USDT 以一个较低的价格创建交易对，模拟用户购买期权。

解题要求：

- 贴出你的代码库链接
- 上传模拟执行发行、行权过程的日志截图
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CallOptionToken is ERC20, Ownable, ReentrancyGuard {
    address public underlyingAsset; // 标的资产（如ETH）
    address public strikeAsset; // 行权价格计价资产（如USDC）
    uint256 public strikePrice; // 行权价格
    uint256 public expiryTimestamp; // 到期时间戳
    uint256 public collateralRatio; // 抵押率（如150% = 15000）

    uint256 public totalCollateral; // 总抵押的标的资产
    uint256 public totalIssuedOptions; // 已发行的期权数量
    uint256 public optionToUnderlyingRatio; // 每个期权Token对应的标的资产数量
    bool public isSettled; // 是否已结算

    uint256 private constant PRECISION = 1e18;
    uint256 private constant COLLATERAL_RATIO_BASE = 10000; // 最低抵押率 100% = 10000

    event OptionIssued(address indexed to, uint256 amount, uint256 collateral);
    event OptionExercised(address indexed user, uint256 amount, uint256 strikePaid);
    event OptionExpired(uint256 totalBurned, uint256 collateralReturned);
    event CollateralAdded(uint256 amount);

    constructor(
        address _owner,
        address _underlyingAsset,
        address _strikeAsset,
        uint256 _strikePrice,
        uint256 _expiryTimestamp,
        uint256 _collateralRatio,
        uint256 _optionToUnderlyingRatio
    ) ERC20("CallOptionToken", "COT") Ownable(_owner) {
        require(_underlyingAsset != address(0), "Invalid underlying asset");
        require(_strikeAsset != address(0), "Invalid strike asset");
        require(_strikePrice > 0, "Invalid strike price");
        require(_expiryTimestamp > block.timestamp, "Invalid expiry time");
        require(_collateralRatio > COLLATERAL_RATIO_BASE, "Invalid collateral ratio");

        underlyingAsset = _underlyingAsset;
        strikeAsset = _strikeAsset;
        strikePrice = _strikePrice;
        expiryTimestamp = _expiryTimestamp;
        collateralRatio = _collateralRatio;
        optionToUnderlyingRatio = _optionToUnderlyingRatio;
    }

    // 发行方法（项目方角色）：根据转入的标的（ETH）发行期权 Token
    function issueOptions(address to, uint256 collateralAmount) external onlyOwner nonReentrant {
        require(block.timestamp < expiryTimestamp, "Options already expired");
        require(collateralAmount > 0, "Invalid collateral amount");

        // 计算可发行的期权数量
        uint256 optionAmount = collateralAmount; // 1:1 ratio
        require(optionAmount > 0, "Invalid option amount");

        // 转移标的资产到合约
        IERC20(underlyingAsset).transferFrom(to, address(this), collateralAmount);

        // 更新状态
        totalCollateral += collateralAmount;
        totalIssuedOptions += optionAmount;

        // 铸造期权Token
        _mint(to, optionAmount);

        emit OptionIssued(to, optionAmount, collateralAmount);
    }

    // 行权方法（用户角色）：在到期日当天，可通过指定的价格兑换出标的资产，并销毁期权 Token
    function exercise(uint256 amount) external nonReentrant {
        require(block.timestamp < expiryTimestamp, "Options already expired");
        require(amount > 0, "Invalid amount");
        require(balanceOf(msg.sender) >= amount, "Insufficient options");
        require(totalCollateral > 0, "No collateral available");

        // 计算行权价格
        // strikePrice is in 18 decimals, but we need to convert to USDC decimals (6)
        uint256 strikeAmount = amount * strikePrice / (10 ** 18) / (10 ** 12);

        // 转移行权价格到合约
        IERC20(strikeAsset).transferFrom(msg.sender, address(this), strikeAmount);

        // 计算可获得的标的资产数量
        uint256 underlyingAmount = amount; // 1:1 ratio

        // 销毁期权Token
        _burn(msg.sender, amount);

        // 转移标的资产给用户
        IERC20(underlyingAsset).transfer(msg.sender, underlyingAmount);

        // 更新状态
        totalIssuedOptions -= amount;
        totalCollateral -= underlyingAmount;

        emit OptionExercised(msg.sender, amount, strikeAmount);
    }

    // 过期销毁（项目方角色）：销毁所有期权 Token 赎回标的
    function settleAfterExpiry() external onlyOwner nonReentrant {
        require(block.timestamp >= expiryTimestamp, "Not yet expired");
        require(!isSettled, "Already settled");
        require(totalCollateral > 0, "No collateral to settle");

        isSettled = true;

        // 销毁所有未行权的期权Token
        uint256 remainingOptions = totalSupply();
        if (remainingOptions > 0) {
            _burnAll();
        }

        // 转移剩余标的资产给项目方
        uint256 remainingCollateral = IERC20(underlyingAsset).balanceOf(address(this));
        if (remainingCollateral > 0) {
            IERC20(underlyingAsset).transfer(owner(), remainingCollateral);
        }

        // 转移行权价格收入给项目方
        uint256 strikeBalance = IERC20(strikeAsset).balanceOf(address(this));
        if (strikeBalance > 0) {
            IERC20(strikeAsset).transfer(owner(), strikeBalance);
        }

        emit OptionExpired(remainingOptions, remainingCollateral);
    }

    // 销毁所有期权Token
    function _burnAll() internal {
        // 这里我们不能直接销毁，因为期权Token在用户手中
        // 我们只需要更新状态变量
        totalIssuedOptions = 0;
    }

    // 获取期权状态信息
    function getOptionInfo()
        external
        view
        returns (
            uint256 _totalCollateral,
            uint256 _totalIssuedOptions,
            uint256 _remainingOptions,
            bool _isExpired,
            bool _isSettled
        )
    {
        return (totalCollateral, totalIssuedOptions, totalSupply(), block.timestamp >= expiryTimestamp, isSettled);
    }

    // 紧急提取（仅限owner）
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}
