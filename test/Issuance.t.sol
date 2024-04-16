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
    uint256 public initialSupplyWithOwner;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant TIMEGAP = 3600;
    uint256 public randomDFTAmount = 2e18;

    function setUp() external {
        DeployInvestMint deployer = new DeployInvestMint();
        (dft, issuance, navTracker) = deployer.run();

        owner = deployer.owner(); // protocol owner
        initialSupplyWithOwner = deployer.initialSupply();
        investMintServer = deployer.investMintServer();
    }

    function _breakProtocolInvariant() internal {
        // randomly minting DFTs without increasing AUM
        vm.prank(address(issuance));
        dft.mint(owner, randomDFTAmount);
    }

    function _issueSetup() internal returns (uint256, uint256) {
        // Setup
        // Deposit underlying assets
        uint256 nav = navTracker.getNAV();
        uint256 assetValueDeposited = (randomDFTAmount * nav) / PRECISION;
        uint256 latestAUM = navTracker.getAUM() + assetValueDeposited;

        vm.startPrank(investMintServer);
        navTracker.aumListener(latestAUM);

        // confirm deposit for market maker
        issuance.confirmDeposit(marketMaker);
        vm.stopPrank();

        // executing the mint request
        // getting the minting fee
        uint256 reqProcessingFee = issuance.calculateRequestProcessingFeeOn(
            randomDFTAmount
        );
        uint256 marketMakerReceives = randomDFTAmount - reqProcessingFee;

        return (marketMakerReceives, reqProcessingFee);
    }

    function _redemptionSetup()
        internal
        returns (uint256, uint256, uint256, uint256)
    {
        // Mint DFT process
        // Deposit underlying assets
        uint256 nav = navTracker.getNAV();
        uint256 assetValueDeposited = (randomDFTAmount * nav) / PRECISION;
        uint256 latestAUM = navTracker.getAUM() + assetValueDeposited;

        vm.startPrank(investMintServer);
        navTracker.aumListener(latestAUM);

        // confirm deposit for market maker
        issuance.confirmDeposit(marketMaker);
        vm.stopPrank();

        vm.prank(marketMaker);
        issuance.issue(randomDFTAmount); // fees deducted

        uint256 marketMakerReceivedBal = dft.balanceOf(marketMaker);

        // Redemption process starts
        vm.warp(block.timestamp + TIMEGAP); // creating time diff. between issue - redeemption for management fee inclusion
        uint256 redeemReqProcessingFee = issuance
            .calculateRequestProcessingFeeOn(marketMakerReceivedBal);
        uint256 dftsBeingRedeemed = marketMakerReceivedBal -
            redeemReqProcessingFee;
        uint256 ownerBalBeforeRedemption = dft.balanceOf(owner);

        // current value of these dfts have to be released by the custodian
        uint256 redeemDFTsValue = (dftsBeingRedeemed * navTracker.getNAV()) /
            PRECISION;
        latestAUM = navTracker.getAUM() - redeemDFTsValue;

        vm.startPrank(investMintServer);
        navTracker.aumListener(latestAUM); // release

        // confirm redemption for market maker
        issuance.confirmRedemption(marketMaker);
        vm.stopPrank();

        return (
            marketMakerReceivedBal,
            redeemReqProcessingFee,
            ownerBalBeforeRedemption,
            nav
        );
    }

    //////////////////////
    ///// issue() tests //
    //////////////////////
    function testIssueRevertsWhenProtocolInvariantBroken() external {
        _breakProtocolInvariant();
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
        (uint256 marketMakerReceives, uint256 reqProcessingFee) = _issueSetup();
        vm.prank(marketMaker);
        vm.expectEmit(true, true, false, true, address(issuance));
        emit DFTIssued(marketMaker, marketMakerReceives);
        issuance.issue(randomDFTAmount);

        // assert
        assertEq(dft.balanceOf(marketMaker), marketMakerReceives);
        assert(
            dft.balanceOf(owner) >= (initialSupplyWithOwner + reqProcessingFee)
        );
    }

    function testNavRemainsSameOnFirstMintButInflatesAfterSecond() external {
        // Setup
        uint256 initialNAV = navTracker.getNAV();
        _issueSetup();

        vm.prank(marketMaker);
        issuance.issue(randomDFTAmount);
        uint256 navAfterFirstMint = navTracker.getNAV();

        vm.warp(block.timestamp + TIMEGAP);
        _issueSetup();
        vm.prank(marketMaker);
        issuance.issue(randomDFTAmount);
        uint256 navAfterSecondMint = navTracker.getNAV();

        assertEq(initialNAV, navAfterFirstMint);
        assert(initialNAV > navAfterSecondMint);
    }

    //////////////////////
    ///// redeem() tests //
    //////////////////////
    function testRedeemRevertsWhenProtocolInvariantBroken() external {
        // Setup
        (uint256 marketMakerBal, , , ) = _redemptionSetup();

        vm.startPrank(marketMaker);
        dft.approve(address(issuance), marketMakerBal);
        vm.expectRevert(); // cannot derive the custom error param values before calling `Issuance::redeem()` hence not matching them.

        issuance.redeem((marketMakerBal * PRECISION) / 15e17); // trying to redeem less than what was withdrawn from the AUM making AUM > (supply * nav), thus breaking the invariant!
        vm.stopPrank();
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

    function testRedeemPostAssetRelease() external {
        // Setup
        (
            uint256 marketMakerBal,
            uint256 redeemReqProcessingFee,
            ,
            uint256 navBeforeRedemption
        ) = _redemptionSetup();

        // executing the redeem request
        vm.startPrank(marketMaker);
        dft.approve(address(issuance), marketMakerBal);
        issuance.redeem(marketMakerBal);
        vm.stopPrank();

        // assert
        assertEq(dft.balanceOf(marketMaker), 0);
        assert(
            dft.balanceOf(owner) >=
                (initialSupplyWithOwner + redeemReqProcessingFee)
        ); // management fee will also be sent to owner post redemption
        assert(navTracker.getNAV() < navBeforeRedemption); // NAV reduces post inflation in supply caused due to management fee
    }

    /////////////////////////////////
    /// confirmDeposit() tests ///
    ////////////////////////////////
    function testIfConfirmDepositRevertsWhenCalledByMMInsteadOfInvestMintServer()
        external
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                IIssuance.Issuance__UnAuthorizedSender.selector,
                marketMaker
            )
        );
        vm.prank(marketMaker);
        issuance.confirmDeposit(marketMaker);
    }

    function testConfirmDepositAddsMMToDepositVerifiedMapping() external {
        vm.prank(investMintServer);
        issuance.confirmDeposit(marketMaker);

        bool marketMakerDepositStatus = issuance.depositVerifiedFor(
            marketMaker
        );
        assertEq(marketMakerDepositStatus, true);
    }

    /////////////////////////////////
    /// confirmRedemption() tests ///
    ////////////////////////////////
    function testIfConfirmRedemptionRevertsWhenCalledByMMInsteadOfInvestMintServer()
        external
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                IIssuance.Issuance__UnAuthorizedSender.selector,
                marketMaker
            )
        );
        vm.prank(marketMaker);
        issuance.confirmRedemption(marketMaker);
    }

    function testConfirmRedemptionAddsMMToRedeemVerifiedMapping() external {
        vm.prank(investMintServer);
        issuance.confirmRedemption(marketMaker);

        bool marketMakerRedemptionStatus = issuance.redeemVerifiedFor(
            marketMaker
        );
        assertEq(marketMakerRedemptionStatus, true);
    }
}
