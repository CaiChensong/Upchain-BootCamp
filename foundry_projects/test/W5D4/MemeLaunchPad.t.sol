// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/W5D4/LaunchPad.sol";

import "uniswap-v2/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "uniswap-v2/v2-core/UniswapV2Factory.sol";
import "uniswap-v2/v2-periphery/UniswapV2Router02.sol";
import "uniswap-v2/v2-periphery/test/WETH9.sol";

contract MemeLaunchPadTest is Test {
    // 事件定义
    event MemeDeployed(
        address indexed memeAddress, string symbol, uint256 totalSupply, uint256 perMint, uint256 price, address creator
    );
    event MemeMinted(address indexed memeAddress, address indexed to, uint256 amount);
    event LiquidityAdded(address indexed memeAddress, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    event MemeBought(address indexed memeAddress, address indexed to, uint256 amount, uint256 price);

    // 核心合约
    MemeLaunchPad public launchPad;

    // Uniswap V2 基础设施
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    WETH9 public weth;

    // 测试账户
    address public owner;
    address public memeCreator;
    address public buyer1;
    address public buyer2;

    // 测试用的Meme代币地址
    address public deployedMeme;

    // 测试常量
    uint256 public constant MEME_TOTAL_SUPPLY = 1000000;
    uint256 public constant MEME_PER_MINT = 1000;
    uint256 public constant MEME_PRICE_PER_TOKEN = 0.00001 ether; // 每个token的价格
    uint256 public constant TOTAL_MINT_PRICE = 0.01 ether; // 每次铸造1000个token需要 0.01 ether

    function setUp() public {
        // 创建测试账户
        owner = makeAddr("owner");
        memeCreator = makeAddr("memeCreator");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");

        // 分配初始ETH
        vm.deal(owner, 100 ether);
        vm.deal(memeCreator, 100 ether);
        vm.deal(buyer1, 100 ether);
        vm.deal(buyer2, 100 ether);

        // 部署Uniswap基础设施
        vm.startPrank(owner);

        // 部署WETH
        weth = new WETH9();

        // 部署Factory
        factory = new UniswapV2Factory(owner);

        // 部署Router
        router = new UniswapV2Router02(address(factory), address(weth));

        // 部署LaunchPad
        launchPad = new MemeLaunchPad(owner, address(router));

        vm.stopPrank();

        // 部署一个测试用的Meme代币
        _deployTestMeme();
    }

    // 辅助函数：部署测试用的Meme代币
    function _deployTestMeme() internal {
        vm.startPrank(memeCreator);

        // 监听MemeDeployed事件来获取部署的地址
        vm.recordLogs();
        launchPad.deployMeme("TESTMEME", MEME_TOTAL_SUPPLY, MEME_PER_MINT, MEME_PRICE_PER_TOKEN);

        // 从事件中提取地址
        Vm.Log[] memory entries = vm.getRecordedLogs();
        deployedMeme = address(uint160(uint256(entries[0].topics[1])));

        vm.stopPrank();
    }

    // ==================== 基础设置测试 ====================

    function testSetUp() public {
        // 验证合约部署
        assertNotEq(address(launchPad), address(0));
        assertNotEq(address(factory), address(0));
        assertNotEq(address(router), address(0));
        assertNotEq(address(weth), address(0));

        // 验证LaunchPad配置
        assertEq(launchPad.owner(), owner);
        assertEq(launchPad.uniswapRouter(), address(router));
        assertEq(launchPad.PROJECT_FEE_PERCENTAGE(), 5);

        // 验证测试Meme代币已部署
        assertTrue(launchPad.isMeme(deployedMeme));
        assertEq(MemeToken(deployedMeme).creator(), memeCreator);
    }

    // ==================== deployMeme 测试 ====================

    function testDeployMeme() public {
        vm.startPrank(memeCreator);

        // 测试正常部署 - 我们只检查事件是否发出，不检查具体地址
        vm.expectEmit(false, false, false, false);
        emit MemeDeployed(address(0), "NEWMEME", 2000000, 2000, 0.00001 ether, memeCreator);

        launchPad.deployMeme("NEWMEME", 2000000, 2000, 0.00001 ether);

        vm.stopPrank();
    }

    function testDeployMemeFailures() public {
        vm.startPrank(memeCreator);

        // 测试总供应量为0
        vm.expectRevert("MemeFactory: Total supply must be greater than 0");
        launchPad.deployMeme("FAIL1", 0, 1000, MEME_PRICE_PER_TOKEN);

        // 测试每次铸造量为0
        vm.expectRevert("MemeFactory: Per mint must be greater than 0");
        launchPad.deployMeme("FAIL2", 1000000, 0, MEME_PRICE_PER_TOKEN);

        // 测试每次铸造量大于总供应量
        vm.expectRevert("MemeFactory: Per mint must be less than or equal to total supply");
        launchPad.deployMeme("FAIL3", 1000, 2000, MEME_PRICE_PER_TOKEN);

        vm.stopPrank();
    }

    // ==================== mintMeme 测试 ====================

    function testMintMeme() public {
        uint256 mintPrice = TOTAL_MINT_PRICE;
        uint256 initialCreatorBalance = memeCreator.balance;

        vm.startPrank(buyer1);

        // 测试正常铸造
        vm.expectEmit(true, true, false, true);
        emit MemeMinted(deployedMeme, buyer1, MEME_PER_MINT);

        launchPad.mintMeme{value: mintPrice}(deployedMeme);

        vm.stopPrank();

        // 验证代币余额
        assertEq(MemeToken(deployedMeme).balanceOf(buyer1), MEME_PER_MINT);

        // 验证费用分配 (95% 给创建者)
        uint256 creatorFee = (mintPrice * 95) / 100;
        assertEq(memeCreator.balance, initialCreatorBalance + creatorFee);

        // 验证流动性已添加
        assertTrue(launchPad.isLiquidityAdded(deployedMeme));
    }

    function testMintMemeWithOverpayment() public {
        uint256 mintPrice = TOTAL_MINT_PRICE;
        uint256 overpayment = 0.5 ether;
        uint256 totalPayment = mintPrice + overpayment;
        uint256 initialBuyerBalance = buyer1.balance;

        vm.startPrank(buyer1);

        launchPad.mintMeme{value: totalPayment}(deployedMeme);

        vm.stopPrank();

        // 验证退款
        assertEq(buyer1.balance, initialBuyerBalance - mintPrice);
    }

    function testMintMemeFailures() public {
        uint256 mintPrice = TOTAL_MINT_PRICE;

        vm.startPrank(buyer1);

        // 测试支付不足
        vm.expectRevert("MemeFactory: Insufficient payment");
        launchPad.mintMeme{value: mintPrice - 1}(deployedMeme);

        // 测试无效代币地址
        vm.expectRevert("MemeFactory: Token is not deployed");
        launchPad.mintMeme{value: mintPrice}(address(0x123));

        vm.stopPrank();
    }

    // ==================== 流动性添加测试 ====================

    function testLiquidityAddition() public {
        uint256 mintPrice = TOTAL_MINT_PRICE;

        // 确保还没有添加流动性
        assertFalse(launchPad.isLiquidityAdded(deployedMeme));

        vm.startPrank(buyer1);

        // 监听流动性添加事件
        vm.expectEmit(true, false, false, false);

        launchPad.mintMeme{value: mintPrice}(deployedMeme);

        vm.stopPrank();

        // 验证流动性已添加
        assertTrue(launchPad.isLiquidityAdded(deployedMeme));

        // 验证pair已创建
        address pair = factory.getPair(deployedMeme, address(weth));
        assertNotEq(pair, address(0));

        // 验证LaunchPad持有LP代币
        assertGt(IERC20(pair).balanceOf(address(launchPad)), 0);
    }

    function testLiquidityNotAddedTwice() public {
        uint256 mintPrice = TOTAL_MINT_PRICE;

        // 第一次铸造 - 应该添加流动性
        vm.prank(buyer1);
        launchPad.mintMeme{value: mintPrice}(deployedMeme);
        assertTrue(launchPad.isLiquidityAdded(deployedMeme));

        // 记录LP代币余额
        address pair = factory.getPair(deployedMeme, address(weth));
        uint256 lpBalanceBefore = IERC20(pair).balanceOf(address(launchPad));

        // 第二次铸造 - 不应该再次添加流动性
        vm.prank(buyer2);
        launchPad.mintMeme{value: mintPrice}(deployedMeme);

        // LP代币余额应该没有变化
        uint256 lpBalanceAfter = IERC20(pair).balanceOf(address(launchPad));
        assertEq(lpBalanceAfter, lpBalanceBefore);
    }

    // ==================== 价格查询测试 ====================

    function testGetUniswapPriceWithoutLiquidity() public {
        // 部署一个新的Meme代币但不添加流动性
        vm.prank(memeCreator);
        launchPad.deployMeme("NOLIQ", 1000000, 1000, MEME_PRICE_PER_TOKEN);

        // 从事件日志中获取新代币地址
        vm.recordLogs();
        vm.prank(memeCreator);
        launchPad.deployMeme("NOLIQ2", 1000000, 1000, MEME_PRICE_PER_TOKEN);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        address newMeme = address(uint160(uint256(entries[0].topics[1])));

        // 没有流动性时应该返回最大值
        uint256 price = launchPad.getUniswapPrice(newMeme);
        assertEq(price, type(uint256).max);
    }

    function testGetUniswapPriceWithLiquidity() public {
        uint256 mintPrice = TOTAL_MINT_PRICE;

        // 添加流动性
        vm.prank(buyer1);
        launchPad.mintMeme{value: mintPrice}(deployedMeme);

        // 查询价格
        uint256 uniswapPrice = launchPad.getUniswapPrice(deployedMeme);

        // 应该能够获取到有效价格
        assertLt(uniswapPrice, type(uint256).max);
        assertGt(uniswapPrice, 0);
    }

    // ==================== buyMeme 测试 ====================

    function testBuyMemeWhenUniswapCheaper() public {
        uint256 mintPrice = TOTAL_MINT_PRICE;

        // 先通过mintMeme添加流动性
        vm.prank(buyer1);
        launchPad.mintMeme{value: mintPrice}(deployedMeme);

        // 检查Uniswap价格
        uint256 uniswapPrice = launchPad.getUniswapPrice(deployedMeme);
        uint256 mintPricePerToken = MEME_PRICE_PER_TOKEN;

        console.log("Uniswap price (tokens per ETH):", uniswapPrice);
        console.log("Mint price per token (wei):", mintPricePerToken);

        // 测试价格比较逻辑
        if (uniswapPrice < mintPricePerToken) {
            // Uniswap价格更优，应该允许购买
            console.log("Uniswap price is better, testing buy functionality");

            uint256 buyAmount = 0.001 ether; // 使用更小的金额减少滑点影响
            uint256 initialBalance = MemeToken(deployedMeme).balanceOf(buyer2);

            vm.startPrank(buyer2);

            // 期望购买成功
            launchPad.buyMeme{value: buyAmount}(deployedMeme);

            vm.stopPrank();

            // 验证买家收到了代币
            uint256 finalBalance = MemeToken(deployedMeme).balanceOf(buyer2);
            assertGt(finalBalance, initialBalance, "Buyer should receive tokens");
            console.log("Successfully bought tokens through Uniswap");
        } else {
            // Mint价格更优，buyMeme应该revert
            console.log("Mint price is better, buyMeme should revert");

            vm.startPrank(buyer2);
            vm.expectRevert("MemeFactory: Uniswap price not better than mint price");
            launchPad.buyMeme{value: 0.001 ether}(deployedMeme);
            vm.stopPrank();
            console.log("Correctly reverted when mint price is better");
        }
    }

    function testBuyMemeFailures() public {
        uint256 mintPrice = TOTAL_MINT_PRICE;

        // 先添加流动性
        vm.prank(buyer1);
        launchPad.mintMeme{value: mintPrice}(deployedMeme);

        vm.startPrank(buyer2);

        // 测试零ETH购买
        vm.expectRevert("MemeFactory: Must send ETH to buy tokens");
        launchPad.buyMeme{value: 0}(deployedMeme);

        // 测试无效代币地址
        vm.expectRevert("MemeFactory: Token is not deployed");
        launchPad.buyMeme{value: TOTAL_MINT_PRICE}(address(0x123));

        vm.stopPrank();
    }

    function testBuyMemeVsMintMemeComparison() public {
        console.log("=== Testing buyMeme vs mintMeme price comparison ===");

        uint256 mintPrice = TOTAL_MINT_PRICE;

        // 1. 添加初始流动性
        vm.prank(buyer1);
        launchPad.mintMeme{value: mintPrice}(deployedMeme);
        console.log("Step 1: Added initial liquidity");

        // 2. 检查价格
        uint256 uniswapPrice = launchPad.getUniswapPrice(deployedMeme);
        uint256 mintPricePerToken = MEME_PRICE_PER_TOKEN;

        console.log("Uniswap price (tokens per ETH):", uniswapPrice);
        console.log("Mint price per token:", mintPricePerToken);
        console.log("Effective uniswap price per token (wei):", 1e18 / uniswapPrice);

        // 3. 根据价格情况测试不同路径
        if (uniswapPrice < mintPricePerToken) {
            console.log("Case: Uniswap price is better");
            _testUniswapPriceIsBetter();
        } else {
            console.log("Case: Mint price is better");
            _testMintPriceIsBetter();
        }

        // 4. 人为制造价格差异进行测试
        console.log("Step 4: Creating artificial price difference for comprehensive testing");
        _testArtificialPriceDifference();
    }

    function _testUniswapPriceIsBetter() internal {
        // Uniswap价格更好，buyMeme应该成功
        uint256 buyAmount = 0.001 ether;
        uint256 initialBalance = MemeToken(deployedMeme).balanceOf(buyer2);

        vm.prank(buyer2);
        launchPad.buyMeme{value: buyAmount}(deployedMeme);

        uint256 finalBalance = MemeToken(deployedMeme).balanceOf(buyer2);
        assertGt(finalBalance, initialBalance, "Should receive tokens when Uniswap price is better");
        console.log("Success: buyMeme worked when Uniswap price is better");
    }

    function _testMintPriceIsBetter() internal {
        // Mint价格更好，buyMeme应该失败
        vm.prank(buyer2);
        vm.expectRevert("MemeFactory: Uniswap price not better than mint price");
        launchPad.buyMeme{value: 0.001 ether}(deployedMeme);
        console.log("Success: buyMeme correctly reverted when mint price is better");
    }

    function _testArtificialPriceDifference() internal {
        // 通过多次购买来改变Uniswap价格，测试价格保护机制
        address buyer3 = makeAddr("buyer3");
        vm.deal(buyer3, 100 ether);

        // 进行几次mintMeme来增加代币供应量，这可能会影响价格
        for (uint256 i = 0; i < 3; i++) {
            address tempBuyer = makeAddr(string(abi.encodePacked("tempBuyer", i)));
            vm.deal(tempBuyer, 100 ether);
            vm.prank(tempBuyer);
            launchPad.mintMeme{value: TOTAL_MINT_PRICE}(deployedMeme);
        }

        console.log("Performed additional mints to affect price");

        // 重新检查价格
        uint256 newUniswapPrice = launchPad.getUniswapPrice(deployedMeme);
        uint256 mintPricePerToken = MEME_PRICE_PER_TOKEN;

        console.log("New Uniswap price:", newUniswapPrice);
        console.log("Mint price per token:", mintPricePerToken);

        // 无论价格如何，都要确保价格保护逻辑正确工作
        if (newUniswapPrice < mintPricePerToken) {
            console.log("After multiple mints: Uniswap still better, testing buy");
            vm.prank(buyer3);
            launchPad.buyMeme{value: 0.001 ether}(deployedMeme);
            assertGt(MemeToken(deployedMeme).balanceOf(buyer3), 0);
        } else {
            console.log("After multiple mints: Mint price now better, testing protection");
            vm.prank(buyer3);
            vm.expectRevert("MemeFactory: Uniswap price not better than mint price");
            launchPad.buyMeme{value: 0.001 ether}(deployedMeme);
        }

        console.log("Comprehensive price comparison test completed");
    }

    // ==================== 管理员功能测试 ====================

    function testUpdateProjectOwner() public {
        address newOwner = makeAddr("newOwner");

        vm.startPrank(owner);
        launchPad.updateProjectOwner(newOwner);
        vm.stopPrank();

        assertEq(launchPad.owner(), newOwner);
    }

    function testUpdateProjectOwnerFailures() public {
        vm.startPrank(owner);

        // 测试零地址
        vm.expectRevert("MemeFactory: New owner can not be zero address");
        launchPad.updateProjectOwner(address(0));

        vm.stopPrank();

        // 测试非owner调用
        vm.startPrank(buyer1);
        vm.expectRevert();
        launchPad.updateProjectOwner(buyer1);
        vm.stopPrank();
    }

    function testUpdateUniswapRouter() public {
        address newRouter = makeAddr("newRouter");

        vm.startPrank(owner);
        launchPad.updateUniswapRouter(newRouter);
        vm.stopPrank();

        assertEq(launchPad.uniswapRouter(), newRouter);
    }

    function testUpdateUniswapRouterFailures() public {
        vm.startPrank(owner);

        // 测试零地址
        vm.expectRevert("MemeFactory: New router can not be zero address");
        launchPad.updateUniswapRouter(address(0));

        vm.stopPrank();

        // 测试非owner调用
        vm.startPrank(buyer1);
        vm.expectRevert();
        launchPad.updateUniswapRouter(buyer1);
        vm.stopPrank();
    }

    // ==================== MemeToken 功能测试 ====================

    function testMemeTokenProperties() public {
        MemeToken memeToken = MemeToken(deployedMeme);

        // 验证基本属性
        assertEq(memeToken.memeSymbol(), "TESTMEME");
        assertEq(memeToken.memeTotalSupply(), MEME_TOTAL_SUPPLY);
        assertEq(memeToken.perMint(), MEME_PER_MINT);
        assertEq(memeToken.price(), MEME_PRICE_PER_TOKEN);
        assertEq(memeToken.creator(), memeCreator);
        assertEq(memeToken.factory(), address(launchPad));
        assertEq(memeToken.mintedAmount(), 0);
    }

    function testMemeTokenMinting() public {
        uint256 mintPrice = TOTAL_MINT_PRICE;

        vm.prank(buyer1);
        launchPad.mintMeme{value: mintPrice}(deployedMeme);

        MemeToken memeToken = MemeToken(deployedMeme);

        // 验证铸造状态更新（包含流动性铸造）
        uint256 liquidityTokenAmount = (TOTAL_MINT_PRICE * 5 / 100) / MEME_PRICE_PER_TOKEN; // 5% 用于流动性
        assertEq(memeToken.mintedAmount(), MEME_PER_MINT + liquidityTokenAmount);
        assertEq(memeToken.balanceOf(buyer1), MEME_PER_MINT);
    }

    // ==================== 综合场景测试 ====================

    function testCompleteFlow() public {
        uint256 mintPrice = TOTAL_MINT_PRICE;

        console.log("=== Complete Flow Test ===");

        // 1. 第一个用户铸造 - 应该添加流动性
        console.log("Step 1: First mint with liquidity addition");
        vm.prank(buyer1);
        launchPad.mintMeme{value: mintPrice}(deployedMeme);

        assertTrue(launchPad.isLiquidityAdded(deployedMeme));
        assertEq(MemeToken(deployedMeme).balanceOf(buyer1), MEME_PER_MINT);
        console.log("Success: Liquidity added, user received tokens");

        // 2. 第二个用户也进行铸造 - 不应该再次添加流动性
        console.log("Step 2: Second mint");
        vm.prank(buyer2);
        launchPad.mintMeme{value: mintPrice}(deployedMeme);

        assertEq(MemeToken(deployedMeme).balanceOf(buyer2), MEME_PER_MINT);
        console.log("Success: Second user minted successfully");

        // 3. 检查价格并尝试通过Uniswap购买
        console.log("Step 3: Check Uniswap price");
        uint256 uniswapPrice = launchPad.getUniswapPrice(deployedMeme);
        uint256 mintPricePerToken = MEME_PRICE_PER_TOKEN;

        console.log("Uniswap price:", uniswapPrice);
        console.log("Mint price:", mintPricePerToken);

        // 3.1 测试价格比较逻辑
        if (uniswapPrice < mintPricePerToken) {
            console.log("Step 3.1: Uniswap price is better, testing buy functionality");

            address buyer3 = makeAddr("buyer3");
            vm.deal(buyer3, 100 ether);
            uint256 buyAmount = 0.001 ether; // 使用较小金额减少滑点影响

            uint256 buyer3InitialBalance = MemeToken(deployedMeme).balanceOf(buyer3);

            vm.prank(buyer3);
            launchPad.buyMeme{value: buyAmount}(deployedMeme);

            uint256 buyer3FinalBalance = MemeToken(deployedMeme).balanceOf(buyer3);
            assertGt(buyer3FinalBalance, buyer3InitialBalance, "Buyer3 should receive tokens from Uniswap");
            console.log("Success: Bought tokens through Uniswap when price is better");
        } else {
            console.log("Step 3.1: Mint price is better, testing price protection");

            address buyer3 = makeAddr("buyer3");
            vm.deal(buyer3, 100 ether);

            vm.prank(buyer3);
            vm.expectRevert("MemeFactory: Uniswap price not better than mint price");
            launchPad.buyMeme{value: 0.001 ether}(deployedMeme);
            console.log("Success: Correctly prevented buying when mint price is better");
        }

        // 3.2 测试价格查询功能
        console.log("Step 3.2: Testing price query functions");
        assertTrue(uniswapPrice > 0 && uniswapPrice < type(uint256).max, "Uniswap price should be valid");
        assertEq(mintPricePerToken, MEME_PRICE_PER_TOKEN, "Mint price should match constant");
        console.log("Success: Price query functions work correctly");

        console.log("=== Complete Flow Test Finished ===");
    }

    // ==================== 辅助函数 ====================

    // 接收ETH
    receive() external payable {}
}
