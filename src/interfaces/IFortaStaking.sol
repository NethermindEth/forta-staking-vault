// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

uint8 constant UNDEFINED_SUBJECT = 255;
uint8 constant SCANNER_SUBJECT = 0;
uint8 constant AGENT_SUBJECT = 1;
uint8 constant SCANNER_POOL_SUBJECT = 2;
uint8 constant DELEGATOR_SCANNER_POOL_SUBJECT = 3;

interface IFortaStaking {
    function deposit(uint8 subjectType, uint256 subject, uint256 stakeValue) external returns (uint256);
}
