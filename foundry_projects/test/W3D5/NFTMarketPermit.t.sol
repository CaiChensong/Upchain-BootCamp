// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import "../../src/W3D5/ERC20PermitToken.sol";
import "../../src/W3D5/NFTMarketPermit.sol";
import "../../src/W3D5/PermitNFT.sol";

contract NFTMarketPermitTest is Test {
    ERC20PermitToken public token;
    PermitNFT public nftToken;
    NFTMarketPermit public nftMarket;

    address public projectOwner;
    address public seller;
    address public buyer;
    address public unauthorizedUser;

    uint256 public projectOwnerPrivateKey;
    uint256 public sellerPrivateKey;
    uint256 public buyerPrivateKey;
    uint256 public unauthorizedUserPrivateKey;

    function setUp() public {
        // 生成测试账户
        projectOwnerPrivateKey = 0xA11CE;
        sellerPrivateKey = 0xB0B;
        buyerPrivateKey = 0xC0C;
        unauthorizedUserPrivateKey = 0xD0D;

        projectOwner = vm.addr(projectOwnerPrivateKey);
        seller = vm.addr(sellerPrivateKey);
        buyer = vm.addr(buyerPrivateKey);
        unauthorizedUser = vm.addr(unauthorizedUserPrivateKey);

        // 部署合约
        token = new ERC20PermitToken("ERC20PermitToken", "EPTK");
        nftToken = new PermitNFT();
        nftMarket = new NFTMarketPermit(address(token), address(nftToken), projectOwner);

        // 给seller一些token和NFT
        token.transfer(seller, 1000 ether);
        nftToken.mint(seller, "ipfs://QmTest1");
        nftToken.mint(seller, "ipfs://QmTest2");

        // 给buyer一些token
        token.transfer(buyer, 1000 ether);
    }

    function test_ListNFT() public {
        vm.startPrank(seller);

        // 授权NFT市场合约
        nftToken.setApprovalForAll(address(nftMarket), true);

        // 上架NFT
        nftMarket.list(0, 100 ether);

        assertEq(nftMarket.prices(0), 100 ether);
        assertEq(nftMarket.sellers(0), seller);

        vm.stopPrank();
    }

    function test_PermitBuySuccess() public {
        vm.startPrank(seller);
        nftToken.setApprovalForAll(address(nftMarket), true);
        nftMarket.list(0, 100 ether);
        vm.stopPrank();

        // 项目方为buyer创建签名
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 messageHash =
            keccak256(abi.encodePacked(buyer, uint256(0), uint256(100 ether), deadline, address(nftMarket)));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(projectOwnerPrivateKey, ethSignedMessageHash);

        // buyer使用签名购买NFT
        vm.startPrank(buyer);
        token.approve(address(nftMarket), 100 ether);
        nftMarket.permitBuy(0, 100 ether, deadline, v, r, s);

        assertEq(nftToken.ownerOf(0), buyer);
        assertEq(nftMarket.prices(0), 0);
        assertEq(nftMarket.sellers(0), address(0));
        vm.stopPrank();
    }

    function test_PermitBuyInvalidSignature() public {
        vm.startPrank(seller);
        nftToken.setApprovalForAll(address(nftMarket), true);
        nftMarket.list(0, 100 ether);
        vm.stopPrank();

        // 使用错误的签名者
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 messageHash =
            keccak256(abi.encodePacked(buyer, uint256(0), uint256(100 ether), deadline, address(nftMarket)));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(unauthorizedUserPrivateKey, ethSignedMessageHash);

        // 应该失败
        vm.startPrank(buyer);
        token.approve(address(nftMarket), 100 ether);
        vm.expectRevert("invalid signature");
        nftMarket.permitBuy(0, 100 ether, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_PermitBuyExpiredSignature() public {
        vm.startPrank(seller);
        nftToken.setApprovalForAll(address(nftMarket), true);
        nftMarket.list(0, 100 ether);
        vm.stopPrank();

        // 创建过期的签名
        uint256 deadline = block.timestamp - 1; // 过期时间（1秒前）
        bytes32 messageHash =
            keccak256(abi.encodePacked(buyer, uint256(0), uint256(100 ether), deadline, address(nftMarket)));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(projectOwnerPrivateKey, ethSignedMessageHash);

        // 应该失败
        vm.startPrank(buyer);
        token.approve(address(nftMarket), 100 ether);
        vm.expectRevert("signature expired");
        nftMarket.permitBuy(0, 100 ether, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_PermitBuyReplayAttack() public {
        vm.startPrank(seller);
        nftToken.setApprovalForAll(address(nftMarket), true);
        nftMarket.list(0, 100 ether);
        vm.stopPrank();

        // 创建签名
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 messageHash =
            keccak256(abi.encodePacked(buyer, uint256(0), uint256(100 ether), deadline, address(nftMarket)));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(projectOwnerPrivateKey, ethSignedMessageHash);

        // 第一次使用签名（应该成功）
        vm.startPrank(buyer);
        token.approve(address(nftMarket), 100 ether);
        nftMarket.permitBuy(0, 100 ether, deadline, v, r, s);
        vm.stopPrank();

        // 上架另一个NFT，使用相同的参数
        vm.startPrank(seller);
        nftMarket.list(1, 100 ether);
        vm.stopPrank();

        // 尝试重复使用相同的签名购买不同的NFT（应该失败，因为签名是针对tokenId=0的）
        vm.startPrank(unauthorizedUser);
        token.approve(address(nftMarket), 100 ether);
        vm.expectRevert("invalid signature");
        nftMarket.permitBuy(1, 100 ether, deadline, v, r, s);
        vm.stopPrank();
    }
}
