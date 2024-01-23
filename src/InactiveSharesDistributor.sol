// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable, IERC20 } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IFortaStaking, DELEGATOR_SCANNER_POOL_SUBJECT } from "./interfaces/IFortaStaking.sol";

contract InactiveSharesDistributor is OwnableUpgradeable, ERC20Upgradeable, ERC1155Holder {
    using SafeERC20 for IERC20;

    IFortaStaking private _staking;
    bool private _claimed;
    uint64 private _deadline;
    IERC20 private _token;
    uint256 private _subject;
    uint256 private _shares;
    uint256 private _assetsReceived;

    function initialize(
        IFortaStaking stakingContract,
        IERC20 token,
        uint256 subject,
        uint256 shares
    )
        public
        initializer
    {
        __Ownable_init(msg.sender);
        __ERC20_init("Inactive Shares", "IS");

        _staking = stakingContract;
        _shares = shares;
        _subject = subject;
        _token = token;

        _mint(msg.sender, shares);
    }

    function initiateUndelegate() public returns (uint64) {
        _deadline = _staking.initiateWithdrawal(DELEGATOR_SCANNER_POOL_SUBJECT, _subject, _shares);
        return _deadline;
    }

    function undelegate() public {
        _staking.withdraw(DELEGATOR_SCANNER_POOL_SUBJECT, _subject);
        uint256 assetsReceived = _token.balanceOf(address(this));
        _assetsReceived = assetsReceived;
        _claimed = true;

        uint256 vaultShares = balanceOf(owner());
        uint256 nonVaultShares = _shares - vaultShares;
        uint256 vaultAssets = assetsReceived - Math.mulDiv(nonVaultShares, _assetsReceived, _shares);
        if (vaultAssets > 0) {
            _token.safeTransfer(owner(), vaultAssets);
        }
        if (vaultShares > 0) {
            _burn(owner(), vaultShares);
        }
    }

    function claim() public returns (bool) {
        if (!_claimed) return false;

        uint256 assetsToDeliver = Math.mulDiv(balanceOf(msg.sender), _assetsReceived, _shares);
        if (assetsToDeliver > 0) {
            _token.safeTransfer(msg.sender, assetsToDeliver);
        }
        _burn(msg.sender, balanceOf(msg.sender));
        return true;
    }
}