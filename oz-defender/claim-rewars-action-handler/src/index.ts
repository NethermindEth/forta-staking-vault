import {AutotaskEvent} from '@openzeppelin/defender-autotask-utils';
import {BlockTriggerEvent, EventConditionSummary} from "@openzeppelin/defender-autotask-utils/lib/types";
import {DefenderRelaySigner, DefenderRelayProvider} from "@openzeppelin/defender-sdk-relay-signer-client/lib/ethers";
import {ethers} from "ethers";

import {ActionRelayerParams} from "@openzeppelin/defender-sdk-relay-signer-client/lib/models/relayer";


exports.handler = async function (event: AutotaskEvent) {

    const VaultABI = `
    [
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "subjectId",
                "type": "uint256"
            },
            {
                "internalType": "uint256",
                "name": "epochNumber",
                "type": "uint256"
            }
        ],
        "name": "claimRewards",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
    ]`;

    const {subjectType, subject, epochNumber} =
        ((event.request.body as BlockTriggerEvent).matchReasons[0] as EventConditionSummary).params;

    const provider = new DefenderRelayProvider(event as ActionRelayerParams);
    const signer = new DefenderRelaySigner(event as ActionRelayerParams, provider, {speed: 'fast'});
    const contractAddress = event.secrets.FORTA_VAULT_ADDRESS;
    if (!contractAddress) {
        throw Error("No FORTA_VAULT_ADDRESS in secrets");
    }
    if (subjectType === 3) { // DELEGATOR_SCANNER_POOL_SUBJECT
        const vault = new ethers.Contract(contractAddress, VaultABI, signer);
        const tx = await vault.claimRewards(subject, epochNumber);
        console.log(`Attempt to Claim Rewards`);
        return tx;
    }
    return null;
}
