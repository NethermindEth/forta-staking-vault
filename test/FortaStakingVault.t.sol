// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TestHelpers} from "./fixture/TestHelpers.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FortaStakingVaultTest is TestHelpers {
    function setUp() public {
        _forkPolygon();
        _deployVault();
    }

    function test_depositAndMint() external {

        _deposit(user1, 100, 98);

        uint256 sharesIssued = vault.balanceOf(user1);
        uint256 assetsRemained = FORTA_COIN.balanceOf(user1);

        assertEq(sharesIssued, 98, "deposited to vault");
        assertEq(assetsRemained, 2, "remained coins");
    }

    function test_delegate() external {
        _deposit(user1, 100, 100);

        uint256 subject = 55;

        vm.prank(operator);
        vault.delegate(subject, 100);

        assertEq(vault.stakes(subject), 100);
        assertEq(vault.subjects(0), subject);

    }

    function _deposit(address user, uint256 mint, uint256 deposit) asPrankedUser(user) private {
        deal(FORTA_ADDRESS, user, mint);
        FORTA_COIN.approve(address(vault), deposit);
        vault.deposit(deposit, user1);
    }

}
