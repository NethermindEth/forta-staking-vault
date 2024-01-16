// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-contracts/blob/master/LICENSE.md

pragma solidity ^0.8.9;

library FortaStakingUtils {
    /**
     * @dev Encode "active" and subjectType in subject by hashing them together, shifting left 9 bits,
     * setting bit 9 (to mark as active) and masking subjectType in
     * @param subjectType agents, scanner or future types of stake subject. See SubjectTypeValidator.sol
     * @param subject id identifying subject (external to FortaStaking).
     * @return ERC1155 token id representing active shares.
     */
    function subjectToActive(uint8 subjectType, uint256 subject) external pure returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(subjectType, subject))) << 9 | uint16(256)) | uint256(subjectType);
    }
}