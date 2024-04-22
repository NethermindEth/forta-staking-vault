// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-contracts/blob/master/LICENSE.md

pragma solidity 0.8.23;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20, IERC20Errors} from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from "@openzeppelin-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {FortaStakingUtils} from "@forta-staking/FortaStakingUtils.sol";
import {DELEGATOR_SCANNER_POOL_SUBJECT} from "@forta-staking/SubjectTypeValidator.sol";
import {RedemptionReceiver, InactiveSharesDistributor, TestHelpers} from "./fixture/TestHelpers.sol";
import {IFortaStaking} from "../src/interfaces/IFortaStaking.sol";
import {FortaStakingVault} from "../src/FortaStakingVault.sol";
import {IRewardsDistributor} from "../src/interfaces/IRewardsDistributor.sol";
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

        assertEq(vault.subjects(0), subject, "Depositor not listed in vault");

        uint256 sharesInStaking = FORTA_STAKING.sharesOf(
            DELEGATOR_SCANNER_POOL_SUBJECT,
            subject,
            address(vault)
        );
        assertEq(sharesInStaking, 100, "Mismatching stake");

        uint256 sharesId = FortaStakingUtils.subjectToActive(
            DELEGATOR_SCANNER_POOL_SUBJECT,
            subject
        );
        uint256 balanceERC1155 = FORTA_STAKING.balanceOf(
            address(vault),
            sharesId
        );
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
        assertEq(
            FORT_TOKEN.balanceOf(alice),
            2,
            "Unexpected balance after redeem"
        );
        address redemptionReceiver = vault.getRedemptionReceiver(alice);
        // should get 20% of 60 which is the amount of shares in subject subject1
        assertEq(
            FORTA_STAKING.inactiveSharesOf(
                DELEGATOR_SCANNER_POOL_SUBJECT,
                subject1,
                redemptionReceiver
            ),
            12,
            "Unexpected shares in subject subject1"
        );
        // should get 20% of 30 which is the amount of shares in subject subject1
        assertEq(
            FORTA_STAKING.inactiveSharesOf(
                DELEGATOR_SCANNER_POOL_SUBJECT,
                subject2,
                redemptionReceiver
            ),
            6,
            "Unexpected shares in subject subject2"
        );

        // let time pass to claim the assets
        vm.warp(block.timestamp + 10 days + 1);

        vault.claimRedeem(bob);
        assertEq(
            FORT_TOKEN.balanceOf(bob),
            18,
            "Unexpected balance after claim redeem"
        );
        assertEq(
            FORTA_STAKING.inactiveSharesOf(
                DELEGATOR_SCANNER_POOL_SUBJECT,
                subject1,
                redemptionReceiver
            ),
            0,
            "Unexpected shares in subject subject1 after claim"
        );
        assertEq(
            FORTA_STAKING.inactiveSharesOf(
                DELEGATOR_SCANNER_POOL_SUBJECT,
                subject2,
                redemptionReceiver
            ),
            0,
            "Unexpected shares in subject subject2 after claim"
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

        assertEq(
            vault.feeInBasisPoints(),
            uint256(5000),
            "New operator fee basis points mismatch"
        );
        assertEq(
            vault.feeTreasury(),
            newTreasury,
            "New operator fee treasure mismatch"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                operator,
                vault.DEFAULT_ADMIN_ROLE()
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
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                operator,
                vault.DEFAULT_ADMIN_ROLE()
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
        assertEq(
            FORT_TOKEN.balanceOf(alice),
            1,
            "Unexpected balance after redeem"
        );
        assertEq(
            FORT_TOKEN.balanceOf(operatorFeeTreasury),
            1,
            "Unexpected fee balance after redeem"
        );

        // let time pass to claim the assets
        vm.warp(block.timestamp + 10 days + 1);

        vault.claimRedeem(bob);
        assertEq(
            FORT_TOKEN.balanceOf(bob),
            9,
            "Unexpected balance after claim redeem"
        );
        assertEq(
            FORT_TOKEN.balanceOf(operatorFeeTreasury),
            10,
            "Unexpected fee balance after claim redeem"
        );
        // 9 + 1(from earlier redeem)

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
        // active from subject1 one 50 * 50 / 300 = |_ 8.3333... _|
        // active from subject2 one 50 * 200 / 300 = |_ 33.333... _|
        assertEq(
            FORT_TOKEN.balanceOf(alice),
            41_666_666_666_666_666_666,
            "Unexpected alice balance after first redemption claim"
        );
        // inactive shares pending because it hasn't been claimed
        // alice decides to claim the undelegation so she can get her part
        vault.undelegate(subject1);

        // inactive 50 - |_ 50 * 50 / 300 _| = 41.666...7
        assertEq(
            FORT_TOKEN.balanceOf(address(vault)),
            41_666_666_666_666_666_667,
            "Unexpected vault balance after first undelegation"
        );
        // alice balance should remains the same until claiming again
        assertEq(
            FORT_TOKEN.balanceOf(alice),
            41_666_666_666_666_666_666,
            "Unexpected alice balance after first undelegation"
        );
        // claim again
        vault.claimRedeem(alice);
        // Almost her 50 ehter, 1 unit missing due to rounding
        assertEq(
            FORT_TOKEN.balanceOf(alice),
            49_999_999_999_999_999_999,
            "Unexpected balance after second redemption claim"
        );
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
        // claim bob assets
        vault.claimRedeem(bob);
        vm.stopPrank();

        vm.prank(alice);
        vault.claimRedeem(alice);

        // almost 100 ether (affected by some roundings)
        assertEq(
            FORT_TOKEN.balanceOf(alice),
            99_999_999_999_999_999_995,
            "Unexpected final amount for alice"
        );
        // almost 200 ether (benefited by some roundings)
        assertEq(
            FORT_TOKEN.balanceOf(bob),
            200_000_000_000_000_000_005,
            "Unexpected final amount for bob"
        );
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
                IRewardsDistributor(rewardsDistributor).claimRewards,
                (DELEGATOR_SCANNER_POOL_SUBJECT, subject, epochs)
            ),
            abi.encode("")
        );

        vm.expectCall(
            address(rewardsDistributor),
            abi.encodeCall(
                IRewardsDistributor(rewardsDistributor).claimRewards,
                (DELEGATOR_SCANNER_POOL_SUBJECT, subject, epochs)
            )
        );
        vault.claimRewards(subject, epoch);
    }

    function test_failOnEmptyDelegations() external {
        _deposit(alice, 100, 100);

        vm.prank(operator);
        vm.expectRevert(FortaStakingVault.EmptyDelegation.selector);
        vault.delegate(10, 0);
    }

    function test_failIfIncorrectInitializationParams() external {
        vault = cloneVault();
        vm.expectRevert(FortaStakingVault.InvalidFee.selector);
        vault.initialize(
            address(FORT_TOKEN),
            address(FORTA_STAKING),
            address(0x1),
            address(0x2),
            2_000_000, // too high
            address(0x3),
            address(0x4)
        );
        vm.expectRevert(FortaStakingVault.InvalidTreasury.selector);
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
        vm.prank(alice);
        vault.redeem(100, alice, alice);
        assertEq(FORT_TOKEN.balanceOf(alice), 200, "Donations not distributed");

        vm.revertTo(snapshot);
        // try to delegate donation
        vm.prank(operator);
        vault.delegate(55, 200);
    }

    function test_totalAssetsIsCorrectAfterEachOperation() external {
        _deposit(alice, 100 ether, 100 ether);
        assertEq(
            vault.totalAssets(),
            100 ether,
            "Deposit updated totalAssets incorrectly"
        );

        vm.prank(operator);
        vault.delegate(55, 20 ether);
        assertEq(
            vault.totalAssets(),
            100 ether,
            "Delegate affected totalAssets"
        );

        vm.startPrank(alice);
        vault.redeem(10 ether, alice, alice);
        assertEq(
            vault.totalAssets(),
            90 ether,
            "Reedem decreased totalAssets incorrectly 1"
        );

        vm.warp(block.timestamp + 10 days + 1);
        vault.claimRedeem(alice);
        assertEq(
            vault.totalAssets(),
            90 ether,
            "ClaimRedeem affected totalAssets 1"
        );
        vm.stopPrank();

        vm.prank(operator);
        vault.initiateUndelegate(55, 18 ether);
        assertEq(
            vault.totalAssets(),
            90 ether,
            "InitiateUndelegate affected totalAssets"
        );

        vm.prank(alice);
        vault.redeem(10 ether, alice, alice);
        assertEq(
            vault.totalAssets(),
            80 ether,
            "Reedem decreased totalAssets incorrectly 2"
        );

        vm.warp(block.timestamp + 10 days + 1);
        vm.prank(operator);
        vault.undelegate(55);
        assertEq(
            vault.totalAssets(),
            80 ether,
            "Undelegate affected totalAssets"
        );

        vm.startPrank(alice);
        vault.claimRedeem(alice);
        assertEq(
            vault.totalAssets(),
            80 ether,
            "ClaimRedeem affected totalAssets 2"
        );

        vault.redeem(10 ether, alice, alice);
        assertEq(
            vault.totalAssets(),
            70 ether,
            "Reedem decreased totalAssets incorrectly 3"
        );
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

    function test_updatePoolAssets() external {
        _deposit(alice, 100 ether, 100 ether);
        _deposit(bob, 200 ether, 200 ether);

        uint256 subject1 = 55;
        uint256 subject2 = 56;

        vm.startPrank(operator);
        vault.delegate(subject1, 100 ether);
        vault.delegate(subject2, 200 ether);

        vault.initiateUndelegate(subject1, 50 ether);

        // After completing the steps above, (_subjectDeadline[subject] != 0) == true
        _deposit(alice, 100, 100);
    }

    function test_supportsInterface() public {
        assertTrue(vault.supportsInterface(type(IERC1155Receiver).interfaceId));

        assertTrue(vault.supportsInterface(type(IAccessControl).interfaceId));

        bytes4 invalidInterfaceId = 0x12345678;
        assertFalse(vault.supportsInterface(invalidInterfaceId));
    }

    function test_failInvalidUndelegation() external {
        _deposit(alice, 100 ether, 100 ether);

        vm.expectRevert(FortaStakingVault.InvalidUndelegation.selector);
        vault.undelegate(100);
    }

    function test_redeem_callerNotOwner() external {
        _deposit(alice, 100, 100);

        uint256 subject1 = 55;
        uint256 subject2 = 56;

        vm.startPrank(operator);
        vault.delegate(subject1, 60);
        vault.delegate(subject2, 30);
        vm.stopPrank();

        vm.startPrank(alice);
        vault.approve(bob, 20);
        vm.stopPrank();

        vm.startPrank(bob);
        vault.redeem(20, alice, alice); // 20% of shares
        // should get 20% of 10 which is the balance in the vault
        assertEq(
            FORT_TOKEN.balanceOf(alice),
            2,
            "Unexpected balance after redeem"
        );
        address redemptionReceiver = vault.getRedemptionReceiver(alice);
        // should get 20% of 60 which is the amount of shares in subject subject1
        assertEq(
            FORTA_STAKING.inactiveSharesOf(
                DELEGATOR_SCANNER_POOL_SUBJECT,
                subject1,
                redemptionReceiver
            ),
            12,
            "Unexpected shares in subject subject1"
        );
        // should get 20% of 30 which is the amount of shares in subject subject1
        assertEq(
            FORTA_STAKING.inactiveSharesOf(
                DELEGATOR_SCANNER_POOL_SUBJECT,
                subject2,
                redemptionReceiver
            ),
            6,
            "Unexpected shares in subject subject2"
        );
        vm.stopPrank();
    }

    function test_redeem_failCallerNotOwner() external {
        _deposit(alice, 100, 100);

        uint256 subject1 = 55;
        uint256 subject2 = 56;
        uint256 shares = 20;

        vm.startPrank(operator);
        vault.delegate(subject1, 60);
        vault.delegate(subject2, 30);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                bob,
                0,
                shares
            )
        );
        vault.redeem(shares, alice, alice);
    }

    function test_redeem_failMaxShares() external {
        _deposit(alice, 100, 100);

        uint256 subject1 = 55;
        uint256 subject2 = 56;
        uint256 shares = 101;
        uint256 maxShares = 100;

        vm.startPrank(operator);
        vault.delegate(subject1, 60);
        vault.delegate(subject2, 30);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC4626Upgradeable.ERC4626ExceededMaxRedeem.selector,
                alice,
                shares,
                maxShares
            )
        );
        vault.redeem(shares, alice, alice);
    }

    function test_mint() external asPrankedUser(alice) {
        address user = alice;
        uint256 mint = 100;

        deal(address(FORT_TOKEN), user, mint);
        FORT_TOKEN.approve(address(vault), mint);
        vault.mint(mint, user);
        assertEq(vault.balanceOf(user), mint);
    }

    function test_withdraw() external {
        _deposit(alice, 100, 100);

        uint256 subject1 = 55;
        uint256 subject2 = 56;

        vm.startPrank(operator);
        vault.delegate(subject1, 60);
        vault.delegate(subject2, 30);
        vm.stopPrank();

        vm.startPrank(alice);
        vault.withdraw(20, alice, alice); // 20% of shares
        // should get 20% of 10 which is the balance in the vault
        assertEq(
            FORT_TOKEN.balanceOf(alice),
            2,
            "Unexpected balance after redeem"
        );
        address redemptionReceiver = vault.getRedemptionReceiver(alice);
        // should get 20% of 60 which is the amount of shares in subject subject1
        assertEq(
            FORTA_STAKING.inactiveSharesOf(
                DELEGATOR_SCANNER_POOL_SUBJECT,
                subject1,
                redemptionReceiver
            ),
            12,
            "Unexpected shares in subject subject1"
        );
        // should get 20% of 30 which is the amount of shares in subject subject1
        assertEq(
            FORTA_STAKING.inactiveSharesOf(
                DELEGATOR_SCANNER_POOL_SUBJECT,
                subject2,
                redemptionReceiver
            ),
            6,
            "Unexpected shares in subject subject2"
        );
        vm.stopPrank();
    }

    function test_getExpectedAssets() external {
        _deposit(alice, 100 ether, 100 ether);
        _deposit(bob, 200 ether, 200 ether);

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
        vault.claimRedeem(alice);
        vault.undelegate(subject1);

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

        vm.startPrank(alice);
        // do 2 different redeems, they should aggregate correctly
        vault.redeem(25 ether, alice, alice);

        RedemptionReceiver redemptionReceiver = RedemptionReceiver(
            vault.getRedemptionReceiver(alice)
        );

        assertEq(
            redemptionReceiver.getExpectedAssets(),
            vault.getExpectedAssets(alice)
        );

        vm.stopPrank();
    }
}
