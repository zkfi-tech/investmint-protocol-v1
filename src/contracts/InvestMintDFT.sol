// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title IMDFT Token
/// @author InvestMint
/// @notice The Digital Fund Token unitizing Vinter Index Multi Asset Basket 
contract InvestMintDFT is ERC20 {
    error InvestMintDFT__ProvideNonZeroAmount();
    error InvestMintDFT__NotTheIssuer(address);
    
    address public issuer;

    modifier onlyIssuer(address sender) {
        if(sender != issuer) {
            revert InvestMintDFT__NotTheIssuer(sender);
        }
        _;
    }
 
    constructor(string memory _name, string memory _symbol, address _issuer) ERC20(_name, _symbol) {
        issuer = _issuer;
    }

    function mint(address account, uint256 value) external onlyIssuer(msg.sender) {
        if(value == 0) {
            revert InvestMintDFT__ProvideNonZeroAmount();
        }

        _mint(account, value);
    }

    function burn(address holder, uint256 value) public onlyIssuer(msg.sender) {
        if(value == 0) {
            revert InvestMintDFT__ProvideNonZeroAmount();
        }
        
        _burn(holder, value);
    }

    function getIssuer() external view returns(address) {
        return issuer;
    }
}