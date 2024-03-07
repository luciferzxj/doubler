import { BigNumber, } from 'ethers'
// import { Options } from '@openzeppelin/hardhat-upgrades/src/utils'

const ethers = require('ethers')
const DBRABI = require('../../abis/DBR.json')
const TokenABI = require('../../abis/token.json')
// const DBRFarmABI = require('../../abis/DBRFarm.json')
const FRNFTABI = require('../../abis/FRNFT.json')
const DoublerPoolABI = require('../../abis/Doubler.json')
const DoublerQueryABI = require('../../abis/DoublerHelper.json')
const FastPriceFeedABI = require('../../abis/FastPriceFeed.json')
const SwapRouterABI = require('../../abis/Aggregator.json')
const dotenv = require('dotenv')

dotenv.config()

const ropstenNetwork = process.env.RPC_CALL

const dbrAddress = process.env.ADDR_DBR
const dbrFarmAddress = process.env.ADDR_DBRFarm
const rfNftAddress = process.env.ADDR_FRNFT
const doublerPoolAddress = process.env.ADDR_DoublerPool
const doublerQueryAddress = process.env.ADDR_DoublerQuery
const swaprouterAddress = process.env.ADDR_mpswaprouter
const mpfactoryAddress = process.env.ADDR_mpfactory
const fastPriceFeedAddress = process.env.ADDR_FastPriceFeed
const fastPriceFeedPythAddress = process.env.ADDR_FastPriceFeedPyth
const nftTraitsAddress = process.env.ADDR_NFTTraits
const teamAddress = process.env.ADDR_Team
const ecoAddress = process.env.ADDR_Ecosystem

const dbtcAddress = process.env.ADDR_DBTC
const dethAddress = process.env.ADDR_DETH
const dsnxAddress = process.env.ADDR_DSNX
const dlinkAddress = process.env.ADDR_DLINK

const privateKey = process.env.PRIVATE_KEY

const ropstenProvider = new ethers.providers.JsonRpcProvider(ropstenNetwork)
const makerWallet = new ethers.Wallet(privateKey, ropstenProvider)
// function wait(ms) {
//     return new Promise((resolve) => setTimeout(() => resolve(), ms))
// }

