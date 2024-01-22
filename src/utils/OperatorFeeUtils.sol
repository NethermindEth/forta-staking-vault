// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-contracts/blob/master/LICENSE.md

pragma solidity 0.8.23;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

uint256 constant FEE_BASIS_POINTS_DENOMINATOR = 10_000;

library OperatorFeeUtils {
    function deductAndTransferFee(
        uint256 amount,
        uint256 feeInBasisPoints,
        address feeReceiver,
        IERC20 token
    )
        internal
        returns (uint256)
    {
        uint256 feeAmount = 0;
        if (feeInBasisPoints > 0) {
            feeAmount = Math.mulDiv(amount, feeInBasisPoints, FEE_BASIS_POINTS_DENOMINATOR);
            if (feeAmount > 0) {
                token.transfer(feeReceiver, feeAmount);
            }
        }
        return amount - feeAmount;
    }
}
