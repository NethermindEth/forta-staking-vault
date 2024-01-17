// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestParameters} from "./TestParameters.sol";
import {AssertionHelpers} from "./AssertionHelpers.sol";
import {FortaStakingVault} from "../../src/FortaStakingVault.sol";
import {OperatorOperations} from "../../src/OperatorOperations.sol";

abstract contract TestHelpers is AssertionHelpers, TestParameters {
    address public user1 = address(11);
    address public user2 = address(12);

    address public operator = makeAddr("Operator");

    FortaStakingVault internal vault;

    modifier asPrankedUser(address user) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    function _forkPolygon() internal {
        vm.createSelectFork("polygon", 52372323);
    }

    function _deployVault() internal {
        vault = new FortaStakingVault(address(FORT_TOKEN), FORTA_STAKING_ADDRESS);
        vault.grantRole(vault.OPERATOR_ROLE(), operator);
    }

    function _deposit(address user, uint256 mint, uint256 deposit) internal asPrankedUser(user) {
        deal(address(FORT_TOKEN), user, mint);
        FORT_TOKEN.approve(address(vault), deposit);
        vault.deposit(deposit, user);
    }
}
