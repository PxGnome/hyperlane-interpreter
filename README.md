# hyperlane-interpreter


## Overview ##
This is intended to be library of routers that is built based on [Hyperlane's Router](https://docs.hyperlane.xyz/docs/apis-and-sdks/building-applications/writing-contracts/router) and works to replacing other messaging protocols with Hyperlane protocol. This allows easier migration of your contract and works as follow:

![Diagram](https://i.imgur.com/0PGgdGN.png)

For more information on how Hyperlane works please check out: [Hyperlane Doc](https://docs.hyperlane.xyz/docs/introduction/readme)


## How To Use ##
Begin by cloning the repo:


`git clone https://github.com/PxGnome/hyperlane-interpreter.git`


### To Test ###

To run tests to see how it works you can run

```forge test```

### To Deploy LayerZero Router ###


#### Using Hardhat (Recommended) ####

To deploy using the deployment scripts you can use the hardhat tasks (more info [here](https://hardhat.org/hardhat-runner/docs/advanced/create-task)) and can be done using the command:


```npx hardhat ${TASK_NAME} ${PARAMETERS}``` 


Here are the current tasks (be sure to replace your parameters):
1. `lzrouter_deploy` - you can use this to deploy your LayerZero router, it includes deployment, initialized routers and domain mapping
2. `lzrouter_enroll ${originRouterAddr} ${destinationNetwork} ${enrollRouterAddr}` - for enrolling router after you it has been deployed
3. `lzrouter_sendMessage ${originRouterAddr} ${destinationNetwork} ${enrollRouterAddr} ${message}` - for sending a test message on your router to ensure it works


Below are some other tasks to help deployment if there are issues:
1. `lzrouter_init ${lzRouterAddr}` - you can use this to initialize LayerZero router if the deployment did not manage to do so
2. `lzrouter_mapping ${lzRouterAddr} ${mappingFor}` - you can use this to handle the domain mapping for LayerZero router if the deployment did not manage to do so


To see the code for the task you can head to the `tasks` folder.




#### Using Foundry ####

To deploy using the deployment scripts you will need to set up an `.env` file just like the `.env.example.` and use the files in `script` folder
- `script/01_Deploy_LayerZeroRouter.s.sol` -- This handles the deployment and needs to be done step by step since it is written in foundry
- `script/02_Test_LayerZeroRouter.s.sol` -- This uses the deployed routers to send some test messages which can be seen on [Hyperlane Explorer](https://explorer.hyperlane.xyz/)

To understand how this works please take a look at the `script` folder in which each deployment is split up one by one by functions.


## How It Works ##
Library is set up using the foundry file structure and it is advised you take a look at these files and edit as you see fit in order to make it suit your needs. The main files you will be interested in are:


### LayerZeroRouter.sol ###
This is the file with the core logic as it is designed based on:
- Hyperlane's `Router` -- Inherits from this, so has all the base configuration to make it work on any chain
- LayerZero's `ILayerZeroEndpoint` -- Designed to work with the standard necessary and supported LayerZero endpoints.

Note that some of the non-core features on `ILayerZeroEndpoint` are not supported by Hyperlane.

Also the following custom functions may need attention:
- `setEstGasAmount` -- Default gas is set to be 200,000 wei by default but you can set a higher gas if your computation on the destination chain is more complex



### SimulateLzReceiver.sol ###

This is to simulate the LzReceiver and is used in testing so you can see how the LayerZeroRouter interacts with the lzReceiver accordingly.



### Other Files of Note ###
Some other files of note:
- `environment/hyperlane/addresses.json` -- list of all the addresses of the Mailbox, InterchainPaymaster and InterSecurityModule for Hyperlane
- `environment/layerzero/domainId.json` -- list of all the domain Ids supported by HyperLane and LayerZero


## Update Log ##

- **2023 May 27** -- Added hardhat and deploy script using typescript to make it easier to deploy.


- **2023 May 18** -- Added AxelarRouter and finished basic unit testing but pending live deployment testing, will work on hardhat deployment as well for both set of code. Will be submitting for this bounty as well ([link](https://github.com/hyperlane-xyz/hyperlane-monorepo/issues/2186))


- **2023 May 15** -- Initial deployment and preparation for submission for Hyperlane bounty on LayerZero implementation ([link](https://github.com/hyperlane-xyz/hyperlane-monorepo/issues/2185))

