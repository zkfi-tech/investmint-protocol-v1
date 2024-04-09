// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract InvestMintDFT is ERC20Burnable, Ownable {
    error InvalidAmount(uint256);
 
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {}

    function mint(address account, uint256 value) external onlyOwner {
        if(value <= 0) {
            revert InvalidAmount(value);
        }

        _mint(account, value);
        
    }
}