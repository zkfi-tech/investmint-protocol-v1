// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title IMDFT Token
/// @author InvestMint
/// @notice The Digital Fund Token unitizing Vinter Index Multi Asset Basket 
/// @dev    owner: Issuance contract (Since ownership was transferred in the deployment script)
contract InvestMintDFT is ERC20, Ownable {
    error InvestMintDFT__ProvideNonZeroAmount();
    
    address public issuer;
 
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {}

    function mint(address account, uint256 value) external onlyOwner {
        if(value == 0) {
            revert InvestMintDFT__ProvideNonZeroAmount();
        }

        _mint(account, value);
    }

    function burn(address holder, uint256 value) public onlyOwner {
        if(value == 0) {
            revert InvestMintDFT__ProvideNonZeroAmount();
        }
        
        _burn(holder, value);
    }
}