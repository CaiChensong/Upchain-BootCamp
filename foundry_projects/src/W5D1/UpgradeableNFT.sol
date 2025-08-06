// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

contract UpgradeableNFTV1 is Initializable, ERC721Upgradeable, OwnableUpgradeable {
    uint256 private _tokenIdCounter;

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __ERC721_init("UpgradeableNFT", "UNFT");
        __Ownable_init(initialOwner);
        _tokenIdCounter = 0;
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(to, tokenId);
    }
}

contract UpgradeableNFTV2 is UpgradeableNFTV1 {
    string public _version;

    function initializeV2() public reinitializer(2) {
        _version = "2.0.0";
    }

    function getVersion() public view returns (string memory) {
        return _version;
    }

    function setVersion(string memory newVersion) public onlyOwner {
        _version = newVersion;
    }
}
