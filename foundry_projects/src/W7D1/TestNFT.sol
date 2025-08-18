// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter = 0;

    constructor() ERC721("TestNFT", "TNFT") Ownable(msg.sender) {}

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(to, tokenId);
    }
}
