// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

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
