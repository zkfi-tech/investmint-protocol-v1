// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {IIssuance} from "../interfaces/IIssuance.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {InvestMintDFT} from "./InvestMintDFT.sol";
import {NavTracker} from "./NavTracker.sol";
import {console} from "forge-std/console.sol";

// TODO: Fee module
// TODO: Rebalancing event (request queuing)
contract Issuance is IIssuance {
    address public investMintServer;
    address public owner;
    InvestMintDFT public dft;
    NavTracker public navTracker;
    uint256 public requestProcessingFee;
    uint256 public constant PRECISION = 1e18;
    mapping(address => bool) public depositVerifiedFor;
    mapping(address => bool) public redeemVerifiedFor;

    modifier onlyInvestMintServer(address sender) {
        if (sender != investMintServer) {
            revert Issuance__UnAuthorizedSender(sender);
        }
        _;
    }

    modifier invariantCheck() {
        invariantChecker();
        _;
    }

    function invariantChecker() internal view {
        uint256 totalDFTSupply = dft.totalSupply();
        uint256 activeNAVPerDFT = navTracker.getNAV();
        uint256 valueOfCirculatingDFTs = (totalDFTSupply * activeNAVPerDFT) /
            PRECISION;
        console.log("Circulating value:", valueOfCirculatingDFTs);
        uint256 AUM = navTracker.getAUM();

        if (valueOfCirculatingDFTs > AUM) {
            revert Issuance__ProtocolInvariantBroken(
                valueOfCirculatingDFTs / PRECISION,
                AUM / PRECISION
            );
        }
    }

    constructor(
        address _investMintServer,
        InvestMintDFT _dft,
        NavTracker _navTracker,
        uint256 _requestProcessingFee,
        address _owner
    ) {
        investMintServer = _investMintServer;
        dft = _dft;
        navTracker = _navTracker;
        requestProcessingFee = _requestProcessingFee;
        owner = _owner; // protocol owner
    }

    function issue(uint256 amount) external invariantCheck {
        address marketMaker = msg.sender;
        if (!depositVerifiedFor[marketMaker]) {
            revert Issuance__NoAssetsDeposited();
        }

        if (amount <= 0) {
            revert Issuance__AmountCannotBeZero();
        }

        uint256 processingFeeInWei = calculateRequestProcessingFeeOn(amount);
        uint256 amountToBeMintedForMarketMaker = amount - processingFeeInWei;

        dft.mint(marketMaker, amountToBeMintedForMarketMaker);
        emit DFTIssued(marketMaker, amountToBeMintedForMarketMaker);
        dft.mint(owner, processingFeeInWei);
        emit FeeReceived(processingFeeInWei);

        invariantChecker(); // FREI-PI pattern (Function: Require-Effect-Interaction, Protocol:Invariant)

        // restoring the deposit status for marketMaker
        delete depositVerifiedFor[marketMaker];
        navTracker.calculateNAV(); // update Nav
    }

    function redeem(uint256 amount) external {
        address marketMaker = msg.sender;
        if (!redeemVerifiedFor[marketMaker]) {
            revert Issuance__UnderlyingAssetsNotRedeemed();
        }

        if (amount <= 0) {
            revert Issuance__AmountCannotBeZero();
        }

        uint256 processingFeeInWei = calculateRequestProcessingFeeOn(amount);
        uint256 amountToBeRedeemed = amount - processingFeeInWei;

        dft.transferFrom(marketMaker, owner, processingFeeInWei); /// @dev market maker should have approved the DFTs to be redeemed, to the Issuance contract, for this to not revert.
        emit FeeReceived(processingFeeInWei);

        dft.burn(marketMaker, amountToBeRedeemed);
        emit DFTRedeemed(marketMaker, amount);

        invariantChecker(); // FREI-PI pattern (Function: Require-Effect-Interaction, Protocol:Invariant

        navTracker.calculateNAV();
        // restoring the redeem status for marketMaker
        delete redeemVerifiedFor[marketMaker];
    }

    /// @dev The exacty quantity of tokens deposited will not be checked onchain as AUM would have changed by that time of checking and DFTs supply would remain the same, resulting in wrong checks. We will rely on our UI+BE to quote and send the right quantities of underlying tokens to the custodian. The deposit & redemption verification functions will just get the deposit status and if true, will mint DFTs.
    function confirmDeposit(
        address depositer
    ) external onlyInvestMintServer(msg.sender) {
        depositVerifiedFor[depositer] = true;
        emit DepositVerifierFor(depositer);
    }

    function confirmRedemption(
        address redeemer
    ) external onlyInvestMintServer(msg.sender) {
        redeemVerifiedFor[redeemer] = true;
        emit RedemptionVerifiedFor(redeemer);
    }

    /// @notice Calculates minting or redemption fee based on the no. of DFTs
    function calculateRequestProcessingFeeOn(
        uint256 amount
    ) public view returns (uint256) {
        uint256 processingFeeInWei = (amount * (requestProcessingFee / 100)) /
            PRECISION;
        return processingFeeInWei;
    }
}
