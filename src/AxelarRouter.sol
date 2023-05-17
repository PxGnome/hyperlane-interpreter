// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Router} from "@hyperlane-xyz/core/contracts/Router.sol";
import {IAxelarGateway, IAxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarExecutable.sol';
import {StringToAddress, AddressToString} from '@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/AddressString.sol';

import "forge-std/console.sol";

/**
 * @notice Simulate the receiver portion of AxelarExecutable contract
 * @dev This needs to be adjusted to suit your needs
 */
contract SimulateAxelarExecutable {
    string public value;
    string public sourceChain;
    string public sourceAddress;
    string public tokenSymbol;
    uint256 amount;

    function _execute(
        string memory sourceChain_,
        string memory sourceAddress_,
        bytes memory payload_
    ) internal {
        console.log("SimulateAxelarExecutable._execute called");
        console.log("sourceChain_:", sourceChain_);
        console.log("sourceAddress_:", sourceAddress_);

        (value) = abi.decode(payload_, (string));
        sourceChain = sourceChain_;
        sourceAddress = sourceAddress_;
    }

    function _executeWithToken(
        string memory sourceChain_,
        string memory sourceAddress_,
        bytes memory payload_,
        string memory tokenSymbol_,
        uint256 amount_
    ) internal {
        console.log("SimulateAxelarExecutable._executeWithToken called");
        (value) = abi.decode(payload_, (string));
        sourceChain = sourceChain_;
        sourceAddress = sourceAddress_;
        tokenSymbol = tokenSymbol_;
        amount = amount_;
    }
}
/**
 * @notice The AxelarRouter contract
 * @dev This contract is a router dressed in Axelar's Gateway
 */
contract AxelarRouter is Router, SimulateAxelarExecutable {
    mapping(string => uint32) public axelarToHyperlaneDomain;
    mapping(uint32 => string) public hyperlaneToAxelarDomain;

    error AxelarDomainNotMapped(string);
    error HyperlaneDomainNotMapped(uint32);

    uint256 estGasAmount = 20000000; //The default from testing

    /**
     * @notice Initializes the LayerZeroRouter
     * @param _mailbox The address of the mailbox contract
     * @param _interchainGasPaymaster The address of the interchain gas paymaster contract
     * @param _interchainSecurityModule The address of the interchain security module contract
     */
    function initialize(
        address _mailbox,
        address _interchainGasPaymaster,
        address _interchainSecurityModule
    ) external initializer {
        __Router_initialize(
            _mailbox,
            _interchainGasPaymaster,
            _interchainSecurityModule
        );
    }

    event ContractCall(
        address indexed sender,
        string destinationChain,
        string destinationContractAddress,
        bytes32 indexed payloadHash,
        bytes payload
    );

    function callContract(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload
    ) external {
        uint32 dstChainId32 = axelarToHyperlaneDomain[destinationChain];
        address toAddress = StringToAddress.toAddress(contractAddress);
        bytes memory messageBody = abi.encode(toAddress, payload);
        bytes32 messageId = _dispatch(dstChainId32, messageBody);
        bytes32 messageHash = generateMessageHash(msg.sender, destinationChain, contractAddress, payload);
        getMessageId[messageHash] = messageId;
    }

    function callContractwithGas(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload
    ) external payable {
        uint32 dstChainId32 = axelarToHyperlaneDomain[destinationChain];
        uint256 gasPayment = interchainGasPaymaster.quoteGasPayment(
            dstChainId32,
            estGasAmount
        );
        require(msg.value >= gasPayment, "Not enough gas");
        address toAddress = StringToAddress.toAddress(contractAddress);
        bytes memory messageBody = abi.encode(toAddress, payload);
        bytes32 messageId = _dispatch(dstChainId32, messageBody);

        interchainGasPaymaster.payForGas{ value: msg.value }(
            messageId, 
            dstChainId32,
            estGasAmount,
            msg.sender 
        );
    }

    mapping(bytes32 => bytes32) public getMessageId;

    function generateMessageHash(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload
    ) public returns (bytes32 messageHash) {
        messageHash = keccak256(abi.encodePacked(sender, destinationChain, destinationAddress, payload));
    }

    function getMessageIdFromHash(bytes32 messageHash) external returns (bytes32) {
        return getMessageId[messageHash];
    }

    function payNativeGasForContractCall(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        address refundAddress
    ) external payable {
        uint32 dstChainId32 = axelarToHyperlaneDomain[destinationChain];
        bytes32 messageHash = generateMessageHash(sender, destinationChain, destinationAddress, payload);

        interchainGasPaymaster.payForGas{ value: msg.value }(
            getMessageId[messageHash], 
            dstChainId32,
            estGasAmount,
            msg.sender 
        );
    }

    function quoteGasPayment(
        string memory _dstChainId,
        uint256 _estGasAmount
    ) public view returns (uint256) {   
        uint32 dstChainId32 = axelarToHyperlaneDomain[_dstChainId];
        return (
            interchainGasPaymaster.quoteGasPayment(
                dstChainId32,
                estGasAmount
            )
        );
    }

    /**
     * @notice Sets the gas amount for the estimateFees function since this will depend upon gas your lzreceive() uses
     * @dev Used for showcase and testing suggest editing getGasAmount
     * @param _gas The amount of gas to set
     */
    function setEstGasAmount(uint256 _gas) external onlyOwner {
        estGasAmount = _gas;
    }

    /**
     * @notice Gets the gas amount for the estimateFees function
     * @dev Please override this to however you wish to calculate your gas usage on destiniation chain
     * @param _payload The payload to be sent to the destination chain
     */

    function getEstGasAmount(bytes memory _payload)
        public
        view
        returns (uint256)
    {
        return estGasAmount;
    }

    /**
     * @notice Adds a domain ID mapping from axelarDomain/hyperlaneDomain domain IDs and vice versa
     * @param _hyperlaneDomains An array of axelarDomain domain IDs
     * @param _hyperlaneDomains An array of hyperlaneDomain domain IDs
     */
    function mapDomains(
        string[] calldata _axelarDomains,
        uint32[] calldata _hyperlaneDomains
    ) external onlyOwner {
        for (uint256 i = 0; i < _axelarDomains.length; i += 1) {
            axelarToHyperlaneDomain[_axelarDomains[i]] = _hyperlaneDomains[i];
            hyperlaneToAxelarDomain[_hyperlaneDomains[i]] = _axelarDomains[i];
        }
    }

    /**
     * @notice Gets Axelar domain ID from hyperlane domain ID
     * @param _hyperlaneDomain The hyperlane domain ID
     */
    function getAxelarDomain(uint32 _hyperlaneDomain)
        public
        view
        returns (string memory axelarDomain)
    {
        axelarDomain = hyperlaneToAxelarDomain[_hyperlaneDomain];
        if (bytes(axelarDomain).length == 0) {
            revert HyperlaneDomainNotMapped(_hyperlaneDomain);
        }
    }

    /**
     * @notice Gets hyperlane domain ID from layerZero domain ID
     * @param _axelarDomain The layerZero domain ID
     */
    function getHyperlaneDomain(string memory _axelarDomain)
        public
        view
        returns (uint32 hyperlaneDomain)
    {
        hyperlaneDomain = axelarToHyperlaneDomain[_axelarDomain];
        if (hyperlaneDomain == 0) {
            revert AxelarDomainNotMapped(_axelarDomain);
        }
    }

    function handle(
        uint32 _originHyperlaneDomain,
        bytes32 _router,
        bytes calldata _message
    )
        public
        override
        onlyMailbox
        onlyRemoteRouter(_originHyperlaneDomain, _router)
    {
        _handle(_originHyperlaneDomain, _router, _message);
    }

    function _handle(
        uint32 _originHyperlaneDomain,
        bytes32 _router, //NOTE: not used because it will always be router address
        bytes calldata _message
    ) internal override {
        string memory srcChainId = getAxelarDomain(_originHyperlaneDomain);
        (address to, bytes memory payload) = abi.decode(_message, (address, bytes));

        string memory toAddrString = AddressToString.toString(to);
        console.log("to: %s", toAddrString);

        _execute(srcChainId, toAddrString, payload);
    }

} 