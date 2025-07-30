// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 优化 NFTMarket 的 Gas 表现

(NFTMarket 合约代码位置: foundry_projects/src/W2D2/NFTMarket.sol)

- 查看先前 NFTMarket 的各函数消耗，测试用例的 gas report 记录到 gas_report_v1.md
- 尝试优化 NFTMarket 合约，尽可能减少 gas ，测试用例 用例的 gas report 记录到 gas_report_v2.md

提交你的 github 代码库链接
*/

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../W2D2/ERC20Hook.sol";

contract NFTMarketBetterGas is Receiver, IERC721Receiver {
    // 将地址变量打包到同一个存储槽中，节省 gas
    address public immutable _token;
    address public immutable _nftToken;

    // 使用结构体将相关数据打包，减少存储槽使用
    struct Listing {
        uint128 price; // 使用 uint128 而不是 uint256，节省 gas
        address seller; // 地址占用 20 字节
    }

    mapping(uint256 => Listing) public listings;

    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTBought(address indexed buyer, uint256 indexed tokenId, uint256 price);

    constructor(address token, address nftToken) {
        _token = token;
        _nftToken = nftToken;
    }

    function list(uint256 tokenId, uint256 value) public {
        // 使用 unchecked 优化，因为 safeTransferFrom 内部会检查
        unchecked {
            IERC721(_nftToken).safeTransferFrom(msg.sender, address(this), tokenId);
        }

        // 使用结构体赋值，减少存储操作
        listings[tokenId] = Listing(uint128(value), msg.sender);

        emit NFTListed(msg.sender, tokenId, value);
    }

    function buyNFT(uint256 tokenId, uint256 value) public {
        Listing memory listing = listings[tokenId];
        require(value >= listing.price, "paid token not enough");

        // 直接使用结构体中的值，避免重复存储读取
        ERC20Extend(_token).transferFrom(msg.sender, listing.seller, listing.price);

        unchecked {
            IERC721(_nftToken).safeTransferFrom(address(this), msg.sender, tokenId);
        }

        emit NFTBought(msg.sender, tokenId, listing.price);

        // 删除整个结构体，比单独清零更高效
        delete listings[tokenId];
    }

    function tokensReceived(address sender, uint256 value, bytes calldata data) external returns (bool) {
        require(_token == msg.sender, "not autherized address");

        uint256 tokenId = abi.decode(data, (uint256));
        Listing memory listing = listings[tokenId];
        require(value >= listing.price, "paid token not enough");

        // 直接使用结构体中的值
        ERC20Extend(_token).transfer(listing.seller, listing.price);

        unchecked {
            IERC721(_nftToken).safeTransferFrom(address(this), sender, tokenId);
        }

        emit NFTBought(sender, tokenId, listing.price);

        // 删除整个结构体
        delete listings[tokenId];
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
