// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract InvestMintDFT is ERC20Burnable {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}
}