// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract UpgradeableNFTMarketV1 is Initializable, IERC721Receiver {
    IERC20 public token;

    struct Listing {
        address owner;
        address nftToken;
        uint256 price;
        bool isActive;
    }

    mapping(uint256 => Listing) public listings;

    event NFTListed(uint256 indexed tokenId, address indexed seller, address indexed nftToken, uint256 price);
    event NFTBought(uint256 indexed tokenId, address indexed buyer, address indexed nftToken, uint256 price);
    event NFTCanceled(uint256 indexed tokenId, address indexed owner, address indexed nftToken, uint256 price);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _token) public initializer {
        token = IERC20(_token);
    }

    function listNFT(address _nftToken, uint256 _tokenId, uint256 _price) public {
        require(_price > 0, "NFTMarket: price must be greater than 0");
        require(_nftToken != address(0), "NFTMarket: nftToken is not valid");
        require(!listings[_tokenId].isActive, "NFTMarket: NFT is already listed");

        IERC721 nft = IERC721(_nftToken);
        address owner = nft.ownerOf(_tokenId);
        require(
            owner == msg.sender || nft.isApprovedForAll(owner, msg.sender) || nft.getApproved(_tokenId) == msg.sender,
            "NFTMarket: caller is not owner nor approved"
        );

        listings[_tokenId] = Listing({owner: msg.sender, nftToken: _nftToken, price: _price, isActive: true});
        emit NFTListed(_tokenId, msg.sender, _nftToken, _price);
    }

    function buyNFT(uint256 _tokenId, uint256 _amount) public {
        Listing memory list = listings[_tokenId];
        require(list.isActive, "NFTMarket: NFT is not listed");
        require(_amount >= list.price, "NFTMarket: paid token not enough");
        require(msg.sender != list.owner, "NFTMarket: cannot buy your own NFT");

        require(token.transferFrom(msg.sender, list.owner, list.price), "NFTMarket: transfer failed");
        IERC721(list.nftToken).transferFrom(list.owner, msg.sender, _tokenId);

        delete listings[_tokenId];
        emit NFTBought(_tokenId, msg.sender, list.nftToken, list.price);
    }

    function cancelListing(uint256 _tokenId) public {
        Listing memory list = listings[_tokenId];
        require(list.isActive, "NFTMarket: NFT is not listed");
        require(msg.sender == list.owner, "NFTMarket: caller is not owner");

        list.isActive = false;
        emit NFTCanceled(_tokenId, msg.sender, list.nftToken, list.price);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}

contract UpgradeableNFTMarketV2 is UpgradeableNFTMarketV1 {
    uint256 private _nonce;

    function initializeV2() public reinitializer(2) {
        _nonce = 0;
    }

    function getNonce() public view returns (uint256) {
        return _nonce;
    }

    function listWithSignature(
        address _nftToken,
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline,
        bytes memory _signature
    ) public {
        require(_price > 0, "NFTMarket: price must be greater than 0");
        require(_nftToken != address(0), "NFTMarket: nftToken is not valid");
        require(!listings[_tokenId].isActive, "NFTMarket: NFT is already listed");
        require(block.timestamp <= _deadline, "NFTMarket: signature is expired");

        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(
            keccak256(abi.encodePacked(address(this), _nftToken, _tokenId, _price, _nonce, _deadline))
        );
        address signer = ECDSA.recover(messageHash, _signature);

        IERC721 nft = IERC721(_nftToken);
        address owner = nft.ownerOf(_tokenId);
        require(
            signer == owner || nft.isApprovedForAll(owner, signer) || nft.getApproved(_tokenId) == signer,
            "NFTMarket: signer is not owner nor approved"
        );

        _nonce++;

        listings[_tokenId] = Listing({owner: owner, nftToken: _nftToken, price: _price, isActive: true});
        emit NFTListed(_tokenId, owner, _nftToken, _price);
    }
}
