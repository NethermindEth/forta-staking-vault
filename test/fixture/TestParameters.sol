// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-contracts/blob/master/LICENSE.md

pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IFortaStaking } from "../../src/interfaces/IFortaStaking.sol";

abstract contract TestParameters {
    IERC20 internal constant FORT_TOKEN = IERC20(0x9ff62d1FC52A907B6DCbA8077c2DDCA6E6a9d3e1);
    IFortaStaking internal constant FORTA_STAKING = IFortaStaking(0xd2863157539b1D11F39ce23fC4834B62082F6874);
}
