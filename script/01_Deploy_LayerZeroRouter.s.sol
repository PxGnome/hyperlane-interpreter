// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {MockHyperlaneEnvironment, MockMailbox} from "@hyperlane-xyz/core/contracts/mock/MockHyperlaneEnvironment.sol";

import {MockLayerZeroRouter} from "../src/MockLayerZeroRouter.sol";
import {MockLzReceiver} from "../src/MockLzReceiver.sol";

// forge script script/01_Deploy_LayerZeroRouter.s.sol:$ACTION --rpc-url $RPC_KEY --broadcast --verify -vvvv

abstract contract Abstract_LayerZeroRouterDeployer is Script {
    using stdJson for string;
    MockLayerZeroRouter lzRouter;

    function domainMapping(MockLayerZeroRouter _router ,string memory networkList) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/environment/layerzero/domainId.json");
        string memory json = vm.readFile(path);
        
        string[] memory list = json.readStringArray(networkList);

        uint16[] memory lzDomains = new uint16[](list.length);
        lzDomains = new uint16[](list.length);
        uint32[] memory hlDomains = new uint32[](list.length);
        string memory key;
        for (uint i = 0; i < list.length; i++) {
            key = string.concat(".", list[i], ".layerzero");
            lzDomains[i] = uint16(json.readUint(key));
            key = string.concat(".", list[i], ".hyperlane");
            hlDomains[i] = uint32(json.readUint(key));
            console.log("%s : %s - %s", list[i], lzDomains[i], hlDomains[i]);
        }

        _router.mapDomains(lzDomains, hlDomains);
    }
    
    function getAddresses(string memory network, string memory _item) internal returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/environment/layerzero/addresses.json");
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", network, ".", _item);
        address addr = json.readAddress(key);
        // console.log("%s Address: %s", key, addr);
        return addr;
    }
    
    function getDomainId(string memory network, string memory _bridge) internal returns (uint256) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/environment/layerzero/domainId.json");
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", network, ".", _bridge);
        uint256 domainId = json.readUint(key);
        console.log("%s-%s domainId: %s", network, _bridge, domainId);
        return domainId;
    }
}

contract DeployRouter is Abstract_LayerZeroRouterDeployer {
    function run() external {
        string memory network = vm.envString("NETWORK");
        console.log("Deploying on network: %s",network);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        lzRouter = new MockLayerZeroRouter();

        vm.stopBroadcast();
        console.log("LayerZero Router Address: %s", address(lzRouter));
    }
}

contract InitRouter is Abstract_LayerZeroRouterDeployer {
    function run() external {
        string memory network = vm.envString("NETWORK");
        console.log("Working on network: %s",network);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address routerAddr = vm.envAddress("ROUTER");
        lzRouter = MockLayerZeroRouter(routerAddr);

        console.log("Initializing lzRouter: %s", address(lzRouter));
        vm.startBroadcast(deployerPrivateKey);

        lzRouter.initialize(
            getAddresses(network, "mailbox"),
            getAddresses(network, "igp"),
            getAddresses(network, "ism")
        );
        vm.stopBroadcast();
        console.log("LayerZero Router initialized");
    }
}

contract MapRouter is Abstract_LayerZeroRouterDeployer {
    function run() external {
        string memory network = vm.envString("NETWORK");
        console.log("Working on network: %s",network);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address routerAddr = vm.envAddress("ROUTER");
        lzRouter = MockLayerZeroRouter(routerAddr);

        domainMapping(lzRouter, ".all");
        vm.stopBroadcast();
        console.log("Domain Mapping done");
    }
}

contract EnrollRouter is Script {
    MockLayerZeroRouter lzRouter;

    function run() external {
        uint32 hlDestinationDomain = uint32(vm.envUint("ENROLL_HL_DOMAIN"));

        console.log("Enrolling on domain Id: %s",hlDestinationDomain);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address routerAddr = vm.envAddress("ROUTER");
        lzRouter = MockLayerZeroRouter(routerAddr);
        address enrollRouterAddr = vm.envAddress("ENROLL_ROUTER");

        enrollRouter(enrollRouterAddr, hlDestinationDomain);
    }

    function enrollRouter(address _enrollRouterAddr, uint32 _hlDestinationDomain) internal {
        lzRouter.enrollRemoteRouter(
            _hlDestinationDomain,
            TypeCasts.addressToBytes32(_enrollRouterAddr)
        );
    }
}


contract Deploy_MockReceiver is Script {
    using stdJson for string;

    MockLzReceiver mockLzReceiver;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        mockLzReceiver = new MockLzReceiver();
        console.log("MockLzReceiver Address: %s", address(mockLzReceiver));
        vm.stopBroadcast();
    }
}