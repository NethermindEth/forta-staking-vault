// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";

import {TestHelpers} from "./fixture/TestHelpers.sol";
import {FortaStakingUtils} from "./fixture/FortaStakingUtils.sol";
import {IFortaStaking, DELEGATOR_SCANNER_POOL_SUBJECT} from "../src/interfaces/IFortaStaking.sol";

import "forge-std/console.sol";

contract FortaStakingVaultTest is TestHelpers {
    function setUp() public {
        _forkPolygon();
        _deployVault();
    }

    function test_delegate() external {
        _deposit(user1, 100, 100);

        uint256 subject = 55;

        vm.prank(operator);
        vault.delegate(subject, 100);

        assertEq(vault.getStakes(subject), 100, "Mismatching depositor amount in vault");
        assertEq(vault.getSubjectByIndex(0), subject, "Depositor not listed in vault");

        uint256 sharesInStaking =
            IFortaStaking(FORTA_STAKING_ADDRESS).sharesOf(DELEGATOR_SCANNER_POOL_SUBJECT, subject, address(vault));
        assertEq(vault.getStakes(subject), sharesInStaking, "Mismatching stake");

        uint256 sharesId = FortaStakingUtils.subjectToActive(DELEGATOR_SCANNER_POOL_SUBJECT, subject);
        uint256 balanceERC1155 = IERC1155(FORTA_STAKING_ADDRESS).balanceOf(address(vault), sharesId);
        assertEq(balanceERC1155, 100, "Mismatching balance of NFT shares");
    }

    function test_totalAssets_afterDelegate() external {
        _deposit(user1, 100, 100);

        uint256 subject = 55;

        vm.prank(operator);
        vault.delegate(subject, 100);

        uint256 totalAssets = vault.totalAssets();

        assertEq(totalAssets, 100, "Mismatching totalAssets after delegate");
    }


}
