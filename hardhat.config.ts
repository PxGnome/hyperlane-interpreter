import "./tasks/deploy_lz"

import "@nomicfoundation/hardhat-toolbox";

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
    'mumbai': 80001,
    sepolia: 11155111
};

// Ensure that we have all the environment variables we need.
const mnemonic: string | undefined = process.env.MNEMONIC;
// if (!mnemonic) {
//     throw new Error("Please set your MNEMONIC in a .env file");
// }

const infuraApiKey: string | undefined = process.env.INFURA_API_KEY;
if (!infuraApiKey) {
    throw new Error("Please set your INFURA_API_KEY in a .env file");
}

const etherscanApiKey: string | undefined = process.env.ETHERSCAN_API_KEY;
if (!etherscanApiKey) {
    throw new Error("Please set your ETHERSCAN_API_KEY in a .env file");
}

// Ensure that we have all the environment variables we need.
var initialIndex: string | undefined = process.env.INITIAL_INDEX;
if (!initialIndex) {
    throw new Error("Please set your initialIndex in a .env file");
}

function getChainConfig(network: keyof typeof chainIds): NetworkUserConfig {
    var url: string;
    if (network == 'mumbai') {
        url = "https://polygon-mumbai.infura.io/v3/" + infuraApiKey;
    } else {
        url = "https://" + network + ".infura.io/v3/" + infuraApiKey;
    }
    const privateKey: string | undefined = process.env.PRIVATE_KEY;
    if (privateKey) {
        return {
            accounts: [privateKey],
            chainId: chainIds[network],
            url,
        };
    } else {
        return {
            accounts: {
                count: 10,
                mnemonic,
                path: "m/44'/60'/0'/0",
                initialIndex: Number(initialIndex),
            },
            chainId: chainIds[network],
            url,
        };
    }
}

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    gasReporter: {
        currency: "USD",
        enabled: process.env.REPORT_GAS ? true : false,
        excludeContracts: [],
        src: "./contracts",
        coinmarketcap: process.env.CMC_API,
    },
    networks: {
        hardhat: {
            accounts: {
                count: 10,
                mnemonic,
                initialIndex: Number(initialIndex),
            },
            chainId: chainIds.hardhat,
            gas: "auto",
            blockGasLimit: 1000000000000
        },
        sepolia: getChainConfig("sepolia"),
        goerli: getChainConfig("goerli"),
        kovan: getChainConfig("kovan"),
        mainnet: getChainConfig("mainnet"),
        rinkeby: getChainConfig("rinkeby"),
        ropsten: getChainConfig("ropsten"),
        'mumbai': getChainConfig("mumbai"),
    },
    etherscan: {
        // Your API key for Etherscan
        // Obtain one at https://etherscan.io/
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
                // https://github.com/paulrberg/solidity-template/issues/31
                bytecodeHash: "none",
            },
            // Disable the optimizer when debugging
            // https://hardhat.org/hardhat-network/#solidity-optimizer-support
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
