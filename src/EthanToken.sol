// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title EthanToken - for game entrancy
 * @author Ethan Walker
 */
contract EthanToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("EthanToken", "EA") {
        _mint(msg.sender, initialSupply);
    }

    // only for testing
    function mint(address to, uint256 value) public {
        _mint(to, value);
    }
}
