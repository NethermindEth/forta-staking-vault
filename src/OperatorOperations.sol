// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IFortaStaking, DELEGATOR_SCANNER_POOL_SUBJECT} from "./interfaces/IFortaStaking.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract OperatorOperations is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    error NotOperator();

    mapping(uint256 => uint256) private stakes;
    uint256[] private subjects;

    address private immutable staking;
    IERC20 private immutable token;
    uint256 private currentlyStaked;

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
        token.approve(staking, assets);
        uint256 shares = IFortaStaking(staking).deposit(DELEGATOR_SCANNER_POOL_SUBJECT, subject, assets);
        if (stakes[subject] == 0) {
            subjects.push(subject);
        }
        stakes[subject] += shares;
        currentlyStaked += assets;
    }

    function getCurrentlyStakedAmount() public view returns (uint256) {
        return currentlyStaked;
    }

    function getStakes(uint256 subject) public view returns (uint256) {
        return stakes[subject];
    }

    function getSubjectByIndex(uint256 index) public view returns (uint256) {
        return subjects[index];
    }

}
