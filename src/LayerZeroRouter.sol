// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {Router} from "@hyperlane-xyz/core/contracts/Router.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {ILayerZeroEndpoint} from "./interfaces/ILayerZeroEndpoint.sol";
import {ILayerZeroReceiver} from "./interfaces/ILayerZeroReceiver.sol";

/**
 * @title LayerZeroRouter
 * @notice Example of middleware to use hyperlane in a layerzero app on layerZero
 * @dev Implemented send() and a virtual lzReceive().
 * @dev Please make sure to edit lzReceive() and setEstGasAmount() to match gas usage of lzReceive() in your app
 * @dev Run `forge test --match-contract LayerZeroRouterTest` to see tests
 */
abstract contract LayerZeroRouter is Router, ILayerZeroEndpoint {
    mapping(uint16 => uint32) layerZeroToHyperlaneDomain;
    mapping(uint32 => uint16) hyperlaneToLayerZeroDomain;

    error LayerZeroDomainNotMapped(uint16);
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

    /**
     * @notice Adds a domain ID mapping from layerZeroDomain/hyperlaneDomain domain IDs and vice versa
     * @param _layerZeroDomains An array of layerZeroDomain domain IDs
     * @param _hyperlaneDomains An array of hyperlaneDomain domain IDs
     */
    function mapDomains(
        uint16[] calldata _layerZeroDomains,
        uint32[] calldata _hyperlaneDomains
    ) external onlyOwner {
        for (uint256 i = 0; i < _layerZeroDomains.length; i += 1) {
            layerZeroToHyperlaneDomain[
                _layerZeroDomains[i]
            ] = _hyperlaneDomains[i];
            hyperlaneToLayerZeroDomain[
                _hyperlaneDomains[i]
            ] = _layerZeroDomains[i];
        }
    }

    /**
     * @notice Gets layerZero domain ID from hyperlane domain ID
     * @param _hyperlaneDomain The hyperlane domain ID
     */
    function getLayerZeroDomain(uint32 _hyperlaneDomain)
        public
        view
        returns (uint16 layerZeroDomain)
    {
        layerZeroDomain = hyperlaneToLayerZeroDomain[_hyperlaneDomain];
        if (layerZeroDomain == 0) {
            revert HyperlaneDomainNotMapped(_hyperlaneDomain);
        }
    }

    /**
     * @notice Gets hyperlane domain ID from layerZero domain ID
     * @param _layerZeroDomain The layerZero domain ID
     */
    function getHyperlaneDomain(uint16 _layerZeroDomain)
        public
        view
        returns (uint32 hyperlaneDomain)
    {
        hyperlaneDomain = layerZeroToHyperlaneDomain[_layerZeroDomain];
        if (hyperlaneDomain == 0) {
            revert LayerZeroDomainNotMapped(_layerZeroDomain);
        }
    }

    /**
     * @notice handles the version Adapter Parameters for LayerZero
     * @param _adapterParams The adapter params used in LayerZero sends
     */
    function _interpretAdapterParamsV1(bytes memory _adapterParams)
        internal
        pure
        returns (uint256 gasAmount)
    {
        uint16 version;
        require(_adapterParams.length == 34, "Please check your adapterparams");
        (version, gasAmount) = abi.decode(_adapterParams, (uint16, uint256));
    }

    /**
     * @notice handles the version Adapter Parameters for LayerZero
     * @param _adapterParams The adapter params used in LayerZero sends
     */
    function _interpretAdapterParamsV2(bytes memory _adapterParams)
        internal
        pure
        returns (
            uint256 gasAmount,
            uint256 nativeForDst,
            address addressOnDst
        )
    {
        require(_adapterParams.length == 86, "Please check your adapterparams");
        uint16 version;
        (version, gasAmount, nativeForDst, addressOnDst) = abi.decode(
            _adapterParams,
            (uint16, uint256, uint256, address)
        );
    }

    function splitAddress(bytes memory hexString)
        public
        pure
        returns (address, address)
    {
        // bytes memory byteArray = bytes(hexString);
        require(
            hexString.length == 40,
            "Input string must be 40 characters long"
        );

        bytes20 firstAddress;
        bytes20 secondAddress;

        assembly {
            firstAddress := mload(add(hexString, 0x20))
            secondAddress := mload(add(hexString, 0x30))
        }

        return (address(firstAddress), address(secondAddress));
    }

    /**
     * @notice Sends a hyperlane message using LayerZero endpoint interface
     * @dev NOTE: Layerzero's documentation is inconsistent in github vs docs. Following: https://layerzero.gitbook.io/docs/evm-guides/master/how-to-send-a-message
     * @param _dstChainId - the destination chain identifier
     * @param _remoteAndLocalAddresses - remote address concated with local address packed into 40 bytes
     * @param _payload - the payload to be sent to the destination chain
     * @param _refundAddress - the address to refund the gas fees to
     * @param _zroPaymentAddress - not used (only for LayerZero)
     * @param _adapterParams - the adapter params used in LayerZero sends
     */
    function send(
        uint16 _dstChainId,
        bytes memory _remoteAndLocalAddresses,
        bytes calldata _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) external payable override {
        uint32 dstChainId32 = layerZeroToHyperlaneDomain[_dstChainId];
        address remoteAddr;
       
        if (_remoteAndLocalAddresses.length == 40) {
             address localAddr;
            (remoteAddr, localAddr) = splitAddress(_remoteAndLocalAddresses);
        } else if (_remoteAndLocalAddresses.length == 32) {
            remoteAddr = abi.decode(_remoteAndLocalAddresses, (address));
        } else {
            revert("Invalid remote and local addresses");
        }

        bytes memory messageBody = abi.encode(remoteAddr, msg.sender, _payload);
        uint256 gasAmount;
        uint256 gasPayment;

        if (_adapterParams.length > 0) {
            if (_adapterParams.length == 33) {
                gasAmount = _interpretAdapterParamsV1(_adapterParams);
            } else if (_adapterParams.length == 86) {
                address addressOnDst;
                (
                    gasAmount,
                    gasPayment,
                    addressOnDst
                ) = _interpretAdapterParamsV2(_adapterParams);
            } else {
                revert("Invalid adapter params");
            }
        } else {
            gasPayment = interchainGasPaymaster.quoteGasPayment(
                dstChainId32,
                estGasAmount
            );
        }

        require(msg.value >= gasAmount, "Not enough gas");
        _dispatchWithGas(
            dstChainId32,
            messageBody,
            estGasAmount,
            gasPayment,
            _refundAddress
        );
        
    }

    /**
     * @notice The internal Router `handle` function which extracts the true recipient of the message and passes the translated hyperlane domain ID to lzReceive
     * @param _originHyperlaneDomain the origin domain as specified by Hyperlane
     * @param _router The layer zero router address
     * @param _message The wrapped message to include sender and recipient
     */
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
        uint16 srcChainId = getLayerZeroDomain(_originHyperlaneDomain);
        (address to, address from, bytes memory payload) = abi.decode(_message, (address, address, bytes));
        bytes memory srcAddress = abi.encode(from);
        ILayerZeroReceiver(to).lzReceive(srcChainId, srcAddress, 0, payload); //NOTE: nonce is not part of hyperlane so will be zero
    }

    /**
     * @notice Gets a quote in source native gas, for the amount that send() requires to pay for message delivery
     * @dev override from ILayerZeroEndpoint.sol
     * @param _dstChainId - the destination chain identifier
     * @param _userApplication - the user app address on this EVM chain
     * @param _payload - the custom message to send over LayerZero
     * @param _payInZRO - if false, user app pays the protocol fee in native token
     * @param _adapterParams - parameters for the adapter service, e.g. send some dust native token to dstChain
     */
    function estimateFees(
        uint16 _dstChainId,
        address _userApplication,
        bytes memory _payload,
        bool _payInZRO,
        bytes memory _adapterParams
    ) public view override returns (uint256 nativeFee, uint256 zroFee) {        
        require(estGasAmount > 0, "Please set gas amount");
        return (
            interchainGasPaymaster.quoteGasPayment(
                layerZeroToHyperlaneDomain[_dstChainId],
                estGasAmount
            ),
            0
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
     * @notice Gets the chain ID of the current chain
     * @dev override from ILayerZeroEndpoint.sol -- NOTE OVERFLOW RISK
     */
    function getChainId() external view override returns (uint16) {
        return hyperlaneToLayerZeroDomain[mailbox.localDomain()];
    }

    /**
     * @notice Gets the mailbox count this source chain since hyperlane does not have nonce
     * @dev override from ILayerZeroEndpoint.sol
     * @param _dstChainId - the destination chain identifier
     * @param _srcAddress - the source chain contract address
     *
     */
    function getOutboundNonce(uint16 _dstChainId, address _srcAddress)
        external
        view
        returns (uint64)
    {
        return uint64(mailbox.count());
    }
}
