// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TestParameters } from "./TestParameters.sol";
import { AssertionHelpers } from "./AssertionHelpers.sol";
import { RedemptionReceiver } from "../../src/RedemptionReceiver.sol";
import { InactiveSharesDistributor } from "../../src/InactiveSharesDistributor.sol";
import { FortaStakingVault } from "../../src/FortaStakingVault.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

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

    function _deployVault(uint256 operatorFee) internal {
        FortaStakingVault vaultImplementation = new FortaStakingVault();
        RedemptionReceiver receiverImplementation = new RedemptionReceiver();
        InactiveSharesDistributor distributorImplementation = new InactiveSharesDistributor();
        vault = FortaStakingVault(Clones.clone(address(vaultImplementation)));
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
}
