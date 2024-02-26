# Forta Staking Vault

Forta Staking enable users to get rewards by staking their FORT tokens. Users need to analyze multiple pools and plan strategies to increase their rewards. Forta Vault introduces a deposit and forget way for user to participate in the staking pools delegating the responsability of increasing rewards to a operator.

## Deployment

To deploy the Vault it is needed to first deploy the `RedemptionReceiver`, `InactiveSharesDistributor` and `FortaStakingVault` contracts

```bash
$ forge create --rpc-url <your_rpc_url> --private-key <your_private_key> src/RedemptionReceiver.sol:RedemptionReceiver
$ forge create --rpc-url <your_rpc_url> --private-key <your_private_key> src/InactiveSharesDistributor.sol:InactiveSharesDistributor
$ forge create --rpc-url <your_rpc_url> --private-key <your_private_key> src/FortaStakingVault.sol:FortaStakingVault
```

Each commands will output the address of the newly deployed contract that will be used to deploy and initialize the Vault.

Vault is meant to be upgradable so a proxy needs to be deployed. Deploy any proxy of your preference and set implementation to the address of the `FortaStakingVault` deployed before.

Then the vault needs to be initialized

```bash
$ cast send \
  --rpc-url <your_rpc_url> \
  --private-key <your_private_key> \
  <deployed_proxy> \
  "initialize(address,address,address,address,uint256,address,address)" \
  <fort-token> \
  <forta-staking> \
  <deployed-redemption-receiver> \
  <deployed-inactive-shares-distributor> \
  <operator-fee> \
  <treasury-address>
```

Caller of the initialize function will get `OPERATOR_ROLE` and `DEFAULT_ADMIN_ROLE` roles in the vault.

## Running Tests

Actual test suite depens on polygon mainnet to run, then, you need to configure a polygon rpc url in your `.env` file.

```bash
RPC_POLYGON=https://polygon-rpc.com
```

> The provided one in the example above is the public polygon rpc

With the rpc in place run

```bash
$ forge test
```

For checking coverage run

```bash
$ forge coverage
```

## Documentation

Documentation for the smart contracts is inlined in the code using [natspec format](https://docs.soliditylang.org/en/latest/natspec-format.html). To generate a web page with documentation run:

```bash
$ forge doc -s
```

Then open the local documentation provided in the server.
