// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { TestHelpers } from "./fixture/TestHelpers.sol";
import { FortaStakingUtils } from "../src/utils/FortaStakingUtils.sol";
import { IFortaStaking, DELEGATOR_SCANNER_POOL_SUBJECT } from "../src/interfaces/IFortaStaking.sol";
import "forge-std/console.sol";
import { FortaStakingVault } from "../src/FortaStakingVault.sol";

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

        vm.expectRevert(FortaStakingVault.InvalidFee.selector);
        vault.updateFeeBasisPoints(10_000);

        vm.expectRevert(FortaStakingVault.InvalidTreasury.selector);
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
        // should get 20% of 10 which is the balance in the vault
        assertEq(FORT_TOKEN.balanceOf(alice), 1, "Unexpected balance after redeem");
        assertEq(FORT_TOKEN.balanceOf(operatorFeeTreasury), 1, "Unexpected fee balance after redeem");

        // let time pass to claim the assets
        vm.warp(block.timestamp + 10 days + 1);

        vault.claimRedeem(bob);
        assertEq(FORT_TOKEN.balanceOf(bob), 9, "Unexpected balance after claim redeem");
        assertEq(FORT_TOKEN.balanceOf(operatorFeeTreasury), 10, "Unexpected fee balance after claim redeem");
        // 9 + 1(from earlier redeem)

        vm.stopPrank();
    }

    function test_inactiveSharesDistribution() external {
        _deposit(alice, 100 ether, 100 ether);
        _deposit(bob, 200 ether, 200 ether);

        console.log(FORT_TOKEN.balanceOf(address(vault)), FORT_TOKEN.totalSupply());


        uint256 subject1 = 55;
        uint256 subject2 = 56;

        vm.startPrank(operator);
        vault.delegate(subject1, 100 ether);
        vault.delegate(subject2, 200 ether);

        vault.initiateUndelegate(subject1, 50 ether);

        // No 2 undelegations on the same pool are allowed
        vm.expectRevert(FortaStakingVault.PendingUndelegation.selector);
        vault.initiateUndelegate(subject1, 50 ether);
        vm.stopPrank();

        // 1st alice withdraw
        vm.startPrank(alice);
        vault.redeem(50 ether, alice, alice);

        // let deadline pass
        vm.warp(block.timestamp + 10 days + 1);
        // claim
        vault.claimRedeem(alice);
        // assets received
        // active from subject1 one 50 * 50 / 100 = |_ 8.3333... _|
        // active from subject2 one 50 * 200 / 100 = |_ 33.333... _|
        assertEq(FORT_TOKEN.balanceOf(alice), 41666666666666666666, "Unexpected alice balance after first redemption claim");
        // inactive shares pending because it hasn't been claimed
        // alice decides to claim the undelegation so she can get her part
        vault.undelegate(subject1);
        // inactive 50 - |_ 50 * 50 / 100 _| = 41.666...7 
        assertEq(FORT_TOKEN.balanceOf(address(vault)), 41666666666666666667, "Unexpected vault balance after first undelegation");
        // alice balance should remains the same until claiming again
        assertEq(FORT_TOKEN.balanceOf(alice), 41666666666666666666, "Unexpected alice balance after first undelegation");
        
        // claim again
        vault.claimRedeem(alice);
        // Almost her 50 ehter, 1 unit missing due to rounding
        assertEq(FORT_TOKEN.balanceOf(alice), 49999999999999999999, "Unexpected balance after second redemption claim");
        vm.stopPrank();

        // multiple users
        vm.startPrank(operator);
        // it can now be undelegated again
        vault.initiateUndelegate(subject1, 40 ether);

        // let some time pass so the undelegations have different deadline
        vm.warp(block.timestamp + 1 days);
        vault.initiateUndelegate(subject2, 100 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        // do 2 different redeems, they should aggregate correctly
        vault.redeem(25 ether, alice, alice);
        vault.redeem(25 ether, alice, alice);
        vm.stopPrank();

        // bob redeem one day later
        vm.warp(block.timestamp + 1 days);
        
        vm.startPrank(bob);
        vault.redeem(200 ether, bob, bob);

        // wait for all deadlines
        vm.warp(block.timestamp + 20 days);
        // undelegate subjects
        vault.undelegate(subject1);
        vault.undelegate(subject2);

        // // claim bob assets
        vault.claimRedeem(bob);
        // console.log(FORT_TOKEN.balanceOf(bob));
        assertEq(FORT_TOKEN.balanceOf(bob), 200000000000000000005, "Unexpected alice balance after first undelegation");
        vm.stopPrank();

        vm.startPrank(alice);
        vault.claimRedeem(alice);
        vault.claimRedeem(alice);
        vault.claimRedeem(alice);
        vm.stopPrank();
        // assertEq(FORT_TOKEN.balanceOf(alice), 100 ether, "Unexpected alice balance after first undelegation");
        console.log(vault.balanceOf(alice), FORT_TOKEN.balanceOf(alice), 0);
        console.log(vault.balanceOf(bob), FORT_TOKEN.balanceOf(bob), 0);
        console.log(FORT_TOKEN.balanceOf(address(vault)), FORT_TOKEN.totalSupply());

    }
}
