// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/W4D4/AirdopMerkleNFTMarket.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdopMerkleNFTMarketTest is Test {
    AirdropToken public token;
    AirdropNFT public nft;
    AirdopMerkleNFTMarket public market;

    address public owner;
    address public seller;
    address public buyer;
    address public whitelistUser1;
    address public whitelistUser2;
    address public whitelistUser3;
    address public nonWhitelistUser;

    uint256 public constant NFT_PRICE = 100 ether;

    bytes32 public merkleRoot;
    bytes32[] public merkleProof1;
    bytes32[] public merkleProof2;
    bytes32[] public merkleProof3;

    function setUp() public {
        // ========== 地址初始化 ==========
        owner = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        seller = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        buyer = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
        whitelistUser1 = address(0x90F79bf6EB2c4f870365E785982E1f101E93b906);
        whitelistUser2 = address(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65);
        whitelistUser3 = address(0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc);
        nonWhitelistUser = address(0x976EA74026E726554dB657fA54763abd0C3a0aa9);

        // 部署合约
        vm.startPrank(owner);
        token = new AirdropToken();
        nft = new AirdropNFT();
        market = new AirdopMerkleNFTMarket(address(token));
        vm.stopPrank();

        // 给卖家一些代币和 NFT
        vm.startPrank(owner);
        token.transfer(seller, 1000 ether);
        nft.mint(seller);
        nft.mint(seller);
        vm.stopPrank();

        // ========== 默克尔树数据初始化 ==========
        merkleRoot = bytes32(0x961f2b8d569b3942388f6194bd5fa6ac7bf529395b9baf42593fb26c49f50a23);
        merkleProof1 = new bytes32[](2);
        merkleProof1[0] = bytes32(0xf4ca8532861558e29f9858a3804245bb30f0303cc71e4192e41546237b6ce58b);
        merkleProof1[1] = bytes32(0xe5c951f74bc89efa166514ac99d872f6b7a3c11aff63f51246c3742dfa925c9b);
        merkleProof2 = new bytes32[](2);
        merkleProof2[0] = bytes32(0x1ebaa930b8e9130423c183bf38b0564b0103180b7dad301013b18e59880541ae);
        merkleProof2[1] = bytes32(0xe5c951f74bc89efa166514ac99d872f6b7a3c11aff63f51246c3742dfa925c9b);
        merkleProof3 = new bytes32[](1);
        merkleProof3[0] = bytes32(0x28ee50ccca7572e60f382e915d3cc323c3cb713b263673ba830ab179d0e5d57f);

        // 设置默克尔根
        vm.prank(owner);
        market.updateMerkleRoot(merkleRoot);

        // 卖家上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.listNFT(address(nft), 0, NFT_PRICE);
        // 将 NFT 转移到市场合约
        nft.transferFrom(seller, address(market), 0);
        vm.stopPrank();
    }

    // 测试基本功能
    function testBasicFunctionality() public {
        // 测试上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.listNFT(address(nft), 1, NFT_PRICE);
        vm.stopPrank();

        // 验证上架信息
        (address listOwner, address nftToken, uint256 price, bool isActive) = market.listings(1);
        assertEq(listOwner, seller);
        assertEq(nftToken, address(nft));
        assertEq(price, NFT_PRICE);
        assertTrue(isActive);
    }

    // 测试普通购买功能
    function testBuyNFT() public {
        // 给买家一些代币
        vm.startPrank(owner);
        token.transfer(buyer, 1000 ether);
        vm.stopPrank();

        // 买家授权并购买
        vm.startPrank(buyer);
        token.approve(address(market), NFT_PRICE);
        market.buyNFT(0, NFT_PRICE);
        vm.stopPrank();

        // 验证 NFT 转移
        assertEq(nft.ownerOf(0), buyer);

        // 验证上架信息被删除
        (,,, bool isActive) = market.listings(0);
        assertFalse(isActive);
    }

    // 测试白名单验证
    function testWhitelistVerification() public {
        // 白名单用户应该能通过验证
        assertTrue(MerkleProof.verify(merkleProof1, merkleRoot, keccak256(abi.encodePacked(whitelistUser1))));
        assertTrue(MerkleProof.verify(merkleProof2, merkleRoot, keccak256(abi.encodePacked(whitelistUser2))));
        assertTrue(MerkleProof.verify(merkleProof3, merkleRoot, keccak256(abi.encodePacked(whitelistUser3))));

        // 非白名单用户应该失败
        bytes32[] memory fakeProof = new bytes32[](1);
        fakeProof[0] = bytes32(0);
        assertFalse(MerkleProof.verify(fakeProof, merkleRoot, keccak256(abi.encodePacked(nonWhitelistUser))));
    }

    // 测试 permit 授权功能
    function testPermitPrePay() public {
        // 给白名单用户一些代币
        vm.startPrank(owner);
        token.transfer(whitelistUser1, 1000 ether);
        vm.stopPrank();

        // 生成 permit 签名
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(whitelistUser1);
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                whitelistUser1,
                address(market),
                NFT_PRICE, // 完整价格，因为 permitPrePay 需要足够的授权
                nonce,
                deadline
            )
        );
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // whitelistUser1 对应的私钥
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6, hash);

        // 调用 permitPrePay
        vm.prank(whitelistUser1);
        market.permitPrePay(0, NFT_PRICE, deadline, v, r, s);

        // 验证授权
        assertEq(token.allowance(whitelistUser1, address(market)), NFT_PRICE);
    }

    // 测试白名单购买功能
    function testClaimNFT() public {
        // 给白名单用户一些代币
        vm.startPrank(owner);
        token.transfer(whitelistUser1, 1000 ether);
        vm.stopPrank();

        // 白名单用户授权并购买
        vm.startPrank(whitelistUser1);
        token.approve(address(market), NFT_PRICE / 2);
        market.claimNFT(0, merkleProof1);
        vm.stopPrank();

        // 验证 NFT 转移
        assertEq(nft.ownerOf(0), whitelistUser1);

        // 验证优惠价格
        assertEq(token.balanceOf(seller), 1000 ether + NFT_PRICE / 2);

        // 验证上架信息被删除
        (,,, bool isActive) = market.listings(0);
        assertFalse(isActive);
    }

    // 测试非白名单用户无法购买
    function testNonWhitelistUserCannotClaim() public {
        // 给非白名单用户一些代币
        vm.startPrank(owner);
        token.transfer(nonWhitelistUser, 1000 ether);
        vm.stopPrank();

        // 非白名单用户尝试购买应该失败
        vm.startPrank(nonWhitelistUser);
        token.approve(address(market), NFT_PRICE / 2);

        bytes32[] memory fakeProof = new bytes32[](1);
        fakeProof[0] = bytes32(0);

        vm.expectRevert("NFTMarket: sender is not in whitelist");
        market.claimNFT(0, fakeProof);
        vm.stopPrank();
    }

    // 主要测试：multicall 组合调用 permitPrePay 和 claimNFT
    function testMulticallPermitAndClaim() public {
        // 给白名单用户一些代币
        vm.startPrank(owner);
        token.transfer(whitelistUser1, 1000 ether);
        vm.stopPrank();

        // 生成 permit 签名
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(whitelistUser1);
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                whitelistUser1,
                address(market),
                NFT_PRICE, // 完整价格，因为 permitPrePay 需要足够的授权
                nonce,
                deadline
            )
        );
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // whitelistUser1 对应的私钥
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6, hash);

        // 准备 multicall 数据
        AirdopMerkleNFTMarket.Call[] memory calls = new AirdopMerkleNFTMarket.Call[](2);

        // 第一个调用：permitPrePay
        calls[0] = AirdopMerkleNFTMarket.Call({
            target: address(market),
            allowFailure: false,
            callData: abi.encodeWithSelector(
                market.permitPrePay.selector,
                0, // tokenId
                NFT_PRICE, // amount - 完整价格
                deadline,
                v,
                r,
                s
            )
        });

        // 第二个调用：claimNFT
        calls[1] = AirdopMerkleNFTMarket.Call({
            target: address(market),
            allowFailure: false,
            callData: abi.encodeWithSelector(
                market.claimNFT.selector,
                0, // tokenId
                merkleProof1
            )
        });

        // 执行 multicall
        vm.prank(whitelistUser1);
        AirdopMerkleNFTMarket.Result[] memory results = market.multicall(calls);

        // 验证结果
        assertTrue(results[0].success, "permitPrePay should succeed");
        assertTrue(results[1].success, "claimNFT should succeed");

        // 验证 NFT 转移
        assertEq(nft.ownerOf(0), whitelistUser1);

        // 验证优惠价格支付
        assertEq(token.balanceOf(seller), 1000 ether + NFT_PRICE / 2);

        // 验证上架信息被删除
        (,,, bool isActive) = market.listings(0);
        assertFalse(isActive);
    }

    // 测试 multicall 失败处理
    function testMulticallWithFailure() public {
        AirdopMerkleNFTMarket.Call[] memory calls = new AirdopMerkleNFTMarket.Call[](2);

        // 第一个调用：有效的调用
        calls[0] = AirdopMerkleNFTMarket.Call({
            target: address(market),
            allowFailure: true,
            callData: abi.encodeWithSelector(market.merkleRoot.selector)
        });

        // 第二个调用：无效的调用（应该失败）
        calls[1] = AirdopMerkleNFTMarket.Call({
            target: address(market),
            allowFailure: true, // 允许失败
            callData: abi.encodeWithSelector(bytes4(0x12345678)) // 无效的选择器
        });

        // 执行 multicall（应该成功，因为 allowFailure 为 true）
        AirdopMerkleNFTMarket.Result[] memory results = market.multicall(calls);

        assertTrue(results[0].success, "First call should succeed");
        assertFalse(results[1].success, "Second call should fail");
    }

    // 测试 multicall 不允许失败的情况
    function testMulticallWithoutAllowFailure() public {
        AirdopMerkleNFTMarket.Call[] memory calls = new AirdopMerkleNFTMarket.Call[](1);

        calls[0] = AirdopMerkleNFTMarket.Call({
            target: address(market),
            allowFailure: false, // 不允许失败
            callData: abi.encodeWithSelector(bytes4(0x12345678)) // 无效的选择器
        });

        // 执行 multicall（应该失败）
        vm.expectRevert("NFTMarket: Multicall failed");
        market.multicall(calls);
    }

    // 测试 multicall 调用自己的方法
    function testMulticallSelfCall() public {
        AirdopMerkleNFTMarket.Call[] memory calls = new AirdopMerkleNFTMarket.Call[](1);

        // 调用自己的 merkleRoot 方法
        calls[0] = AirdopMerkleNFTMarket.Call({
            target: address(market),
            allowFailure: false,
            callData: abi.encodeWithSelector(market.merkleRoot.selector)
        });

        // 执行 multicall
        AirdopMerkleNFTMarket.Result[] memory results = market.multicall(calls);

        // 验证结果
        assertTrue(results[0].success, "Self call should succeed");
        assertEq(results[0].returnData.length, 32, "Should return merkleRoot");
    }

    // 测试第三个白名单用户
    function testWhitelistUser3() public {
        // 给第三个白名单用户一些代币
        vm.startPrank(owner);
        token.transfer(whitelistUser3, 1000 ether);
        vm.stopPrank();

        // 第三个白名单用户授权并购买
        vm.startPrank(whitelistUser3);
        token.approve(address(market), NFT_PRICE / 2);
        market.claimNFT(0, merkleProof3);
        vm.stopPrank();

        // 验证 NFT 转移
        assertEq(nft.ownerOf(0), whitelistUser3);

        // 验证优惠价格
        assertEq(token.balanceOf(seller), 1000 ether + NFT_PRICE / 2);

        // 验证上架信息被删除
        (,,, bool isActive) = market.listings(0);
        assertFalse(isActive);
    }
}
