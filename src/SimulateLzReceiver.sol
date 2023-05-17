// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILayerZeroReceiver} from "./interfaces/ILayerZeroReceiver.sol";

import "forge-std/console.sol";

/**
 * @title SimulateLzReceiver
 * @notice SimulateLzReceiver for testing and showcasing how lzReceive would work
 */

contract SimulateLzReceiver is ILayerZeroReceiver {
    bytes public lastSender;
    bytes public lastData;

    address public lastCaller;
    string public lastCallMessage;

    event ReceivedMessage(
        uint32 indexed origin,
        bytes indexed sender,
        string message
    );

     function lzReceive(
         uint16 _srcChainId,
         bytes calldata _srcAddress,
         uint64 _nonce,
         bytes calldata _payload
     ) external override {
        console.log("SimulateLzReceiver.lzReceive called");
        emit ReceivedMessage(_srcChainId, _srcAddress, string(_payload));

        lastSender = _srcAddress;
        lastData = _payload;
     }
 }