// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {InvestMintDFT} from "src/contracts/InvestMintDFT.sol";
import {Issuance} from "src/contracts/Issuance.sol";
import {NavTracker} from "src/contracts/NavTracker.sol";

contract DeployInvestMint is Script {
    address public investMintServer = makeAddr("investMintServer");
    /// @notice These values have to be updated based on the off-chain AUM deposted and the desired initial NAV.
    uint256 public initialAUM = 5000e18; // $5000
    uint256 public initialNAV = 10e18; // $10
    uint256 public requestProcessingFee = 1e16; // 0.01
    uint256 public initialSupply;
    uint256 public constant PRECISION = 1e18;
    address public owner = makeAddr("owner");
    uint256 deployer = vm.envUint("ANVIL_PRIVATE_KEY");

    function run() external returns (InvestMintDFT, Issuance, NavTracker) {
        vm.startBroadcast(deployer);
        InvestMintDFT dft = new InvestMintDFT("InvestMintDFT", "IMDFT");
        NavTracker navTracker = new NavTracker(
            initialNAV,
            investMintServer,
            initialAUM,
            dft
        );
        Issuance issuance = new Issuance(
            investMintServer,
            dft,
            navTracker,
            requestProcessingFee,
            owner
        );

        dft.transferOwnership(address(issuance));
        vm.stopBroadcast();

        // minting the initial supply based on initial AUM & NAV to the protocol owner
        initialSupply = (initialAUM * PRECISION) / initialNAV; // 500e18 DFTs
        vm.prank(address(issuance));
        dft.mint(owner, initialSupply);

        return (dft, issuance, navTracker);
    }
}
