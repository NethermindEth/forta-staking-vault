// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./OperatorOperations.sol";

contract FortaStakingVault is ERC4626, ERC1155Holder, OperatorOperations {
    constructor(address _asset, address _fortaStaking)
        ERC20("FORT Staking Vault", "vFORT")
        ERC4626(IERC20(_asset))
        OperatorOperations(msg.sender, IERC20(_asset), _fortaStaking)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Holder, OperatorOperations)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
