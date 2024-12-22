// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {EthanToken} from "../src/EthanToken.sol";


contract DeployEthanToken is Script {
    uint256 constant INITIAL_SUPPLY = 1000000 ether;
    address public ANVIL_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public MAINNET_ACCOUNT = 0x67612F0D87a3A6bBc13074Bf54c0500dbA12f4D4;
    address public SEPOLIA_ACCOUNT = 0x67612F0D87a3A6bBc13074Bf54c0500dbA12f4D4;
    function run() external returns (EthanToken) {
        address account;
        if (block.chainid == 1) {
            account = MAINNET_ACCOUNT;
        } else if (block.chainid == 42) {
            account = SEPOLIA_ACCOUNT;
        } else {
            account = ANVIL_ACCOUNT;
        }

        vm.startBroadcast(account);
        EthanToken ethanToken = new EthanToken(INITIAL_SUPPLY);
        vm.stopBroadcast();
        return ethanToken;
    }
}