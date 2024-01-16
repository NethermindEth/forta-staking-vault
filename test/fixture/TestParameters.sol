// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract TestParameters {
    address internal constant FORTA_ADDRESS = 0x9ff62d1FC52A907B6DCbA8077c2DDCA6E6a9d3e1;
    ERC20 internal constant FORTA_COIN = ERC20(FORTA_ADDRESS);

    address internal constant FORTA_STAKING_ADDRESS = 0xd2863157539b1D11F39ce23fC4834B62082F6874;
}
