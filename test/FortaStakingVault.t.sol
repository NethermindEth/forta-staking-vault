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

    function test_depositAndMint() external asPrankedUser(user1) {
        deal(FORTA_ADDRESS, user1, 100);
        FORTA_COIN.approve(address(vault), 98);

        vault.deposit(98, user1);

        uint256 balanceInVault = vault.balanceOf(user1);
        uint256 balanceInAssets = FORTA_COIN.balanceOf(user1);

        assertEq(balanceInVault, 98, "deposited to vault");
        assertEq(balanceInAssets, 2, "remained coins");
    }
}
