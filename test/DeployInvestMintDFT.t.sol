// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {DeployInvestMintDFT} from "script/DeployInvestMintDFT.s.sol";
import {InvestMintDFT} from "src/contracts/InvestMintDFT.sol";
import {Issuance} from "src/contracts/Issuance.sol";
import {NavTracker} from "src/contracts/NavTracker.sol";
 
contract DeployInvestMintDFTTest is Test {
    DeployInvestMintDFT deployer;
    InvestMintDFT dft;
    Issuance issuance;
    NavTracker navTracker;

    function setUp() external {
        deployer = new DeployInvestMintDFT();
        (dft, issuance, navTracker) = deployer.run();
    }

    function testDFTDeployed() external {
        assert(address(dft) != address(0));
    }
    
    function testIssuanceDeployed() external {
        assert(address(issuance) != address(0));
    }
    
    function testNavTrackerDeployed() external {
        assert(address(navTracker) != address(0));
    }
}