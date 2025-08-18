// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IReceiver {
    function tokensReceived(address sender, uint256 value, bytes calldata data) external returns (bool);
}

contract NFTMarketForGraph is IReceiver, IERC721Receiver {
    address public immutable _token;
    address public immutable _nftToken;

    struct Listing {
        uint128 price;
        address seller;
    }

    mapping(uint256 => Listing) public listings;

    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTBought(address indexed buyer, uint256 indexed tokenId, uint256 price);

    constructor(address token, address nftToken) {
        _token = token;
        _nftToken = nftToken;
    }

    function list(uint256 tokenId, uint256 value) public {
        unchecked {
            IERC721(_nftToken).safeTransferFrom(msg.sender, address(this), tokenId);
        }

        listings[tokenId] = Listing(uint128(value), msg.sender);

        emit NFTListed(msg.sender, tokenId, value);
    }

    function buyNFT(uint256 tokenId, uint256 value) public {
        Listing memory listing = listings[tokenId];
        require(value >= listing.price, "paid token not enough");

        IERC20(_token).transferFrom(msg.sender, listing.seller, listing.price);

        unchecked {
            IERC721(_nftToken).safeTransferFrom(address(this), msg.sender, tokenId);
        }

        emit NFTBought(msg.sender, tokenId, listing.price);

        delete listings[tokenId];
    }

    function tokensReceived(address sender, uint256 value, bytes calldata data) external returns (bool) {
        require(_token == msg.sender, "not autherized address");

        uint256 tokenId = abi.decode(data, (uint256));
        Listing memory listing = listings[tokenId];
        require(value >= listing.price, "paid token not enough");

        IERC20(_token).transfer(listing.seller, listing.price);

        unchecked {
            IERC721(_nftToken).safeTransferFrom(address(this), sender, tokenId);
        }

        emit NFTBought(sender, tokenId, listing.price);

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
