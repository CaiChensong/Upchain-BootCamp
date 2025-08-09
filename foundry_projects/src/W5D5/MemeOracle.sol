// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 获取 Uniswap v2 中 TWAP 价格

编写一个合约去获取 LaunchPad 发行的 Meme 的 TWAP 价格，请在测试中模拟不同时间的多个交易。

提交你的 github 链接

相关合约：
- foundry_projects/src/W5D4/LaunchPad.sol
- foundry_projects/lib/uniswap_v2_fork/src
*/

import "uniswap-v2/v2-core/interfaces/IUniswapV2Factory.sol";
import "uniswap-v2/v2-core/interfaces/IUniswapV2Pair.sol";
import "uniswap-v2/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "uniswap-v2/v2-periphery/libraries/UniswapV2OracleLibrary.sol";
import "uniswap-v2/solidity-lib/libraries/FixedPoint.sol";

contract MemeOracle {
    using FixedPoint for *;

    // TWAP观察数据结构
    struct Observation {
        uint32 timestamp;
        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
    }

    // 每个代币对的TWAP数据
    struct TWAPData {
        address pair; // Uniswap交易对地址
        address token0; // 代币0地址
        address token1; // 代币1地址
        bool isToken0Base; // 是否以token0为基准计算价格
        uint32 period; // TWAP计算周期（秒）
        Observation[] observations; // 历史观察数据
        uint8 observationIndex; // 当前观察索引
    }

    // 状态变量
    IUniswapV2Factory public immutable factory;
    IUniswapV2Router02 public immutable router;

    // 存储每个Meme代币的TWAP数据
    mapping(address => TWAPData) public twapData;

    // 已初始化的代币集合
    mapping(address => bool) public initialized;

    // 事件
    event TWAPInitialized(address indexed token, address indexed pair, uint32 period);
    event ObservationUpdated(
        address indexed token, uint32 timestamp, uint256 price0Cumulative, uint256 price1Cumulative
    );

    constructor(address _factory, address _router) {
        require(_factory != address(0), "MemeOracle: Factory address cannot be zero");
        require(_router != address(0), "MemeOracle: Router address cannot be zero");

        factory = IUniswapV2Factory(_factory);
        router = IUniswapV2Router02(_router);
    }

    // 为Meme代币初始化TWAP观察器
    function initializeTWAP(address token, uint32 period) external {
        require(token != address(0), "MemeOracle: Token address cannot be zero");
        require(period > 0, "MemeOracle: Period must be greater than zero");
        require(!initialized[token], "MemeOracle: Already initialized");

        // 获取代币对地址（Meme/WETH）
        address pair = factory.getPair(token, router.WETH());
        require(pair != address(0), "MemeOracle: Pair does not exist");

        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        address token0 = pairContract.token0();
        address token1 = pairContract.token1();

        // 获取当前累积价格
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(pair);

        // 初始化TWAP数据
        TWAPData storage data = twapData[token];
        data.pair = pair;
        data.token0 = token0;
        data.token1 = token1;
        data.isToken0Base = (token == token0);
        data.period = period;

        // 添加初始观察点
        data.observations.push(
            Observation({
                timestamp: blockTimestamp,
                price0CumulativeLast: price0Cumulative,
                price1CumulativeLast: price1Cumulative
            })
        );

        data.observationIndex = 0;
        initialized[token] = true;

        emit TWAPInitialized(token, pair, period);
    }

    // 更新价格观察点
    function updateObservation(address token) external {
        require(initialized[token], "MemeOracle: Not initialized");

        TWAPData storage data = twapData[token];

        // 获取当前累积价格
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(data.pair);

        // 检查是否需要更新（避免在同一个区块重复更新）
        uint256 currentIndex = data.observationIndex;
        if (data.observations[currentIndex].timestamp == blockTimestamp) {
            return; // 同一区块内不更新
        }

        // 添加新的观察点
        data.observations.push(
            Observation({
                timestamp: blockTimestamp,
                price0CumulativeLast: price0Cumulative,
                price1CumulativeLast: price1Cumulative
            })
        );

        // 更新索引（循环使用，保持最近的观察点）
        data.observationIndex = uint8((currentIndex + 1) % 255); // 最多保存255个观察点

        emit ObservationUpdated(token, blockTimestamp, price0Cumulative, price1Cumulative);
    }

    // 获取当前TWAP价格（使用默认时间窗口）
    function getTWAPPrice(address token) external view returns (uint256 twapPrice) {
        require(initialized[token], "MemeOracle: Not initialized");

        TWAPData storage data = twapData[token];
        return _calculateTWAP(token, data.period);
    }

    // 获取当前TWAP价格（自定义时间窗口）
    function getTWAPPrice(address token, uint32 timeWindow) external view returns (uint256 twapPrice) {
        return _calculateTWAP(token, timeWindow);
    }

    // 计算指定时间窗口的TWAP价格
    function _calculateTWAP(address token, uint32 timeWindow) private view returns (uint256 twapPrice) {
        require(initialized[token], "MemeOracle: Not initialized");
        require(timeWindow > 0, "MemeOracle: Time window must be greater than zero");

        TWAPData storage data = twapData[token];
        uint256 observationsLength = data.observations.length;
        require(observationsLength >= 2, "MemeOracle: Insufficient observations");

        // 获取当前累积价格
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 currentTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(data.pair);

        // 寻找timeWindow前的观察点
        uint32 targetTimestamp = currentTimestamp - timeWindow;
        uint256 oldObservationIndex = _findObservationIndex(data, targetTimestamp);

        Observation storage oldObservation = data.observations[oldObservationIndex];

        // 计算时间差
        uint32 timeElapsed = currentTimestamp - oldObservation.timestamp;
        require(timeElapsed > 0, "MemeOracle: No time elapsed");

        // 计算累积价格差值并计算平均价格
        if (data.isToken0Base) {
            // token是token0，计算token0/token1的价格（即token/WETH）
            uint256 priceCumulativeDiff = price0Cumulative - oldObservation.price0CumulativeLast;
            twapPrice = priceCumulativeDiff / timeElapsed;
        } else {
            // token是token1，计算token1/token0的价格（即token/WETH）
            uint256 priceCumulativeDiff = price1Cumulative - oldObservation.price1CumulativeLast;
            twapPrice = priceCumulativeDiff / timeElapsed;
        }
    }

    // 查找指定时间戳之前最近的观察点索引
    function _findObservationIndex(TWAPData storage data, uint32 targetTimestamp)
        internal
        view
        returns (uint256 index)
    {
        uint256 observationsLength = data.observations.length;

        // 从最新的观察点向前查找
        for (uint256 i = observationsLength; i > 0; i--) {
            uint256 currentIndex = i - 1;
            if (data.observations[currentIndex].timestamp <= targetTimestamp) {
                return currentIndex;
            }
        }

        // 如果没有找到合适的观察点，返回最早的观察点
        return 0;
    }
}
