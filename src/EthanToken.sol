// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EthanToken is ERC20 {
    // Set my token's name and symbol
    constructor(uint256 initialSupply) ERC20("EthanToken", "EA") {
        _mint(msg.sender, initialSupply);
    }

    // 仅供 test 函数中使用, 实际部署不能有这个函数
    function mint(address to, uint256 value) public {
        _mint(to, value);
    }
}
