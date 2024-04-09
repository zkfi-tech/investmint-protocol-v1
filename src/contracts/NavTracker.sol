// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {INavTracker} from "../interfaces/INavTracker.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract NavTracker is INavTracker {
    // States //
    uint256 public assetsUnderManagement;
    uint256 public navPerDFT;
    IERC20 public immutable investMintDFT;

    address public issuance;
    address public investMintServer;

    uint256 public constant PRECISION = 1e18;

    // Modifiers / Constructors //
    modifier only(address who) {
        if (msg.sender != who) {
            revert NavTracker__NotAuthorized(msg.sender);
        }
        _;
    }

    constructor(
        uint256 _initialNav,
        address _issuance,
        address _investMintServer,
        uint256 _initialAUM,
        IERC20 _investMintDFT
    ) {
        navPerDFT = _initialNav; // 18 decimals
        issuance = _issuance;
        investMintServer = _investMintServer;
        assetsUnderManagement = _initialAUM;
        investMintDFT = _investMintDFT;

        emit LatestNav(navPerDFT);
        emit AUMReceived(assetsUnderManagement, block.timestamp);
    }

    // External Functions //
    function aumListener(uint256 latestAUM) external only(investMintServer) {
        assetsUnderManagement = latestAUM; // 18 decimals
        emit AUMReceived(assetsUnderManagement, block.timestamp);
        calculateNAV();
    }

    function calculateNAV() public returns (uint256) {
        uint256 circulatingDFTs = investMintDFT.totalSupply();

        if (circulatingDFTs > 0) {
            navPerDFT = (assetsUnderManagement / circulatingDFTs);
        }

        return navPerDFT;
    }

    // Getter Functions //
    function getNAV() external view returns (uint256) {
        return navPerDFT;
    }

    function getNAVWithoutPrecision() external view returns (uint256) {
        return (navPerDFT / PRECISION);
    }

    function getAUM() external view returns (uint256) {
        return assetsUnderManagement; // with PRECISION
    }

    function getAUMWithoutPrecision() external view returns (uint256) {
        return (assetsUnderManagement / PRECISION);
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }
}
