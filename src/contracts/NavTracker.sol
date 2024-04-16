// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {INavTracker} from "../interfaces/INavTracker.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {console} from "forge-std/console.sol";

contract NavTracker is INavTracker {
    
    // States //
    IERC20 public immutable investMintDFT;
    uint256 public assetsUnderManagement;
    uint256 public navPerDFT;
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
        address _investMintServer,
        uint256 _initialAUM,
        IERC20 _investMintDFT
    ) {
        navPerDFT = _initialNav; // 18 decimals
        investMintServer = _investMintServer;
        assetsUnderManagement = _initialAUM;
        investMintDFT = _investMintDFT;

        emit LatestNav(navPerDFT);
        emit AUMReceived(assetsUnderManagement, block.timestamp);
    }

    // External Functions //
    function aumListener(uint256 latestAUM) external only(investMintServer) {
        assetsUnderManagement = latestAUM; // with PRECISION
        emit AUMReceived(assetsUnderManagement, block.timestamp);
    }

    function calculateNAV() public returns (uint256) {
        uint256 circulatingDFTs = investMintDFT.totalSupply();

        if (circulatingDFTs > 0) {
            console.log('AUM when calc NAV:', assetsUnderManagement);
            navPerDFT = ((assetsUnderManagement * PRECISION) / circulatingDFTs);
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
