// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-contracts/blob/master/LICENSE.md

pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1155HolderUpgradeable } from
    "@openzeppelin-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { DELEGATOR_SCANNER_POOL_SUBJECT } from "@forta-staking/SubjectTypeValidator.sol";
import { OperatorFeeUtils } from "./utils/OperatorFeeUtils.sol";
import { IFortaStaking } from "./interfaces/IFortaStaking.sol";
import { InactiveSharesDistributor } from "./InactiveSharesDistributor.sol";
import { FortaStakingUtils } from "@forta-staking/FortaStakingUtils.sol";

/**
 * @title Redemption Receiver
 * @author Nethermind
 * @notice Personal contract for each Vault participant to receive redeemed assets
 * @dev Needed to separate delays associated to redemptions of different users
 */
contract RedemptionReceiver is OwnableUpgradeable, ERC1155HolderUpgradeable {
    using SafeERC20 for IERC20;

    uint256[] public subjects;
    address[] public distributors;
    uint256[] public frozenSubjects;
    address[] public frozenDistributors;
    uint256 public deadline;

    IFortaStaking private _staking;
    IERC20 private _token;

    constructor() {
        _disableInitializers();
    }

    /**
     * Initializes the contract
     * @param staking FortaStaking contract address
     * @param token FORT contract address
     */
    function initialize(IFortaStaking staking, IERC20 token) external initializer {
        __Ownable_init(_msgSender());
        _staking = staking;
        _token = token;
    }

    function redeem(
        uint256[] memory newUndelegations,
        uint256[] memory shares,
        address[] memory newDistributors,
        uint256 idleBalanceSent
    )
        external
        onlyOwner
    {
        require(deadline == 0, "Pending redemption unclaimed");

        uint256 deadline1 = addUndelegations(newUndelegations, shares);
        uint256 deadline2 = addDistributors(newDistributors);
        if (deadline1 < deadline2) {
            deadline1 = deadline2;
        }
        if (idleBalanceSent != 0) {
            uint256 deadline3 = block.timestamp + 10 days;
            if (deadline1 < deadline3) {
                deadline1 = deadline3;
            }
        }
        deadline = deadline1;
    }

    /**
     * @notice Register undelegations to initiate
     * @param newUndelegations List of subjects to undelegate from
     * @param shares list of shares to undelegate from each subject
     */
    function addUndelegations(uint256[] memory newUndelegations, uint256[] memory shares) internal returns (uint256) {
        uint256 length = newUndelegations.length;
        uint256 maxDeadline = block.timestamp;
        for (uint256 i = 0; i < length; ++i) {
            uint256 subject = newUndelegations[i];
            subjects.push(subject);
            uint256 poolDeadline = _staking.initiateWithdrawal(DELEGATOR_SCANNER_POOL_SUBJECT, subject, shares[i]);
            if (poolDeadline > maxDeadline) {
                maxDeadline = poolDeadline;
            }
        }
        return maxDeadline;
    }

    /**
     * @notice Register inactive shares to claim
     * @param newDistributors List of inactive shares distributors contracts to claim from
     */
    function addDistributors(address[] memory newDistributors) internal returns (uint256) {
        uint256 length = newDistributors.length;
        uint256 maxDeadline = deadline;
        for (uint256 i = 0; i < length; ++i) {
            address distributor = newDistributors[i];
            distributors.push(distributor);
            uint256 poolDeadline = InactiveSharesDistributor(distributor).deadline();
            if (poolDeadline > maxDeadline) {
                maxDeadline = poolDeadline;
            }
        }
        return maxDeadline;
    }

    function canClaim() public view returns (bool) {
        return (deadline != 0) && (deadline <= block.timestamp);
    }

    /**
     * @notice Claim user redemptions
     * @param receiver Address to receive the claimed assets
     * @param feeInBasisPoints Fee to apply to the claimed assets
     * @param feeTreasury Address to send the deducted fee
     * @return Amount of claimed assets
     */
    function claim(
        address receiver,
        uint256 feeInBasisPoints,
        address feeTreasury
    )
        external
        onlyOwner
        returns (uint256)
    {
        require(canClaim(), "Nothing to claim");

        uint256 stake;
        uint256 length = subjects.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 subject = subjects[i];
            if (_staking.isFrozen(DELEGATOR_SCANNER_POOL_SUBJECT, subject)) {
                frozenSubjects.push(subject);
            } else {
                stake += _staking.withdraw(DELEGATOR_SCANNER_POOL_SUBJECT, subject);
            }
        }
        delete subjects;

        length = distributors.length;
        for (uint256 i = 0; i < length; ++i) {
            InactiveSharesDistributor distributor = InactiveSharesDistributor(distributors[i]);
            uint256 balanceBefore = _token.balanceOf(address(this));
            if (distributor.claim()) {
                uint256 balanceAfter = _token.balanceOf(address(this));
                stake += (balanceAfter - balanceBefore);
            } else {
                frozenDistributors.push(address(distributor));
            }
        }
        delete distributors;

        // No deadline as there is no active assets to claim
        delete deadline;

        OperatorFeeUtils.deductAndTransferFee(stake, feeInBasisPoints, feeTreasury, _token);
        // everything is transferred to include donations and idle assets from the vault.
        _token.safeTransfer(receiver, _token.balanceOf(address(this)));
        return stake;
    }

    function claimFrozen(
        uint256[] calldata subjectsIndexes,
        uint256[] calldata distributorIndexes,
        address receiver,
        uint256 feeInBasisPoints,
        address feeTreasury
    )
        external
        onlyOwner
        returns (uint256)
    {
        uint256 stake;
        uint256 lastIndex = type(uint256).max;
        for (uint256 i = 0; i < subjectsIndexes.length; ++i) {
            require(lastIndex > subjectsIndexes[i], "Indexes should be strictly decreasing");
            lastIndex = subjectsIndexes[i];

            stake += _staking.withdraw(DELEGATOR_SCANNER_POOL_SUBJECT, frozenSubjects[lastIndex]);
            frozenSubjects[lastIndex] = frozenSubjects[frozenSubjects.length - 1];
            frozenSubjects.pop();
        }
        lastIndex = type(uint256).max;
        for (uint256 i = 0; i < distributorIndexes.length; ++i) {
            require(lastIndex > distributorIndexes[i], "Indexes should be strictly decreasing");
            lastIndex = distributorIndexes[i];

            uint256 balanceBefore = _token.balanceOf(address(this));
            require(InactiveSharesDistributor(frozenDistributors[lastIndex]).claim(), "Distributor still frozen");
            uint256 balanceAfter = _token.balanceOf(address(this));
            stake += (balanceAfter - balanceBefore);

            frozenDistributors[lastIndex] = frozenDistributors[frozenDistributors.length - 1];
            frozenDistributors.pop();
        }

        uint256 userStake = OperatorFeeUtils.deductAndTransferFee(stake, feeInBasisPoints, feeTreasury, _token);
        _token.safeTransfer(receiver, userStake);
        return stake;
    }

    function getSubjectAssets(uint256 subject) internal view returns (uint256) {
        uint256 inactiveSharesId = FortaStakingUtils.subjectToInactive(DELEGATOR_SCANNER_POOL_SUBJECT, subject);
        uint256 inactiveShares = _staking.balanceOf(address(this), inactiveSharesId);
        return _staking.inactiveSharesToStake(inactiveSharesId, inactiveShares);
    }

    function getDistributorAssets(address distributor) internal view returns (uint256) {
        return InactiveSharesDistributor(distributor).getExpectedAssets(address(this));
    }

    function getExpectedAssets() external view returns (uint256) {
        if (deadline == 0) {
            return 0;
        }

        uint256 stakeValue = 0;
        uint256 length = subjects.length;
        for (uint256 i = 0; i < length; ++i) {
            stakeValue += getSubjectAssets(subjects[i]);
        }

        length = distributors.length;
        for (uint256 i = 0; i < length; ++i) {
            stakeValue += getDistributorAssets(distributors[i]);
        }

        return stakeValue + _token.balanceOf(address(this));
    }

    function getExpectedFrozenAssets(
        uint256[] calldata subjectsIndexes,
        uint256[] calldata distributorIndexes
    )
        external
        view
        returns (uint256[] memory subjectsValue, uint256[] memory distributorsValue)
    {
        subjectsValue = new uint256[](subjectsIndexes.length);
        for (uint256 i = 0; i < subjectsIndexes.length; ++i) {
            subjectsValue[i] = getSubjectAssets(frozenSubjects[subjectsIndexes[i]]);
        }

        distributorsValue = new uint256[](distributorIndexes.length);
        for (uint256 i = 0; i < distributorIndexes.length; ++i) {
            distributorsValue[i] = getDistributorAssets(frozenDistributors[distributorIndexes[i]]);
        }
    }
}
