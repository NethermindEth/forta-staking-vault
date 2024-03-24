// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-contracts/blob/master/LICENSE.md

pragma solidity 0.8.23;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable, IERC20 } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { ERC1155HolderUpgradeable } from
    "@openzeppelin-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { DELEGATOR_SCANNER_POOL_SUBJECT } from "@forta-staking/SubjectTypeValidator.sol";
import { IFortaStaking } from "./interfaces/IFortaStaking.sol";
import { IFortaStakingVault } from "./interfaces/IFortaStakingVault.sol";
import { FortaStakingUtils } from "@forta-staking/FortaStakingUtils.sol";

/**
 * @title Inactive shares distributor
 * @author Nethermind
 * @notice Simulates the behavior of a vault so the inactive shares in each of the pools can be distributed given that
 * they are not transferable
 */
contract InactiveSharesDistributor is OwnableUpgradeable, ERC20Upgradeable, ERC1155HolderUpgradeable {
    using SafeERC20 for IERC20;

    IFortaStaking private _staking;
    bool private _claimable;
    uint64 public deadline;
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
        external
        initializer
    {
        __Ownable_init(_msgSender());
        __ERC20_init("Inactive Shares", "IS");

        _staking = stakingContract;
        _totalShares = shares;
        _subject = subject;
        _token = token;

        _mint(_msgSender(), shares);
    }

    /**
     * @notice Initiates the undelegation process
     * @dev Shares become inactive at this point
     * @return Deadline of the undelegation
     */
    function initiateUndelegate() external onlyOwner returns (uint64) {
        deadline = _staking.initiateWithdrawal(DELEGATOR_SCANNER_POOL_SUBJECT, _subject, _totalShares);
        return deadline;
    }

    /**
     * @notice Finish the undelegation process
     * @dev Shares are withdrawn from the pool and undelegated assets
     * entitled to vault are sent to the vault
     */
    function undelegate() external onlyOwner returns (uint256) {
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
    function claim() external returns (bool) {
        uint256 shares = balanceOf(_msgSender());
        if (shares == 0) return false;

        if (!_claimable) {
            try IFortaStakingVault(owner()).undelegate(_subject) { }
            catch {
                return false;
            }
        }

        uint256 assetsToDeliver = Math.mulDiv(shares, _assetsReceived, _totalShares);
        if (assetsToDeliver > 0) {
            _token.safeTransfer(_msgSender(), assetsToDeliver);
        }
        _burn(_msgSender(), shares);
        return true;
    }

    function getExpectedAssets(address user) external view returns (uint256) {
        uint256 inactiveSharesId = FortaStakingUtils.subjectToInactive(DELEGATOR_SCANNER_POOL_SUBJECT, _subject);

        uint256 inactiveShares = _staking.balanceOf(address(this), inactiveSharesId);
        uint256 stakeValue = _staking.inactiveSharesToStake(inactiveSharesId, inactiveShares);

        uint256 shares = balanceOf(user);
        return Math.mulDiv(shares, stakeValue, _totalShares);
    }
}
