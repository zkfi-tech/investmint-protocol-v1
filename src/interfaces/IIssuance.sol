// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IIssuance {
    /// Errors
    error Issuance__NoAssetsDeposited();
    error Issuance__UnderlyingAssetsNotRedeemed();
    error Issuance__UnAuthorizedSender(address);
    error Issuance__ProtocolInvariantBroken(uint256 valueOfCirculatingDFTs, uint256 AUM);

    /// Events
    event DFTIssued(address, uint256);
    event DFTRedeemed(address, uint256);
    event DepositVerifierFor(address);
    event RedemptionVerifiedFor(address);

    /// @notice Issue DFTs to market maker
    function issue(uint256 amount) external;

    /// @notice Redeem DFTs for underlying tokens to markert maker
    function redeem(uint256 amount) external;

    /// @notice Get underlying asset deposit confirmation from custodian
    function confirmDeposit(
        address depositer
    ) external;

    /// @notice Get underlying asset redemption confirmation from custodian
    function confirmRedemption(
        address redeemer
    ) external;
}
