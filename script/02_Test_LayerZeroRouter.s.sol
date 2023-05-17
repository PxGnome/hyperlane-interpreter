// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {MockHyperlaneEnvironment, MockMailbox} from "@hyperlane-xyz/core/contracts/mock/MockHyperlaneEnvironment.sol";
import {LayerZeroRouter} from "../src/LayerZeroRouter.sol";
import {SimulateLzReceiver} from "../src/SimulateLzReceiver.sol";


abstract contract AbstractSendMessageFrom is Script {
    using stdJson for string;
    LayerZeroRouter lzRouter;

    function getDomainId(string memory network, string memory _bridge) internal returns (uint256) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/environment/layerzero/domainId.json");
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", network, ".", _bridge);
        uint256 domainId = json.readUint(key);
        console.log("%s-%s domainId: %s", network, _bridge, domainId);
        return domainId;
    }

    function compare(string memory str1, string memory str2) public pure returns (bool) {
        if (bytes(str1).length != bytes(str2).length) {
            return false;
        }
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }

    function send(string memory _routerType) internal {
        _routerType = string.concat(_routerType, "_");
        string memory network = vm.envString(string.concat(_routerType,"NETWORK"));
        console.log("Sending from network: %s", network);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

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
        network = vm.envString(string.concat(_routerType,"NETWORK"));
        uint16 lzDestinationDomain = uint16(getDomainId(network, "layerzero"));
        
        address remoteAddr = vm.envAddress(string.concat(_routerType, "RECEIVER"));
        console.log("Sending to: %s", remoteAddr);
        address senderAddr = msg.sender;
        bytes memory destination = abi.encodePacked(remoteAddr, senderAddr);

        bytes memory payload = abi.encode("TEST");

        vm.startBroadcast(deployerPrivateKey);

        (uint256 gasPayment, ) = lzRouter.estimateFees(lzDestinationDomain, remoteAddr, payload, false, "");
        
        console.log("Gas Value: %s",gasPayment);

        lzRouter.send{value: gasPayment}(
            lzDestinationDomain,
            destination,
            payload,
            payable(address(0)),
            address(0),
            ""
        );

        vm.stopBroadcast();
        console.log("Message Sent");
    }
}

contract SendMessageFrom_Origin is AbstractSendMessageFrom {
    function run() public {
        send("ORIGIN");
    }
}

contract SendMessageFrom_Destination is AbstractSendMessageFrom {
    function run() public {
        send("DESTINATION");
    }
}