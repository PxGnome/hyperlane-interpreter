// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {MockHyperlaneEnvironment, MockMailbox} from "@hyperlane-xyz/core/contracts/mock/MockHyperlaneEnvironment.sol";

import {LayerZeroRouter} from "../src/LayerZeroRouter.sol";
import {SimulateLzReceiver} from "../src/SimulateLzReceiver.sol";


abstract contract Abstract_LayerZeroRouterDeployer is Script {
    using stdJson for string;
    LayerZeroRouter lzRouter;

    function domainMapping(LayerZeroRouter _router ,string memory networkList) internal {
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
        string memory path = string.concat(root, "/environment/hyperlane/addresses.json");
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
    function deploy(string memory _routerType) internal {
        console.log("Deploying on network: %s",_routerType);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        lzRouter = new LayerZeroRouter();

        vm.stopBroadcast();
        console.log("LayerZero Router Address: %s", address(lzRouter));
    }

    function init(string memory _routerType) internal {
        console.log("Working on network: %s",_routerType);
        _routerType = string.concat(_routerType, "_");
        string memory network = vm.envString(string.concat(_routerType,"NETWORK"));
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address routerAddr = vm.envAddress(string.concat(_routerType,"ROUTER"));
        lzRouter = LayerZeroRouter(routerAddr);

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
    function mapRouter(string memory _routerType) internal {
        console.log("Working on network: %s",_routerType);
        _routerType = string.concat(_routerType, "_");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address routerAddr = vm.envAddress(string.concat(_routerType,"ROUTER"));
        lzRouter = LayerZeroRouter(routerAddr);

        domainMapping(lzRouter, ".all");
        vm.stopBroadcast();
        console.log("Domain Mapping done");
    }

    function compare(string memory str1, string memory str2) public pure returns (bool) {
        if (bytes(str1).length != bytes(str2).length) {
            return false;
        }
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }

    function enrollRouter(string memory _routerType) internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        _routerType = string.concat(_routerType, "_");

        address routerAddr = vm.envAddress(string.concat(_routerType,"ROUTER"));
        lzRouter = LayerZeroRouter(routerAddr);

        if(compare(_routerType, "ORIGIN_")){
            _routerType = "DESTINATION_";
        } else if(compare(_routerType, "DESTINATION_")){
            _routerType = "ORIGIN_";
        } else {
            console.log("Invalid network");
            return;
        }

        routerAddr = vm.envAddress(string.concat(_routerType,"ROUTER"));
        address enrollRouterAddr = address(LayerZeroRouter(routerAddr));

        string memory network = vm.envString(string.concat(_routerType,"NETWORK"));
        uint32 hlDestinationDomain = uint32(getDomainId(network, "hyperlane"));
        
        console.log("Enrolling %s for domain Id: %s",enrollRouterAddr, hlDestinationDomain);

        vm.startBroadcast(deployerPrivateKey);

        lzRouter.enrollRemoteRouter(
            hlDestinationDomain,
            TypeCasts.addressToBytes32(enrollRouterAddr)
        );   
        vm.stopBroadcast(); 
        }

}

contract DeployRouter_Origin is Abstract_LayerZeroRouterDeployer {
    function run() external {
        deploy("ORIGIN");
    }
}
contract DeployRouter_Destination is Abstract_LayerZeroRouterDeployer {
    function run() external {
        deploy("DESTINATION");
    }
}

contract InitRouter_Origin is Abstract_LayerZeroRouterDeployer {
    function run() external {
        init("ORIGIN");
    }
}

contract InitRouter_Destination is Abstract_LayerZeroRouterDeployer {
    function run() external {
        init("DESTINATION");
    }
}

contract MapRouter_Origin is Abstract_LayerZeroRouterDeployer {
    function run() external {
        mapRouter("ORIGIN");
    }
}

contract MapRouter_Destination is Abstract_LayerZeroRouterDeployer {
    function run() external {
        mapRouter("DESTINATION");
    }
}

contract EnrollRouter_Origin is Abstract_LayerZeroRouterDeployer {
    function run() external {
        enrollRouter("ORIGIN");
    }

}
contract EnrollRouter_Destination is Abstract_LayerZeroRouterDeployer {
    function run() external {
        enrollRouter("DESTINATION");
    }
}


contract DeploySimulateLzReceiver is Script {
    using stdJson for string;

    SimulateLzReceiver simulateLzReceiver;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        simulateLzReceiver = new SimulateLzReceiver();
        console.log("SimulateLzReceiver Address: %s", address(simulateLzReceiver));
        vm.stopBroadcast();
    }
}