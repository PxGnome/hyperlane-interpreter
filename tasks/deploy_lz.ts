import { task } from "hardhat/config";
import { Signer } from "@ethersproject/abstract-signer";

import hlAddressesJson from '../environment/hyperlane/addresses.json';
import lzDomainIdJson from '../environment/layerzero/domainId.json';

task("lzrouter_deploy", "deploy router")
  .addPositionalParam("isMainnet")
  .setAction(async (_taskArgs, hre) => {
    const accounts: Signer[] = await hre.ethers.getSigners();

    const owner = accounts[0];
    const networkName = hre.network.name;

    console.log("Deploying on network: %s", networkName);

    const LzRouter = await hre.ethers.getContractFactory("LayerZeroRouter");
    const lzRouter = await LzRouter.connect(owner).deploy();
    console.log("LayerZero Router Address: %s", lzRouter.address);

    console.log("lzRouter deployed at: ", lzRouter.address);
    console.log("Initializing lzRouter: %s", lzRouter.address);

    await lzRouter.connect(owner).initialize(
      hlAddressesJson[networkName].mailbox,
      hlAddressesJson[networkName].igp,
      hlAddressesJson[networkName].ism,
    );
    console.log("LayerZero Router initialized");

    console.log("Mapping Routers");

    var hlDomains = [] as string[];
    var lzDomains = [] as string[];

    var listOfNetwork = lzDomainIdJson[_taskArgs.mappingFor];
    console.log("Mapping for: ", _taskArgs.mappingFor);
    for (var i in listOfNetwork) {
      lzDomains.push(lzDomainIdJson[listOfNetwork[i]]['layerzero']);
      hlDomains.push(lzDomainIdJson[listOfNetwork[i]]['hyperlane']);
    }

    for (var i in listOfNetwork) {
      lzDomains.push(lzDomainIdJson[listOfNetwork[i]]['layerzero']);
      hlDomains.push(lzDomainIdJson[listOfNetwork[i]]['hyperlane']);
    }

    await lzRouter.connect(owner).mapDomains(lzDomains, hlDomains);
    console.log("Domain Mapping done");

    console.log("Router Setup Complete")
  });

task("lzrouter_init", "init router if failed during deploy")
  .addPositionalParam("lzRouterAddr")
  .setAction(async (_taskArgs, hre) => {
    const accounts: Signer[] = await hre.ethers.getSigners();
    const owner = accounts[0];
    const networkName = hre.network.name;

    console.log("Executing on network: %s", networkName);
    const lzRouterAddr = _taskArgs.lzRouterAddr;

    const lzRouter = await hre.ethers.getContractAt("LayerZeroRouter", lzRouterAddr);
    console.log("LayerZero Router Address: %s", lzRouter.address);

    console.log("Initializing lzRouter: %s", lzRouter.address);

    await lzRouter.connect(owner).initialize(
      hlAddressesJson[networkName].mailbox,
      hlAddressesJson[networkName].igp,
      hlAddressesJson[networkName].ism,
    );
    console.log("LayerZero Router initialized");
  });


task("lzrouter_mapping", "mapping router if failed during deploy")
  .addPositionalParam("lzRouterAddr")
  .addPositionalParam("mappingFor")
  .setAction(async (_taskArgs, hre) => {
    const accounts: Signer[] = await hre.ethers.getSigners();
    // npx hardhat lzrouter_mapping 0xDddD17bDeF830103846f89cF61d362A689195c29 testnet
    const owner = accounts[0];
    const networkName = hre.network.name;

    console.log("Executing on network: %s", networkName);

    const lzRouterAddr = _taskArgs.lzRouterAddr;

    const lzRouter = await hre.ethers.getContractAt("LayerZeroRouter", lzRouterAddr);
    console.log("LayerZero Router Address: %s", lzRouter.address);

    console.log("Mapping Routers");

    var hlDomains = [] as string[];
    var lzDomains = [] as string[];

    var listOfNetwork = lzDomainIdJson[_taskArgs.mappingFor];
    console.log("Mapping for: ", _taskArgs.mappingFor);
    for (var i in listOfNetwork) {
      lzDomains.push(lzDomainIdJson[listOfNetwork[i]]['layerzero']);
      hlDomains.push(lzDomainIdJson[listOfNetwork[i]]['hyperlane']);
    }

    await lzRouter.connect(owner).mapDomains(lzDomains, hlDomains);
    console.log("Domain Mapping done");
  });

