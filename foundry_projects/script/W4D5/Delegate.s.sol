// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// forge script script/W4D5/Delegate.s.sol --private-key $PRIVATE_KEY --rpc-url sepolia --broadcast --verify

import "forge-std/Script.sol";
import "../../src/W4D5/Delegate.sol";
import "../../src/W4D5/TokenBank.sol";

contract DelegateScript is Script {
    Delegate public delegate;
    TokenBank public tokenBank;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 使用已知的MyToken地址
        address myTokenAddress = 0xC044905455DBe3ba560FF064304161b9995B1898;

        TokenBank tokenBank = new TokenBank(myTokenAddress);
        console.log("TokenBank deployed at:", address(tokenBank));
        console.log("MyToken address:", myTokenAddress);

        Delegate delegate = new Delegate();
        console.log("Delegate deployed at:", address(delegate));

        vm.stopBroadcast();
    }
}
