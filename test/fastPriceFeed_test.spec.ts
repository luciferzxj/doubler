import { expect } from 'chai'
import { BigNumber } from 'ethers'
const { ethers, upgrades } = require('hardhat')
const MoonPoolABI = require('../abis/MoonPool.json')
const UniswapV2PairABI = require('../abis/UniswapV2Pair.json')
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import {
    FastPriceFeed,
    FastPriceFeed__factory,
    ERC20,
} from 'typechain-types'
import { Address } from 'hardhat-deploy/dist/types'
describe.only('Moonpool Case List', () => {
    let accounts: SignerWithAddress[]
    let owner: SignerWithAddress
    let priceFeed: FastPriceFeed
    let USDC: Address
    let USDT: Address
    let DAI: Address
    let OP: Address
    let WETH: Address
    let LINK: Address
    let ONE: Address
    let WLD: Address
    let WBTC: Address
    let SUSD: Address
    let DOGE: Address
    let ether: BigNumber
    let pyth: Address
    beforeEach(async () => {
        accounts = await ethers.getSigners()
        owner = accounts[0]
        ether = BigNumber.from('1000000000000000000')

        LINK = ethers.utils.getAddress('0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6');
        USDC = ethers.utils.getAddress('0x7F5c764cBc14f9669B88837ca1490cCa17c31607');
        USDT = ethers.utils.getAddress('0x94b008aA00579c1307B0EF2c499aD98a8ce58e58');
        OP = ethers.utils.getAddress('0x4200000000000000000000000000000000000042');
        WLD = ethers.utils.getAddress('0xdC6fF44d5d932Cbd77B52E5612Ba0529DC6226F1');
        ONE = ethers.utils.getAddress('0x68Ac1AfFe00cf64EbC71e7E835A6871A379C5587');
        WETH = ethers.utils.getAddress('0x4200000000000000000000000000000000000006');
        WBTC = ethers.utils.getAddress('0x68f180fcCe6836688e9084f035309E29Bf0A2095');
        SUSD = ethers.utils.getAddress('0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9');
        DAI = ethers.utils.getAddress('0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1');
        DOGE = ethers.utils.getAddress('0xbA2aE424d960c26247Dd6c32edC70B295c744C43');
        pyth = ethers.utils.getAddress('0xff1a0f4744e8582DF1aE09D5611b887B6a12925C');
        ether = BigNumber.from('1000000000000000000')
        const FAS: FastPriceFeed__factory = await ethers.getContractFactory('FastPriceFeed', owner)
        priceFeed = await FAS.deploy(owner.address)
        await priceFeed.deployed()
    })

    describe('fastPriceFeed main case', () => {
        it('case: test WETH ', async () => {
            let uniV3Pool = ethers.utils.getAddress('0x03aF20bDAaFfB4cC0A521796a223f7D85e2aAc31')
            let token = [WETH]
            let limit = [{
                min: ether.mul(3200),
                max: ether.mul(3800),
            }]
            let plan = BigNumber.from('0')
            await priceFeed.connect(owner).newAsset(WETH, uniV3Pool, ethers.utils.formatBytes32String('0'), 18000, plan, BigNumber.from('20000'))
            await priceFeed.batchSetAssetPriceLimit(token, limit);
            let dexPrice = await priceFeed.getPrice(WETH)
            console.log('WETH Uniswap Price:', dexPrice)
        })
        it('case: test WLD ', async () => {
            let uniV3Pool = ethers.utils.getAddress('0xD1F1baD4c9E6c44DeC1e9bF3B94902205c5Cd6C3')
            let chainlink = ethers.utils.getAddress('0x4e1C6B168DCFD7758bC2Ab9d2865f1895813D236')
            let pythId = '0xd6835ad1f773de4a378115eb6824bd0c0e42d84d1c84d9750e853fb6b6c7794a'
            let token = [WLD]
            let limit = [{
                min: ether.mul(7),
                max: ether.mul(10),
            }]
            let plan = BigNumber.from('0')
            await priceFeed.connect(owner).newAsset(WLD, uniV3Pool, ethers.utils.formatBytes32String('0'), 18000, plan, BigNumber.from('0'))
            await priceFeed.connect(owner).batchSetAssetPriceLimit(token, limit);
            let dexPrice = await priceFeed.getPrice(WLD)
            console.log('WLD Uniswap Price:', dexPrice)

            plan = BigNumber.from('1')
            await priceFeed.connect(owner).upgradePlan(WLD, chainlink, plan, ethers.utils.formatBytes32String('0'), 0);
            console.log('WLD Chainlink Price:', await priceFeed.getPrice(WLD))

            plan = BigNumber.from('2')
            await priceFeed.connect(owner).upgradePlan(WLD, pyth, plan, pythId, 86400);
            console.log('WLD Pyth Price:', await priceFeed.getPrice(WLD))
        })
        it('case: test OP ', async () => {
            let uniV3Pool = ethers.utils.getAddress('0x1C3140aB59d6cAf9fa7459C6f83D4B52ba881d36')
            let chainlink = ethers.utils.getAddress('0x0D276FC14719f9292D5C1eA2198673d1f4269246')
            let pythId = '0x385f64d993f7b77d8182ed5003d97c60aa3361f3cecfe711544d2d59165e9bdf'
            let token = [OP]
            let limit = [{
                min: ether.mul(3),
                max: ether.mul(5),
            }]
            let plan = BigNumber.from('0')
            await priceFeed.connect(owner).newAsset(OP, uniV3Pool, ethers.utils.formatBytes32String('0'), 18000, plan, BigNumber.from('0'))
            await priceFeed.connect(owner).batchSetAssetPriceLimit(token, limit);
            let dexPrice = await priceFeed.getPrice(OP)
            console.log('OP Uniswap Price:', dexPrice)

            plan = BigNumber.from('1')
            await priceFeed.connect(owner).upgradePlan(OP, chainlink, plan, ethers.utils.formatBytes32String('0'), 0);
            console.log('OP Chainlink Price:', await priceFeed.getPrice(OP))

            plan = BigNumber.from('2')
            await priceFeed.connect(owner).upgradePlan(OP, pyth, plan, pythId, 86400);
            console.log('OP Pyth Price:', await priceFeed.getPrice(OP))
        })
        it('case: test USDC ', async () => {
            let chainlink = ethers.utils.getAddress('0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3')
            let pythId = '0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a'
            let token = [USDC]
            let limit = [{
                min: ether.mul(9).div(10),
                max: ether.mul(11).div(10),
            }]
            let plan = BigNumber.from('1')
            await priceFeed.connect(owner).newAsset(USDC, chainlink, ethers.utils.formatBytes32String('0'), 18000, plan, BigNumber.from('0'))
            await priceFeed.connect(owner).batchSetAssetPriceLimit(token, limit);
            console.log('USDC Chainlink Price:', await priceFeed.getPrice(USDC))

            plan = BigNumber.from('2')
            await priceFeed.connect(owner).upgradePlan(USDC, pyth, plan, pythId, 200 * 86400);
            console.log('USDC Pyth Price:', await priceFeed.getPrice(USDC))
        })
        it('case: test WBTC ', async () => {
            let chainlink = ethers.utils.getAddress('0x718A5788b89454aAE3A028AE9c111A29Be6c2a6F')
            let token = [WBTC]
            let limit = [{
                min: ether.mul(64000),
                max: ether.mul(68000),
            }]
            let plan = BigNumber.from('1')
            await priceFeed.connect(owner).newAsset(WBTC, chainlink, ethers.utils.formatBytes32String('0'), 18000, plan, 200 * 86400)
            await priceFeed.connect(owner).batchSetAssetPriceLimit(token, limit);
            console.log('WBTC Chainlink Price:', await priceFeed.getPrice(WBTC))
        })
        it('case: test USDT ', async () => {
            let chainlink = ethers.utils.getAddress('0xECef79E109e997bCA29c1c0897ec9d7b03647F5E')
            let pythId = '0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b'
            let token = [USDT]
            let limit = [{
                min: ether.mul(9).div(10),
                max: ether.mul(11).div(10),
            }]
            let plan = BigNumber.from('1')
            await priceFeed.connect(owner).newAsset(USDT, chainlink, ethers.utils.formatBytes32String('0'), 18000, plan, BigNumber.from('0'))
            await priceFeed.connect(owner).batchSetAssetPriceLimit(token, limit);
            console.log('USDT Chainlink Price:', await priceFeed.getPrice(USDT))

            plan = BigNumber.from('2')
            await priceFeed.connect(owner).upgradePlan(USDT, pyth, plan, pythId, 200 * 86400);
            console.log('USDT Pyth Price:', await priceFeed.getPrice(USDT))
        })
        it('case: test SUSD ', async () => {
            let uniV3Pool = ethers.utils.getAddress('0xAdb35413eC50E0Afe41039eaC8B930d313E94FA4')
            let chainlink = ethers.utils.getAddress('0x7f99817d87baD03ea21E05112Ca799d715730efe')
            let token = [SUSD]
            let limit = [{
                min: ether.mul(9).div(10),
                max: ether.mul(11).div(10),
            }]
            let plan = BigNumber.from('0')
            await priceFeed.connect(owner).newAsset(SUSD, uniV3Pool, ethers.utils.formatBytes32String('0'), 18000, plan, BigNumber.from('0'))
            await priceFeed.connect(owner).batchSetAssetPriceLimit(token, limit);
            console.log('SUSD Uniswap Price:', await priceFeed.getPrice(SUSD))

            plan = BigNumber.from('1')
            await priceFeed.connect(owner).upgradePlan(SUSD, chainlink, plan, ethers.utils.formatBytes32String('0'), 0);
            console.log('SUSD Chainlink Price:', await priceFeed.getPrice(SUSD))
        })

        it('case: test DAI ', async () => {
            let uniV3Pool = ethers.utils.getAddress('0x100bdC1431A9b09C61c0EFC5776814285f8fB248')
            let chainlink = ethers.utils.getAddress('0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6')
            let pythId = '0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd'
            let token = [DAI]
            let limit = [{
                min: ether.mul(9).div(10),
                max: ether.mul(11).div(10),
            }]
            let plan = BigNumber.from('0')
            await priceFeed.connect(owner).newAsset(DAI, uniV3Pool, ethers.utils.formatBytes32String('0'), 18000, plan, BigNumber.from('0'))
            await priceFeed.connect(owner).batchSetAssetPriceLimit(token, limit);
            console.log('DAI Uniswap Price:', await priceFeed.getPrice(DAI))

            plan = BigNumber.from('1')
            await priceFeed.connect(owner).upgradePlan(DAI, chainlink, plan, ethers.utils.formatBytes32String('0'), 0);
            console.log('DAI Chainlink Price:', await priceFeed.getPrice(DAI))

            plan = BigNumber.from('2')
            await priceFeed.connect(owner).upgradePlan(DAI, pyth, plan, pythId, 1000 * 86400);
            console.log('DAI Pyth Price:', await priceFeed.getPrice(DAI))
        })

        it('case: test DOGE ', async () => {
            let chainlink = ethers.utils.getAddress('0xC6066533917f034Cf610c08e1fe5e9c7eADe0f54')
            let pythId = '0xdcef50dd0a4cd2dcc17e45df1676dcb336a11a61c69df7a0299b0150c672d25c'
            let token = [DOGE]
            let limit = [{
                min: ether.mul(1).div(10),
                max: ether.mul(2).div(10),
            }]
            let plan = BigNumber.from('1')
            await priceFeed.connect(owner).newAsset(DOGE, chainlink, ethers.utils.formatBytes32String('0'), 18000, plan, BigNumber.from('0'))
            await priceFeed.connect(owner).batchSetAssetPriceLimit(token, limit);
            console.log('DOGE Chainlink Price:', await priceFeed.getPrice(DOGE))

            plan = BigNumber.from('2')
            await priceFeed.connect(owner).upgradePlan(DOGE, pyth, plan, pythId, 86400);
            console.log('DOGE Pyth Price:', await priceFeed.getPrice(DOGE))
        })

        it('case: test LINK ', async () => {
            let chainlink = ethers.utils.getAddress('0xCc232dcFAAE6354cE191Bd574108c1aD03f86450')
            let pythId = '0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221'
            let token = [LINK]
            let limit = [{
                min: ether.mul(19),
                max: ether.mul(21),
            }]
            let plan = BigNumber.from('1')
            await priceFeed.connect(owner).newAsset(LINK, chainlink, ethers.utils.formatBytes32String('0'), 18000, plan, BigNumber.from('0'))
            await priceFeed.connect(owner).batchSetAssetPriceLimit(token, limit);
            console.log('LINK Chainlink Price:', await priceFeed.getPrice(LINK))

            plan = BigNumber.from('2')
            await priceFeed.connect(owner).upgradePlan(LINK, pyth, plan, pythId, 86400);
            console.log('LINK Pyth Price:', await priceFeed.getPrice(LINK))
        })
        it('case: test ONE ', async () => {
            let chainlink = ethers.utils.getAddress('0x7CFB4fac1a2FDB1267F8bc17FADc12804AC13CFE')

            let token = [ONE]
            let limit = [{
                min: ether.mul(3).div(100),
                max: ether.mul(5).div(10),
            }]
            let plan = BigNumber.from('1')
            await priceFeed.connect(owner).newAsset(ONE, chainlink, ethers.utils.formatBytes32String('0'), 18000, plan, BigNumber.from('0'))
            await priceFeed.connect(owner).batchSetAssetPriceLimit(token, limit);
            console.log('ONE Chainlink Price:', await priceFeed.getPrice(ONE))
        })
    })
})