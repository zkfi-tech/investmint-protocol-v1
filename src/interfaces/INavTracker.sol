// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

interface INavTracker {
    // Errors //
    error NavTracker__NotAuthorized(address sender);

    // Events //
    event AUMReceived(uint256 tvl, uint256 timestamp);
    event LatestNav(uint256 nav);

    /// @notice will receive and store the latest assets under management value from the custodian
    function aumListener(uint256 latestAUM) external;

    /// @notice NAV Calculator
    /// @dev will maintain latest NAV using formula = TVL / No. of DFTs in circulation
    function calculateNAV() external returns(uint256);

    /// @notice returns the latest AUM
    function getAUM() external view returns(uint256);

    /// @notice returns the latest AUM in human readable form
    function getAUMWithoutPrecision() external view returns (uint256);

    /// @notice returns the latest NAV
    function getNAV() external view returns(uint256);

     /// @notice returns the latest NAV in human readable form
    function getNAVWithoutPrecision() external view returns (uint256);

    function getPrecision() external pure returns(uint256);
}