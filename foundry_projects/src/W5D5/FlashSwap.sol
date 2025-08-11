// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 模拟闪电兑换套利

在测试网上部署两个自己的 ERC20 合约 MyToken ，再部署两个 Uniswap，并创建两个Uniswap V2 流动池（称为 PoolA 和 PoolB），让 PoolA 和 PoolB 形成价差，创造套利条件。

编写合约执行闪电兑换，可参考 V2 的 ExampleFlashSwap。
提示：你需要在 UniswapV2Call中，用从 PoolA 收到的 TokenA 在 PoolB 兑换为 TokenB 并还回到 uniswapV2 Pair 中。

解题要求：

- 贴出你的代码库链接
- 上传执行闪电兑换的日志，能够反映闪电兑换成功执行。
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "uniswap-v2/v2-core/interfaces/IUniswapV2Callee.sol";
import "uniswap-v2/v2-core/interfaces/IUniswapV2Pair.sol";
import "uniswap-v2/v2-periphery/libraries/UniswapV2Library.sol";

contract FlashSwap is IUniswapV2Callee, Ownable {
    // 两个 Uniswap V2 工厂地址
    address public immutable factoryA;
    address public immutable factoryB;

    // 事件声明
    event FlashSwapExecuted(
        address indexed tokenA, address indexed tokenB, uint256 borrowedTokenAAmount, uint256 profitTokenBAmount
    );

    event FlashLoanBorrowed(address indexed tokenA, address indexed tokenB, uint256 amount);

    constructor(address _factoryA, address _factoryB) Ownable(msg.sender) {
        require(_factoryA != address(0), "FlashSwap: factoryA cannot be zero");
        require(_factoryB != address(0), "FlashSwap: factoryB cannot be zero");
        factoryA = _factoryA;
        factoryB = _factoryB;
    }

    // 执行闪电兑换套利的主函数
    // 1. 从 PoolA 借入 TokenA
    // 2. 在 PoolB 中用 TokenA 兑换为 TokenB
    // 3. 在 PoolA 中用部分 TokenB 兑换为 TokenA
    // 4. 把兑换好的 TokenA 还回 PoolA
    // 5. 计算利润
    function executeFlashSwapArbitrage(
        address tokenA, // TokenA 的地址
        address tokenB, // TokenB 的地址
        uint256 borrowAmount // 从 PoolA 借入的 TokenA 数量
    ) external onlyOwner {
        require(tokenA != tokenB, "FlashSwap: tokenA and tokenB are the same");
        require(borrowAmount > 0, "FlashSwap: borrowAmount must be greater than 0");
        require(tokenA != address(0), "FlashSwap: tokenA cannot be zero");
        require(tokenB != address(0), "FlashSwap: tokenB cannot be zero");

        // 获取 PoolA 的 Pair 合约
        IUniswapV2Pair pairA = IUniswapV2Pair(UniswapV2Library.pairFor(factoryA, tokenA, tokenB));
        require(address(pairA) != address(0), "FlashSwap: PoolA pair not found");

        // 计算需要借入的 TokenA 数量，根据 PoolA 中 TokenA 是 token0 还是 token1 来决定
        uint256 amount0 = pairA.token0() == tokenA ? borrowAmount : 0;
        uint256 amount1 = pairA.token1() == tokenA ? borrowAmount : 0;

        // 编码回调数据，包含 TokenA、TokenB 地址、借入数量
        bytes memory data = abi.encode(tokenA, tokenB);

        // 发出借入事件
        emit FlashLoanBorrowed(tokenA, tokenB, borrowAmount);

        // 执行闪电兑换，这会触发 uniswapV2Call 回调函数
        pairA.swap(amount0, amount1, address(this), data);
    }

    // Uniswap V2 闪电兑换的回调函数（当 PoolA 调用 swap 方法时，会触发这个函数）
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external override {
        // 解码回调数据，获取 TokenA、TokenB 地址、借入数量
        (address tokenA, address tokenB) = abi.decode(data, (address, address));

        // 验证调用者确实是 PoolA
        require(msg.sender == UniswapV2Library.pairFor(factoryA, tokenA, tokenB), "FlashSwap: caller must be PoolA");
        require(sender == address(this), "FlashSwap: sender must be this contract");

        // 计算实际借入的 TokenA 数量
        uint256 borrowedTokenAAmount = amount0 > 0 ? amount0 : amount1;

        // 执行套利逻辑
        uint256 profitAmount = _executeArbitrage(tokenA, tokenB, borrowedTokenAAmount);

        // 发出事件
        emit FlashSwapExecuted(tokenA, tokenB, borrowedTokenAAmount, profitAmount);

        // 将 TokenA 和 TokenB 转回给合约所有者
        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        if (balanceA > 0) {
            IERC20(tokenA).transfer(owner(), balanceA);
        }

        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));
        if (balanceB > 0) {
            IERC20(tokenB).transfer(owner(), balanceB);
        }
    }

    // 执行套利逻辑的核心函数
    function _executeArbitrage(address tokenA, address tokenB, uint256 borrowedTokenAAmount)
        internal
        returns (uint256)
    {
        // 获取 PoolA 和 PoolB 的 Pair 合约
        address pairA = UniswapV2Library.pairFor(factoryA, tokenA, tokenB);
        address pairB = UniswapV2Library.pairFor(factoryB, tokenA, tokenB);

        // 步骤1: 在 PoolB 中用 TokenA 兑换为 TokenB
        uint256 receivedTokenBAmount = _swapToken(tokenA, tokenB, borrowedTokenAAmount, pairB);

        // 步骤2: 计算需要还回 PoolA 的 TokenA 数量（包含 0.3% 的手续费）
        uint256 amountToRepay = borrowedTokenAAmount * 1000 / 997 + 1;

        // 步骤3: 计算需要多少 TokenB 来兑换回指定数量的 TokenA
        uint256 tokenBAmountNeeded = _calculateAmountIn(tokenA, tokenB, amountToRepay, pairA);

        // 步骤4: 在 PoolA 中用部分 TokenB 兑换为 TokenA
        // uint256 tokenAAmountToRepay = _swapToken(tokenB, tokenA, tokenBAmountNeeded, pairA);
        // require(tokenAAmountToRepay >= amountToRepay, "FlashSwap: insufficient TokenA to repay");

        // 步骤5: 还款给配对合约
        IERC20(tokenB).transfer(msg.sender, tokenBAmountNeeded);

        // 步骤6: 计算利润
        uint256 profitAmount = receivedTokenBAmount - tokenBAmountNeeded;

        return profitAmount;
    }

    // 兑换代币
    function _swapToken(address tokenIn, address tokenOut, uint256 amountIn, address pairAddress)
        internal
        returns (uint256)
    {
        require(pairAddress != address(0), "FlashSwap: Pool pair not found");
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);

        // 获取储备金
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();

        // 计算输出数量
        uint256 amountOut = UniswapV2Library.getAmountOut(amountIn, reserve0, reserve1);

        // 确定输出方向
        uint256 amount0Out = 0;
        uint256 amount1Out = 0;

        if (tokenIn == pair.token0()) {
            amount1Out = amountOut; // tokenIn是token0，输出tokenOut (token1)
        } else {
            amount0Out = amountOut; // tokenIn是token1，输出tokenOut (token0)
        }

        IERC20(tokenIn).transfer(pairAddress, amountIn);

        // 执行兑换
        pair.swap(amount0Out, amount1Out, address(this), new bytes(0));

        return amountOut;
    }

    function _calculateAmountIn(address tokenIn, address tokenOut, uint256 amountOut, address pairAddress)
        internal
        view
        returns (uint256)
    {
        require(pairAddress != address(0), "FlashSwap: Pool pair not found");
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);

        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();

        if (tokenIn == pair.token0()) {
            return UniswapV2Library.getAmountIn(amountOut, reserve0, reserve1);
        } else {
            return UniswapV2Library.getAmountIn(amountOut, reserve1, reserve0);
        }
    }

    // 紧急提取函数，用于提取意外发送到合约的代币
    function emergencyWithdraw(address token) external onlyOwner {
        require(token != address(0), "FlashSwap: token cannot be zero");
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(msg.sender, balance);
        }
    }
}
