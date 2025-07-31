// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../../src/W4D4/AirdopMerkleNFTMarket.sol";

contract AirdopMerkleNFTMarketScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        AirdropToken token = new AirdropToken();
        console.log("AirdropToken deployed at:", address(token));

        AirdropNFT nft = new AirdropNFT();
        console.log("AirdropNFT deployed at:", address(nft));

        AirdopMerkleNFTMarket market = new AirdopMerkleNFTMarket(address(token));
        console.log("AirdopMerkleNFTMarket deployed at:", address(market));

        vm.stopBroadcast();
    }
}
