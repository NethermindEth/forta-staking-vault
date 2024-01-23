## Build 

```
    yarn install
    yarn build
```

result of build process will be vanilla js file - `index.js` in `dist/` folder. 

This file is the main deployable artifact in below `Acton` section. 


## OpenZeppelin Defender Configuration

### Relayer
Create corresponding on the target network under section Manage/Relayers.
Once created top-up the address of the relayer with network native token. 

_With Defender v2. there is no need to create api/secret key pair._ 


### Action
Create dedicated Action.
In order to react on the on-chain event, the Action should be type of `Monitor`
Important, this new action should be connected to Relayer, created previous step.

Under the `Code` section, goes code from `index.js` (result of the build) 


### Monitor
Create dedicated monitor, that points to the `RewardDistributorProxy` contract - one that emits the `Rewarded` event. 

Set 1 block(s) confirmation. 

Defender will scan contract's API. 

Monitor should listen for `Rewarded(uint8,uint256,uint256,uint256)` event, selected under `Events` sections.

To allow Monitor execute action from previous step, bind it under `Execute an Action` box of `Alerts` section.

### Secret
Add new `Secret` pair, with key `FORTA_VAULT_ADDRESS` and with value as address of `FortsStakingVault` contract address.
This secret is used as mandatory configuration value for `Action`'s javascript code. 
