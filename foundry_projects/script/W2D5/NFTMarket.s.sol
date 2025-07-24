// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// forge script script/W2D5/NFTMarket.s.sol --private-key $PRIVATE_KEY --rpc-url http://127.0.0.1:8545 --broadcast

import {Script, console} from "forge-std/Script.sol";
import "../../src/W2D5/NFTMarket.sol";

contract NFTMarketScript is Script {
    NFTMarket public nftMarket;
    MockERC20 public token;
    MockERC721 public nftToken;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        token = new MockERC20("MockToken", "MTK");
        nftToken = new MockERC721("MockNFTToken", "MNFT");
        nftMarket = new NFTMarket(address(token), address(nftToken));

        vm.stopBroadcast();
    }
}
