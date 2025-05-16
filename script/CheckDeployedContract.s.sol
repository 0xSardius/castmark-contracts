// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/CastmarkRegistry.sol";

contract CheckDeployedContractScript is Script {
    function run() external view {
        address contractAddress = 0x9e1F0463792D7858142a3414A811DEbB16132190;
        CastmarkRegistry registry = CastmarkRegistry(contractAddress);

        console.log("Contract VERSION:", registry.VERSION());
        console.log("Contract owner:", registry.owner());
        console.log("Contract paused:", registry.paused());

        // Try checking if a collection exists
        bool testExists = registry.isRegistered("test-collection");
        console.log("Test collection exists:", testExists);
    }
}
