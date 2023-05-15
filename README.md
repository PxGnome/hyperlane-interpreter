# hyperlane-interpreter


**Update:**


- **2023 May 15** -- Initial deployment and preparation for submission for Hyperlane bounty on LayerZero implementation ([link](https://github.com/hyperlane-xyz/hyperlane-monorepo/issues/2185))


## Overview ##
This is intended to be library of routers that is built based on [Hyperlane's Router](https://docs.hyperlane.xyz/docs/apis-and-sdks/building-applications/writing-contracts/router) and works to replacing other messaging protocols with Hyperlane protocol. This allows easier migration of your contract and works as follow:

![Diagram](https://i.imgur.com/0PGgdGN.png)

For more information on how Hyperlane works please check out: [Hyperlane Doc](https://docs.hyperlane.xyz/docs/introduction/readme)



## Explanation ##
Library is set up using the foundry file structure and the main files you will be interested in are:


### LayerZeroRouter.sol ###
This is the file with the core logic as it inherits from:
- Hyperlane's `Router` -- Has all the base configuration to make it work on any chain
- LayerZero's `ILayerZeroEndpoint` -- Ensures that it is usable to replace existing LayerZero endpoints.

However it is an abstract contract as some of the non-core features on `ILayerZeroEndpoint` are not supported by Hyperlane.


### MockLayerZeroRouter.sol ###


This is an example of how you can implement the LayerZeroRouter with all the base features and is used in all the deployment and testing.


### MockLzReceiver.sol ###


This is an example of a simple receiver built using the interface `ILayerZeroReceiver` to show case how the receive works just as normal.


### Other Files of Note ###
Some other files of note:
- `environment/layerzero/addresses.json` -- list of all the addresses of the Mailbox, InterchainPaymaster and InterSecurityModule for Hyperlane
- `environment/layerzero/domainId.json` -- list of all the domain Ids supported by HyperLane and LayerZero


## How To Use ##
Begin by cloning the repo:


`git clone https://github.com/PxGnome/hyperlane-interpreter.git`


To run tests to see how it works you can run


```forge test```

To deploy using the deployment scripts you will need to set up an `.env` file just like the `.env.example.` and use:
- `script/01_Deploy_LayerZeroRouter.s.sol` -- This handles the deployment and needs to be done step by step since it is written in foundry
- `script/02_Test_LayerZeroRouter.s.sol` -- This uses the deployed routers to send some test messages which can be seen on [Hyperlane Explorer](https://explorer.hyperlane.xyz/)

## Examples ##
### Contracts ###
- [MockerLayerZeroRouter on Sepolia](
https://sepolia.etherscan.io/address/0x060b3d668D108F4B8EB3214830378C9528736942)
- [MockerLayerZeroRouter on Mumbai](https://mumbai.polygonscan.com/address/0x83931a023ace2af8f799c61697c491c040422a0d)
- [MockLzReceive on Sepolia](
https://sepolia.etherscan.io/address/0x5f2de53c87189c653ca31235c06199c1757482b5)
- [MockLzReceive on Mumbai](https://mumbai.polygonscan.com/address/0xd0ef7e1f13ca989f726badd852345cb096a43b9f)

### Messages ###

- [Example Message](https://explorer.hyperlane.xyz/message/0x6346ef364ee68056a8df60d71980333042b349e3d5168021373a3e9a6ecef796) -- Mumbai :arrow_right: Sepolia
- [Example Message](https://explorer.hyperlane.xyz/message/0xe6571bb933b51372950a6284c907f13e2fbe195ad585799c97d10f461f98dc5d) -- Sepolia :arrow_right: Mumbai




