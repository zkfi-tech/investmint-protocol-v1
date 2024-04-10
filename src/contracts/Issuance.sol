// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {IIssuance} from "../interfaces/IIssuance.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {InvestMintDFT} from "./InvestMintDFT.sol";
import {NavTracker} from "./NavTracker.sol";

    // TODO: Fee module
    // TODO: Rebalancing event (request queuing)
contract Issuance is IIssuance {
    address public investMintServer;
    InvestMintDFT public dft;
    NavTracker public navTracker;
    uint256 public constant PRECISION = 1e18;
    mapping(address => bool) public depositVerifiedFor;
    mapping(address => bool) public redeemVerifiedFor;

    modifier onlyInvestMintServer(address sender) {
        if(sender != investMintServer) {
            revert Issuance__UnAuthorizedSender(sender);
        }
        _;
    }

    modifier invariantCheck() {
        uint256 totalDFTSupply = dft.totalSupply();
        uint256 activeNAVPerDFT = navTracker.getNAV();
        uint256 valueOfCirculatingDFTs = totalDFTSupply * activeNAVPerDFT;
        uint256 AUM = navTracker.getAUM();
        
        if(valueOfCirculatingDFTs > AUM) {
            revert Issuance__ProtocolInvariantBroken(valueOfCirculatingDFTs/PRECISION, AUM/PRECISION);
        }
        _;
    }

    constructor(address _investMintServer, InvestMintDFT _dft, NavTracker _navTracker) {
        investMintServer = _investMintServer;
        dft = _dft;
        navTracker = _navTracker;

        dft.setIssuer(address(this));
    }

    function issue(uint256 amount) external invariantCheck() {
        if(!depositVerifiedFor[msg.sender]) {
            revert Issuance__NoAssetsDeposited();
        }

        dft.mint(msg.sender, amount);
        emit DFTIssued(msg.sender, amount);

        navTracker.calculateNAV();

        // restoring the deposit status for msg.sender
        delete depositVerifiedFor[msg.sender];
        
        invariantCheck(); // FREI-PI pattern (Function: Require-Effect-Interaction, Protocol:Invariant)
    }

    function redeem(uint256 amount) external invariantCheck() {
         if(!redeemVerifiedFor[msg.sender]) {
            revert Issuance__UnderlyingAssetsNotRedeemed();
        }

        dft.burn(msg.sender, amount);
        emit DFTRedeemed(msg.sender, amount);

        navTracker.calculateNAV();
        // restoring the redeem status for msg.sender
        delete redeemVerifiedFor[msg.sender];
        
        invariantCheck(); // FREI-PI pattern (Function: Require-Effect-Interaction, Protocol:Invariant
    }

    /// @dev The exacty quantity of tokens deposited will not be checked onchain as AUM would have changed by that time of checking and DFTs supply would remain the same, resulting in wrong checks. We will rely on our UI+BE to quote and send the right quantities of underlying tokens to the custodian. The deposit & redemption verification functions will just get the deposit status and if true, will mint DFTs.
    function confirmDeposit(address depositer) external onlyInvestMintServer(msg.sender) {
        depositVerifiedFor[depositer] = true;
        emit DepositVerifierFor(depositer);
    }
    
    function confirmRedemption(address redeemer) external onlyInvestMintServer(msg.sender){
        redeemVerifiedFor[redeemer] = true;
        emit RedemptionVerifiedFor(redeemer);
    }
}