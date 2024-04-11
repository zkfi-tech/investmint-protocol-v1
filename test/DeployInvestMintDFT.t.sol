// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {DeployInvestMint} from "script/DeployInvestMint.s.sol";
import {InvestMintDFT} from "src/contracts/InvestMintDFT.sol";
import {Issuance} from "src/contracts/Issuance.sol";
import {NavTracker} from "src/contracts/NavTracker.sol";

contract DeployInvestMintTest is Test {
    DeployInvestMint deployer;
    InvestMintDFT dft;
    Issuance issuance;
    NavTracker navTracker;

    function setUp() external {
        deployer = new DeployInvestMint();
        (dft, issuance, navTracker) = deployer.run();
    }

    function testDFTDeployed() external view {
        assert(address(dft) != address(0));
        assert(dft.totalSupply() == deployer.initialSupply());
        assertEq(dft.owner(), address(issuance));
    }

    function testIssuanceDeployed() external view {
        assert(address(issuance) != address(0));
    }

    function testNavTrackerDeployed() external view {
        assert(address(navTracker) != address(0));
    }
}
