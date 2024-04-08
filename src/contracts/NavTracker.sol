// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {INavTracker} from "../interfaces/INavTracker.sol";

contract NavTracker is INavTracker {
    
    function tvlListener(uint256 latestTvl) external {}
    
    function calculateNAV() external returns(uint256) {}

    function getNav() external view returns(uint256) {}

    function getTvl() external view returns(uint256) {}
}