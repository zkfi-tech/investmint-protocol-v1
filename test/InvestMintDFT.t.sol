// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {InvestMintDFT} from "src/contracts/InvestMintDFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract InvestMintDFTTest is Test {
    address public owner = makeAddr("owner");
    address public randomAddr = makeAddr("random");
    InvestMintDFT dft;
    uint256 public randomDFTAmount = 10e18;

    function setUp() external {
        vm.prank(owner);
        dft = new InvestMintDFT("InvestMint", "IMDFT");
    }

    ////////////////////////
    ////// mint() tests ///
    ///////////////////////

    function testMintRevertsWhenNotCalledByOwner() external {
        vm.prank(randomAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
            Ownable.OwnableUnauthorizedAccount.selector, randomAddr));
        dft.mint(randomAddr, 25);
    }

    function testMintRevertsIfZeroAmountMintReq() external {
        vm.prank(owner);
        vm.expectRevert(InvestMintDFT.InvestMintDFT__ProvideNonZeroAmount.selector);
        dft.mint(randomAddr, 0);
    }

    function testMint() external {
        vm.prank(owner);
        dft.mint(randomAddr, randomDFTAmount);

        assertEq(dft.totalSupply(), randomDFTAmount);
        assertEq(dft.balanceOf(randomAddr), randomDFTAmount);
    }

     ////////////////////////
    ////// burn() tests ///
    ///////////////////////

    function testBurnRevertsWhenNotCalledByOwner() external {
        vm.prank(randomAddr);
        vm.expectRevert(
            abi.encodeWithSelector(
            Ownable.OwnableUnauthorizedAccount.selector, randomAddr));
        dft.burn(randomAddr, randomDFTAmount);
    }

    function testBurnRevertsIfZeroAmountBurnReq() external {
        vm.prank(owner);
        vm.expectRevert(InvestMintDFT.InvestMintDFT__ProvideNonZeroAmount.selector);
        dft.burn(randomAddr, 0);
    }

    function testBurn() external {
        vm.startPrank(owner);
        dft.mint(randomAddr, randomDFTAmount);
        dft.burn(randomAddr, randomDFTAmount);
        vm.stopPrank();

        assertEq(dft.totalSupply(), 0);
        assertEq(dft.balanceOf(randomAddr), 0);
    }
}