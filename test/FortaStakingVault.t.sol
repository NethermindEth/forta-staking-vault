// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";

import { TestHelpers } from "./fixture/TestHelpers.sol";
import { FortaStakingUtils } from "../src/utils/FortaStakingUtils.sol";
import { IFortaStaking, DELEGATOR_SCANNER_POOL_SUBJECT } from "../src/interfaces/IFortaStaking.sol";

import "forge-std/console.sol";

contract FortaStakingVaultTest is TestHelpers {
    function setUp() public {
        _forkPolygon();
        _deployVault(0);
    }

    function test_delegate() external {
        _deposit(alice, 100, 100);

        uint256 subject = 55;

        vm.prank(operator);
        vault.delegate(subject, 100);

        assertEq(vault.assetsPerSubject(subject), 100, "Mismatching depositor amount in vault");
        assertEq(vault.subjects(0), subject, "Depositor not listed in vault");

        uint256 sharesInStaking = FORTA_STAKING.sharesOf(DELEGATOR_SCANNER_POOL_SUBJECT, subject, address(vault));
        assertEq(vault.assetsPerSubject(subject), sharesInStaking, "Mismatching stake");

        uint256 sharesId = FortaStakingUtils.subjectToActive(DELEGATOR_SCANNER_POOL_SUBJECT, subject);
        uint256 balanceERC1155 = FORTA_STAKING.balanceOf(address(vault), sharesId);
        assertEq(balanceERC1155, 100, "Mismatching balance of NFT shares");
    }

    function test_redeem() external {
        _deposit(alice, 100, 100);

        uint256 subject1 = 55;
        uint256 subject2 = 56;

        vm.startPrank(operator);
        vault.delegate(subject1, 60);
        vault.delegate(subject2, 30);
        vm.stopPrank();

        vm.startPrank(alice);
        vault.redeem(20, alice, alice); // 20% of shares
        // should get 20% of 10 which is the balance in the vault
        assertEq(FORT_TOKEN.balanceOf(alice), 2, "Unexpected balance after redeem");
        address redemptionReceiver = vault.getRedemptionReceiver(alice);
        // should get 20% of 60 which is the amount of shares in subject 55
        assertEq(
            FORTA_STAKING.inactiveSharesOf(DELEGATOR_SCANNER_POOL_SUBJECT, 55, redemptionReceiver),
            12,
            "Unexpected shares in subject 55"
        );
        // should get 20% of 30 which is the amount of shares in subject 55
        assertEq(
            FORTA_STAKING.inactiveSharesOf(DELEGATOR_SCANNER_POOL_SUBJECT, 56, redemptionReceiver),
            6,
            "Unexpected shares in subject 56"
        );

        // let time pass to claim the assets
        vm.warp(block.timestamp + 10 days + 1);

        vault.claimRedeem(bob);
        assertEq(FORT_TOKEN.balanceOf(bob), 18, "Unexpected balance after claim redeem");
        assertEq(
            FORTA_STAKING.inactiveSharesOf(DELEGATOR_SCANNER_POOL_SUBJECT, 55, redemptionReceiver),
            0,
            "Unexpected shares in subject 55 after claim"
        );
        assertEq(
            FORTA_STAKING.inactiveSharesOf(DELEGATOR_SCANNER_POOL_SUBJECT, 56, redemptionReceiver),
            0,
            "Unexpected shares in subject 56 after claim"
        );
        vm.stopPrank();
    }

    function test_multipleRedemptions() external {
        _deposit(alice, 100, 100);

        uint256 subject1 = 55;
        uint256 subject2 = 56;

        vm.prank(operator);
        vault.delegate(subject1, 60);

        vm.startPrank(alice);
        vault.redeem(100, alice, alice); // all shares
        // let time pass to claim the assets
        vm.warp(block.timestamp + 10 days + 1);
        vault.claimRedeem(alice);

        // deposit again in a different pool
        FORT_TOKEN.approve(address(vault), 100);
        vault.deposit(100, alice);
        vm.stopPrank();

        vm.prank(operator);
        vault.delegate(subject2, 20);

        vm.startPrank(alice);
        vault.redeem(100, alice, alice); // all shares
        // let time pass to claim the assets
        vm.warp(block.timestamp + 10 days + 1);
        vault.claimRedeem(alice);
        vm.stopPrank();

        assertEq(FORT_TOKEN.balanceOf(alice), 100, "Unexpected final balance");
    }

    function test_updateFeeBasisPoints() external {
        vault.updateFeeBasisPoints(5_000);

        address newTreasury = makeAddr("new-treasury");
        vault.updateFeeTreasury(newTreasury);

        assertEq(vault.feeInBasisPoints(), uint256(5_000), "New operator fee basis points mismatch");
        assertEq(vault.feeTreasury(), newTreasury, "New operator fee treasure mismatch");

        vm.expectRevert();
        vm.prank(operator);
        vault.updateFeeBasisPoints(5_000);

        vm.expectRevert();
        vm.prank(operator);
        vault.updateFeeTreasury(newTreasury);

    }

    function test_redeemWithFee() external {
        _deployVault(500);
        _deposit(alice, 100, 100);

        vm.startPrank(alice);
        vault.redeem(100, alice, alice);

        // should get 95% of and treasury 5%
        assertEq(FORT_TOKEN.balanceOf(alice), 95, "Unexpected user balance after redeem with fee");
        assertEq(FORT_TOKEN.balanceOf(address(this)), 5, "Unexpected treasury balance after redeem with fee");

    }

}
