// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {MockHyperlaneEnvironment, MockMailbox} from "@hyperlane-xyz/core/contracts/mock/MockHyperlaneEnvironment.sol";

import {AxelarRouter} from "../src/AxelarRouter.sol";

import "forge-std/StdJson.sol";

contract AxelarRoutertest is Test {
    using stdJson for string;

    MockHyperlaneEnvironment testEnvironment;

    AxelarRouter originRouter;
    AxelarRouter destinationRouter;

    string axOriginDomain;
    string axDestinationDomain;

    uint32 hlOriginDomain;
    uint32 hlDestinationDomain;

    function getDomainIdForAx(string memory _network) internal returns (string memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/environment/axelar/domainId.json");
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", _network, ".axelar");
        return json.readString(key);
    }

    function getDomainIdForHl(string memory _network) internal returns (uint32) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/environment/axelar/domainId.json");
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", _network, ".hyperlane");
        return uint32(json.readUint(key));
    }

    function setUp() public {
        hlOriginDomain = getDomainIdForHl("arbitrumGoerli");
        axOriginDomain = getDomainIdForAx("arbitrumGoerli");

        hlDestinationDomain = getDomainIdForHl("mumbai");
        axDestinationDomain = getDomainIdForAx("mumbai");

        originRouter = new AxelarRouter();
        destinationRouter = new AxelarRouter();

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
        console.log("Origin Mailbox: %s", address(testEnvironment.mailboxes(hlOriginDomain)));
        console.log("Destination Router Address: %s", address(destinationRouter));
        console.log("Destination Mailbox: %s", address(testEnvironment.mailboxes(hlDestinationDomain)));

        string[] memory axDomains = new string[](2);
        axDomains[0] = axOriginDomain;
        axDomains[1] = axDestinationDomain;

        uint32[] memory hlDomains = new uint32[](2);
        hlDomains[0] = hlOriginDomain;
        hlDomains[1] = hlDestinationDomain;

        originRouter.mapDomains(axDomains, hlDomains);
        destinationRouter.mapDomains(axDomains, hlDomains);

        originRouter.enrollRemoteRouter(hlDestinationDomain, TypeCasts.addressToBytes32(address(destinationRouter)));
        destinationRouter.enrollRemoteRouter(hlOriginDomain, TypeCasts.addressToBytes32(address(originRouter)));
    }

    function testCanSendReceiveMessage() public {
        uint256 estGasAmount = 2000000;

        address remoteAddr = address(destinationRouter);

        address senderAddr = msg.sender;
        // string memory destination = vm.toString(remoteAddr);
        string memory destination = "0x2e234DAe75C793f67A35089C9d99245E1C58470b";
        console.log("Destination: %s", destination);

        console.log("Recipient: %s", remoteAddr);
        console.log("Sender: %s", senderAddr);
        vm.startPrank(senderAddr);

        bytes memory payload = abi.encode("");

        uint256 gasValue = originRouter.quoteGasPayment(axDestinationDomain, estGasAmount);

        console.log("Gas Value: %s", gasValue);
        originRouter.callContractwithGas{value: gasValue}(axDestinationDomain, destination, payload);

        bytes32 senderAsBytes32 = TypeCasts.addressToBytes32(address(originRouter));

        bytes memory messageBody = abi.encode(remoteAddr, payload);

        vm.expectCall(
            address(destinationRouter),
            abi.encodeWithSelector(destinationRouter.handle.selector, hlOriginDomain, senderAsBytes32, messageBody)
        );
        testEnvironment.processNextPendingMessage();

        assertEq(destinationRouter.sourceChain(), axOriginDomain);
        // assertEq(destinationRouter.sourceAddress(), destination);
    }

    function testMapping() public {
        domainMapping(originRouter, ".mainnet");
        domainMapping(destinationRouter, ".mainnet");

        assertEq(originRouter.getHyperlaneDomain("Ethereum"), 1);
        assertEq(destinationRouter.getHyperlaneDomain("celo"), 42220);

        assertEq(originRouter.getAxelarDomain(56), "binance");
        assertEq(destinationRouter.getAxelarDomain(43114), "Avalanche");

        domainMapping(originRouter, ".testnet");
        domainMapping(destinationRouter, ".testnet");

        assertEq(destinationRouter.getHyperlaneDomain("optimism"), 420);
        assertEq(destinationRouter.getHyperlaneDomain("arbitrum"), 421613);

        assertEq(destinationRouter.getAxelarDomain(1287), "Moonbeam");
        assertEq(destinationRouter.getAxelarDomain(80001), "Polygon");
    }

    function domainMapping(AxelarRouter _router, string memory _networkList) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/environment/axelar/domainId.json");
        string memory json = vm.readFile(path);

        string[] memory list = json.readStringArray(_networkList);

        string[] memory axDomains = new string[](list.length);
        uint32[] memory hlDomains = new uint32[](list.length);
        string memory key;
        for (uint256 i = 0; i < list.length; i++) {
            key = string.concat(".", list[i], ".axelar");
            axDomains[i] = json.readString(key);
            key = string.concat(".", list[i], ".hyperlane");
            hlDomains[i] = uint32(json.readUint(key));
            // console.log("Network: %s", list[i]);
            // console.log("AX: %s", axDomains[i]);
            // console.log("HL: %s", hlDomains[i]);
        }

        _router.mapDomains(axDomains, hlDomains);
    }
}
