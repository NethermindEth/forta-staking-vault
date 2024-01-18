// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/interfaces/IFortaStaking.sol";

abstract contract TestParameters {
    ERC20 internal constant FORT_TOKEN = ERC20(0x9ff62d1FC52A907B6DCbA8077c2DDCA6E6a9d3e1);
    IFortaStaking internal constant FORTA_STAKING = IFortaStaking(0xd2863157539b1D11F39ce23fC4834B62082F6874);
}
