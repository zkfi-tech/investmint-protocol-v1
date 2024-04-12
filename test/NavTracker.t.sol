// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NavTracker} from "src/contracts/NavTracker.sol";
import {INavTracker} from "src/interfaces/INavTracker.sol";
import {InvestMintDFT} from "src/contracts/InvestMintDFT.sol";
import {Issuance} from "src/contracts/Issuance.sol";
import {DeployInvestMint} from "script/DeployInvestMint.s.sol";

contract NavTrackerTest is Test {
    NavTracker public navTracker;
    InvestMintDFT public dft;
    Issuance public issuance;
    DeployInvestMint public deployer;
    address public marketMaker = makeAddr("marketMaker");
    address public owner;
    address public random = makeAddr("random");
    address public investMintServer;
    uint256 public constant PRECISION = 1e18;

    function setUp() external {
        deployer = new DeployInvestMint();
        (dft, issuance, navTracker) = deployer.run();
        investMintServer = deployer.investMintServer();
        owner = deployer.owner();
    }

    ////////////////////////////////
    ///// aumListener() tests /////
    //////////////////////////////
    function testAUMRevertsWhenCalledByNonAuthorisedAddress() external {
        uint256 randomAUM = 30e18;
        vm.prank(random);
        vm.expectRevert(
            abi.encodeWithSelector(
                INavTracker.NavTracker__NotAuthorized.selector,
                random
            )
        );

        navTracker.aumListener(randomAUM);
    }

    function testAUMReceived() external {
        uint256 updatedAUM = 5200e18;
        vm.prank(investMintServer);
        navTracker.aumListener(updatedAUM);

        assertEq(navTracker.getAUM(), updatedAUM);
    }

    //////////////////////////////////
    ///// CalculateNAV() tests //////
    /////////////////////////////////
    function testNAVIncreasesWhenAUMIncreases() external {
        // Setup
        uint256 totalSupply = dft.totalSupply();
        uint256 initialNav = navTracker.getNAV();
        uint256 currentAUM = navTracker.getAUM();

        // Act
        uint256 increasedAUM = currentAUM + 500e18; // increase due to inc. in asset market prices
        vm.prank(investMintServer);
        navTracker.aumListener(increasedAUM);

        // Assert
        // current AUM = 5000
        // increased AUM = 5500
        // totalSupply = 500
        // active nav = 5500/500 = $11
        uint256 expectedNav = ((increasedAUM * PRECISION) / totalSupply);
        navTracker.calculateNAV();
        uint256 activeNav = navTracker.getNAV();

        assert(initialNav < activeNav);
        assertEq(activeNav, expectedNav);
    }

    function testNavRemainsConstantIfNoMovementInMarketValueOfAssets()
        external
    {
        // Setup
        // increasing AUM
        uint256 initialNAV = navTracker.getNAV(); // 10e18
        uint256 currentAUM = navTracker.getAUM(); // 5000e18
        uint256 mintDFTs = 5e18;
        uint256 valueToDeposit = (mintDFTs * initialNAV) / PRECISION; // (5e18 * 10e18)/ 1e18 = 50e18
        // 5 * $10 = $50

        uint256 increasedAUM = (currentAUM + valueToDeposit) ; // 5050e18

        vm.prank(investMintServer);
        navTracker.aumListener(increasedAUM); // 5050e18

        // minting 5 DFTs post deposit
        vm.prank(address(issuance));
        dft.mint(marketMaker, mintDFTs);

        navTracker.calculateNAV(); // being calculated after both AUM & total supply have been updated

        // Assert
        uint256 currentNAV = navTracker.getNAV();
        assertEq(initialNAV, currentNAV);
    }

    //////////////////////////////////
    ///// Getter functions tests /////
    /////////////////////////////////

    function testGetAUM() external view {
        uint256 AUM = navTracker.getAUM();
        uint256 initialAUM = deployer.initialAUM();

        assertEq(AUM, initialAUM);
    }

    function testgetNAV() external view {
        uint256 NAV = navTracker.getNAV();
        uint256 initialNAV = deployer.initialNAV();

        assertEq(NAV, initialNAV);
    }

    function testGetPrecision() external view {
        assertEq(navTracker.getPrecision(), 1e18);
    }

    function testGetAUMWithoutPrecision() external view {
        uint256 currentAUM = navTracker.getAUM();
        uint256 currentAUMWithoutPrecision = navTracker
            .getAUMWithoutPrecision();

        assertEq(currentAUMWithoutPrecision, currentAUM / 1e18);
    }

    function testgetNAVWithoutPrecision() external view {
        uint256 currentNAV = navTracker.getNAV();
        uint256 currentNAVWithoutPrecision = navTracker
            .getNAVWithoutPrecision();

        assertEq(currentNAVWithoutPrecision, currentNAV / 1e18);
    }
}
