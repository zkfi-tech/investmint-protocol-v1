// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {IIssuance} from "../interfaces/IIssuance.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Issuance is IIssuance {
    function issue(uint256 amount) external {}

    function redeem(uint256 amount) external {}

    function confirmDeposit(address depositer, IERC20[] memory tokens, uint256[] memory tokenAmounts) external {}
    
    function confirmRedemption(address redeemer, IERC20[] memory tokens, uint256[] memory tokenAmounts) external {}
}