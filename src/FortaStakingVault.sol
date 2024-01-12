// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./OperatorOperations.sol";


contract FortaStakingVault is
ERC4626,
OperatorOperations
{

    IERC20 public immutable token;

    constructor(string memory name_, string memory symbol_, address _asset) ERC20(name_, symbol_) ERC4626(IERC20(_asset)) OperatorOperations(msg.sender, msg.sender) {
        token = IERC20(_asset);
    }


}