async function initMain() {
  console.log('init contract start')
  const dbr = new ethers.Contract(dbrAddress, DBRABI, makerWallet)
  const dbrFarm = new ethers.Contract(dbrFarmAddress, DBRFarmABI, makerWallet)
  const frNft = new ethers.Contract(rfNftAddress, FRNFTABI, makerWallet)
  const doublerPool = new ethers.Contract(doublerPoolAddress, DoublerPoolABI, makerWallet)
  const doublerHelper = new ethers.Contract(doublerQueryAddress, DoublerQueryABI, makerWallet)
  const fastPriceFeed = new ethers.Contract(fastPriceFeedAddress, FastPriceFeedABI, makerWallet)
  const swapRouter = new ethers.Contract(swaprouterAddress, SwapRouterABI, makerWallet)
  console.log('init contract end')

  // init.
  console.log('init start')
  const erc20Decimals = ethers.BigNumber.from('1000000000000000000')
  const MUL = 100
  let tx
  let rt

  let multiSigWallet = makerWallet.address;
  let farmWallet = makerWallet.address;;

  // // init nft
  tx = await frNft.initialize(doublerPool.address, multiSigWallet);
  rt = await tx.wait();
  console.log(`frNft.initialize, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

  // // doubler
  let initProtectBlock = 200
  tx = await doublerPool.initialize(
    teamAddress,
    ecoAddress,
    fastPriceFeedPythAddress,
    rfNftAddress,
    multiSigWallet,
    initProtectBlock)
  rt = await tx.wait();
  console.log(`doublerPool.initialize, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

  // // init farm
  let _initBoostPer = erc20Decimals.mul(30);
  let _initLastlayerPer = erc20Decimals.mul(20);
  tx = await dbrFarm.initializeV2(dbrAddress, doublerPoolAddress, rfNftAddress, multiSigWallet, farmWallet, mpfactoryAddress, _initBoostPer, _initLastlayerPer)
  rt = await tx.wait();
  console.log(`dbrFarm.initializeV2, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

  // // // init DoublerHelper
  tx = await doublerHelper.initializeHelper(doublerPoolAddress, rfNftAddress, fastPriceFeedPythAddress, dbrFarmAddress, mpfactoryAddress)
  rt = await tx.wait();
  console.log(`doublerHelper.initializeHelper, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

  const initdbrFarmAmount = erc20Decimals.mul(10000000)
  tx = await dbr.mint(farmWallet, initdbrFarmAmount)
  rt = await tx.wait()
  console.log(`dbr.mint, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

  tx = await dbr.approve(dbrFarmAddress, initdbrFarmAmount)
  rt = await tx.wait()
  console.log(`dbr.approve, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

  let assetList = [
    "0x50A34cC244afef98e71f13B68bbB2E779e5BaBf7",
    "0xC2E3492Cf1aa218b2e1dD78925740fe7981e63f2",
  ];

  for (let i = 0; i < assetList.length; i++) {
    tx = await doublerPool.updateAssetConfig(assetList[i], true)
    rt = await tx.wait()
    console.log(`doublerPool.updateAssetConfig, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)
  }

  for (let i = 0; i < assetList.length; i++) {
    tx = await dbrFarm.updateAssetPerBlock(assetList[i], erc20Decimals.mul(20))
    rt = await tx.wait()
    console.log(`dbrFarm.updateAssetPerBlock, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)
  }

  tx = await doublerHelper.updateFastPriceTokens(assetList);
  rt = await tx.wait()
  console.log(`doublerHelper.updateFastPriceTokens, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

  // moon buy asset
  assetList = [
    "0x728A85205f9cD20Cc8E8255D52737eEf788b29bd",
    "0x305ae7fD65B3a2a67578398680AAC89FB24F52e1",
  ];
  tx = await doublerHelper.updateMoonPoolPriceTokens(assetList);
  rt = await tx.wait()
  console.log(`doublerHelper.updateMoonPoolPriceTokens, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

  //fastPriceFeed
  let chainlink = ethers.utils.getAddress('0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6')
  const pyth = ethers.utils.getAddress('0xff1a0f4744e8582DF1aE09D5611b887B6a12925C')
  const USDC = ethers.utils.getAddress('0xaf88d065e77c8cC2239327C5EDb3A432268e5831')
  const USDT = ethers.utils.getAddress('0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9')
  const ARB = ethers.utils.getAddress('0x912CE59144191C1204E64559FE8253a0e49E6548')
  const WETH = ethers.utils.getAddress('0x82aF49447D8a07e3bd95BD0d56f35241523fBab1')
  const MAX = ethers.utils.getAddress('0x9e37523f0304980b6cFADCc7BA15b8ca59e2B717')
  let plan = BigNumber.from('1')
  tx = await fastPriceFeed.newAsset(ARB, chainlink, ethers.utils.formatBytes32String('0'), 1800, plan, BigNumber.from('0'))
  rt = await tx.wait()
  console.log(`fastPriceFeed.newAsset, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

  plan = BigNumber.from('2')
  let pythId = '0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace'
  tx = await fastPriceFeed.newAsset(WETH, pyth, pythId, 1800, plan, BigNumber.from('2160000'))
  rt = await tx.wait()
  console.log(`fastPriceFeed.newAsset, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

  plan = BigNumber.from('0')
  let uniPool = ethers.utils.getAddress('0x4468D34EC0E213a8A060D6282De6Fd407B7B55b3')
  tx = await fastPriceFeed.newAsset(MAX, uniPool, ethers.utils.formatBytes32String('0'), 1800, plan, BigNumber.from('0'))
  rt = await tx.wait()
  console.log(`fastPriceFeed.newAsset, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

  const ether = BigNumber.from('1000000000000000000')
  let token = [ARB, WETH]
  let limit = [
    {
      min: ether.mul(1),
      max: ether.mul(5),
    },
    {
      min: ether.mul(3000),
      max: ether.mul(5000)
    }]
  tx = await fastPriceFeed.batchSetAssetPriceLimit(token, limit)
  rt = await tx.wait()
  console.log(`fastPriceFeed.batchSetAssetPriceLimit, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)
  //aggregator
  //USDT-WETH
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
      index :0
    }
    tx = await swapRouter.addUniV3Strategy(paths2[i][0], paths2[i][1], data)
    rt = await tx.wait()
    console.log(`swapRouter.addUniV3Strategy, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)

    data = {
      path: paths2[i],
      ratio: ratios[i][1],
      index:1
    }
    tx = await swapRouter.addUniV2Strategy(paths2[i][0], paths2[i][1], data)
    rt = await tx.wait()
    console.log(`swapRouter.addUniV2Strategy, tx status ${rt.status}, transactionHash : ${rt.transactionHash} `)
  }

}

initMain()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
