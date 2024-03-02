// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable, IERC20 } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { ERC1155HolderUpgradeable } from
    "@openzeppelin-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IFortaStaking, DELEGATOR_SCANNER_POOL_SUBJECT } from "./interfaces/IFortaStaking.sol";

/**
 * @title Inactives shares distributor
 * @author Nethermind
 * @notice Simulates the behavior of a vault so the invalidShares in each of the pools can be distributed given that
 * they are not transferrable
 */
contract InactiveSharesDistributor is OwnableUpgradeable, ERC20Upgradeable, ERC1155HolderUpgradeable {
    using SafeERC20 for IERC20;

    IFortaStaking private _staking;
    bool private _claimable;
    uint64 private _deadline;
    IERC20 private _token;
    uint256 private _subject;
    uint256 private _totalShares;
    uint256 private _assetsReceived;

    constructor() {
        _disableInitializers();
    }

    /**
     * Initializes the contract
     * @param stakingContract FortaStaking contract address
     * @param token Forta token address
     * @param subject Subject from where inactive shares are going to be distributed
     * @param shares Shares to distribute
     */
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
        _totalShares = shares;
        _subject = subject;
        _token = token;

        _mint(msg.sender, shares);
    }

    /**
     * @notice Initiates the undelegation process
     * @dev Shares become inactive at this point
     * @return Deadline of the undelegation
     */
    function initiateUndelegate() public onlyOwner returns (uint64) {
        _deadline = _staking.initiateWithdrawal(DELEGATOR_SCANNER_POOL_SUBJECT, _subject, _totalShares);
        return _deadline;
    }

    /**
     * @notice Finish the undelegation process
     * @dev Shares are withdrawn from the pool and undelegated assets
     * entitled to vault are sent to the vault
     */
    function undelegate() public onlyOwner returns (uint256) {
        uint256 assetsReceived = _staking.withdraw(DELEGATOR_SCANNER_POOL_SUBJECT, _subject);
        _assetsReceived = assetsReceived;
        _claimable = true;

        uint256 vaultShares = balanceOf(owner());
        if (vaultShares > 0) {
            uint256 nonVaultShares = _totalShares - vaultShares;
            uint256 vaultAssets = assetsReceived - Math.mulDiv(nonVaultShares, assetsReceived, _totalShares);
            if (vaultAssets > 0) {
                _token.safeTransfer(owner(), vaultAssets);
            }
            _burn(owner(), vaultShares);
        }
        return assetsReceived;
    }

    /**
     * @notice Claim the assets associated to the
     * portion of the inactive shares owned by the caller
     * @dev Shares are burned in the process
     * @return Boolean indicating if the claim succeed (true) or not (false)
     */
    function claim() public returns (bool) {
        if (!_claimable) return false;

        uint256 shares = balanceOf(msg.sender);
        if (shares == 0) return false;

        uint256 assetsToDeliver = Math.mulDiv(shares, _assetsReceived, _totalShares);
        if (assetsToDeliver > 0) {
            _token.safeTransfer(msg.sender, assetsToDeliver);
        }
        _burn(msg.sender, balanceOf(msg.sender));
        return true;
    }
}
