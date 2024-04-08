// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

interface INavTracker {
    // Errors //
    error NavTracker__NotAuthorized(address sender);

    // Events //
    event TVLReceived(uint256 tvl, uint256 timestamp);
    event LatestNav(uint256 nav);

    /// @notice will receive and store the latest total value locked from the custodian
    function tvlListener(uint256 latestTvl) external;

    /// @notice NAV Calculator
    /// @dev will maintain latest NAV using formula = TVL / No. of DFTs in circulation
    function calculateNAV() external returns(uint256);

    /// @notice returns the latest TVL
    function getTvl() external view returns(uint256);

    /// @notice returns the latest NAV
    function getNav() external view returns(uint256);

    function getPrecision() external pure returns(uint256);
}