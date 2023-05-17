import "./tasks/accounts"

import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";

import { resolve } from "path";

import { config as dotenvConfig } from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import { NetworkUserConfig } from "hardhat/types";

dotenvConfig({ path: resolve(__dirname, "./.env") });

const chainIds = {
  goerli: 5,
  hardhat: 31337,
  kovan: 42,
  mainnet: 1,
  rinkeby: 4,
  ropsten: 3,
  sepolia: 11155111,
  cantotestnet: 7701,
  'polygon-mumbai': 80001,
};

// Ensure that we have all the environment variables we need.
const private_key = process.env.PRIVATE_KEY;
if (!private_key) {
  throw new Error("Please set your MNEMONIC in a .env file");
}

const infuraApiKey = process.env.INFURA_API_KEY;
if (!infuraApiKey) {
  throw new Error("Please set your INFURA_API_KEY in a .env file");
}

const etherscanApiKey = process.env.ETHERSCAN_API_KEY;
if (!etherscanApiKey) {
  throw new Error("Please set your ETHERSCAN_API_KEY in a .env file");
}

function getChainConfig(chainIds) {
  var url;
  if(network == 'cantotestnet') {
    url = 'http://canto-testnet.plexnode.wtf';
  } else {
    url = "https://" + network + ".infura.io/v3/" + infuraApiKey;
  }
  return {
    accounts: [private_key],
    chainId: chainIds[network],
    url,
  };
}

const config = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      accounts: [],
      chainId: chainIds.hardhat,
      gas: "auto",
      blockGasLimit: 1000000000000
    },
    goerli: getChainConfig("goerli"),
    kovan: getChainConfig("kovan"),
    mainnet: getChainConfig("mainnet"),
    rinkeby: getChainConfig("rinkeby"),
    ropsten: getChainConfig("ropsten"),
    'polygon-mumbai': getChainConfig("polygon-mumbai"),
    sepolia: getChainConfig("sepolia"),
    cantotestnet: getChainConfig("cantotestnet")
  },
  etherscan: {
    apiKey: etherscanApiKey
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    version: "0.8.19",
    settings: {
      metadata: {
        // Not including the metadata hash
        bytecodeHash: "none",
      },
      // Disable the optimizer when debugging
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },
  typechain: {
    outDir: "src/types",
    target: "ethers-v5",
  },
};

export default config;
