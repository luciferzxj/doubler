// import { Options } from '@openzeppelin/hardhat-upgrades/src/utils'
// import { BigNumber, Contract } from 'ethers'
import { UpgradeProxyOptions } from '@openzeppelin/hardhat-upgrades/dist/utils'
// import { Options } from '@openzeppelin/hardhat-upgrades/src/utils'
const { ethers, network, upgrades } = require('hardhat')
// const ethers = require('ethers')
const SwapRouterABI = require('../../abis/Aggregator.json')
const dotenv = require('dotenv')

dotenv.config()

const ropstenNetwork = process.env.RPC_CALL
const swaprouterAddress = process.env.ADDR_mpswaprouter

const privateKey = process.env.PRIVATE_KEY

const ropstenProvider = new ethers.providers.JsonRpcProvider(ropstenNetwork)
const makerWallet = new ethers.Wallet(privateKey, ropstenProvider)
// function wait(ms) {
//     return new Promise((resolve) => setTimeout(() => resolve(), ms))
// }

async function initMain() {
  console.log('init contract start')
  const swapRouter = new ethers.Contract(swaprouterAddress, SwapRouterABI, makerWallet)
  console.log('init contract end')

  // init.
  console.log('init start')
  let tx
  let rt

  const USDC = ethers.utils.getAddress('0xaf88d065e77c8cC2239327C5EDb3A432268e5831')
  const USDT = ethers.utils.getAddress('0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9')
  const ARB = ethers.utils.getAddress('0x912CE59144191C1204E64559FE8253a0e49E6548')
  const WETH = ethers.utils.getAddress('0x82aF49447D8a07e3bd95BD0d56f35241523fBab1')
  const MAX = ethers.utils.getAddress('0x9e37523f0304980b6cFADCc7BA15b8ca59e2B717')



  //aggregator
  let paths = [
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address", "uint24", "address"], [WETH, 500, ARB, 500, USDT]),
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [WETH, 500, USDT]),
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [ARB, 500, USDT]),
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [ARB, 500, USDT]),
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [MAX, 10000, USDT]),
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [MAX, 10000, USDT]),
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [WETH, 500, USDC]),
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [WETH, 500, USDC]),
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [ARB, 500, USDC]),
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [ARB, 500, USDC]),
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [MAX, 10000, USDC]),
    ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address"], [MAX, 10000, USDC])
  ];
  let paths2 = [[USDT, WETH], [WETH, USDT], [USDT, ARB], [ARB, USDT], [USDT, MAX], [MAX, USDT], [USDC, WETH], [WETH, USDC], [USDC, ARB], [ARB, USDC], [USDC, MAX], [MAX, USDC]];
  let ratios = [[6000, 4000], [6000, 4000], [6000, 4000], [6000, 4000], [6000, 4000], [6000, 4000], [6000, 4000], [6000, 4000], [6000, 4000], [6000, 4000], [6000, 4000], [6000, 4000]];

  for (let i = 0; i < paths.length; i++) {
    let data = {
      path: paths[i],
      ratio: ratios[i][0],
      index: 0
    }
    tx = await swapRouter.addUniV3Strategy(paths2[i][0], paths2[i][1], data)
    rt = await tx.wait()
    console.log(`swapRouter.addUniV3Strategy, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

    data = {
      path: paths2[i],
      ratio: ratios[i][1],
      index: 1
    }
    tx = await swapRouter.addUniV2Strategy(paths2[i][0], paths2[i][1], data)
    rt = await tx.wait()
    console.log(`swapRouter.addUniV2Strategy, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)
  }
  console.log('init end')
}

initMain()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
