// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forge script script/W2D2/NFTMarket.s.sol --private-key $MNEMONIC --rpc-url http://127.0.0.1:8545 --broadcast

import {Script, console} from "forge-std/Script.sol";
import "../../src/W2D2/NFTMarket.sol";
import "../../src/W2D2/MyNFT.sol";
import "../../src/W2D2/ERC20Hook.sol";

contract NFTMarketScript is Script {
    MyNFTMarket public nftMarket;
    NFTAerialCCC public nft;
    ERC20Extend public token;

    function setUp() public {
        // mnemonic = vm.envString("MNEMONIC");
        // (deployer, ) = deriveRememberKey(mnemonic, 0);

        // uint256 deployerPrivateKey = vm.envUint(“PRIVATE_KEY");
        // user = vm.addr(deployerPrivateKey)
    }

    function run() public {
        vm.startBroadcast();

        token = new ERC20Extend();
        nft = new NFTAerialCCC();
        nftMarket = new MyNFTMarket(address(token), address(nft));

        vm.stopBroadcast();
    }
}
