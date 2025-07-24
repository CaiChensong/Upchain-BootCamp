// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// forge script script/W2D4/MyToken.s.sol --private-key $MNEMONIC --rpc-url sepolia --broadcast

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../../src/W2D4/MyToken.sol";

contract MyTokenScript is Script {
    MyToken public myToken;

    function setUp() public {
        // mnemonic = vm.envString("MNEMONIC");
        // (deployer, ) = deriveRememberKey(mnemonic, 0);

        // uint256 deployerPrivateKey = vm.envUint(“PRIVATE_KEY");
        // user = vm.addr(deployerPrivateKey)
    }

    function run() public {
        vm.startBroadcast();

        myToken = new MyToken("MyToken", "MTK");

        vm.stopBroadcast();
    }
}
