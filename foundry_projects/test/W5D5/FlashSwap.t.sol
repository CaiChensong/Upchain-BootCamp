// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/W5D5/FlashSwap.sol";
import "../../src/W5D5/TestToken.sol";
import "uniswap-v2/v2-core/UniswapV2Factory.sol";
import "uniswap-v2/v2-core/UniswapV2Pair.sol";
import "uniswap-v2/v2-periphery/UniswapV2Router02.sol";
import "uniswap-v2/v2-periphery/test/WETH9.sol";

contract FlashSwapTest is Test {
    // 核心合约实例
    FlashSwap flashSwap;
    UniswapV2Factory factoryA;
    UniswapV2Factory factoryB;
    UniswapV2Router02 routerA;
    UniswapV2Router02 routerB;
    WETH9 weth;

    // 测试代币
    TestToken tokenA;
    TestToken tokenB;

    // 测试账户
    address owner;
    address user;

    // 测试常量
    uint256 constant INITIAL_ETH = 1000 ether;
    uint256 constant TOKEN_SUPPLY = 1e5 * 1e18; // 10万代币（与TestToken.sol一致）
    uint256 constant LIQUIDITY_AMOUNT = 10000 * 1e18; // 10000个代币，增加流动性

    function setUp() public {
        console.log("Setting up FlashSwap test environment...");

        // 创建测试账户
        owner = makeAddr("owner");
        user = makeAddr("user");

        // 分配初始ETH
        vm.deal(owner, INITIAL_ETH);
        vm.deal(user, INITIAL_ETH);

        // 1. 部署两个token合约 和 WETH（Router需要）
        vm.startPrank(owner);
        tokenA = new TestToken("TokenA", "TKA");
        tokenB = new TestToken("TokenB", "TKB");
        weth = new WETH9();

        console.log("WETH deployed at:", address(weth));
        console.log("TokenA deployed at:", address(tokenA));
        console.log("TokenB deployed at:", address(tokenB));

        // 2. 部署两个工厂合约
        factoryA = new UniswapV2Factory(owner);
        factoryB = new UniswapV2Factory(owner);
        console.log("FactoryA deployed at:", address(factoryA));
        console.log("FactoryB deployed at:", address(factoryB));

        // 3. 部署两个router合约
        routerA = new UniswapV2Router02(address(factoryA), address(weth));
        routerB = new UniswapV2Router02(address(factoryB), address(weth));
        console.log("RouterA deployed at:", address(routerA));
        console.log("RouterB deployed at:", address(routerB));

        // 4. 授权 routerA 和 routerB 合约使用 token
        tokenA.approve(address(routerA), LIQUIDITY_AMOUNT * 5);
        tokenB.approve(address(routerA), LIQUIDITY_AMOUNT * 5);

        tokenA.approve(address(routerB), LIQUIDITY_AMOUNT * 5);
        tokenB.approve(address(routerB), LIQUIDITY_AMOUNT * 5);

        // 5. 为 PoolA 添加流动性（TokenA/TokenB，比例1:1）
        try routerA.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0, // 滑点保护
            0, // 滑点保护
            owner,
            block.timestamp + 300
        ) {
            console.log("PoolA liquidity added successfully");
        } catch Error(string memory reason) {
            console.log("PoolA liquidity failed:", reason);
            revert("PoolA liquidity addition failed");
        }

        // 6. 为 PoolB 添加流动性（TokenA/TokenB，比例1:5，创造更大的价格差异）
        try routerB.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT * 5, // 1:5比例，创造更大的套利机会
            0, // 滑点保护
            0, // 滑点保护
            owner,
            block.timestamp + 300
        ) {
            console.log("PoolB liquidity added successfully");
        } catch Error(string memory reason) {
            console.log("PoolB liquidity failed:", reason);
            revert("PoolB liquidity addition failed");
        }

        console.log("Liquidity pools setup completed");
        vm.stopPrank();

        // 7. 部署 FlashSwap 合约
        vm.startPrank(owner);
        tokenA.transfer(user, 2000 * 10 ** 18); // 给user一些TokenA
        tokenB.transfer(user, 2000 * 10 ** 18); // 给user一些TokenB
        vm.stopPrank();

        vm.startPrank(user);
        flashSwap = new FlashSwap(address(factoryA), address(factoryB));
        console.log("FlashSwap deployed at:", address(flashSwap));

        tokenA.transfer(address(flashSwap), 1000 * 10 ** 18); // 1000个 TokenA
        tokenB.transfer(address(flashSwap), 1000 * 10 ** 18); // 1000个 TokenB
        vm.stopPrank();

        console.log("Gave initial tokens to FlashSwap:");
        console.log("TokenA:", tokenA.balanceOf(address(flashSwap)));
        console.log("TokenB:", tokenB.balanceOf(address(flashSwap)));

        console.log("Test setup completed");
    }

    // 测试FlashSwap合约部署和基本配置
    function testFlashSwapDeployment() public {
        console.log("\n=== Testing FlashSwap Deployment ===");

        // 验证合约部署
        assertTrue(address(flashSwap) != address(0), "FlashSwap should be deployed");
        assertTrue(address(factoryA) != address(0), "FactoryA should be deployed");
        assertTrue(address(factoryB) != address(0), "FactoryB should be deployed");

        // 验证工厂地址设置
        assertEq(flashSwap.factoryA(), address(factoryA), "FactoryA should be set correctly");
        assertEq(flashSwap.factoryB(), address(factoryB), "FactoryB should be set correctly");

        // 验证所有者设置
        assertEq(flashSwap.owner(), user, "Owner should be set correctly");

        console.log("FlashSwap deployment verified successfully!");
    }

    // 测试流动性池设置
    function testLiquidityPoolsSetup() public {
        console.log("\n=== Testing Liquidity Pools Setup ===");

        // 获取PoolA和PoolB的地址
        address pairA = UniswapV2Library.pairFor(address(factoryA), address(tokenA), address(tokenB));
        address pairB = UniswapV2Library.pairFor(address(factoryB), address(tokenA), address(tokenB));

        assertTrue(pairA != address(0), "PoolA should exist");
        assertTrue(pairB != address(0), "PoolB should exist");

        // 检查PoolA的储备金（应该是1:1比例）
        IUniswapV2Pair poolA = IUniswapV2Pair(pairA);
        (uint256 reserve0A, uint256 reserve1A,) = poolA.getReserves();

        if (poolA.token0() == address(tokenA)) {
            assertEq(reserve0A, LIQUIDITY_AMOUNT, "PoolA TokenA reserve should be correct");
            assertEq(reserve1A, LIQUIDITY_AMOUNT, "PoolA TokenB reserve should be correct");
        } else {
            assertEq(reserve1A, LIQUIDITY_AMOUNT, "PoolA TokenA reserve should be correct");
            assertEq(reserve0A, LIQUIDITY_AMOUNT, "PoolA TokenB reserve should be correct");
        }

        // 检查PoolB的储备金（应该是1:5比例）
        IUniswapV2Pair poolB = IUniswapV2Pair(pairB);
        (uint256 reserve0B, uint256 reserve1B,) = poolB.getReserves();

        if (poolB.token0() == address(tokenA)) {
            assertEq(reserve0B, LIQUIDITY_AMOUNT, "PoolB TokenA reserve should be correct");
            assertEq(reserve1B, LIQUIDITY_AMOUNT * 5, "PoolB TokenB reserve should be correct");
        } else {
            assertEq(reserve1B, LIQUIDITY_AMOUNT, "PoolB TokenA reserve should be correct");
            assertEq(reserve0B, LIQUIDITY_AMOUNT * 5, "PoolB TokenB reserve should be correct");
        }

        console.log("Liquidity pools setup verified successfully!");
        console.log("PoolA reserves - TokenA:", reserve0A, "TokenB:", reserve1A);
        console.log("PoolB reserves - TokenA:", reserve0B, "TokenB:", reserve1B);
    }

    // 测试闪电兑换套利功能
    function testExecuteFlashSwapArbitrage() public {
        console.log("\n=== Testing FlashSwap Arbitrage Execution ===");

        // 记录测试前的状态
        uint256 initialTokenABalance = tokenA.balanceOf(user);
        uint256 initialTokenBBalance = tokenB.balanceOf(user);

        console.log("Initial balances:");
        console.log("User TokenA:", initialTokenABalance);
        console.log("User TokenB:", initialTokenBBalance);

        // 记录流动性池状态
        _logPoolReserves("initial");

        // 计算套利参数
        uint256 borrowAmount = 1000 * 10 ** 18; // 借入1000个TokenA
        console.log("Borrow amount:", borrowAmount);

        // 执行闪电兑换套利
        console.log("Executing flash swap arbitrage...");
        vm.startPrank(user);

        try flashSwap.executeFlashSwapArbitrage(address(tokenA), address(tokenB), borrowAmount) {
            console.log("Flash swap arbitrage executed successfully!");
        } catch Error(string memory reason) {
            console.log("Flash swap arbitrage failed:", reason);
            revert("Flash swap arbitrage execution failed");
        }

        vm.stopPrank();

        // 记录测试后的状态
        uint256 finalTokenABalance = tokenA.balanceOf(user);
        uint256 finalTokenBBalance = tokenB.balanceOf(user);

        console.log("Final balances:");
        console.log("User TokenA:", finalTokenABalance);
        console.log("User TokenB:", finalTokenBBalance);

        // 记录流动性池最终状态
        _logPoolReserves("final");

        // 计算变化量
        uint256 tokenAChange = finalTokenABalance - initialTokenABalance;
        uint256 tokenBChange = finalTokenBBalance - initialTokenBBalance;

        console.log("Balance changes:");
        console.log("User TokenA change:", tokenAChange);
        console.log("User TokenB change:", tokenBChange);

        // 验证闪电兑换后的状态
        assertEq(tokenA.balanceOf(address(flashSwap)), 0, "FlashSwap should have 0 TokenA after execution");
        assertEq(tokenB.balanceOf(address(flashSwap)), 0, "FlashSwap should have 0 TokenB after execution");

        // 验证用户获得了利润（TokenB增加）
        assertTrue(tokenBChange > 0, "User should gain TokenB from arbitrage");

        console.log("Flash swap arbitrage test completed successfully!");
        console.log("Arbitrage profit in TokenB:", tokenBChange);
    }

    // 辅助函数：记录流动性池储备金
    function _logPoolReserves(string memory stage) internal view {
        address pairA = UniswapV2Library.pairFor(address(factoryA), address(tokenA), address(tokenB));
        address pairB = UniswapV2Library.pairFor(address(factoryB), address(tokenA), address(tokenB));

        IUniswapV2Pair poolA = IUniswapV2Pair(pairA);
        IUniswapV2Pair poolB = IUniswapV2Pair(pairB);

        (uint256 reserve0A, uint256 reserve1A,) = poolA.getReserves();
        (uint256 reserve0B, uint256 reserve1B,) = poolB.getReserves();

        console.log("PoolA", stage);
        console.log("TokenA:", reserve0A);
        console.log("TokenB:", reserve1A);
        console.log("PoolB", stage);
        console.log("TokenA:", reserve0B);
        console.log("TokenB:", reserve1B);
    }
}
