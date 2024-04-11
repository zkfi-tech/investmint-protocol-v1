// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {DeployInvestMint} from "script/DeployInvestMint.s.sol";
import {InvestMintDFT} from "src/contracts/InvestMintDFT.sol";
import {Issuance} from "src/contracts/Issuance.sol";
import {IIssuance} from "src/interfaces/IIssuance.sol";
import {NavTracker} from "src/contracts/NavTracker.sol";

contract IssuanceTest is Test {
    // Events //
    event DFTIssued(address indexed, uint256 indexed);

    // States //
    InvestMintDFT dft;
    Issuance issuance;
    NavTracker navTracker;
    address owner;
    address public marketMaker = makeAddr("marketMaker");
    address public investMintServer;
    uint256 public constant PRECISION = 1e18;
    uint256 public randomDFTAmount = 2e18;

    function setUp() external {
        DeployInvestMint deployer = new DeployInvestMint();
        (dft, issuance, navTracker) = deployer.run();
        owner = dft.owner();
        investMintServer = deployer.investMintServer();
    }

    modifier breakProtocolInvariant() {
        // minting DFTs without increasing AUM
        vm.prank(owner);
        dft.mint(owner, randomDFTAmount);
        _;
    }

    //////////////////////
    ///// issue() tests //
    //////////////////////
    function testIssueRevertsWhenProtocolInvariantBroken()
        external
        breakProtocolInvariant
    {
        // values after breaking invariant
        uint256 valueOfCirculatingDFTs = (dft.totalSupply() *
            navTracker.getNAV()) / PRECISION;
        uint256 AUM = navTracker.getAUM();

        vm.expectRevert(
            abi.encodeWithSelector(
                IIssuance.Issuance__ProtocolInvariantBroken.selector,
                valueOfCirculatingDFTs / PRECISION,
                AUM / PRECISION
            )
        );
        issuance.issue(randomDFTAmount);
    }

    function testIssueRevertsWhenAssetDepositNotConfirmedByCustodian()
        external
    {
        vm.prank(marketMaker);
        vm.expectRevert(IIssuance.Issuance__NoAssetsDeposited.selector);
        issuance.issue(randomDFTAmount);
    }

    function testIssueRevertsIfProtocolInvariantBreaksPostMinting() external {
        // Setup
        // Deposit underlying assets
        uint256 assetValueDeposited = (randomDFTAmount * navTracker.getNAV()) /
            PRECISION;
        uint256 latestAUM = navTracker.getAUM() + assetValueDeposited;

        vm.startPrank(investMintServer);
        navTracker.aumListener(latestAUM);

        // confirm deposit for market maker
        issuance.confirmDeposit(marketMaker);
        vm.stopPrank();

        // executing the mint request
        uint256 inflatedMintRequest = randomDFTAmount + 10e18; // minting more than what we should be minting to break invariant post minting

        vm.prank(marketMaker);
        vm.expectRevert();
        issuance.issue(inflatedMintRequest);
    }

    function testIssuePostAssetDeposit() external {
        // Setup
        // Deposit underlying assets
        uint256 assetValueDeposited = (randomDFTAmount * navTracker.getNAV()) /
            PRECISION;
        uint256 latestAUM = navTracker.getAUM() + assetValueDeposited;

        vm.startPrank(investMintServer);
        navTracker.aumListener(latestAUM);

        // confirm deposit for market maker
        issuance.confirmDeposit(marketMaker);
        vm.stopPrank();

        // executing the mint request
        vm.prank(marketMaker);
        vm.expectEmit(true, true, false, true, address(issuance));
        emit DFTIssued(marketMaker, randomDFTAmount);
        issuance.issue(randomDFTAmount);

        // assert
        assertEq(dft.balanceOf(marketMaker), randomDFTAmount);
    }

    //////////////////////
    ///// redeem() tests //
    //////////////////////
    function testRedeemRevertsWhenProtocolInvariantBroken()
        external
        breakProtocolInvariant
    {
        // values after breaking invariant
        uint256 valueOfCirculatingDFTs = (dft.totalSupply() *
            navTracker.getNAV()) / PRECISION;
        uint256 AUM = navTracker.getAUM();

        vm.expectRevert(
            abi.encodeWithSelector(
                IIssuance.Issuance__ProtocolInvariantBroken.selector,
                valueOfCirculatingDFTs / PRECISION,
                AUM / PRECISION
            )
        );
        issuance.redeem(randomDFTAmount);
    }

    function testRedeemRevertsWhenAssetReleaseNotConfirmedByCustodian()
        external
    {
        vm.prank(marketMaker);
        vm.expectRevert(
            IIssuance.Issuance__UnderlyingAssetsNotRedeemed.selector
        );
        issuance.redeem(randomDFTAmount);
    }

    function testRedeemRevertsIfProtocolInvariantBreaksPostRedeeminng()
        external
    {
        // Setup
        // Deposit underlying assets
        uint256 assetValueDeposited = (randomDFTAmount * navTracker.getNAV()) /
            PRECISION;
        uint256 latestAUM = navTracker.getAUM() + assetValueDeposited;

        vm.startPrank(investMintServer);
        navTracker.aumListener(latestAUM);

        // confirm deposit for market maker
        issuance.confirmDeposit(marketMaker);
        vm.stopPrank();

        vm.prank(marketMaker);
        issuance.issue(randomDFTAmount);

        // Now redeeming DFT > no. of DFTs minted (randomDFTAmount)
        latestAUM = navTracker.getAUM() - assetValueDeposited; // releasing the deposited value considering no change in token prices

        vm.startPrank(investMintServer);
        navTracker.aumListener(latestAUM);
        issuance.confirmRedemption(marketMaker);
        vm.stopPrank();

        // executing the redemption request
        uint256 inflatedRedemptionRequest = randomDFTAmount + 10e18; // redeming more than what we should be to break invariant post minting

        vm.prank(marketMaker);
        vm.expectRevert();
        issuance.redeem(inflatedRedemptionRequest);
    }

    function testRedeemPostAssetRelease() external {
        // Setup
        // Deposit underlying assets
        uint256 assetValueDeposited = (randomDFTAmount * navTracker.getNAV()) /
            PRECISION;
        uint256 latestAUM = navTracker.getAUM() + assetValueDeposited;

        vm.startPrank(investMintServer);
        navTracker.aumListener(latestAUM);

        // confirm deposit for market maker
        issuance.confirmDeposit(marketMaker);
        vm.stopPrank();

        // executing the mint request
        vm.prank(marketMaker);
        issuance.issue(randomDFTAmount);

        vm.startPrank(investMintServer);
        navTracker.aumListener(latestAUM - assetValueDeposited); // release

        // confirm deposit for market maker
        issuance.confirmRedemption(marketMaker);
        vm.stopPrank();

        // executing the mint request
        vm.prank(marketMaker);
        issuance.redeem(randomDFTAmount);

        // assert
        assertEq(dft.balanceOf(marketMaker), 0);
    }
}
