// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-contracts/blob/master/LICENSE.md

pragma solidity 0.8.23;

interface IRewardsDistributor {
    function claimRewards(uint8 subjectType, uint256 subjectId, uint256[] calldata epochNumbers) external;
}
