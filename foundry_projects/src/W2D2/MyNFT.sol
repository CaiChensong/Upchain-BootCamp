// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1
用 ERC721 标准（可复用 OpenZepplin 库）发行一个自己 NFT 合约，并用图片铸造几个 NFT ，
请把图片和 Meta Json数据上传到去中心的存储服务中，请贴出在 OpenSea 的 NFT 链接。
*/

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTAerialCCC is ERC721URIStorage, Ownable {
    uint256 private _tokenIdCounter = 0;

    constructor() ERC721("NFT_AerialCCC", "AERIALCCC") Ownable(msg.sender) {}

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
}
