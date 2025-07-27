// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// forge script script/W3D5/NFTMarketPermit.s.sol --private-key $PRIVATE_KEY --rpc-url $LOCAL_RPC_URL --broadcast

import {Script, console} from "forge-std/Script.sol";
import "../../src/W3D5/ERC20PermitToken.sol";
import "../../src/W3D5/NFTMarketPermit.sol";
import "../../src/W3D5/PermitNFT.sol";

contract NFTMarketPermitScript is Script {
    ERC20PermitToken public token;
    PermitNFT public nftToken;
    NFTMarketPermit public nftMarket;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 部署ERC20PermitToken
        token = new ERC20PermitToken("ERC20PermitToken", "EPTK");
        console.log("ERC20PermitToken deployed at:", address(token));

        // 部署MyNFT（从NFTMarketPermit.sol中导入）
        nftToken = new PermitNFT();
        console.log("PermitNFT deployed at:", address(nftToken));

        // 部署NFTMarketPermit，传入token地址、nft地址和项目方地址（使用部署者地址作为项目方）
        nftMarket = new NFTMarketPermit(address(token), address(nftToken), msg.sender);
        console.log("NFTMarketPermit deployed at:", address(nftMarket));

        vm.stopBroadcast();
    }
}
