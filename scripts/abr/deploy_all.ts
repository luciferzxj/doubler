import { BigNumber, Contract } from 'ethers'
import { UpgradeProxyOptions } from '@openzeppelin/hardhat-upgrades/dist/utils'
// import { Options } from '@openzeppelin/hardhat-upgrades/src/utils'
const { ethers, network, upgrades } = require('hardhat')
const dotenv = require('dotenv')

dotenv.config()
const pythAddress = process.env.ADDR_PythContract
const dbrAddress = process.env.ADDR_DBR
const dbrFarmAddress = process.env.ADDR_DBRFarm
const rfNftAddress = process.env.ADDR_FRNFT
const doublerPoolAddress = process.env.ADDR_DoublerPool
const doublerQueryAddress = process.env.ADDR_DoublerQuery
const fastPriceFeedPythAddress = process.env.ADDR_FastPriceFeedPyth
const nftTraitsAddress = process.env.ADDR_NFTTraits
const teamAddress = process.env.ADDR_Team
const ecoAddress = process.env.ADDR_Ecosystem
const swaprouterAddress = process.env.ADDR_mpswaprouter

const dbtcAddress = process.env.ADDR_DBTC
const ethAddress = process.env.ADDR_DETH
const usdtAddress = process.env.ADDR_USDT
const usdcAddress = process.env.ADDR_USDC

const multiSigWalletAddress = process.env.ADDR_MultiSigWallet

export async function deployContract(name: string, args: any[] = []): Promise<Contract> {
  console.log(`start deployContract ${network.name} ${name}, ${args}`)
  const factory = await ethers.getContractFactory(name)
  if (args.length > 0) {
    const constructorArgumentsABIEncoded = ethers.utils.defaultAbiCoder.encode(
      factory.interface.fragments[0].inputs,
      args
    )
    // console.log(`contract ${network.name} ${name} constructorArgumentsABIEncoded: ${constructorArgumentsABIEncoded}`)
  }
  const contract = await factory.deploy(...args)
  console.log(`contract ${network.name} ${name} address ${contract.address}`)
  console.log(`contract ${network.name} ${name} deploy transaction hash ${contract.deployTransaction.hash}`)
  await contract.deployed()
  console.log(`finish deployContract ${network.name} ${name}`)
  return contract
}

async function deployProxyContract(name: string, args: any[] = []): Promise<Contract> {
  console.log(`start deployProxyContract ${network.name} ${name}, ${args}`)
  const factory = await ethers.getContractFactory(name)
  const contract = await upgrades.deployProxy(factory, args)
  console.log(`contract ${network.name} ${name} address ${contract.address}`)
  console.log(`contract ${network.name} ${name} deploy transaction hash ${contract.deployTransaction.hash}`)
  await contract.deployed()
  console.log(`finish deployProxyContract ${network.name} ${name}`)
  return contract
}

async function deployProxyContractV2(name: string): Promise<Contract> {
  console.log(`start deployProxyContract ${network.name} ${name}`)
  const factory = await ethers.getContractFactory(name)
  const contract = await upgrades.deployProxy(factory, { initializer: 'initialize' })
  console.log(`contract ${network.name} ${name} address ${contract.address}`)
  console.log(`contract ${network.name} ${name} deploy transaction hash ${contract.deployTransaction.hash}`)
  await contract.deployed()
  console.log(`finish deployProxyContract ${network.name} ${name}`)
  return contract
}

async function upgradeProxyContract(name: string, proxyAddress: string, opts?: UpgradeProxyOptions) {
  try {
    console.log(`start upgradeProxyContract ${network.name} ${name} ${proxyAddress}`)
    const factory = await ethers.getContractFactory(name)
    const contract = await upgrades.upgradeProxy(proxyAddress, factory, opts)
    console.log(`contract ${network.name} ${name} address ${contract.address} ${contract.deployTransaction.hash}`)
    console.log(`finish upgradeProxyContract ${network.name} ${name} ${proxyAddress}`)
  } catch (e: any) {
    console.error(
      `upgradeProxyContract ${network.name} error ${name} ${proxyAddress} ${e.error?.message || e.reason || e.data?.message || e.message
      }`
    )
  }
}

async function forceImportProxyContract(name: string, proxyAddress: string, opts?: Options) {
  try {
    console.log(`start forceImportProxyContract ${network.name} ${name} ${proxyAddress}`)
    const factory = await ethers.getContractFactory(name)
    await upgrades.forceImport(proxyAddress, factory, opts)
    console.log(`finish forceImportProxyContract ${network.name} ${name} ${proxyAddress}`)
  } catch (e: any) {
    console.error(
      `forceImportProxyContract ${network.name} error ${name} ${proxyAddress} ${e.error?.message || e.reason || e.data?.message || e.message
      }`
    )
  }
}

async function changeProxyAdmin(proxyAddress: string, newAdmin: string) {
  console.log(`start changeProxyAdmin ${network.name} ${proxyAddress} ${newAdmin}`)
  await upgrades.admin.changeProxyAdmin(proxyAddress, newAdmin)
  console.log(`finish upgradeProxyContract ${network.name} ${proxyAddress} ${newAdmin} `)
}

async function main() {
  console.log(`Deploy_BlockNo=${(await ethers.provider.getBlockNumber()).toString()}`)

  // todo init FastPriceFeed
  await deployContract('FastPriceFeed', [ethers.utils.getAddress('0x686cFfb90EB812d39Cf3bc60f87e2F41373c2893')])
  // todo init Aggregator
  const uniV3Router = ethers.utils.getAddress('0xE592427A0AEce92De3Edee1F18E0157C05861564')
  const uniV2Router = ethers.utils.getAddress('0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506')
  let cfg = [uniV3Router,uniV2Router]

  await deployContract('Aggregator', [cfg, ethers.utils.getAddress('0x686cFfb90EB812d39Cf3bc60f87e2F41373c2893')])
  
  // deploy dbr

  // await deployContract('Token', ["Test Doubler Token", "DBR"])

  // await deployContract('Doubler')
  // await deployContract('FRNFT', ['Flexible Return NFT', 'FR'])
  // await deployContract('MockSwapRouter')
  // await deployProxyContract('DBRFarm')
  // await deployProxyContract('DoublerHelper')

  // let initMpF = {
  //   eco: ecoAddress,
  //   dbr: dbrAddress,
  //   dbrFarm: dbrFarmAddress,
  //   frnft: rfNftAddress,
  //   doubler:doublerPoolAddress,
  //   priceFeed: fastPriceFeedPythAddress,
  //   swapRouter: swaprouterAddress,
  //   initAmountMin: ethers.BigNumber.from('1000000000000000000').mul(10000)
  // }
  // await deployContract('MoonPoolFactory', [initMpF, [usdtAddress, usdcAddress], multiSigWalletAddress])

}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
