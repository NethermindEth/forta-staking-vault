// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-contracts/blob/master/LICENSE.md

pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/FortaStakingVault.sol";
import "../src/InactiveSharesDistributor.sol";
import "../src/RedemptionReceiver.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer ->", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        RedemptionReceiver receiver = new RedemptionReceiver();
        InactiveSharesDistributor distributor = new InactiveSharesDistributor();
        FortaStakingVault vault = new FortaStakingVault();

        bytes memory data = abi.encodeCall(FortaStakingVault.initialize, (
            vm.envOr("FORT_TOKEN", address(0x9ff62d1FC52A907B6DCbA8077c2DDCA6E6a9d3e1)), 
            vm.envOr("FORTA_STAKING", address(0xd2863157539b1D11F39ce23fC4834B62082F6874)),
            address(receiver), 
            address(distributor), 
            vm.envOr("VAULT_FEE", uint256(0)), 
            vm.envOr("TREASURY_ADDRESS", deployer),
            vm.envOr("REWARDS_DISTRIBUTOR", address(0xf7239f26b79145297737166b0C66F4919af9c507))
        ));

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(vault), deployer, data);
        console.log("Vault address ->", address(proxy));
        vm.stopBroadcast();
    }
}