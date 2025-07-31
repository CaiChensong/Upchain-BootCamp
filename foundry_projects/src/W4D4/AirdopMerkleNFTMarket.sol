// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/*
题目#1 组合使用 MerkleTree 白名单、 Permit 授权 及 Multicall

实现一个 AirdopMerkleNFTMarket 合约(假定 Token、NFT、AirdopMerkleNFTMarket 都是同一个开发者开发)，功能如下：

- 基于 Merkel 树验证某用户是否在白名单中
- 在白名单中的用户可以使用上架指定价格的优惠 50% 的 Token 来购买 NFT， Token 需支持 permit 授权。

要求使用 multicall( delegateCall 方式) 一次性调用两个方法：

- permitPrePay() : 调用 token 的 permit 进行授权
- claimNFT() : 通过默克尔树验证白名单，并利用 permitPrePay 的授权，转入 token 转出 NFT 。

请贴出你的代码 github ，代码需包含合约，multicall 调用封装，Merkel 树的构建以及测试用例。
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdropToken is ERC20Permit, Ownable {
    constructor() ERC20("AirdropToken", "ADT") ERC20Permit("AirdropToken") Ownable(msg.sender) {
        _mint(msg.sender, 10000 ether);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract AirdropNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;

    constructor() ERC721("AirdropNFT", "ANFT") Ownable(msg.sender) {}

    function mint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(to, tokenId);
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter;
    }
}

contract AirdopMerkleNFTMarket is IERC721Receiver, Ownable {
    IERC20 public immutable token;
    bytes32 public merkleRoot;

    struct Listing {
        address owner;
        address nftToken;
        uint256 price;
        bool isActive;
    }

    mapping(uint256 => Listing) public listings;

    event NFTListed(uint256 indexed tokenId, address indexed seller, address indexed nftToken, uint256 price);
    event NFTBought(uint256 indexed tokenId, address indexed buyer, address indexed nftToken, uint256 price);
    event WhitelistNFTClaimed(
        uint256 indexed tokenId, address indexed buyer, address indexed seller, address nftToken, uint256 price
    );

    constructor(address _token) Ownable(msg.sender) {
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
        IERC721(list.nftToken).transferFrom(address(this), msg.sender, _tokenId);

        delete listings[_tokenId];
        emit NFTBought(_tokenId, msg.sender, list.nftToken, list.price);
    }

    function permitPrePay(uint256 tokenId, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        Listing memory list = listings[tokenId];
        require(list.isActive, "NFTMarket: NFT is not listed");
        require(amount >= list.price, "NFTMarket: paid amount is not enough");

        // owner：代币持有者（签名者）地址, spender：被授权消费代币的地址
        IERC20Permit(address(token)).permit(msg.sender, address(this), list.price, deadline, v, r, s);
    }

    function claimNFT(uint256 _tokenId, bytes32[] memory proof) external {
        Listing memory list = listings[_tokenId];
        require(list.isActive, "NFTMarket: NFT is not listed");

        // 验证白名单
        require(_verify(msg.sender, proof), "NFTMarket: sender is not in whitelist");

        // 计算优惠价格
        uint256 newPrice = list.price / 2;

        require(token.transferFrom(msg.sender, list.owner, newPrice), "NFTMarket: transfer failed");
        IERC721(list.nftToken).transferFrom(address(this), msg.sender, _tokenId);

        delete listings[_tokenId];
        emit WhitelistNFTClaimed(_tokenId, msg.sender, list.owner, list.nftToken, newPrice);
    }

    // Merkle 树验证，调用 MerkleProof 库的 verify() 函数
    function _verify(address account, bytes32[] memory proof) internal view returns (bool) {
        return MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(account)));
    }

    function updateMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    struct Call {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function multicall(Call[] calldata calls) public returns (Result[] memory returnData) {
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call calldata call_i;

        // 在循环中依次调用
        for (uint256 i = 0; i < length; i++) {
            Result memory result = returnData[i];
            call_i = calls[i];
            (result.success, result.returnData) = call_i.target.delegatecall(call_i.callData);
            // 如果 call_i.allowFailure 和 result.success 均为 false，则 revert
            if (!(call_i.allowFailure || result.success)) {
                revert("NFTMarket: Multicall failed");
            }
        }
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}
