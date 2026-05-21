// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Vault.sol";
import "../src/OracleVerifier.sol";
import "../src/NFTxLendRouter.sol";

/**
 * @title DeployNFTxLend
 * @notice Foundry deployment script for the NFTxLend EVM suite.
 * @dev Deploy order: OracleVerifier → NFTVault → NFTxLendRouter
 *
 *      forge script script/DeployNFTxLend.s.sol:DeployNFTxLend \
 *        --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
 */
contract DeployNFTxLend is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address oracleSigner = vm.envAddress("ORACLE_SIGNER");
        address relayerAddr = vm.envAddress("RELAYER_ADDRESS");

        vm.startBroadcast(deployerKey);

        OracleVerifier oracle = new OracleVerifier(oracleSigner);
        console.log("OracleVerifier:", address(oracle));

        NFTVault vault = new NFTVault(relayerAddr);
        console.log("NFTVault:", address(vault));

        NFTxLendRouter router = new NFTxLendRouter(address(vault), address(oracle));
        console.log("NFTxLendRouter:", address(router));

        vm.stopBroadcast();
    }
}
