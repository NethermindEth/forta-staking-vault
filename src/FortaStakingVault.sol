// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";


contract FortaStakingVault is ERC4626
//, ERC1155Holder
{

//    mapping(address => uint256) balances;

    IERC20 public immutable token;

    constructor(string memory name_, string memory symbol_, address _asset) ERC20(name_, symbol_) ERC4626(IERC20(_asset)) {
        token = IERC20(_asset);
    }



}