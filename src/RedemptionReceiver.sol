// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { OperatorFeeUtils } from "./utils/OperatorFeeUtils.sol";
import { IFortaStaking, DELEGATOR_SCANNER_POOL_SUBJECT } from "./interfaces/IFortaStaking.sol";
import { InactiveSharesDistributor } from "./InactiveSharesDistributor.sol";

contract RedemptionReceiver is OwnableUpgradeable, ERC1155Holder {
    uint256[] private _subjects;
    address[] private _distributors;
    mapping(uint256 => uint256) private _subjectsPending;
    mapping(address => bool) private _distributorsPending;
    IFortaStaking private _staking;

    function initialize(address owner_, IFortaStaking staking) public initializer {
        __Ownable_init(owner_);
        _staking = staking;
    }

    function addUndelegations(uint256[] memory newUndelegations, uint256[] memory shares) public onlyOwner {
        for (uint256 i = 0; i < newUndelegations.length; ++i) {
            uint256 subject = newUndelegations[i];
            if (_subjectsPending[subject] == 0) {
                _subjects.push(subject);
            }
            _subjectsPending[subject] = _staking.initiateWithdrawal(DELEGATOR_SCANNER_POOL_SUBJECT, subject, shares[i]);
        }
    }

    function addDistributors(address[] memory newDistributors) public onlyOwner {
        for (uint256 i = 0; i < newDistributors.length; ++i) {
            address distributor = newDistributors[i];
            if (!_distributorsPending[distributor]) {
                _distributors.push(distributor);
                _distributorsPending[distributor] = true;
            }
        }
    }

    function claim(
        address receiver,
        uint256 feeInBasisPoints,
        address feeTreasury
    )
        public
        onlyOwner
        returns (uint256)
    {
        uint256 stake;
        for (uint256 i = 0; i < _subjects.length;) {
            uint256 subject = _subjects[i];
            if (
                (_subjectsPending[subject] < block.timestamp)
                    && !_staking.isFrozen(DELEGATOR_SCANNER_POOL_SUBJECT, subject)
            ) {
                stake += _staking.withdraw(DELEGATOR_SCANNER_POOL_SUBJECT, subject);
                _subjects[i] = _subjects[_subjects.length - 1];
                delete _subjectsPending[subject];
                _subjects.pop();
            } else {
                ++i;
            }
        }
        for (uint256 i = 0; i < _distributors.length;) {
            InactiveSharesDistributor distributor = InactiveSharesDistributor(_distributors[i]);
            uint256 balanceBefore = IERC20(_staking.stakedToken()).balanceOf(address(this));
            bool validClaim = distributor.claim();
            if (validClaim) {
                uint256 balanceAfter = IERC20(_staking.stakedToken()).balanceOf(address(this));
                stake += (balanceAfter - balanceBefore);
                _distributorsPending[address(distributor)] = false;
                _distributors[i] = _distributors[_distributors.length - 1];
                _distributors.pop();
            } else {
                ++i;
            }
        }
        uint256 userStake =
            OperatorFeeUtils.deductAndTransferFee(stake, feeInBasisPoints, feeTreasury, IERC20(_staking.stakedToken()));
        IERC20(_staking.stakedToken()).transfer(receiver, userStake);
        return stake;
    }
}
