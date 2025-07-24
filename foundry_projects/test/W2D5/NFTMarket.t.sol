// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1
编写 NFTMarket 合约：
- 支持设定任意ERC20价格来上架NFT
- 支持支付ERC20购买指定的NFT

要求测试内容：
- 上架NFT：测试上架成功和失败情况，要求断言错误信息和上架事件。
- 购买NFT：测试购买成功、自己购买自己的NFT、NFT被重复购买、支付Token过多或者过少情况，要求断言错误信息和购买事件。
- 模糊测试：测试随机使用 0.01-10000 Token价格上架NFT，并随机使用任意Address购买NFT
- 「可选」不可变测试：测试无论如何买卖，NFTMarket合约中都不可能有 Token 持仓

提交内容要求
- 使用 foundry 测试和管理合约；
- 提交 Github 仓库链接到挑战中；
- 提交 foge test 测试执行结果txt到挑战中；
*/
import {Test, console} from "forge-std/Test.sol";
import "../../src/W2D5/NFTMarket.sol";

contract NFTMarketTest is Test {
    NFTMarket public nftMarket;
    MockERC20 public token;
    MockERC721 public nftToken;
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    function setUp() public {
        token = new MockERC20("MockToken", "MTK");
        nftToken = new MockERC721("MockNFTToken", "MNFT");
        nftMarket = new NFTMarket(address(token), address(nftToken));

        token.mint(user1, 10000 ether);
        token.mint(user2, 10000 ether);
        token.mint(user3, 10000 ether);
        nftToken.safeMint(user1, 1);
        nftToken.safeMint(user2, 2);
        nftToken.safeMint(user3, 3);

        vm.prank(user1);
        token.approve(address(nftMarket), type(uint256).max);
        vm.prank(user2);
        token.approve(address(nftMarket), type(uint256).max);
        vm.prank(user3);
        token.approve(address(nftMarket), type(uint256).max);
        vm.prank(user1);
        nftToken.approve(address(nftMarket), 1);
        vm.prank(user2);
        nftToken.approve(address(nftMarket), 2);
        vm.prank(user3);
        nftToken.approve(address(nftMarket), 3);
    }

    function test_list_success() public {
        vm.prank(user1);
        nftMarket.list(1, 100 ether);

        assertEq(nftToken.ownerOf(1), address(nftMarket));
        assertEq(nftMarket.prices(1), 100 ether);
        assertEq(nftMarket.sellers(1), user1);
    }

    function test_list_fail_not_owner() public {
        vm.expectRevert();
        nftMarket.list(1, 100 ether);
    }

    function test_buy_success() public {
        vm.prank(user1);
        nftMarket.list(1, 100 ether);
        vm.prank(user2);
        nftMarket.buy(1, 100 ether);

        assertEq(nftToken.ownerOf(1), user2);
        assertEq(token.balanceOf(user1), 10000 ether + 100 ether);
        assertEq(token.balanceOf(user2), 10000 ether - 100 ether);
        assertEq(nftMarket.prices(1), 0);
        assertEq(nftMarket.sellers(1), address(0));
    }

    function test_buy_fail_self_buy() public {
        vm.prank(user1);
        nftMarket.list(1, 100 ether);

        vm.prank(user1);
        vm.expectRevert();
        nftMarket.buy(1, 100 ether);
    }

    function test_buy_fail_repeat() public {
        vm.prank(user1);
        nftMarket.list(1, 100 ether);

        vm.prank(user2);
        nftMarket.buy(1, 100 ether);

        vm.prank(user3);
        vm.expectRevert();
        nftMarket.buy(1, 100 ether);
    }

    function test_buy_fail_token_not_enough() public {
        vm.prank(user1);
        nftMarket.list(1, 100 ether);

        vm.prank(user2);
        vm.expectRevert();
        nftMarket.buy(1, 99 ether);
    }

    function test_buy_success_token_more_than_price() public {
        vm.prank(user1);
        nftMarket.list(1, 100 ether);

        vm.prank(user2);
        nftMarket.buy(1, 200 ether);
        assertEq(nftToken.ownerOf(1), user2);
    }

    function test_fuzz_list_and_buy(uint96 price, uint8 buyerIndex) public {
        price = uint96(bound(price, 0.01 ether, 10000 ether));
        address buyer = buyerIndex % 2 == 0 ? user2 : user3;

        vm.prank(user1);
        nftMarket.list(1, price);

        vm.prank(buyer);
        nftMarket.buy(1, price);
        assertEq(nftToken.ownerOf(1), buyer);
    }

    function test_market_never_hold_token() public {
        vm.prank(user1);
        nftMarket.list(1, 100 ether);

        vm.prank(user2);
        nftMarket.buy(1, 100 ether);
        assertEq(token.balanceOf(address(nftMarket)), 0);
    }
}
