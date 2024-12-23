// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title EthanToken - for game entrancy
 * @author Ethan Walker
 */
contract EthanToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("EthanToken", "EA") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    // only for testing
    function mint(address to, uint256 value) external onlyOwner {
        _mint(to, value);
    }
}
