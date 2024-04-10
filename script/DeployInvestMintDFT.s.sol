// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {InvestMintDFT} from "src/contracts/InvestMintDFT.sol";
import {Issuance} from "src/contracts/Issuance.sol";
import {NavTracker} from "src/contracts/NavTracker.sol";

contract DeployInvestMintDFT is Script {
    address public investMintServer = makeAddr('investMintServer');
    uint256 public initialAUM = 5000e18; // $5000
    uint256 public initialNAV = 10e18; // $10
    uint256 public initialSupply;
    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public owner = makeAddr("owner");

    function run() external returns(InvestMintDFT, Issuance, NavTracker) {
        vm.startBroadcast(owner);
        InvestMintDFT dft = new InvestMintDFT("InvestMintDFT", "IMDFT");
        NavTracker navTracker = new NavTracker(initialNAV, investMintServer, initialAUM, dft);
        Issuance issuance = new Issuance(investMintServer, dft, navTracker);

        dft.transferOwnership(address(issuance));
        vm.stopBroadcast();

        // minting the initial supply based on initial AUM & NAV to the protocol owner
        initialSupply = initialAUM / initialNAV;
        vm.prank(address(issuance));
        dft.mint(owner, initialSupply);

        return (dft, issuance, navTracker);
    }
}