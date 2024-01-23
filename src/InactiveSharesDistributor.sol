// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IFortaStaking.sol";
import "forge-std/console.sol";

contract InactiveSharesDistributor is OwnableUpgradeable, ERC20Upgradeable, ERC1155Holder {
    IFortaStaking _staking;
    bool _claimed;
    uint64 _deadline;
    uint256 _subject;
    uint256 _shares;
    uint256 _assetsReceived;

    function initialize(IFortaStaking stakingContract, uint256 subject, uint256 shares) public initializer {
        __Ownable_init(msg.sender);
        __ERC20_init("Inactive Shares", "IS");

        _staking = stakingContract;
        _shares = shares;
        _subject = subject;

        _mint(msg.sender, shares);
    }

    function initiateUndelegate() public returns (uint64) {
        _deadline = _staking.initiateWithdrawal(DELEGATOR_SCANNER_POOL_SUBJECT, _subject, _shares);
        return _deadline;
    }

    function undelegate() public {
        _staking.withdraw(DELEGATOR_SCANNER_POOL_SUBJECT, _subject);
        uint256 assetsReceived = IERC20(_staking.stakedToken()).balanceOf(address(this));
        _assetsReceived = assetsReceived;
        _claimed = true;

        uint256 vaultShares = balanceOf(owner());
        uint256 nonVaultShares = totalSupply() - vaultShares;
        uint256 vaultAssets = assetsReceived - Math.mulDiv(nonVaultShares, _assetsReceived, _shares);
        if (vaultAssets > 0) {
            IERC20(_staking.stakedToken()).transfer(owner(), vaultAssets);
        }
        if (vaultShares > 0) {
            _burn(owner(), vaultShares);
        }
    }

    function claim() public returns (bool) {
        if (!_claimed) return false;

        uint256 assetsToDeliver = Math.mulDiv(balanceOf(msg.sender), _assetsReceived, _shares);
        if (assetsToDeliver > 0) {
            IERC20(_staking.stakedToken()).transfer(msg.sender, assetsToDeliver);
        }
        return true;
    }
}
