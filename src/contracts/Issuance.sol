// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {IIssuance} from "../interfaces/IIssuance.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {InvestMintDFT} from "./InvestMintDFT.sol";
import {NavTracker} from "./NavTracker.sol";
import {console} from "forge-std/console.sol";
import {SolmateMath} from "lib/solmate-math.sol";

// TODO: Fee module
// TODO: Rebalancing event (request queuing)
contract Issuance is IIssuance {
    using SolmateMath for int256;

    address public investMintServer;
    address public owner;
    InvestMintDFT public investMintDFT;
    NavTracker public navTracker;
    uint256 public requestProcessingFee;
    int256 public timestampOfLastInflation;
    
    uint256 public constant PRECISION = 1e18;
    int256 public constant MANAGEMENT_FEE = 0.01e18; // 1% = 0.01
    
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
        uint256 totalDFTSupply = investMintDFT.totalSupply();
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
        investMintDFT = _dft;
        navTracker = _navTracker;
        requestProcessingFee = _requestProcessingFee;
        owner = _owner; // protocol owner
        timestampOfLastInflation = int256(block.timestamp) - 60 minutes;
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

        investMintDFT.mint(marketMaker, amountToBeMintedForMarketMaker);
        emit DFTIssued(marketMaker, amountToBeMintedForMarketMaker);
        investMintDFT.mint(owner, processingFeeInWei);
        emit FeeReceived(processingFeeInWei);

        invariantChecker(); // FREI-PI pattern (Function: Require-Effect-Interaction, Protocol:Invariant)

        // restoring the deposit status for marketMaker
        delete depositVerifiedFor[marketMaker];
        _inflateNAV(); 
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

        investMintDFT.transferFrom(marketMaker, owner, processingFeeInWei); /// @dev market maker should have approved the DFTs to be redeemed, to the Issuance contract, for this to not revert.
        emit FeeReceived(processingFeeInWei);

        investMintDFT.burn(marketMaker, amountToBeRedeemed);
        emit DFTRedeemed(marketMaker, amount);

        invariantChecker(); // FREI-PI pattern (Function: Require-Effect-Interaction, Protocol:Invariant

        navTracker.calculateNAV();
        // restoring the redeem status for marketMaker
        delete redeemVerifiedFor[marketMaker];
        _inflateNAV();
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

    ////////////////////////////////
    ///// Internal Functions //////
    ///////////////////////////////

    /// @dev Charging management fee by inflating the DFT supply and therefore decreasing the NAV. Calls `NavTracker::calculateNAV()` to get latest NAV after inflation of supply.
    function _inflateNAV() internal {
        int256 dftSupply = int256(investMintDFT.totalSupply()); // 5.02e20
        int256 inflationMultiplier = _calculateInflationMultiplier(); // 1000001147299271560
        int256 inflatedSupply = (dftSupply * inflationMultiplier) / int256(PRECISION); 
        // mint extra dfts to match inflatedSupply
        int256 extraDFTs = inflatedSupply - dftSupply; // 5.759e14 = 0.0005759e18
        
        // mint extraDFTs and send them to fee receiver/owner
        investMintDFT.mint(owner, uint256(extraDFTs));
        navTracker.calculateNAV(); // 9999988527020447341 - 10000000000000000000 = 
    }

    
    /// @dev Calculates the inflation multiplier based on the below formula
    /*
    1/r^n=1-x
    => 1/(1-x) = r^n
    r = inflation multiplier to calculate new supply
    x = annual management fee %
    n=365*24*60/m ; where m = minutes passed since last mint or redemption
*/

    function _calculateInflationMultiplier() internal view returns (int256) {
        int256 managementFeeSubtractedFromOne = 1e18 - MANAGEMENT_FEE; // 1-x = 1 - 0.01 (scaled up to 1e18)

        int256 leftSide = (1e18 * int256(PRECISION)) /
            managementFeeSubtractedFromOne; // 1/(1-x)

        // calculating `n`
        // first calculate `m`: mins passed since last mint/redeem
        int256 minutesPassedSinceLastInflation = ((int256(block.timestamp) -
            timestampOfLastInflation) * int256(PRECISION)) / 60;
        
        // now `n` which is basically portioning the whole year into portions with each portion = `m`
        int256 portioningAYearByMinsPassed = (365 *
            24 *
            60 *
            int256(PRECISION)) / minutesPassedSinceLastInflation; // n

        // r = (1/(1-x))^1/n = leftSide^1/n
        int256 inflationMultiplier = SolmateMath.wadPow(
            leftSide,
            ((1 * int256(PRECISION)) / portioningAYearByMinsPassed)
        );

        return inflationMultiplier;
    } 
}
