// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-contracts/blob/master/LICENSE.md

pragma solidity ^0.8.0;

import { TestParameters } from "./TestParameters.sol";
import { AssertionHelpers } from "./AssertionHelpers.sol";
import { RedemptionReceiver } from "../../src/RedemptionReceiver.sol";
import { InactiveSharesDistributor } from "../../src/InactiveSharesDistributor.sol";
import { FortaStakingVault } from "../../src/FortaStakingVault.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { FortaStakingUtils } from "@forta-staking/FortaStakingUtils.sol";
import { DELEGATOR_SCANNER_POOL_SUBJECT } from "@forta-staking/SubjectTypeValidator.sol";

abstract contract TestHelpers is AssertionHelpers, TestParameters {
    address public alice = makeAddr("Alice");
    address public bob = makeAddr("Bob");
    address public operator = makeAddr("Operator");
    address public operatorFeeTreasury = makeAddr("OperatorFeeTreasury");
    address public rewardsDistributor = makeAddr("RewardsDistributor");

    FortaStakingVault internal vault;

    modifier asPrankedUser(address user) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    function _forkPolygon() internal {
        vm.createSelectFork("polygon", 52_372_323);
    }

    function cloneVault() internal returns (FortaStakingVault) {
        FortaStakingVault vaultImplementation = new FortaStakingVault();
        return FortaStakingVault(Clones.clone(address(vaultImplementation)));
    }

    function _deployVault(uint256 operatorFee) internal {
        RedemptionReceiver receiverImplementation = new RedemptionReceiver();
        InactiveSharesDistributor distributorImplementation = new InactiveSharesDistributor();
        vault = cloneVault();
        vault.initialize(
            address(FORT_TOKEN),
            address(FORTA_STAKING),
            address(receiverImplementation),
            address(distributorImplementation),
            operatorFee,
            operatorFeeTreasury,
            rewardsDistributor
        );
        vault.grantRole(vault.OPERATOR_ROLE(), operator);
        vault.revokeRole(vault.OPERATOR_ROLE(), address(this));
    }

    function _deposit(address user, uint256 mint, uint256 deposit) internal asPrankedUser(user) returns (uint256) {
        deal(address(FORT_TOKEN), user, mint);
        FORT_TOKEN.approve(address(vault), deposit);
        return vault.deposit(deposit, user);
    }

    function freezeSubject(uint256 subject, uint256 value) internal {
        uint256 sharesId = FortaStakingUtils.subjectToActive(DELEGATOR_SCANNER_POOL_SUBJECT, subject);

        // record reads
        vm.record();
        FORTA_STAKING.openProposals(sharesId);

        // 0 is FORTA_STAKING
        // 1 is openProposals[sharesId]
        (bytes32[] memory reads,) = vm.accesses(address(FORTA_STAKING));

        vm.store(address(FORTA_STAKING), reads[1], bytes32(uint256(value)));
    }

    function freezeSubject(uint256 subject) internal {
        freezeSubject(subject, 1);
    }

    function unfreezeSubject(uint256 subject) internal {
        freezeSubject(subject, 0);
    }
}
