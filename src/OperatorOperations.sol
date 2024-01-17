// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IFortaStaking, DELEGATOR_SCANNER_POOL_SUBJECT} from "./interfaces/IFortaStaking.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract OperatorOperations is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    error NotOperator();

    mapping(uint256 => uint256) public stakes; // todo: should it be public ?
    uint256[] public subjects;

    address private immutable staking;
    IERC20 private immutable token;

    constructor(address admin, IERC20 _token, address _staking) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        token = _token;
        staking = _staking;
    }

    function _validateIsOperator() private view {
        if (!hasRole(OPERATOR_ROLE, msg.sender)) {
            revert NotOperator();
        }
    }

    function delegate(uint256 subject, uint256 assets) public {
        _validateIsOperator();
        if (stakes[subject] == 0) {
            subjects.push(subject);
        }
        token.approve(staking, assets);
        uint256 shares = IFortaStaking(staking).deposit(DELEGATOR_SCANNER_POOL_SUBJECT, subject, assets);
        stakes[subject] += shares;
    }

    function initiateUndelegate(uint256 subject, uint256 amount) public returns (uint64) {
        _validateIsOperator();
        uint64 lock = IFortaStaking(staking).initiateWithdrawal(DELEGATOR_SCANNER_POOL_SUBJECT, subject, amount);
        // here we can count pending withdrawals shares
        return lock;
    }

    function undelegate(uint256 subject) public {
        _validateIsOperator();
        uint256 withdrawn = IFortaStaking(staking).withdraw(DELEGATOR_SCANNER_POOL_SUBJECT, subject);
        assert(stakes[subject] >= withdrawn);
        stakes[subject] -= withdrawn;
        if (stakes[subject] == 0) {
            for (uint i = 0; i < subjects.length; i++) {
                if (subjects[i] == subject) {
                    subjects[i] = subjects[subjects.length - 1];
                    subjects.pop();
                }
            }
        }
    }

}
