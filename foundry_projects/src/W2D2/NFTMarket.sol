// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
题目#2
编写一个简单的 NFTMarket 合约，使用自己发行的 ERC20 扩展 Token 来买卖 NFT， NFTMarket 的函数有：

- list() : 实现上架功能，NFT 持有者可以设定一个价格（需要多少个 Token 购买该 NFT）并上架 NFT 到 NFTMarket，上架之后，其他人才可以购买。

- buyNFT() : 普通的购买 NFT 功能，用户转入所定价的 token 数量，获得对应的 NFT。

- 实现 ERC20 扩展 Token 所要求的接收者方法 tokensReceived  ，在 tokensReceived 中实现 NFT 购买功能(注意扩展的转账需要添加一个额外数据参数)。

*/

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../W2D2/ERC20Hook.sol";

contract MyNFTMarket is Receiver, IERC721Receiver {
    address public _token;
    address public _nftToken;

    mapping(uint256 => uint256) public prices;
    mapping(uint256 => address) public sellers;

    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTBought(address indexed buyer, uint256 indexed tokenId, uint256 price);

    constructor(address token, address nftToken) {
        _token = token;
        _nftToken = nftToken;
    }

    function list(uint256 tokenId, uint256 value) public {
        IERC721(_nftToken).safeTransferFrom(msg.sender, address(this), tokenId);
        prices[tokenId] = value;
        sellers[tokenId] = msg.sender;
        emit NFTListed(msg.sender, tokenId, value);
    }

    function buyNFT(uint256 tokenId, uint256 value) public {
        require(value >= prices[tokenId], "paid token not enough");
        ERC20Extend(_token).transferFrom(msg.sender, sellers[tokenId], prices[tokenId]);
        IERC721(_nftToken).safeTransferFrom(address(this), msg.sender, tokenId);
        emit NFTBought(msg.sender, tokenId, prices[tokenId]);

        prices[tokenId] = 0;
        sellers[tokenId] = address(0);
    }

    function tokensReceived(address sender, uint256 value, bytes calldata data) external returns (bool) {
        require(_token == msg.sender, "not autherized address");

        uint256 tokenId = abi.decode(data, (uint256));
        require(value >= prices[tokenId], "paid token not enough");
        IERC721(_nftToken).safeTransferFrom(address(this), sender, tokenId);
        emit NFTBought(sender, tokenId, prices[tokenId]);

        prices[tokenId] = 0;
        sellers[tokenId] = address(0);
        return true;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        require(_nftToken == msg.sender, "not autherized address");
        return this.onERC721Received.selector;
    }
}
