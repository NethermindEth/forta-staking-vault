// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TestParameters } from "./TestParameters.sol";
import { AssertionHelpers } from "./AssertionHelpers.sol";
import { RedemptionReceiver } from "../../src/RedemptionReceiver.sol";
import { FortaStakingVault } from "../../src/FortaStakingVault.sol";

abstract contract TestHelpers is AssertionHelpers, TestParameters {
    address public alice = makeAddr("Alice");
    address public bob = makeAddr("Bob");
    address public operator = makeAddr("Operator");
    address public operatorFeeTreasury = makeAddr("OperatorFeeTreasury");

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
        RedemptionReceiver receiverImplementation = new RedemptionReceiver();
        vault = new FortaStakingVault(
            address(FORT_TOKEN),
            address(FORTA_STAKING),
            address(receiverImplementation),
            operatorFee,
            operatorFeeTreasury
        );
        vault.grantRole(vault.OPERATOR_ROLE(), operator);
    }

    function _deposit(address user, uint256 mint, uint256 deposit) internal asPrankedUser(user) returns (uint256) {
        deal(address(FORT_TOKEN), user, mint);
        FORT_TOKEN.approve(address(vault), deposit);
        return vault.deposit(deposit, user);
    }
}
