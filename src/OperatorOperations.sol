// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IFortaStaking, DELEGATOR_SCANNER_POOL_SUBJECT} from "./IFortaStaking.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract OperatorOperations is AccessControl {

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    error NotOperator();

    mapping(uint256 => uint256) private stakes;
    uint256[] subjects;

    address private immutable staking;
    IERC20 private immutable token;

    constructor(address admin, IERC20 _token, address _staking) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        token = _token;
        staking = _staking;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
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

}

