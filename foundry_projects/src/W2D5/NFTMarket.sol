// SPDX-License-Identifier: MIT
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

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract NFTMarket is IERC721Receiver {

    address public immutable token;
    address public immutable nftToken;

    mapping(uint256 => uint256) public prices;
    mapping(uint256 => address) public sellers;

    constructor(address _token, address _nftToken) {
        token = _token;
        nftToken = _nftToken;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
      require(nftToken == msg.sender, "not autherized address");
      return this.onERC721Received.selector;
    }

    function list(uint tokenId, uint amount) public {
        IERC721(nftToken).safeTransferFrom(msg.sender, address(this), tokenId);
        prices[tokenId] = amount;
        sellers[tokenId] = msg.sender;
    }

    function buy(uint tokenId, uint amount) external {
      require(amount >= prices[tokenId], "paid token not enough");
      require(IERC721(nftToken).ownerOf(tokenId) == address(this), "aleady selled");
      require(msg.sender != sellers[tokenId], "cannot buy your own NFT");

      IERC20(token).transferFrom(msg.sender, sellers[tokenId], prices[tokenId]);
      IERC721(nftToken).transferFrom(address(this), msg.sender, tokenId);

      prices[tokenId] = 0;
      sellers[tokenId] = address(0);
    }
}
