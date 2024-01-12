// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IFortaStaking, SCANNER_SUBJECT} from "./IFortaStaking.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract OperatorOperations is AccessControl, ERC1155Holder {

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    error NotOperator();

    mapping(address => uint256) private stakes;

    constructor(address admin, address operator) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, operator);
    }

    function _validateIsOperator() private view {
        if (!hasRole(OPERATOR_ROLE, msg.sender)) {
            revert NotOperator();
        }
    }

    function delegate(address pool, uint256 assets) public {
        _validateIsOperator();
        IFortaStaking fortaPool = IFortaStaking(pool);
        // do we need to call allowance ?
        uint256 shares = fortaPool.deposit(SCANNER_SUBJECT, 123, assets);
        stakes[pool] += shares;
    }

}