task("lzrouter_enroll", "enroll router")
  .addPositionalParam("originRouterAddr")
  .addPositionalParam("destinationNetwork")
  .addPositionalParam("enrollRouterAddr")
  .setAction(async (_taskArgs, hre) => {
    const accounts: Signer[] = await hre.ethers.getSigners();

    const owner = accounts[0];

    // npx hardhat lzrouter_enroll 0xDddD17bDeF830103846f89cF61d362A689195c29 mumbai 0x695b3e0da6823093d4A7d6628CdDFb37aa8CA907 --network sepolia

    const networkName = hre.network.name;
    console.log("Executing on network: %s", networkName);

    const originRouterAddr = _taskArgs.originRouterAddr;
    const destinationNetwork = _taskArgs.destinationNetwork;
    const enrollRouterAddr = _taskArgs.enrollRouterAddr;

    const hlDestinationDomain = lzDomainIdJson[destinationNetwork]['hyperlane'];

    console.log("Enrolling Router: %s for domain Id: %s", enrollRouterAddr, hlDestinationDomain);


    const lzRouter = await hre.ethers.getContractAt("LayerZeroRouter", originRouterAddr);
    var addressAsBytes32 = hre.ethers.utils.defaultAbiCoder.encode(["address"], [enrollRouterAddr])
    await lzRouter.connect(owner).enrollRemoteRouter(hlDestinationDomain, addressAsBytes32);
    console.log("Enroll complete");
  });

task("lzrouter_sendMessage", "Send Message using Lz Router")
  .addPositionalParam("originRouterAddr")
  .addPositionalParam("destinationNetwork")
  .addPositionalParam("destinationAddr")
  .addPositionalParam("message")
  .setAction(async (_taskArgs, hre) => {
    const accounts: Signer[] = await hre.ethers.getSigners();

    const owner = accounts[0];

    // npx hardhat lzrouter_sendMessage 0xDddD17bDeF830103846f89cF61d362A689195c29 mumbai 0x695b3e0da6823093d4A7d6628CdDFb37aa8CA907 abc --network sepolia

    const networkName = hre.network.name;

    console.log("Executing on network: %s", networkName);

    const originRouterAddr = _taskArgs.originRouterAddr;
    const destinationNetwork = _taskArgs.destinationNetwork;
    const destinationAddr = _taskArgs.destinationAddr;
    const message = _taskArgs.message;

    console.log("Send Message to: %s", destinationAddr);
    console.log("Message: %s", message);

    const lzDestinationDomain = lzDomainIdJson[destinationNetwork]['layerzero'];

    const lzRouter = await hre.ethers.getContractAt("LayerZeroRouter", originRouterAddr);

    var payload = hre.ethers.utils.arrayify(hre.ethers.utils.toUtf8Bytes(message));

    var adapterParams = hre.ethers.utils.arrayify(hre.ethers.utils.toUtf8Bytes(''));

    var gasPayment = await lzRouter.estimateFees(lzDestinationDomain, destinationAddr, payload, false, adapterParams);

    console.log("Gas Value: %s", gasPayment.nativeFee);

    var destinationAddrAsBytes32 = hre.ethers.utils.solidityPack(["address", "address"], [originRouterAddr, destinationAddr]);

    var messageId = await lzRouter.send(
      lzDestinationDomain,
      destinationAddrAsBytes32,
      payload,
      owner.address,
      hre.ethers.constants.AddressZero,
      adapterParams,
      { value: gasPayment.nativeFee }
    );

    console.log("Message Sent %s", messageId);
  });
