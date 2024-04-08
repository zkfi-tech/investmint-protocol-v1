// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;
import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface IIssuance {
    /// Errors
    error Issuance__NoTokensIssued();

    /// Events
    event DFTIssued(address, uint256);
    event DFTRedeemed(address, uint256);

    /// @notice Issue DFTs to market maker
    function issue(uint256 amount) external;

    /// @notice Redeem DFTs for underlying tokens to markert maker
    function redeem(uint256 amount) external;

    /// @notice Get underlying asset deposit confirmation from custodian
    function confirmDeposit(address depositer, IERC20[] memory tokens, uint256[] memory tokenAmounts) external;

    /// @notice Get underlying asset redemption confirmation from custodian
    function confirmRedemption(address redeemer, IERC20[] memory tokens, uint256[] memory tokenAmounts) external;
}