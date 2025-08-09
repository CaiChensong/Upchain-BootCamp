// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/W5D5/MemeOracle.sol";
import "../../src/W5D4/LaunchPad.sol";
import "uniswap-v2/v2-core/UniswapV2Factory.sol";
import "uniswap-v2/v2-core/UniswapV2Pair.sol";
import "uniswap-v2/v2-periphery/UniswapV2Router02.sol";
import "uniswap-v2/v2-periphery/test/WETH9.sol";

contract MemeOracleTest is Test {
    // 事件定义，用于监听部署的Meme代币地址
    event MemeDeployed(
        address indexed memeAddress, string symbol, uint256 totalSupply, uint256 perMint, uint256 price, address creator
    );

    // 核心合约实例
    MemeOracle oracle;
    MemeLaunchPad launchPad;
    UniswapV2Factory factory;
    UniswapV2Router02 router;
    WETH9 weth;

    // 测试账户
    address memeToken;
    address owner;
    address memeCreator;
    address buyer1;
    address buyer2;
    address buyer3;

    // 测试常量（参考MemeLaunchPad.t.sol的设置）
    uint256 constant INITIAL_ETH = 100 ether;
    uint256 constant MEME_TOTAL_SUPPLY = 1000000; // 100万代币
    uint256 constant MEME_PER_MINT = 1000; // 每次铸造1000代币
    uint256 constant MEME_PRICE_PER_TOKEN = 0.00001 ether; // 每个代币0.00001 ETH
    uint256 constant TOTAL_MINT_PRICE = 0.01 ether; // 每次铸造总价格 = 1000 * 0.00001 = 0.01 ETH

    function setUp() public {
        console.log("Setting up test environment...");

        // 创建测试账户
        owner = makeAddr("owner");
        memeCreator = makeAddr("memeCreator");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        buyer3 = makeAddr("buyer3");

        // 分配初始ETH
        vm.deal(owner, INITIAL_ETH);
        vm.deal(memeCreator, INITIAL_ETH);
        vm.deal(buyer1, INITIAL_ETH);
        vm.deal(buyer2, INITIAL_ETH);
        vm.deal(buyer3, INITIAL_ETH);
        vm.deal(address(this), INITIAL_ETH);

        // 部署Uniswap基础设施
        vm.startPrank(owner);

        // 部署WETH
        weth = new WETH9();
        console.log("WETH deployed at:", address(weth));

        // 部署Uniswap V2 Factory
        factory = new UniswapV2Factory(owner);
        console.log("Uniswap V2 Factory deployed at:", address(factory));

        // 部署Uniswap V2 Router
        router = new UniswapV2Router02(address(factory), address(weth));
        console.log("Uniswap V2 Router deployed at:", address(router));

        // 部署MemeLaunchPad
        launchPad = new MemeLaunchPad(owner, address(router));
        console.log("MemeLaunchPad deployed at:", address(launchPad));

        // 部署MemeOracle
        oracle = new MemeOracle(address(factory), address(router));
        console.log("MemeOracle deployed at:", address(oracle));

        vm.stopPrank();

        // 部署测试用的Meme代币
        _deployTestMeme();

        console.log("Test setup completed");
    }

    // 辅助函数：部署测试用的Meme代币
    function _deployTestMeme() internal {
        vm.startPrank(memeCreator);

        // 监听MemeDeployed事件来获取部署的地址
        vm.recordLogs();
        launchPad.deployMeme("TESTMEME", MEME_TOTAL_SUPPLY, MEME_PER_MINT, MEME_PRICE_PER_TOKEN);

        // 从事件中提取地址
        Vm.Log[] memory entries = vm.getRecordedLogs();
        memeToken = address(uint160(uint256(entries[0].topics[1])));

        console.log("Test Meme token deployed at:", memeToken);

        vm.stopPrank();
    }

    function testCompleteFlow() public {
        console.log("\n=== Starting Complete TWAP Oracle Test Flow ===");

        // 步骤1: 通过LaunchPad铸造代币以添加流动性
        _mintMemesToAddLiquidity();

        // 步骤2: 初始化TWAP Oracle
        _initializeTWAPOracle();

        // 步骤3: 模拟不同时间的多个交易
        _simulateTradesOverTime();

        // 步骤4: 测试TWAP计算功能
        _testTWAPCalculations();

        console.log("\n=== Complete TWAP Oracle Test Flow Finished ===");
    }

    // 步骤1: 通过LaunchPad铸造代币以添加流动性
    function _mintMemesToAddLiquidity() internal {
        console.log("\n--- Step 1: Minting Memes to Add Liquidity ---");

        // 验证Meme代币已部署
        assertTrue(launchPad.isMeme(memeToken), "Meme token should be deployed");
        console.log("Using deployed Meme token:", memeToken);

        // 使用预定义的铸造价格
        console.log("Mint price per transaction:", TOTAL_MINT_PRICE);

        vm.startPrank(buyer1);

        // 第一次铸造会自动添加流动性到Uniswap
        launchPad.mintMeme{value: TOTAL_MINT_PRICE}(memeToken);

        vm.stopPrank();

        // 验证流动性已添加
        assertTrue(launchPad.isLiquidityAdded(memeToken), "Liquidity should be added");

        // 验证Uniswap交易对已创建
        address pair = factory.getPair(memeToken, address(weth));
        assertTrue(pair != address(0), "Uniswap pair should exist");

        console.log("Uniswap pair created at:", pair);
        console.log("User1 meme balance:", MemeToken(memeToken).balanceOf(buyer1));
        console.log("Liquidity added successfully");
    }

    // 步骤2: 初始化TWAP Oracle
    function _initializeTWAPOracle() internal {
        console.log("\n--- Step 2: Initialize TWAP Oracle ---");

        // 验证Uniswap交易对存在
        address pair = factory.getPair(memeToken, address(weth));
        assertTrue(pair != address(0), "Uniswap pair must exist before initializing oracle");

        // 初始化TWAP Oracle
        uint32 period = 3600; // 1小时周期
        oracle.initializeTWAP(memeToken, period);

        console.log("TWAP Oracle initialized for token:", memeToken);
        console.log("Default period:", period, "seconds");

        // 验证初始化成功
        bool isInit = oracle.initialized(memeToken);
        assertTrue(isInit, "Oracle should be initialized");
        console.log("Oracle initialization status:", isInit);

        // 获取并显示当前交易对储备量
        (uint112 reserve0, uint112 reserve1,) = UniswapV2Pair(pair).getReserves();
        console.log("Initial pair reserves:");
        console.log("Reserve0:", uint256(reserve0));
        console.log("Reserve1:", uint256(reserve1));
    }

    // 步骤3: 模拟不同时间的多个交易
    function _simulateTradesOverTime() internal {
        console.log("\n--- Step 3: Simulating Trades Over Time ---");

        // 初始观察点记录
        oracle.updateObservation(memeToken);
        console.log("Initial observation recorded");

        // 交易1: buyer2用1 ETH购买代币 (时间: 0)
        console.log("\n> Trade 1 - Buyer2 buys with 1 ETH");
        _performSwap(buyer2, 1 ether, true);
        oracle.updateObservation(memeToken);
        _logCurrentState("After Trade 1");

        // 时间推进30分钟
        vm.warp(block.timestamp + 1800);
        console.log("\nTime advanced by 30 minutes");

        // 交易2: buyer3通过LaunchPad铸造代币
        console.log("\n> Trade 2 - Buyer3 mints through LaunchPad");
        vm.prank(buyer3);
        launchPad.mintMeme{value: TOTAL_MINT_PRICE}(memeToken);
        oracle.updateObservation(memeToken);
        _logCurrentState("After Trade 2");

        // 时间推进30分钟 (总计1小时)
        vm.warp(block.timestamp + 1800);
        console.log("\nTime advanced by 30 minutes (total: 1 hour)");

        // 交易3: buyer1进行大额购买
        console.log("\n> Trade 3 - Buyer1 large buy with 2 ETH");
        _performSwap(buyer1, 2 ether, true);
        oracle.updateObservation(memeToken);
        _logCurrentState("After Trade 3");

        // 时间推进15分钟
        vm.warp(block.timestamp + 900);
        console.log("\nTime advanced by 15 minutes");

        // 最终观察点更新
        oracle.updateObservation(memeToken);
        console.log("Final observation updated");
    }

    // 辅助函数: 执行Uniswap交易
    function _performSwap(address user, uint256 amount, bool isBuy) internal {
        address[] memory path = new address[](2);

        vm.startPrank(user);

        if (isBuy) {
            // 购买代币（用ETH买代币）
            path[0] = address(weth);
            path[1] = memeToken;

            try router.swapExactETHForTokens{value: amount}(0, path, user, block.timestamp + 300) returns (
                uint256[] memory amounts
            ) {
                console.log("Bought tokens:", amounts[1]);
                console.log("User token balance:", MemeToken(memeToken).balanceOf(user));
            } catch Error(string memory reason) {
                console.log("Swap failed:", reason);
            }
        } else {
            // 卖出代币（用代币换ETH）
            path[0] = memeToken;
            path[1] = address(weth);

            MemeToken(memeToken).approve(address(router), amount);

            try router.swapExactTokensForETH(amount, 0, path, user, block.timestamp + 300) returns (
                uint256[] memory amounts
            ) {
                console.log("Sold tokens for ETH:", amounts[1]);
                console.log("User remaining tokens:", MemeToken(memeToken).balanceOf(user));
            } catch Error(string memory reason) {
                console.log("Swap failed:", reason);
            }
        }

        vm.stopPrank();
    }

    // 辅助函数: 记录当前状态
    function _logCurrentState(string memory phase) internal view {
        address pair = factory.getPair(memeToken, address(weth));
        (uint112 reserve0, uint112 reserve1,) = UniswapV2Pair(pair).getReserves();
        console.log(phase, "- Current reserves:");
        console.log("Reserve0:", uint256(reserve0));
        console.log("Reserve1:", uint256(reserve1));
    }

    // 步骤4: 测试TWAP计算功能
    function _testTWAPCalculations() internal {
        console.log("\n--- Step 4: Testing TWAP Calculations ---");

        // 测试不同时间窗口的TWAP
        console.log("\n> Testing different TWAP periods:");

        // 测试15分钟TWAP
        try oracle.getTWAPPrice(memeToken, 900) returns (uint256 twap15min) {
            console.log("TWAP (15 minutes):", twap15min);
            assertTrue(twap15min > 0, "TWAP should be greater than 0");
        } catch Error(string memory reason) {
            console.log("TWAP (15 minutes) failed:", reason);
        }

        // 测试30分钟TWAP
        try oracle.getTWAPPrice(memeToken, 1800) returns (uint256 twap30min) {
            console.log("TWAP (30 minutes):", twap30min);
        } catch Error(string memory reason) {
            console.log("TWAP (30 minutes) failed:", reason);
        }

        // 测试1小时TWAP
        try oracle.getTWAPPrice(memeToken, 3600) returns (uint256 twap1hour) {
            console.log("TWAP (1 hour):", twap1hour);
        } catch Error(string memory reason) {
            console.log("TWAP (1 hour) failed:", reason);
        }

        // 测试默认周期TWAP
        try oracle.getTWAPPrice(memeToken) returns (uint256 defaultTwap) {
            console.log("TWAP (default period):", defaultTwap);
        } catch Error(string memory reason) {
            console.log("TWAP (default period) failed:", reason);
        }

        // 验证Oracle功能
        console.log("\n> Oracle functionality verification:");
        assertTrue(oracle.initialized(memeToken), "Oracle should be initialized");
        console.log("Is initialized:", oracle.initialized(memeToken));

        // 获取当前即时价格作为对比
        address pair = factory.getPair(memeToken, address(weth));
        (uint112 reserve0, uint112 reserve1,) = UniswapV2Pair(pair).getReserves();

        address token0 = UniswapV2Pair(pair).token0();
        uint256 spotPrice;
        if (token0 == memeToken) {
            spotPrice = (uint256(reserve1) * 1e18) / uint256(reserve0);
        } else {
            spotPrice = (uint256(reserve0) * 1e18) / uint256(reserve1);
        }
        console.log("Current spot price (WETH per token):", spotPrice);
        console.log("Final pair reserves:");
        console.log("Reserve0:", uint256(reserve0));
        console.log("Reserve1:", uint256(reserve1));
    }

    // 测试Oracle基础功能
    function testOracleBasicFunctionality() public {
        console.log("\n=== Testing Oracle Basic Functionality ===");

        // 运行完整流程
        testCompleteFlow();

        // 验证Oracle状态
        assertTrue(oracle.initialized(memeToken), "Oracle should be initialized");
        assertTrue(launchPad.isMeme(memeToken), "Token should be registered in LaunchPad");

        console.log("Oracle basic functionality test passed");
    }

    // 测试Oracle错误条件
    function testOracleErrorConditions() public {
        console.log("\n=== Testing Oracle Error Conditions ===");

        address nonExistentToken = address(0x999);

        // 测试未初始化的代币
        vm.expectRevert("MemeOracle: Not initialized");
        oracle.getTWAPPrice(nonExistentToken);

        // 测试零周期
        vm.expectRevert("MemeOracle: Period must be greater than zero");
        oracle.initializeTWAP(address(0x888), 0);

        // 测试不存在的交易对
        vm.expectRevert("MemeOracle: Pair does not exist");
        oracle.initializeTWAP(address(0x777), 1800);

        console.log("Oracle error condition tests passed");
    }

    // 测试Oracle初始化
    function testOracleInitialization() public {
        console.log("\n=== Testing Oracle Initialization ===");

        // 先添加流动性
        vm.prank(buyer1);
        launchPad.mintMeme{value: TOTAL_MINT_PRICE}(memeToken);

        // 验证流动性已添加
        assertTrue(launchPad.isLiquidityAdded(memeToken), "Liquidity should be added");

        // 初始化Oracle
        uint32 testPeriod = 1800; // 30分钟
        oracle.initializeTWAP(memeToken, testPeriod);

        // 验证初始化结果
        assertTrue(oracle.initialized(memeToken), "Oracle should be initialized");

        console.log("Oracle initialization test passed");
    }

    // 允许合约接收ETH
    receive() external payable {}
}
