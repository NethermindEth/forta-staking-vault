// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-contracts/blob/master/LICENSE.md

pragma solidity 0.8.23;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { FortaStakingUtils } from "@forta-staking/FortaStakingUtils.sol";
import { DELEGATOR_SCANNER_POOL_SUBJECT } from "@forta-staking/SubjectTypeValidator.sol";
import { TestHelpers } from "./fixture/TestHelpers.sol";
import { IFortaStaking } from "../src/interfaces/IFortaStaking.sol";
import { IFortaStakingVault } from "../src/interfaces/IFortaStakingVault.sol";
import { IRewardsDistributor } from "../src/interfaces/IRewardsDistributor.sol";

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

        assertEq(vault.getSubjects()[0], subject, "Depositor not listed in vault");

        uint256 sharesInStaking = FORTA_STAKING.sharesOf(DELEGATOR_SCANNER_POOL_SUBJECT, subject, address(vault));
        assertEq(sharesInStaking, 100, "Mismatching stake");

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
        address redemptionReceiver = vault.getRedemptionReceiver(alice);
        // should get 20% of 10 which is the balance in the vault
        assertEq(FORT_TOKEN.balanceOf(redemptionReceiver), 2, "Unexpected balance after redeem");
        // should get 20% of 60 which is the amount of shares in subject subject1
        assertEq(
            FORTA_STAKING.inactiveSharesOf(DELEGATOR_SCANNER_POOL_SUBJECT, subject1, redemptionReceiver),
            12,
            "Unexpected shares in subject subject1"
        );
        // should get 20% of 30 which is the amount of shares in subject subject1
        assertEq(
            FORTA_STAKING.inactiveSharesOf(DELEGATOR_SCANNER_POOL_SUBJECT, subject2, redemptionReceiver),
            6,
            "Unexpected shares in subject subject2"
        );

        // let time pass to claim the assets
        vm.warp(block.timestamp + 10 days + 1);

        vault.claimRedeem(bob);
        assertEq(FORT_TOKEN.balanceOf(bob), 20, "Unexpected balance after claim redeem");
        assertEq(
            FORTA_STAKING.inactiveSharesOf(DELEGATOR_SCANNER_POOL_SUBJECT, subject1, redemptionReceiver),
            0,
            "Unexpected shares in subject subject1 after claim"
        );
        assertEq(
            FORTA_STAKING.inactiveSharesOf(DELEGATOR_SCANNER_POOL_SUBJECT, subject2, redemptionReceiver),
            0,
            "Unexpected shares in subject subject2 after claim"
        );
        assertEq(FORT_TOKEN.balanceOf(redemptionReceiver), 0, "Unexpected balance in receiver after claim redeem");
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

    function test_updateFeeSettings() external {
        vault.updateFeeBasisPoints(5000);

        address newTreasury = makeAddr("new-treasury");
        vault.updateFeeTreasury(newTreasury);

        assertEq(vault.feeInBasisPoints(), uint256(5000), "New operator fee basis points mismatch");
        assertEq(vault.feeTreasury(), newTreasury, "New operator fee treasure mismatch");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, operator, vault.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(operator);
        vault.updateFeeBasisPoints(5000);

        vm.expectRevert(IFortaStakingVault.InvalidFee.selector);
        vault.updateFeeBasisPoints(10_000);

        vm.expectRevert(IFortaStakingVault.InvalidTreasury.selector);
        vault.updateFeeTreasury(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, operator, vault.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(operator);
        vault.updateFeeTreasury(newTreasury);
    }

    function test_redeemWithFee() external {
        _deployVault(5000); // 50% fee
        _deposit(alice, 100, 100);

        uint256 subject1 = 55;
        uint256 subject2 = 56;

        vm.startPrank(operator);
        vault.delegate(subject1, 60);
        vault.delegate(subject2, 30);
        vm.stopPrank();

        vm.startPrank(alice);
        vault.redeem(20, alice, alice); // 20% of shares
        // should get 10% of 10 which is 20% of the balance in the vault minus 50% fee
        assertEq(FORT_TOKEN.balanceOf(vault.getRedemptionReceiver(alice)), 1, "Unexpected balance after redeem");
        assertEq(FORT_TOKEN.balanceOf(operatorFeeTreasury), 1, "Unexpected fee balance after redeem");

        // let time pass to claim the assets
        vm.warp(block.timestamp + 10 days + 1);

        vault.claimRedeem(bob);
        assertEq(FORT_TOKEN.balanceOf(bob), 10, "Unexpected balance after claim redeem");
        assertEq(FORT_TOKEN.balanceOf(operatorFeeTreasury), 10, "Unexpected fee balance after claim redeem");

        vm.stopPrank();
    }

    function test_inactiveSharesDistribution() external {
        _deposit(alice, 100 ether, 100 ether);
        _deposit(bob, 200 ether, 200 ether);

        uint256 subject1 = 55;
        uint256 subject2 = 56;

        vm.startPrank(operator);
        vault.delegate(subject1, 100 ether);
        vault.delegate(subject2, 200 ether);

        vault.initiateUndelegate(subject1, 50 ether);

        // No 2 undelegations on the same pool are allowed
        vm.expectRevert(IFortaStakingVault.PendingUndelegation.selector);
        vault.initiateUndelegate(subject1, 50 ether);
        vm.stopPrank();

        // 1st alice withdraw
        vm.startPrank(alice);
        vault.redeem(50 ether, alice, alice);

        // let deadline pass
        vm.warp(block.timestamp + 10 days);
        // claim
        vault.claimRedeem(alice);
        // assets received
        // active from subject1    50 * 50 / 300 = |_ 8.3333... _|
        // inactive from subject1  50 * 50 / 300 = |_ 8.3333... _|
        // active from subject2    50 * 200 / 300 = |_ 33.333... _|
        // Almost her 50 ether, 1 unit missing due to rounding
        assertEq(
            FORT_TOKEN.balanceOf(alice),
            49_999_999_999_999_999_999,
            "Unexpected alice balance after first redemption claim"
        );
        // alice claim triggered subject1 undelegation
        // inactive 50 - |_ 50 * 50 / 300 _| = 41.666...7
        assertEq(
            FORT_TOKEN.balanceOf(address(vault)),
            41_666_666_666_666_666_667,
            "Unexpected vault balance after first redemption claim"
        );

        // Try to claim again
        vm.expectRevert("Nothing to claim");
        vault.claimRedeem(alice);
        vm.stopPrank();

        // multiple users
        vm.startPrank(operator);
        // it can now be undelegated again
        vault.initiateUndelegate(subject1, 40 ether);
        // let some time pass so the undelegations have different deadline
        vm.warp(block.timestamp + 1 days);
        vault.initiateUndelegate(subject2, 100 ether);
        vm.stopPrank();

        vm.prank(alice);
        vault.redeem(50 ether, alice, alice);

        // bob redeem one day later
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(bob);
        vault.redeem(200 ether, bob, bob);

        // wait for all deadlines
        vm.warp(block.timestamp + 20 days);

        // claim bob assets
        vault.claimRedeem(bob);
        vm.stopPrank();

        vm.prank(alice);
        vault.claimRedeem(alice);

        // almost 100 ether (affected by some roundings)
        assertEq(FORT_TOKEN.balanceOf(alice), 99_999_999_999_999_999_998, "Unexpected final amount for alice");
        // almost 200 ether (benefited by some roundings)
        assertEq(FORT_TOKEN.balanceOf(bob), 200_000_000_000_000_000_002, "Unexpected final amount for bob");
    }

    function test_claimRewards() external {
        _deposit(alice, 100, 100);

        uint256 subject = 55;

        uint256 epoch = 808_080;
        uint256[] memory epochs = new uint256[](1);
        epochs[0] = epoch;

        vm.prank(operator);
        vault.delegate(subject, 100);

        vm.mockCall(
            address(rewardsDistributor),
            abi.encodeCall(
                IRewardsDistributor(rewardsDistributor).claimRewards, (DELEGATOR_SCANNER_POOL_SUBJECT, subject, epochs)
            ),
            abi.encode("")
        );

        vm.expectCall(
            address(rewardsDistributor),
            abi.encodeCall(
                IRewardsDistributor(rewardsDistributor).claimRewards, (DELEGATOR_SCANNER_POOL_SUBJECT, subject, epochs)
            )
        );
        vault.claimRewards(subject, epoch);
    }

    function test_failOnEmptyDelegations() external {
        _deposit(alice, 100, 100);

        vm.prank(operator);
        vm.expectRevert(IFortaStakingVault.EmptyDelegation.selector);
        vault.delegate(10, 0);
    }

    function test_failIfIncorrectInitializationParams() external {
        vault = cloneVault();
        vm.expectRevert(IFortaStakingVault.InvalidFee.selector);
        vault.initialize(
            address(FORT_TOKEN),
            address(FORTA_STAKING),
            address(0x1),
            address(0x2),
            2_000_000, // too high
            address(0x3),
            address(0x4)
        );
        vm.expectRevert(IFortaStakingVault.InvalidTreasury.selector);
        vault.initialize(
            address(FORT_TOKEN),
            address(FORTA_STAKING),
            address(0x1),
            address(0x2),
            0,
            address(0x0), // empty treasury
            address(0x4)
        );
    }

    function test_vaultAcceptDonations() external {
        _deposit(alice, 100, 100);

        deal(address(FORT_TOKEN), address(vault), 200);

        uint256 snapshot = vm.snapshot();

        // try to redeem donation
        vm.startPrank(alice);
        vault.redeem(100, alice, alice);
        vm.warp(block.timestamp + 10 days);
        vault.claimRedeem(alice);
        vm.stopPrank();
        assertEq(FORT_TOKEN.balanceOf(alice), 200, "Donations not distributed");

        vm.revertTo(snapshot);
        // try to delegate donation
        vm.prank(operator);
        vault.delegate(55, 200);
    }

    function test_totalAssetsIsCorrectAfterEachOperation() external {
        _deposit(alice, 100 ether, 100 ether);
        assertEq(vault.totalAssets(), 100 ether, "Deposit updated totalAssets incorrectly");

        vm.prank(operator);
        vault.delegate(55, 20 ether);
        assertEq(vault.totalAssets(), 100 ether, "Delegate affected totalAssets");

        vm.startPrank(alice);
        vault.redeem(10 ether, alice, alice);
        assertEq(vault.totalAssets(), 90 ether, "Reedem decreased totalAssets incorrectly 1");

        vm.warp(block.timestamp + 10 days + 1);
        vault.claimRedeem(alice);
        assertEq(vault.totalAssets(), 90 ether, "ClaimRedeem affected totalAssets 1");
        vm.stopPrank();

        vm.prank(operator);
        vault.initiateUndelegate(55, 18 ether);
        assertEq(vault.totalAssets(), 90 ether, "InitiateUndelegate affected totalAssets");

        vm.prank(alice);
        vault.redeem(10 ether, alice, alice);
        assertEq(vault.totalAssets(), 80 ether, "Reedem decreased totalAssets incorrectly 2");

        vm.warp(block.timestamp + 10 days + 1);
        vm.prank(operator);
        vault.undelegate(55);
        assertEq(vault.totalAssets(), 80 ether, "Undelegate affected totalAssets");

        vm.startPrank(alice);
        vault.claimRedeem(alice);
        assertEq(vault.totalAssets(), 80 ether, "ClaimRedeem affected totalAssets 2");

        vault.redeem(10 ether, alice, alice);
        assertEq(vault.totalAssets(), 70 ether, "Reedem decreased totalAssets incorrectly 3");
        vm.stopPrank();
    }

    function test_stall_undelegations() external {
        _deposit(alice, 100 ether, 100 ether);

        uint256 subject1 = 55;

        //delegate and initiate undelegate
        vm.startPrank(operator);
        vault.delegate(subject1, 50 ether);
        (, address distributor) = vault.initiateUndelegate(subject1, 50 ether);
        vm.stopPrank();

        // wait thawing period
        vm.warp(block.timestamp + 20 days);

        // send 1 FORT to bob and transfer it to the distributor
        vm.startPrank(bob);
        deal(address(FORT_TOKEN), bob, 1);
        FORT_TOKEN.transfer(distributor, 1);
        vm.stopPrank();

        // undelegate subjects
        vault.undelegate(subject1);
    }
}
