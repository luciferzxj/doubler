import 'dotenv/config'

import { HardhatUserConfig, task, subtask } from 'hardhat/config'
import { getNetwork } from '@ethersproject/networks'
import { TASK_TEST_GET_TEST_FILES } from 'hardhat/builtin-tasks/task-names'

import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-etherscan'
import '@nomiclabs/hardhat-solhint'
import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'
import 'hardhat-abi-exporter'
import 'hardhat-contract-sizer'
import 'hardhat-deploy'
import 'hardhat-docgen'
import 'hardhat-gas-reporter'
import 'hardhat-watcher'
import 'solidity-coverage'
import '@openzeppelin/hardhat-upgrades'
import 'tsconfig-paths/register'

task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners()
  for (const account of accounts) {
    console.log(account.address)
  }
})

subtask(TASK_TEST_GET_TEST_FILES).setAction(async (_, __, runSuper) => {
  const paths = await runSuper()
  // @ts-ignore
  return paths.filter((file) => (file as string).endsWith('.spec.ts'))
})

const PRIVATE_KEY = process.env.PRIVATE_KEY || '0x1111111111111111111111111111111111111111111111111111111111111111'
const PRIVATE_KEY_FAUCET =
  process.env.PRIVATE_KEY_FAUCET || '0x1111111111111111111111111111111111111111111111111111111111111111'
const INFURA_API_KEY = process.env.INFURA_API_KEY || '00'

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat', //fat,hardhat,sepolia
  networks: {
    // hardhat: {
    //   allowUnlimitedContractSize: false,
    //   hardfork: 'berlin', // Berlin is used (temporarily) to avoid issues with coverage
    //   mining: {
    //     // .@see https://hardhat.org/hardhat-network/docs/reference
    //     auto: true,
    //     interval: 50000,
    //   },
    //   gasPrice: 'auto',
    // },
    hardhat: {
      forking: {
        url: "https://opt-mainnet.g.alchemy.com/v2/jTyU-Rhb3RrfCDBAI2H1Jr6sgAeH0Fal"
      }
    },
    fat: {
      url: 'https://rpcfat.doubler.pro/dou',
      chainId: 231337,
      // accounts: [PRIVATE_KEY,PRIVATE_KEY_FAUCET],
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
      chainId: getNetwork('mainnet').chainId,
      accounts: [PRIVATE_KEY],
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${INFURA_API_KEY}`,
      chainId: getNetwork('ropsten').chainId,
      accounts: [PRIVATE_KEY],
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${INFURA_API_KEY}`,
      chainId: getNetwork('goerli').chainId,
      accounts: [PRIVATE_KEY],
    },
    bnbmain: {
      // url: 'https://spring-falling-water.bsc.quiknode.pro/',
      url: ' https://bsc-dataseed.binance.org/',
      chainId: getNetwork('bnb').chainId,
      accounts: [PRIVATE_KEY],
    },
    bnbtest: {
      url: process.env.BNBTEST_PROVIDER_URL || 'https://data-seed-prebsc-1-s3.binance.org:8545/',
      chainId: getNetwork('bnbt').chainId,
      accounts: [PRIVATE_KEY],
    },
    artiotest: {
      url: 'https://rpc1.jaz.network/',
      chainId: 1688,
      accounts: [PRIVATE_KEY],
    },
    sepolia: {
      // url: 'https://rpc.ankr.com/eth_sepolia/4a7900f177c114e1aaba64542d7b7404ff2e7852ea16a9f0896b0584ca4573f8',
      // url: 'https://ethereum-sepolia.publicnode.com',
      url: 'https://ethereum-sepolia.publicnode.com',
      chainId: 11155111,
      accounts: [PRIVATE_KEY],
    },
    arbitrum: {
      // url: 'https://rpc.ankr.com/eth_sepolia/4a7900f177c114e1aaba64542d7b7404ff2e7852ea16a9f0896b0584ca4573f8',
      // url: 'https://ethereum-sepolia.publicnode.com',
      url: 'https://arbitrum.llamarpc.com',
      chainId: 42161,
      accounts: [PRIVATE_KEY],
    },
    optimism: {
      // url: 'https://rpc.ankr.com/eth_sepolia/4a7900f177c114e1aaba64542d7b7404ff2e7852ea16a9f0896b0584ca4573f8',
      // url: 'https://ethereum-sepolia.publicnode.com',
      url: 'https://optimism.llamarpc.com',
      chainId: 10,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  solidity: {
    compilers: [
      {
        version: '0.8.12',
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
      {
        version: '0.8.11',
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
      {
        version: '0.4.18',
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
    ],
  },
  paths: {
    sources: './contracts/',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
  abiExporter: {
    path: './abis',
    runOnCompile: true,
    clear: true,
    flat: true,
    pretty: false,
    except: ['lib'],
  },
  gasReporter: {
    enabled: !!process.env.REPORT_GAS,
    excludeContracts: ['test*', '@openzeppelin*'],
  },
  typechain: {
    outDir: 'typechain-types',
    target: 'ethers-v5',
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
    only: ['Doubler', 'FRNFT', 'DBRFarm', 'FastPriceFeed', 'DoublerHelper', 'MoonPool'],
  },
}

export default config
