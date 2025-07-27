// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
实现 Token 购买 NFT 的 NTFMarket 合约
添加功能 permitBuy() 实现只有离线授权的白名单地址才可以购买 NFT （用自己的名称发行 NFT，再上架） 。

白名单具体实现逻辑为：
项目方给白名单地址签名，
白名单用户拿到签名信息后，传给 permitBuy() 函数，
在 permitBuy() 中判断是否是经过许可的白名单用户，如果是，才可以进行后续购买，否则 revert 。
*/

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./PermitNFT.sol";

contract NFTMarketPermit is IERC721Receiver {
    IERC20 public immutable token;
    PermitNFT public immutable nftToken;

    address public immutable projectOwner;

    using ECDSA for bytes32;

    mapping(uint256 => uint256) public prices;
    mapping(uint256 => address) public sellers;

    mapping(bytes32 => bool) public usedSignatures;

    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTBought(address indexed buyer, uint256 indexed tokenId, uint256 price);
    event NFTBoughtWithPermit(address indexed buyer, uint256 indexed tokenId, uint256 price);

    constructor(address _token, address _nftToken, address _projectOwner) {
        token = IERC20(_token);
        nftToken = PermitNFT(_nftToken);
        projectOwner = _projectOwner;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        require(address(nftToken) == msg.sender, "not authorized address");
        return this.onERC721Received.selector;
    }

    function list(uint256 tokenId, uint256 amount) public {
        require(nftToken.ownerOf(tokenId) == msg.sender, "not owner of NFT");
        nftToken.safeTransferFrom(msg.sender, address(this), tokenId);
        prices[tokenId] = amount;
        sellers[tokenId] = msg.sender;
        emit NFTListed(msg.sender, tokenId, amount);
    }

    function buy(uint256 tokenId, uint256 amount) external {
        require(amount >= prices[tokenId], "paid token not enough");
        require(nftToken.ownerOf(tokenId) == address(this), "already sold");
        require(msg.sender != sellers[tokenId], "cannot buy your own NFT");

        token.transferFrom(msg.sender, sellers[tokenId], prices[tokenId]);
        nftToken.transferFrom(address(this), msg.sender, tokenId);
        emit NFTBought(msg.sender, tokenId, prices[tokenId]);

        prices[tokenId] = 0;
        sellers[tokenId] = address(0);
    }

    function permitBuy(uint256 tokenId, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(block.timestamp <= deadline, "signature expired");
        require(amount >= prices[tokenId], "paid token not enough");
        require(nftToken.ownerOf(tokenId) == address(this), "already sold");
        require(msg.sender != sellers[tokenId], "cannot buy your own NFT");

        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, tokenId, amount, deadline, address(this)));

        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        address signer = ethSignedMessageHash.recover(v, r, s);
        require(signer == projectOwner, "invalid signature");

        bytes32 signatureHash = keccak256(abi.encodePacked(v, r, s));
        require(!usedSignatures[signatureHash], "signature already used");
        usedSignatures[signatureHash] = true;

        token.transferFrom(msg.sender, sellers[tokenId], prices[tokenId]);
        nftToken.transferFrom(address(this), msg.sender, tokenId);
        emit NFTBoughtWithPermit(msg.sender, tokenId, prices[tokenId]);

        prices[tokenId] = 0;
        sellers[tokenId] = address(0);
    }
}
