// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../../src/W7D1/NFTMarketForGraph.sol";
import "../../src/W7D1/TestNFT.sol";

contract DeployNFTMarketForGraphScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address myToken = 0xC044905455DBe3ba560FF064304161b9995B1898;

        vm.startBroadcast(deployerPrivateKey);

        TestNFT testNFT = new TestNFT();
        NFTMarketForGraph nftMarketForGraph = new NFTMarketForGraph(myToken, address(testNFT));

        console.log("NFTMarketForGraph deployed to:", address(nftMarketForGraph));
        console.log("TestNFT deployed to:", address(testNFT));

        vm.stopBroadcast();
    }
}

contract NFTMarketOperationsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address nftMarketAddress = 0x72bE779C26C45F84e1Bb20665FBC1F1535248636;
        address testNFTAddress = 0x84daD945a537Db3B4042f812785d5B2f0fc37D7d;
        address myTokenAddress = 0xC044905455DBe3ba560FF064304161b9995B1898;

        console.log("Contract Addresses:");
        console.log("NFT Market:", nftMarketAddress);
        console.log("Test NFT:", testNFTAddress);
        console.log("My Token:", myTokenAddress);
        console.log("Deployer:", deployer);

        // 获取合约实例
        NFTMarketForGraph nftMarket = NFTMarketForGraph(nftMarketAddress);
        TestNFT testNFT = TestNFT(testNFTAddress);
        IERC20 myToken = IERC20(myTokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 铸造NFT
        console.log("\nMint NFT");
        for (uint256 i = 0; i < 3; i++) {
            testNFT.safeMint(deployer);
            console.log("Mint NFT ID:", i);
            console.log("Mint NFT to address:", deployer);
        }

        // 2. 上架NFT
        console.log("\nList NFT");
        uint256[] memory prices = new uint256[](3);
        prices[0] = 10 * 10 ** 18; // 10 tokens
        prices[1] = 20 * 10 ** 18; // 20 tokens
        prices[2] = 15 * 10 ** 18; // 15 tokens

        for (uint256 i = 0; i < 3; i++) {
            // 首先需要授权NFT市场合约转移NFT
            testNFT.approve(address(nftMarket), i);

            // 上架NFT
            nftMarket.list(i, prices[i]);
            console.log("List NFT ID:", i);
            console.log("List NFT price:", prices[i] / 10 ** 18);
        }

        vm.stopBroadcast();

        console.log("\nOperation completed");
    }
}

contract BuyNFTScript is Script {
    function run() external {
        uint256 buyerPrivateKey = vm.envUint("PRIVATE_KEY_2");
        address buyer = vm.addr(buyerPrivateKey);

        address nftMarketAddress = 0x72bE779C26C45F84e1Bb20665FBC1F1535248636;
        address myTokenAddress = 0xC044905455DBe3ba560FF064304161b9995B1898;

        console.log("Buyer address:", buyer);
        console.log("NFT Market:", nftMarketAddress);
        console.log("My Token:", myTokenAddress);

        // 获取合约实例
        NFTMarketForGraph nftMarket = NFTMarketForGraph(nftMarketAddress);
        IERC20 myToken = IERC20(myTokenAddress);

        vm.startBroadcast(buyerPrivateKey);

        // 购买NFT ID 0
        uint256 tokenId = 0;
        uint256 price = 10 * 10 ** 18; // 10 tokens

        // 首先需要授权NFT市场合约转移tokens
        myToken.approve(address(nftMarket), price);

        // 购买NFT
        nftMarket.buyNFT(tokenId, price);
        console.log("Successfully bought NFT ID:", tokenId);
        console.log("Bought NFT price:", price / 10 ** 18);

        vm.stopBroadcast();

        console.log("Purchase completed!");
    }
}
