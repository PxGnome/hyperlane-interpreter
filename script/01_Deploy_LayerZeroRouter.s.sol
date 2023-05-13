// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {MockHyperlaneEnvironment, MockMailbox} from "@hyperlane-xyz/core/contracts/mock/MockHyperlaneEnvironment.sol";

import {MockLayerZeroRouter} from "../src/MockLayerZeroRouter.sol";
import {MockLzReceiver} from "../src/MockLzReceiver.sol";

contract MyScript is Script {
    using stdJson for string;

    MockLayerZeroRouter originRouter;
    MockLayerZeroRouter destinationRouter;

    MockLzReceiver mockLzReceiver;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        originRouter = new MockLayerZeroRouter();
        destinationRouter = new MockLayerZeroRouter();

        originRouter.initialize(
            getAddresses("sepolia", "mailbox"),
            getAddresses("sepolia", "igp"),
            getAddresses("sepolia", "ism")
        );

        destinationRouter.initialize(
            getAddresses("mumbai", "mailbox"),
            getAddresses("mumbai", "igp"),
            getAddresses("mumbai", "ism")
        );

        domainMapping(originRouter, ".mainnet");
        domainMapping(destinationRouter, ".mainnet");

        domainMapping(originRouter, ".testnet");
        domainMapping(destinationRouter, ".testnet");

        console.log("Origin Router Address: %s", address(originRouter));
        console.log("Destination Router Address: %s", address(destinationRouter));

        uint32 hlOriginDomain = uint32(getDomainId("sepolia", "hyperlane"));
        uint32 hlDestinationDomain = uint32(getDomainId("mumbai", "hyperlane"));

        originRouter.enrollRemoteRouter(
            hlDestinationDomain,
            TypeCasts.addressToBytes32(address(destinationRouter))
        );
        destinationRouter.enrollRemoteRouter(
            hlOriginDomain,
            TypeCasts.addressToBytes32(address(originRouter))
        );

        mockLzReceiver = new MockLzReceiver();
        console.log("MockLzReceiver Address: %s", address(mockLzReceiver));
        vm.stopBroadcast();
    }


    function domainMapping(MockLayerZeroRouter _router ,string memory _networkList) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/environment/layerzero/domainId.json");
        string memory json = vm.readFile(path);
        
        string[] memory list = json.readStringArray(_networkList);

        uint16[] memory lzDomains = new uint16[](list.length);
        lzDomains = new uint16[](list.length);
        uint32[] memory hlDomains = new uint32[](list.length);
        string memory key;
        for (uint i = 0; i < list.length; i++) {
            key = string.concat(".", list[i], ".layerzero");
            lzDomains[i] = uint16(json.readUint(key));
            key = string.concat(".", list[i], ".hyperlane");
            hlDomains[i] = uint32(json.readUint(key));
            console.log("Network Mapping: %s", list[i]);
            console.log("LZ: %s", lzDomains[i]);
            console.log("HL: %s", hlDomains[i]);    
        }

        _router.mapDomains(lzDomains, hlDomains);
    }
    
    function getAddresses(string memory _network, string memory _item) internal returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/environment/layerzero/addresses.json");
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", _network, ".", _item);
        address addr = json.readAddress(key);
        console.log("%s Address: %s", key, addr);
        return addr;
    }
    
    function getDomainId(string memory _network, string memory _bridge) internal returns (uint256) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/environment/layerzero/domainId.json");
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", _network, ".", _bridge);
        uint256 domainId = json.readUint(key);
        console.log("%s-%s domainId: %s", _network, _bridge, domainId);
        return domainId;
    }
}