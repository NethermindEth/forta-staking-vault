// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-contracts/blob/master/LICENSE.md

pragma solidity ^0.8.4;

interface IFortaStakingVault {
    error NotOperator();
    error InvalidTreasury();
    error InvalidFee();
    error PendingUndelegation();
    error InvalidUndelegation();
    error EmptyDelegation();

    /**
     * @notice Emitted when fee basis points is updated
     */
    event FeeBasisPointsUpdated(uint256 newFee);
    /**
     * @notice Emitted when the fee treasury is updated
     */
    event FeeTreasuryUpdated(address newTreasury);

    /**
     * @notice Initializes the Vault
     * @param asset_ Asset to stake (FORT Token address)
     * @param fortaStaking FortaStaking contract address
     * @param redemptionReceiverImplementation RedemptionReceiver implementation contract
     * @param inactiveSharesDistributorImplementation InactiveSharesDistributor implementation contract
     * @param operatorFeeInBasisPoints Fee applied on redemptions
     * @param operatorFeeTreasury Treasury address to receive the fees
     * @param rewardsDistributor RewardsDistributor contract address
     */
    function initialize(
        address asset_,
        address fortaStaking,
        address redemptionReceiverImplementation,
        address inactiveSharesDistributorImplementation,
        uint256 operatorFeeInBasisPoints,
        address operatorFeeTreasury,
        address rewardsDistributor
    )
        external;

    /**
     * @notice Claim rewards associated to a subject
     * @param subjectId Subject to claim rewards from
     * @param epochNumber Epoch where the rewards were generated
     * @dev meant to be called by a relayer (i.e OZ Defender)
     */
    function claimRewards(uint256 subjectId, uint256 epochNumber) external;

    /**
     * @notice Claim user redeemed assets
     * @param receiver Address to receive the redeemed assets
     * @return Amount of assets claimed
     */
    function claimRedeem(address receiver) external returns (uint256);

    /**
     * @notice Delegate FORT in the vault to a subject
     * @param subject Subject to delegate assets to
     * @param assets Amount of assets to delegate
     */
    function delegate(uint256 subject, uint256 assets) external returns (uint256);

    /**
     * @return Fee in basis points
     */
    function feeInBasisPoints() external view returns (uint256);

    /**
     * @return Fee treasury address
     */
    function feeTreasury() external view returns (address);

    /**
     * @notice Return the redemption receiver contract of a user
     * @param user Address of the user the receiver is associated to
     * @return Address of the receiver contract associated to the user
     */
    function getRedemptionReceiver(address user) external view returns (address);

    /**
     * @notice Initiate an undelegation from a subject
     * @param subject Subject to undelegate assets from
     * @param shares Amount of shares to undelegate
     * @dev generated a new contract to simulate a pool given
     * that inactiveShares are not transferable
     * @return A tuple containing the undelegation deadline and the
     * address of the distributor contract that will split the undelegation assets
     */
    function initiateUndelegate(uint256 subject, uint256 shares) external returns (uint256, address);

    /**
     * @return List of subjects with delegations
     */
    function getSubjects() external view returns (uint256[] memory);

    /**
     * @notice Finish an undelegation from a subject
     * @param subject Subject being undelegate
     * @dev vault receives the portion of undelegated assets
     * not redeemed by users
     */
    function undelegate(uint256 subject) external returns (uint256);

    /**
     * @notice Updates the redemption fee
     * @param feeBasisPoints New fee
     */
    function updateFeeBasisPoints(uint256 feeBasisPoints) external;

    /**
     * @notice Updates the treasury address
     * @param treasury New treasury address
     */
    function updateFeeTreasury(address treasury) external;
}
