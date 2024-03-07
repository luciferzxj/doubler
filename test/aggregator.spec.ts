import { expect } from 'chai'
import { BigNumber } from 'ethers'
const { ethers, upgrades } = require('hardhat')
const UniswapV2PairABI = require('../abis/UniswapV2Pair.json')
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import {
    FRNFT,
    FRNFT__factory,
    Aggregator,
    Aggregator__factory,
    TokenTe,
    TokenTe__factory,
    WETH9,
    WETH9__factory,
    UniV2Router,
    UniV2Router__factory,
    SwapRouter,
    SwapRouter__factory,
} from 'typechain-types'
describe.only('Aggregator Case List', () => {
    let accounts: SignerWithAddress[]
    let owner: SignerWithAddress
    let user1: SignerWithAddress
    let developer: SignerWithAddress
    let fr: FRNFT
    let dbr: TokenTe
    let aggregator: Aggregator
    let nftName: string
    let nftSymbol: string
    let ether: BigNumber
    let USDC: TokenTe
    let USDT: TokenTe
    let DAI: TokenTe
    let OP: TokenTe
    let WETH: WETH9
    let uniV2Router: UniV2Router
    let uniV3Router: SwapRouter
    // let pair:UniswapV2Pair
    // let pair3:UniswapV2Pair
    beforeEach(async () => {
        ether = BigNumber.from('1000000000000000000')
        accounts = await ethers.getSigners()
        owner = accounts[0]
        user1 = accounts[1]
        developer = accounts[2]
        // deploy erc721
        const FRNFT: FRNFT__factory = await ethers.getContractFactory('FRNFT', owner)
        nftName = 'FR NFT'
        nftSymbol = 'FR'
        fr = await FRNFT.deploy(nftName, nftSymbol)
        await fr.deployed()

        // deploy erc20 DBR
        const DBR: TokenTe__factory = await ethers.getContractFactory('TokenTe', owner)
        dbr = await DBR.deploy('DBR', 'DBR')
        await dbr.deployed()

        const MockUSDT: TokenTe__factory = await ethers.getContractFactory('TokenTe', owner)
        USDT = await MockUSDT.deploy('USDT', 'USDT')
        await USDT.deployed()
        const MockUSDC: TokenTe__factory = await ethers.getContractFactory('TokenTe', owner)
        USDC = await MockUSDC.deploy('USDC', 'USDC')
        await USDC.deployed()
        const MockDAI: TokenTe__factory = await ethers.getContractFactory('TokenTe', owner)
        DAI = await MockDAI.deploy('DAI', 'DAI')
        await DAI.deployed()
        const MockOP: TokenTe__factory = await ethers.getContractFactory('TokenTe', owner)
        OP = await MockOP.deploy('OP', 'OP')
        await OP.deployed()
        const MockWETH: WETH9__factory = await ethers.getContractFactory('WETH9', owner)
        WETH = await MockWETH.deploy('WETH', 'WETH')
        await WETH.deployed()
        //deploy uniV2 uniV3
        const MockUniv2: UniV2Router__factory = await ethers.getContractFactory('UniV2Router', owner)
        uniV2Router = await MockUniv2.deploy()
        await uniV2Router.deployed()
        const MockUniv3: SwapRouter__factory = await ethers.getContractFactory('swapRouter', owner)
        uniV3Router = await MockUniv3.deploy()
        await uniV3Router.deployed()
        let temp = [uniV3Router.address,uniV2Router.address]
        const MockSwapRouter: Aggregator__factory = await ethers.getContractFactory('Aggregator', owner)
        aggregator = await MockSwapRouter.deploy(temp, owner.address)
        await aggregator.deployed()
        await aggregator.updateSlippage(600);


        //mint Token
        await USDT.mint(200000 * 10 ** 6);
        await USDT.transfer(owner.address, 100000 * 10 ** 6);
        await USDT.transfer(user1.address, 100000 * 10 ** 6);
        await DAI.mint(ether.mul(200000));
        await DAI.transfer(owner.address, ether.mul(100000));
        await DAI.transfer(user1.address, ether.mul(100000));


    })
    describe('aggregator main case', () => {
        it('case: deploy uniV2 ', async () => {
            await deployUniV2()
        })
        it('case: deploy uniV3 ', async () => {
            await deployUniV3()
        })
        it('case: set Strategy ', async () => {
            await setStrategy()
        })

        it('case: test swapCustomIn ', async () => {
            await testSwapIn()
        })
        it('case: test swapCustomOut ', async () => {
            await testSwapOut()
        })


    })
    async function deployUniV2() {
        await USDT.mint(4000000 * 10 ** 6);
        await DAI.mint(ether.mul(3000000));
        await USDC.mint(2000000 * 10 ** 6);
        await OP.mint(ether.mul(500000));
        await WETH.mint(500 * 10 ** 8);
        await uniV2Router.createPair(DAI.address, USDT.address);
        let pairAddress = await uniV2Router.getPair(DAI.address, USDT.address)
        let pair = new ethers.Contract(pairAddress, UniswapV2PairABI, owner)
        await DAI.transfer(pair.address, ether.mul(1000000));
        await USDT.transfer(pair.address, 1000000 * 10 ** 6);
        await pair.sync();
        await uniV2Router.createPair(DAI.address, USDC.address);
        pairAddress = await uniV2Router.getPair(DAI.address, USDC.address)
        pair = new ethers.Contract(pairAddress, UniswapV2PairABI, owner)
        await DAI.transfer(pair.address, ether.mul(1000000));
        await USDC.transfer(pair.address, 1000000 * 10 ** 6);
        await pair.sync();
        await uniV2Router.createPair(DAI.address, OP.address);
        pairAddress = await uniV2Router.getPair(DAI.address, OP.address)
        pair = new ethers.Contract(pairAddress, UniswapV2PairABI, owner)
        await DAI.transfer(pair.address, ether.mul(1000000));
        await OP.transfer(pair.address, ether.mul(250000));
        await pair.sync();
        await uniV2Router.createPair(USDC.address, USDT.address);
        pairAddress = await uniV2Router.getPair(USDT.address, USDC.address)
        pair = new ethers.Contract(pairAddress, UniswapV2PairABI, owner)
        await USDC.transfer(pair.address, 1000000 * 10 ** 6);
        await USDT.transfer(pair.address, 1000000 * 10 ** 6);
        await pair.sync();
        await uniV2Router.createPair(OP.address, USDT.address);
        pairAddress = await uniV2Router.getPair(OP.address, USDT.address)
        pair = new ethers.Contract(pairAddress, UniswapV2PairABI, owner)
        await OP.transfer(pair.address, ether.mul(250000));
        await USDT.transfer(pair.address, 1000000 * 10 ** 6);
        await pair.sync();
        await uniV2Router.createPair(WETH.address, USDT.address);
        pairAddress = await uniV2Router.getPair(WETH.address, USDT.address)
        pair = new ethers.Contract(pairAddress, UniswapV2PairABI, owner)
        await WETH.transfer(pair.address, 500 * 10 ** 8);
        await USDT.transfer(pair.address, 1000000 * 10 ** 6);
        await pair.sync();
    }
    async function deployUniV3() {
        await deployUniV2()
        await USDT.mint(4000000 * 10 ** 6);
        await DAI.mint(ether.mul(3000000));
        await USDC.mint(2000000 * 10 ** 6);
        await OP.mint(ether.mul(500000));
        await WETH.mint(500 * 10 ** 8);
        await uniV3Router.createPair(DAI.address, USDT.address);
        let pairAddress = await uniV3Router.getPair(DAI.address, USDT.address)
        let pair = new ethers.Contract(pairAddress, UniswapV2PairABI, owner)
        await DAI.transfer(pair.address, ether.mul(1000000));
        await USDT.transfer(pair.address, 1000000 * 10 ** 6);
        await pair.sync();
        await uniV3Router.createPair(DAI.address, USDC.address);
        pairAddress = await uniV3Router.getPair(DAI.address, USDC.address)
        pair = new ethers.Contract(pairAddress, UniswapV2PairABI, owner)
        await DAI.transfer(pair.address, ether.mul(1000000));
        await USDC.transfer(pair.address, 1000000 * 10 ** 6);
        await pair.sync();
        await uniV3Router.createPair(DAI.address, OP.address);
        pairAddress = await uniV3Router.getPair(DAI.address, OP.address)
        pair = new ethers.Contract(pairAddress, UniswapV2PairABI, owner)
        await DAI.transfer(pair.address, ether.mul(1000000));
        await OP.transfer(pair.address, ether.mul(250000));
        await pair.sync();
        await uniV3Router.createPair(USDC.address, USDT.address);
        pairAddress = await uniV3Router.getPair(USDT.address, USDC.address)
        pair = new ethers.Contract(pairAddress, UniswapV2PairABI, owner)
        await USDC.transfer(pair.address, 1000000 * 10 ** 6);
        await USDT.transfer(pair.address, 1000000 * 10 ** 6);
        await pair.sync();
        await uniV3Router.createPair(OP.address, USDT.address);
        pairAddress = await uniV3Router.getPair(OP.address, USDT.address)
        pair = new ethers.Contract(pairAddress, UniswapV2PairABI, owner)
        await OP.transfer(pair.address, ether.mul(250000));
        await USDT.transfer(pair.address, 1000000 * 10 ** 6);
        await pair.sync();
        await uniV3Router.createPair(WETH.address, USDT.address);
        pairAddress = await uniV3Router.getPair(WETH.address, USDT.address)
        pair = new ethers.Contract(pairAddress, UniswapV2PairABI, owner)
        await WETH.transfer(pair.address, 500 * 10 ** 8);
        await USDT.transfer(pair.address, 1000000 * 10 ** 6);
        await pair.sync();
    }
    async function setStrategy() {
        await deployUniV3()
        let type = ["address", "uint24", "address"]
        //DAI-USDT
        let path = ethers.utils.defaultAbiCoder.encode(type, [USDT.address, 100, DAI.address])
        let data = {
            path: path,
            ratio: 5000,
            index:0
        }
        await aggregator.addUniV3Strategy(DAI.address, USDT.address, data)
        data.path = ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address", "uint24", "address"], [USDT.address, 100, USDC.address, 100, DAI.address])
        data.ratio = 2000
        await aggregator.addUniV3Strategy(DAI.address, USDT.address, data)

        let data2 = {
            path: [DAI.address, USDT.address],
            ratio: 3000,
            index :1
        }
        await aggregator.addUniV2Strategy(DAI.address, USDT.address, data2)
        //USDT-DAI
        path = ethers.utils.defaultAbiCoder.encode(type, [USDT.address, 100, DAI.address])
        data = {
            path: path,
            ratio: 4000,
            index:0
        }
        await aggregator.addUniV3Strategy(USDT.address, DAI.address, data)

        data2 = {
            path: [USDT.address, USDC.address, DAI.address],
            ratio: 4000,
            index:1
        }
        await aggregator.addUniV2Strategy(USDT.address, DAI.address, data2)

        data2 = {
            path: [USDT.address, DAI.address],
            ratio: 2000,
            index:1
        }
        await aggregator.addUniV2Strategy(USDT.address, DAI.address, data2)
        //DAI-USDC
        path = ethers.utils.defaultAbiCoder.encode(type, [USDC.address, 100, DAI.address])
        data = {
            path: path,
            ratio: 5000,
            index:0
        }
        await aggregator.addUniV3Strategy(DAI.address, USDC.address, data)

        data2 = {
            path: [DAI.address, USDC.address],
            ratio: 5000,
            index:1
        }
        await aggregator.addUniV2Strategy(DAI.address, USDC.address, data2)
        //USDC-DAI
        path = ethers.utils.defaultAbiCoder.encode(type, [USDC.address, 100, DAI.address])
        data = {
            path: path,
            ratio: 5000,
            index:0
        }
        await aggregator.addUniV3Strategy(USDC.address, DAI.address, data)

        data2 = {
            path: [USDC.address, DAI.address],
            ratio: 5000,
            index:1
        }
        await aggregator.addUniV2Strategy(USDC.address, DAI.address, data2)
        //DAI-OP
        path = ethers.utils.defaultAbiCoder.encode(type, [OP.address, 100, DAI.address])
        data = {
            path: path,
            ratio: 5000,
            index:0
        }
        await aggregator.addUniV3Strategy(DAI.address, OP.address, data)

        data2 = {
            path: [DAI.address, OP.address],
            ratio: 5000,
            index:1
        }
        await aggregator.addUniV2Strategy(DAI.address, OP.address, data2)
        //OP-DAI
        path = ethers.utils.defaultAbiCoder.encode(type, [OP.address, 100, DAI.address])
        data = {
            path: path,
            ratio: 5000,
            index:0
        }
        await aggregator.addUniV3Strategy(OP.address, DAI.address, data)

        data2 = {
            path: [OP.address, DAI.address],
            ratio: 5000,
            index:1
        }
        await aggregator.addUniV2Strategy(OP.address, DAI.address, data2)
        //USDT-USDC
        path = ethers.utils.defaultAbiCoder.encode(type, [USDC.address, 100, USDT.address])
        data = {
            path: path,
            ratio: 5000,
            index:0
        }
        await aggregator.addUniV3Strategy(USDT.address, USDC.address, data)

        data2 = {
            path: [USDT.address, USDC.address],
            ratio: 5000,
            index:1
        }
        await aggregator.addUniV2Strategy(USDT.address, USDC.address, data2)
        //USDC-USDT
        path = ethers.utils.defaultAbiCoder.encode(type, [USDC.address, 100, USDT.address])
        data = {
            path: path,
            ratio: 5000,
            index:0
        }
        await aggregator.addUniV3Strategy(USDC.address, USDT.address, data)

        data2 = {
            path: [USDC.address, USDT.address],
            ratio: 5000,
            index:1
        }
        await aggregator.addUniV2Strategy(USDC.address, USDT.address, data2)
        //USDT-OP
        path = ethers.utils.defaultAbiCoder.encode(type, [OP.address, 100, USDT.address])
        data = {
            path: path,
            ratio: 5000,
            index:0
        }
        await aggregator.addUniV3Strategy(USDT.address, OP.address, data)

        data2 = {
            path: [USDT.address, OP.address],
            ratio: 5000,
            index:1
        }
        await aggregator.addUniV2Strategy(USDT.address, OP.address, data2)
        //OP-USDT
        path = ethers.utils.defaultAbiCoder.encode(type, [OP.address, 100, USDT.address])
        data = {
            path: path,
            ratio: 5000,
            index:0
        }
        await aggregator.addUniV3Strategy(OP.address, USDT.address, data)

        data2 = {
            path: [OP.address, USDT.address],
            ratio: 5000,
            index:1
        }
        await aggregator.addUniV2Strategy(OP.address, USDT.address, data2)
        //USDT-WETH
        path = ethers.utils.defaultAbiCoder.encode(type, [WETH.address, 100, USDT.address])
        data = {
            path: path,
            ratio: 5000,
            index:0
        }
        await aggregator.addUniV3Strategy(USDT.address, WETH.address, data)

        data2 = {
            path: [USDT.address, WETH.address],
            ratio: 5000,
            index:1
        }
        await aggregator.addUniV2Strategy(USDT.address, WETH.address, data2)
        //WETH-USDT
        path = ethers.utils.defaultAbiCoder.encode(type, [WETH.address, 100, USDT.address])
        data = {
            path: path,
            ratio: 5000,
            index:0
        }
        await aggregator.addUniV3Strategy(WETH.address, USDT.address, data)

        data2 = {
            path: [WETH.address, USDT.address],
            ratio: 5000,
            index:1
        }
        await aggregator.addUniV2Strategy(WETH.address, USDT.address, data2)
    }
    async function testSwapIn(){
        await setStrategy()
        await DAI.connect(user1).approve(aggregator.address,ether.mul(10500))
        await aggregator.connect(user1).swapCustomIn(DAI.address,ether.mul(10500),USDT.address,ether.mul(10000).div(1000000000000))
    }
    async function testSwapOut(){
        await setStrategy()
        await USDT.connect(user1).approve(aggregator.address,ether.mul(10500))
        await aggregator.connect(user1).swapCustomOut(USDT.address,ether.mul(10000).div(1000000000000),DAI.address,ether.mul(9800))
    }
   
})