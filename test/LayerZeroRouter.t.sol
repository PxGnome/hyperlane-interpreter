// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {MockHyperlaneEnvironment, MockMailbox} from "@hyperlane-xyz/core/contracts/mock/MockHyperlaneEnvironment.sol";

import {MockLayerZeroRouter} from "../src/MockLayerZeroRouter.sol";
import {MockLzReceiver} from "../src/MockLzReceiver.sol";


import "forge-std/StdJson.sol";

// import "../environment/layerzero/addresses.json";

contract LayerZeroRouterTest is Test {
    using stdJson for string;

    MockHyperlaneEnvironment testEnvironment;

    MockLayerZeroRouter originRouter;
    MockLayerZeroRouter destinationRouter;

    MockLzReceiver mockLzReceiver;

    uint16 lzOriginDomain;
    uint16 lzDestinationDomain;

    uint32 hlOriginDomain;
    uint32 hlDestinationDomain;

    function getDomainId(string memory _network, string memory _bridge) internal returns (uint256) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/environment/layerzero/domainId.json");
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", _network, ".", _bridge);
        uint256 domainId = json.readUint(key);
        return domainId;
    }

    function setUp() public {
        lzOriginDomain = uint16(getDomainId("sepolia", "layerzero"));
        lzDestinationDomain = uint16(getDomainId("mumbai", "layerzero"));

        hlOriginDomain = uint32(getDomainId("sepolia", "hyperlane"));
        hlDestinationDomain = uint32(getDomainId("mumbai", "hyperlane"));

        originRouter = new MockLayerZeroRouter();
        destinationRouter = new MockLayerZeroRouter();

        testEnvironment = new MockHyperlaneEnvironment(
            hlOriginDomain,
            hlDestinationDomain
        );

        originRouter.initialize(
            address(testEnvironment.mailboxes(hlOriginDomain)),
            address(testEnvironment.igps(hlOriginDomain)),
            address(testEnvironment.isms(hlOriginDomain))
        );

        destinationRouter.initialize(
            address(testEnvironment.mailboxes(hlDestinationDomain)),
            address(testEnvironment.igps(hlDestinationDomain)),
            address(testEnvironment.isms(hlDestinationDomain))
        );

        console.log("Origin Router Address: %s", address(originRouter));
        console.log(
            "Origin Mailbox: %s",
            address(testEnvironment.mailboxes(hlOriginDomain))
        );
        console.log(
            "Destination Router Address: %s",
            address(destinationRouter)
        );
        console.log(
            "Destination Mailbox: %s",
            address(testEnvironment.mailboxes(hlDestinationDomain))
        );

        uint16[] memory lzDomains = new uint16[](2);
        lzDomains[0] = lzOriginDomain;
        lzDomains[1] = lzDestinationDomain;

        uint32[] memory hlDomains = new uint32[](2);
        hlDomains[0] = hlOriginDomain;
        hlDomains[1] = hlDestinationDomain;

        originRouter.mapDomains(lzDomains, hlDomains);
        destinationRouter.mapDomains(lzDomains, hlDomains);

        originRouter.enrollRemoteRouter(
            hlDestinationDomain,
            TypeCasts.addressToBytes32(address(destinationRouter))
        );
        destinationRouter.enrollRemoteRouter(
            hlOriginDomain,
            TypeCasts.addressToBytes32(address(originRouter))
        );

        mockLzReceiver = new MockLzReceiver();

        //Set expected gas usage
        // uint256 gasEstimate = 10505;
        // originRouter.setEstGasAmount(gasEstimate);
        // destinationRouter.setEstGasAmount(gasEstimate);
    }

    function testCanSendReceiveMessage() public {
        // uint256 gasValue = 200000000;
        
        address remoteAddr = address(mockLzReceiver);
        address senderAddr = msg.sender;
        bytes memory destination = abi.encodePacked(remoteAddr, senderAddr);

        console.log("Recipient: %s", remoteAddr);
        console.log("Sender: %s", senderAddr);
        vm.startPrank(senderAddr);

        bytes memory payload = abi.encode("");

        (uint256 gasValue, ) = originRouter.estimateFees(lzDestinationDomain, remoteAddr, payload, false, "");
        // gasValue += 100000;
        console.log("Gas Value: %s", gasValue);
        originRouter.send{value: gasValue}(
            lzDestinationDomain,
            destination,
            payload,
            payable(address(0)),
            address(0),
            ""
        );

        bytes32 senderAsBytes32 = TypeCasts.addressToBytes32(
            address(originRouter)
        );
        bytes memory messageBody = abi.encode(remoteAddr, msg.sender, payload);

        vm.expectCall(
            address(destinationRouter),
            abi.encodeWithSelector(
                destinationRouter.handle.selector,
                hlOriginDomain,
                senderAsBytes32,
                messageBody
            )
        );
        testEnvironment.processNextPendingMessage();

        assertEq(mockLzReceiver.lastData(), payload);
        assertEq(mockLzReceiver.lastSender(), abi.encode(senderAddr));
        
        bytes memory destinationAs32 = abi.encode(address(mockLzReceiver));

        originRouter.send{value: gasValue}(
            lzDestinationDomain,
            destinationAs32,
            payload,
            payable(address(0)),
            address(0),
            ""
        );

        vm.expectCall(
            address(destinationRouter),
            abi.encodeWithSelector(
                destinationRouter.handle.selector,
                hlOriginDomain,
                senderAsBytes32,
                messageBody
            )
        );
        testEnvironment.processNextPendingMessage();

        assertEq(mockLzReceiver.lastData(), payload);
        assertEq(mockLzReceiver.lastSender(), abi.encode(senderAddr));
    }
    function testMapping() public {
        domainMapping(originRouter, ".all");
        domainMapping(destinationRouter, ".all");

        assertEq(originRouter.getHyperlaneDomain(101), 1);
        assertEq(destinationRouter.getHyperlaneDomain(125), 42220);
        
        assertEq(originRouter.getLayerZeroDomain(56), 102);
        assertEq(destinationRouter.getLayerZeroDomain(43114), 106);

        assertEq(destinationRouter.getHyperlaneDomain(10132), 420);
        assertEq(destinationRouter.getHyperlaneDomain(10143), 421613);

        assertEq(destinationRouter.getLayerZeroDomain(1287), 10126);
        assertEq(destinationRouter.getLayerZeroDomain(80001), 10109);
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
            // console.log("Network: %s", list[i]);
            // console.log("LZ: %s", lzDomains[i]);
            // console.log("HL: %s", hlDomains[i]);    
        }

        _router.mapDomains(lzDomains, hlDomains);
    }
}
