# Forta Staking Vault

Forta Staking enable users to get rewards by staking their FORT tokens. Users need to analyze multiple pools and plan strategies to increase their rewards. Forta Vault introduces a deposit and forget way for user to participate in the staking pools delegating the responsability of increasing rewards to a operator.

## Deployed Contracts

| Contract                           | Polygon                                                                                                                       |
|:-----------------------------------|:------------------------------------------------------------------------------------------------------------------------------|
| FortaStakingVault (Proxy)          | [0xF22F690A41d22496496d4959acFFf0f3baCC24F1](https://polygonscan.com/address/0xf22f690a41d22496496d4959acfff0f3bacc24f1#code) |
| FortaStakingVault (Implementation) | [0x35Bb253BF0802EAC46E42E46B9fA697a250aBA01](https://polygonscan.com/address/0x35bb253bf0802eac46e42e46b9fa697a250aba01#code) |
| RedemptionReceiver                 | [0xcEcD2A3248863461c7E50930551E78CBea3098F1](https://polygonscan.com/address/0xcecd2a3248863461c7e50930551e78cbea3098f1#code) |
| InactiveSharesDistributor          | [0x39B13e83dC24A8eC3Ecf48979e22860C1921ce69](https://polygonscan.com/address/0x39b13e83dc24a8ec3ecf48979e22860c1921ce69#code) |

## Dependencies

This projects was developed with [foundry](https://book.getfoundry.sh/). Install it by executing

```bash
curl -L https://foundry.paradigm.xyz | bash
```

or check other installation options [here](https://book.getfoundry.sh/getting-started/installation)

## Deployment

1.  Set deployer private key in the `.env` file
    ```bash
    PRIVATE_KEY=
    ```
    Make sure it starts with `0x` if it is in hexadecimal
2.  Run the deployment script

    ```bash
    forge script Deploy --rpc-url "your-rpc-url" --broadcast
    ```

    1.  In order to verify the contracts deployed you can add the `--verify` flag if the api key of the explorer of the network used is set in the `.env`
        ```bash
        ETHERSCAN_API_KEY=
        ```
        > Note that you can set any api key in that var, not necesarly from etherscan. e.g polygonscan api key can be a valid value if you use Polygon Mainnet or Mumbai RPCs.
    2.  Some parameters can be set in the enviroment for custom deployments

        ```bash
        FORT_TOKEN=            # 0x9ff62d1FC52A907B6DCbA8077c2DDCA6E6a9d3e1 if omitted
        FORTA_STAKING=         # 0xd2863157539b1D11F39ce23fC4834B62082F6874 if ommitted
        VAULT_FEE=             # 0 if omitted
        TREASURY_ADDRESS=      # Deployer if omitted
        REWARDS_DISTRIBUTOR=   # 0xf7239f26b79145297737166b0C66F4919af9c507 if omitted
        ```

        Default values use addresses of Forta deployed contracts on Polygon

> Deploment script deploys a [TransparentUpgradeableProxy](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) to manage upgrades in the Forta vault.

## Running Tests

Actual test suite depens on polygon mainnet to run, then, you need to configure a polygon rpc url in your `.env` file.

```bash
POLYGON_RPC=https://polygon-rpc.com
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

To check the coverage in detail

```bash
$ forge coverage --report lcov
$ genhtml lcov.info --branch-coverage --output-dir coverage
$ open ./coverage/index.html

```

## Documentation

Documentation for the smart contracts is inlined in the code using [natspec format](https://docs.soliditylang.org/en/latest/natspec-format.html). To generate a web page with documentation run:

```bash
$ forge doc -s
```

Then open the local documentation provided in the server.
