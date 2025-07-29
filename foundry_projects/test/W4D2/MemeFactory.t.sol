// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/W4D2/MemeFactory.sol";

contract MemeFactoryTest is Test {
    MemeFactory public memeFactory;
    address public projectOwner;
    address public memeCreator;
    address public buyer1;
    address public buyer2;
    address public buyer3;

    // 用于跟踪部署的Meme合约
    address[] public deployedMemes;

    event MemeDeployed(
        address indexed memeAddress, string symbol, uint256 totalSupply, uint256 perMint, uint256 price, address creator
    );

    event MemeMinted(address indexed memeAddress, address indexed to, uint256 amount);

    function setUp() public {
        projectOwner = makeAddr("projectOwner");
        memeCreator = makeAddr("memeCreator");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        buyer3 = makeAddr("buyer3");

        vm.startPrank(projectOwner);
        memeFactory = new MemeFactory(projectOwner);
        vm.stopPrank();

        // 给测试账户一些ETH
        vm.deal(buyer1, 100 ether);
        vm.deal(buyer2, 100 ether);
        vm.deal(buyer3, 100 ether);
        vm.deal(memeCreator, 100 ether);
    }

    // 测试部署Meme合约
    function testDeployMeme() public {
        vm.startPrank(memeCreator);

        // 监听MemeDeployed事件来获取部署的地址
        vm.recordLogs();
        memeFactory.deployMeme("DOGE", 1000000, 1000, 0.01 ether);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        // 从事件中获取部署的地址
        address deployedAddress = address(uint160(uint256(entries[0].topics[1])));
        deployedMemes.push(deployedAddress);

        // 验证Meme合约是否被正确部署
        assertTrue(memeFactory.isMeme(deployedAddress), "Meme not recognized by factory");

        Meme memeToken = Meme(deployedAddress);
        assertEq(memeToken.memeSymbol(), "DOGE", "Symbol incorrect");
        assertEq(memeToken.memeTotalSupply(), 1000000, "Total supply incorrect");
        assertEq(memeToken.perMint(), 1000, "Per mint incorrect");
        assertEq(memeToken.price(), 0.01 ether, "Price incorrect");
        assertEq(memeToken.creator(), memeCreator, "Creator incorrect");
    }

    // 测试费用按比例正确分配到Meme发行者账号及项目方账号
    function testFeeDistribution() public {
        // 部署Meme合约
        vm.startPrank(memeCreator);
        vm.recordLogs();
        memeFactory.deployMeme("DOGE", 1000000, 1000, 0.01 ether);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        address memeAddress = address(uint160(uint256(entries[0].topics[1])));
        deployedMemes.push(memeAddress);
        Meme memeToken = Meme(memeAddress);

        // 记录初始余额
        uint256 projectOwnerInitialBalance = projectOwner.balance;
        uint256 creatorInitialBalance = memeCreator.balance;
        uint256 buyerInitialBalance = buyer1.balance;

        // 计算预期费用
        uint256 perMintPrice = memeToken.price() * memeToken.perMint(); // 0.01 ether * 1000 = 10 ether
        uint256 expectedProjectFee = (perMintPrice * 1) / 100; // 1% = 0.1 ether
        uint256 expectedCreatorFee = perMintPrice - expectedProjectFee; // 99% = 9.9 ether

        // 购买Meme
        vm.startPrank(buyer1);
        memeFactory.mintMeme{value: perMintPrice}(memeAddress);
        vm.stopPrank();

        // 验证费用分配
        assertEq(projectOwner.balance, projectOwnerInitialBalance + expectedProjectFee, "Project owner fee incorrect");
        assertEq(memeCreator.balance, creatorInitialBalance + expectedCreatorFee, "Creator fee incorrect");
        assertEq(buyer1.balance, buyerInitialBalance - perMintPrice, "Buyer balance incorrect");

        // 验证代币铸造
        assertEq(memeToken.balanceOf(buyer1), 1000, "Token balance incorrect");
        assertEq(memeToken.mintedAmount(), 1000, "Minted amount incorrect");
    }

    // 测试每次发行的数量正确
    function testMintAmountCorrect() public {
        // 部署Meme合约
        vm.startPrank(memeCreator);
        vm.recordLogs();
        memeFactory.deployMeme("DOGE", 1000000, 1000, 0.01 ether);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        address memeAddress = address(uint160(uint256(entries[0].topics[1])));
        deployedMemes.push(memeAddress);
        Meme memeToken = Meme(memeAddress);

        // 多次购买，验证每次铸造数量正确
        for (uint256 i = 0; i < 5; i++) {
            uint256 perMintPrice = memeToken.price() * memeToken.perMint();
            uint256 expectedMintedAmount = (i + 1) * memeToken.perMint();

            vm.startPrank(buyer1);
            memeFactory.mintMeme{value: perMintPrice}(memeAddress);
            vm.stopPrank();

            assertEq(memeToken.balanceOf(buyer1), expectedMintedAmount, "Token balance incorrect");
            assertEq(memeToken.mintedAmount(), expectedMintedAmount, "Minted amount incorrect");
        }
    }

    // 测试不会超过totalSupply
    function testNotExceedTotalSupply() public {
        // 部署Meme合约，设置较小的总供应量
        vm.startPrank(memeCreator);
        vm.recordLogs();
        memeFactory.deployMeme("DOGE", 2500, 1000, 0.01 ether); // totalSupply = 2500, perMint = 1000
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        address memeAddress = address(uint160(uint256(entries[0].topics[1])));
        deployedMemes.push(memeAddress);
        Meme memeToken = Meme(memeAddress);

        // 前两次铸造应该成功
        for (uint256 i = 0; i < 2; i++) {
            uint256 perMintPrice = memeToken.price() * memeToken.perMint();

            vm.startPrank(buyer1);
            memeFactory.mintMeme{value: perMintPrice}(memeAddress);
            vm.stopPrank();
        }

        // 第三次铸造应该失败，因为会超过totalSupply (2000 + 1000 > 2500)
        uint256 perMintPrice = memeToken.price() * memeToken.perMint();

        vm.startPrank(buyer2);
        vm.expectRevert("MemeToken: Minted amount exceeds total supply");
        memeFactory.mintMeme{value: perMintPrice}(memeAddress);
        vm.stopPrank();

        // 验证最终状态
        assertEq(memeToken.mintedAmount(), 2000, "Final minted amount incorrect");
        assertEq(memeToken.balanceOf(buyer1), 2000, "Final buyer balance incorrect");
    }

    // 测试退款功能
    function testRefundExcessPayment() public {
        // 部署Meme合约
        vm.startPrank(memeCreator);
        vm.recordLogs();
        memeFactory.deployMeme("DOGE", 1000000, 1000, 0.01 ether);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        address memeAddress = address(uint160(uint256(entries[0].topics[1])));
        deployedMemes.push(memeAddress);
        Meme memeToken = Meme(memeAddress);

        uint256 perMintPrice = memeToken.price() * memeToken.perMint(); // 10 ether
        uint256 excessPayment = 2 ether;
        uint256 totalPayment = perMintPrice + excessPayment;

        // 记录初始余额
        uint256 buyerInitialBalance = buyer1.balance;

        // 支付超过所需金额
        vm.startPrank(buyer1);
        memeFactory.mintMeme{value: totalPayment}(memeAddress);
        vm.stopPrank();

        // 验证退款
        assertEq(buyer1.balance, buyerInitialBalance - perMintPrice, "Refund amount incorrect");
        assertEq(memeToken.balanceOf(buyer1), 1000, "Token balance incorrect");
    }

    // 测试参数验证
    function testParameterValidation() public {
        vm.startPrank(memeCreator);

        // 测试totalSupply为0
        vm.expectRevert("MemeFactory: Total supply must be greater than 0");
        memeFactory.deployMeme("DOGE", 0, 1000, 0.01 ether);

        // 测试perMint为0
        vm.expectRevert("MemeFactory: Per mint must be greater than 0");
        memeFactory.deployMeme("DOGE", 1000000, 0, 0.01 ether);

        // 测试perMint大于totalSupply
        vm.expectRevert("MemeFactory: Per mint must be less than or equal to total supply");
        memeFactory.deployMeme("DOGE", 1000, 2000, 0.01 ether);

        vm.stopPrank();
    }

    // 测试支付金额不足
    function testInsufficientPayment() public {
        // 部署Meme合约
        vm.startPrank(memeCreator);
        vm.recordLogs();
        memeFactory.deployMeme("DOGE", 1000000, 1000, 0.01 ether);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        address memeAddress = address(uint160(uint256(entries[0].topics[1])));
        deployedMemes.push(memeAddress);
        Meme memeToken = Meme(memeAddress);

        uint256 perMintPrice = memeToken.price() * memeToken.perMint();
        uint256 insufficientPayment = perMintPrice - 0.001 ether;

        // 支付金额不足
        vm.startPrank(buyer1);
        vm.expectRevert("MemeFactory: Insufficient payment");
        memeFactory.mintMeme{value: insufficientPayment}(memeAddress);
        vm.stopPrank();
    }

    // 测试无效的token地址
    function testInvalidTokenAddress() public {
        address invalidAddress = makeAddr("invalid");
        uint256 perMintPrice = 10 ether;

        vm.startPrank(buyer1);
        vm.expectRevert("MemeFactory: Token is not deployed");
        memeFactory.mintMeme{value: perMintPrice}(invalidAddress);
        vm.stopPrank();
    }

    // 测试多次部署不同的Meme
    function testMultipleMemeDeployment() public {
        address[] memory creators = new address[](3);
        creators[0] = makeAddr("creator1");
        creators[1] = makeAddr("creator2");
        creators[2] = makeAddr("creator3");

        string[] memory symbols = new string[](3);
        symbols[0] = "DOGE";
        symbols[1] = "SHIB";
        symbols[2] = "PEPE";

        // 给新创建者一些ETH
        vm.deal(creators[0], 100 ether);
        vm.deal(creators[1], 100 ether);
        vm.deal(creators[2], 100 ether);

        // 部署多个Meme合约
        for (uint256 i = 0; i < 3; i++) {
            vm.startPrank(creators[i]);
            vm.recordLogs();
            memeFactory.deployMeme(symbols[i], 1000000, 1000, 0.01 ether);
            Vm.Log[] memory entries = vm.getRecordedLogs();
            vm.stopPrank();

            address deployedAddress = address(uint160(uint256(entries[0].topics[1])));
            deployedMemes.push(deployedAddress);
        }

        // 验证所有Meme都被正确部署
        assertEq(deployedMemes.length, 3, "Number of deployed memes incorrect");

        for (uint256 i = 0; i < 3; i++) {
            assertTrue(memeFactory.isMeme(deployedMemes[i]), "Meme not recognized");

            Meme memeToken = Meme(deployedMemes[i]);
            assertEq(memeToken.memeSymbol(), symbols[i], "Symbol incorrect");
            assertEq(memeToken.creator(), creators[i], "Creator incorrect");
        }
    }

    // 测试最小代理的Gas效率
    function testGasEfficiency() public {
        // 记录部署基础合约的gas消耗
        uint256 baseDeploymentGas = gasleft();
        address baseMeme = address(new Meme());
        baseDeploymentGas = baseDeploymentGas - gasleft();

        // 记录通过工厂部署的gas消耗
        vm.startPrank(memeCreator);
        uint256 factoryDeploymentGas = gasleft();
        memeFactory.deployMeme("DOGE", 1000000, 1000, 0.01 ether);
        factoryDeploymentGas = factoryDeploymentGas - gasleft();
        vm.stopPrank();

        // 验证工厂部署的gas消耗远小于直接部署
        assertLt(factoryDeploymentGas, baseDeploymentGas, "Factory deployment should be more gas efficient");

        console.log("Base deployment gas:", baseDeploymentGas);
        console.log("Factory deployment gas:", factoryDeploymentGas);
        console.log("Gas savings:", baseDeploymentGas - factoryDeploymentGas);
    }

    // 测试事件正确性
    function testEventEmission() public {
        vm.startPrank(memeCreator);

        // 监听MemeDeployed事件
        vm.recordLogs();
        memeFactory.deployMeme("DOGE", 1000000, 1000, 0.01 ether);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        // 验证MemeDeployed事件
        assertEq(entries.length, 1, "Should emit one event");
        assertEq(
            entries[0].topics[0],
            keccak256("MemeDeployed(address,string,uint256,uint256,uint256,address)"),
            "Wrong event signature"
        );

        // 解析事件数据
        address deployedAddress = address(uint160(uint256(entries[0].topics[1])));
        deployedMemes.push(deployedAddress);

        // 验证事件参数
        (string memory symbol, uint256 totalSupply, uint256 perMint, uint256 price, address creator) =
            abi.decode(entries[0].data, (string, uint256, uint256, uint256, address));

        assertEq(symbol, "DOGE", "Symbol in event incorrect");
        assertEq(totalSupply, 1000000, "Total supply in event incorrect");
        assertEq(perMint, 1000, "Per mint in event incorrect");
        assertEq(price, 0.01 ether, "Price in event incorrect");
        assertEq(creator, memeCreator, "Creator in event incorrect");

        Meme memeToken = Meme(deployedAddress);

        // 测试MemeMinted事件
        vm.startPrank(buyer1);
        uint256 perMintPrice = memeToken.price() * memeToken.perMint();

        vm.recordLogs();
        memeFactory.mintMeme{value: perMintPrice}(deployedAddress);
        Vm.Log[] memory mintEntries = vm.getRecordedLogs();
        vm.stopPrank();

        // 验证MemeMinted事件（应该有两个事件：MemeMinted和ERC20 Transfer）
        assertEq(mintEntries.length, 2, "Should emit two events (MemeMinted and Transfer)");

        // 找到MemeMinted事件
        bool foundMemeMinted = false;
        for (uint256 i = 0; i < mintEntries.length; i++) {
            if (mintEntries[i].topics[0] == keccak256("MemeMinted(address,address,uint256)")) {
                foundMemeMinted = true;

                address mintedToken = address(uint160(uint256(mintEntries[i].topics[1])));
                address mintedTo = address(uint160(uint256(mintEntries[i].topics[2])));
                uint256 mintedAmount = abi.decode(mintEntries[i].data, (uint256));

                assertEq(mintedToken, deployedAddress, "Token address in mint event incorrect");
                assertEq(mintedTo, buyer1, "Recipient in mint event incorrect");
                assertEq(mintedAmount, 1000, "Amount in mint event incorrect");
                break;
            }
        }
        assertTrue(foundMemeMinted, "MemeMinted event not found");
    }

    // 测试边界条件
    function testEdgeCases() public {
        // 测试最大可能的参数值
        vm.startPrank(memeCreator);
        vm.recordLogs();
        memeFactory.deployMeme("MAX", type(uint256).max, 1, 1);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        address memeAddress = address(uint160(uint256(entries[0].topics[1])));
        deployedMemes.push(memeAddress);
        Meme memeToken = Meme(memeAddress);

        // 测试最小支付金额
        vm.startPrank(buyer1);
        memeFactory.mintMeme{value: 1}(memeAddress);
        vm.stopPrank();

        assertEq(memeToken.balanceOf(buyer1), 1, "Edge case token balance incorrect");
    }

    // 测试重复初始化
    function testReinitialize() public {
        // 部署Meme合约
        vm.startPrank(memeCreator);
        vm.recordLogs();
        memeFactory.deployMeme("DOGE", 1000000, 1000, 0.01 ether);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        address memeAddress = address(uint160(uint256(entries[0].topics[1])));
        deployedMemes.push(memeAddress);
        Meme memeToken = Meme(memeAddress);

        // 尝试重复初始化
        vm.startPrank(memeCreator);
        vm.expectRevert("MemeToken: Already initialized");
        memeToken.initialize("DOGE2", 2000000, 2000, 0.02 ether, memeCreator);
        vm.stopPrank();
    }

    // 测试只有工厂可以铸造
    function testOnlyFactoryCanMint() public {
        // 部署Meme合约
        vm.startPrank(memeCreator);
        vm.recordLogs();
        memeFactory.deployMeme("DOGE", 1000000, 1000, 0.01 ether);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        address memeAddress = address(uint160(uint256(entries[0].topics[1])));
        deployedMemes.push(memeAddress);
        Meme memeToken = Meme(memeAddress);

        // 尝试直接调用mint函数
        vm.startPrank(buyer1);
        vm.expectRevert("MemeToken: Only MemeFactory can mint");
        memeToken.mint(buyer1);
        vm.stopPrank();
    }
}
