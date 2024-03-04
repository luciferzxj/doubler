import { expect } from 'chai'
import { BigNumber } from 'ethers'
const { ethers, upgrades } = require('hardhat')
const MoonPoolABI = require('../abis/MoonPool.json')
const UniswapV2PairABI = require('../abis/UniswapV2Pair.json')
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import {
    DoublerTe,
    DoublerTe__factory,
    FRNFT,
    DbrFarm,
    DbrFarm__factory,
    FRNFT__factory,
    DoublerHelper,
    DoublerHelper__factory,
    Aggregator,
    Aggregator__factory,
    MoonPool,
    MoonPoolFactory,
    MoonPoolFactory__factory,
    FastPriceFeedTest,
    FastPriceFeedTest__factory,
    TokenTe,
    TokenTe__factory,
    WETH9,
    WETH9__factory,
    UniV2Router,
    UniV2Router__factory,
    SwapRouter,
    SwapRouter__factory,
} from 'typechain-types'
describe.only('Moonpool Case List', () => {
    let accounts: SignerWithAddress[]
    let owner: SignerWithAddress
    let user1: SignerWithAddress
    let developer: SignerWithAddress
    let fr: FRNFT
    let dbr: TokenTe
    let priceFeed: FastPriceFeedTest
    let doublerPool: DoublerTe
    let doublerHelper: DoublerHelper
    let aggregator: Aggregator
    let factory: MoonPoolFactory
    let moon: MoonPool
    let nftName: string
    let dbrfarm: DbrFarm
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
        let temp = {
            uniswapV2Router: uniV2Router.address,
            uniswapV3Router: uniV3Router.address,
        }
        const MockSwapRouter: Aggregator__factory = await ethers.getContractFactory('Aggregator', owner)
        aggregator = await MockSwapRouter.deploy(temp, owner.address)
        await aggregator.deployed()
        await aggregator.updateSlippage(600);
        // deploy DoublerPool
        let tokens = [USDT.address, USDC.address, DAI.address, OP.address, WETH.address]
        const DoublerPool: DoublerTe__factory = await ethers.getContractFactory('DoublerTe', owner)
        doublerPool = await DoublerPool.deploy(tokens)
        await doublerPool.deployed()

        // deploy priceFeed
        const FastPriceFeed: FastPriceFeedTest__factory = await ethers.getContractFactory('FastPriceFeedTest', owner)
        priceFeed = await upgrades.deployProxy(FastPriceFeed)
        await priceFeed.deployed()
        await doublerPool.setNft(fr.address, priceFeed.address)

        const DBRFarm: DbrFarm__factory = await ethers.getContractFactory('DbrFarm', owner)
        dbrfarm = await DBRFarm.deploy(dbr.address)
        await dbrfarm.deployed()

        const DoublerHelper: DoublerHelper__factory = await ethers.getContractFactory('DoublerHelper', owner)
        doublerHelper = await upgrades.deployProxy(DoublerHelper)
        await doublerHelper.deployed()


        //mint Token
        await USDT.mint(200000 * 10 ** 6);
        await USDT.transfer(owner.address, 100000 * 10 ** 6);
        await USDT.transfer(user1.address, 100000 * 10 ** 6);
        await DAI.mint(ether.mul(200000));
        await DAI.transfer(owner.address, ether.mul(100000));
        await DAI.transfer(user1.address, ether.mul(100000));

        // init erc721
        await fr.initialize(doublerPool.address, owner.address)
        //init priceFeed
        await priceFeed.setAssetPrice(USDT.address, 1 * 10 ** 6, 6);
        await priceFeed.setAssetPrice(USDC.address, 1 * 10 ** 6, 6);
        await priceFeed.setAssetPrice(DAI.address, ether, 18);
        await priceFeed.setAssetPrice(WETH.address, 2000 * 10 ** 8, 8);
        await priceFeed.setAssetPrice(OP.address, ether.mul(4), 18);
    })
    describe('moon pool main case', () => {
        it('case: deploy uniV2 ', async () => {
            await deployUniV2()
        })
        it('case: deploy uniV3 ', async () => {
            await deployUniV3()
        })
        it('case: set Strategy ', async () => {
            await setStrategy()
        })
        it('case: testCreateFactory ', async () => {
            await createFactory()
        })
        it('case: test create DAI pool ', async () => {
            await createDAIPool()
        })
        it('case: test buy DAI  ', async () => {
            await buyDAI()
        })
        it('case: test sell DAI ', async () => {
            await sellDAI()
        })
        it('case: test input DAI to USDT ', async () => {
            await inputDAI(0)
        })
        it('case: test input DAI to USDC ', async () => {
            await inputDAI(1)
        })
        it('case: test input DAI to OP ', async () => {
            await inputDAI(2)
        })
        it('case: test output USDT to DAI ', async () => {
            await gainDAI(0)
        })
        it('case: test output USDC to DAI ', async () => {
            await gainDAI(1)
        })
        it('case: test output OP to DAI ', async () => {
            await gainDAI(2)
        })
        it('case: test create USDT pool ', async () => {
            await createUSDTPool()
        })
        it('case: test buy USDT  ', async () => {
            await buyUSDT()
        })
        it('case: test sell USDT  ', async () => {
            await sellUSDT()
        })
        it('case: test input USDT to USDC  ', async () => {
            await inputUSDT(0)
        })
        it('case: test input USDT to OP  ', async () => {
            await inputUSDT(1)
        })
        it('case: test input USDT to WETH  ', async () => {
            await inputUSDT(2)
        })
        it('case: test output USDC to USDT  ', async () => {
            await gainUSDT(0)
        })
        it('case: test output OP to USDT  ', async () => {
            await gainUSDT(1)
        })
        it('case: test output WETH to USDT  ', async () => {
            await gainUSDT(2)
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
        deployUniV3()
        let type = ["address", "uint24", "address"]
        //DAI-USDT
        let path = ethers.utils.defaultAbiCoder.encode(type, [USDT.address, 100, DAI.address])
        let data = {
            path: path,
            ratio: 5000,
        }
        await aggregator.addUniV3Strategy(DAI.address, USDT.address, data)
        data.path = ethers.utils.defaultAbiCoder.encode(["address", "uint24", "address", "uint24", "address"], [USDT.address, 100, USDC.address, 100, DAI.address])
        data.ratio = 2000
        await aggregator.addUniV3Strategy(DAI.address, USDT.address, data)

        let data2 = {
            path: [DAI.address, USDT.address],
            ratio: 3000,
        }
        await aggregator.addUniV2Strategy(DAI.address, USDT.address, data2)
        //USDT-DAI
        path = ethers.utils.defaultAbiCoder.encode(type, [USDT.address, 100, DAI.address])
        data = {
            path: path,
            ratio: 4000,
        }
        await aggregator.addUniV3Strategy(USDT.address, DAI.address, data)

        data2 = {
            path: [USDT.address, USDC.address, DAI.address],
            ratio: 4000,
        }
        await aggregator.addUniV2Strategy(USDT.address, DAI.address, data2)

        data2 = {
            path: [USDT.address, DAI.address],
            ratio: 2000,
        }
        await aggregator.addUniV2Strategy(USDT.address, DAI.address, data2)
        //DAI-USDC
        path = ethers.utils.defaultAbiCoder.encode(type, [USDC.address, 100, DAI.address])
        data = {
            path: path,
            ratio: 5000,
        }
        await aggregator.addUniV3Strategy(DAI.address, USDC.address, data)

        data2 = {
            path: [DAI.address, USDC.address],
            ratio: 5000,
        }
        await aggregator.addUniV2Strategy(DAI.address, USDC.address, data2)
        //USDC-DAI
        path = ethers.utils.defaultAbiCoder.encode(type, [USDC.address, 100, DAI.address])
        data = {
            path: path,
            ratio: 5000,
        }
        await aggregator.addUniV3Strategy(USDC.address, DAI.address, data)

        data2 = {
            path: [USDC.address, DAI.address],
            ratio: 5000,
        }
        await aggregator.addUniV2Strategy(USDC.address, DAI.address, data2)
        //DAI-OP
        path = ethers.utils.defaultAbiCoder.encode(type, [OP.address, 100, DAI.address])
        data = {
            path: path,
            ratio: 5000,
        }
        await aggregator.addUniV3Strategy(DAI.address, OP.address, data)

        data2 = {
            path: [DAI.address, OP.address],
            ratio: 5000,
        }
        await aggregator.addUniV2Strategy(DAI.address, OP.address, data2)
        //OP-DAI
        path = ethers.utils.defaultAbiCoder.encode(type, [OP.address, 100, DAI.address])
        data = {
            path: path,
            ratio: 5000,
        }
        await aggregator.addUniV3Strategy(OP.address, DAI.address, data)

        data2 = {
            path: [OP.address, DAI.address],
            ratio: 5000,
        }
        await aggregator.addUniV2Strategy(OP.address, DAI.address, data2)
        //USDT-USDC
        path = ethers.utils.defaultAbiCoder.encode(type, [USDC.address, 100, USDT.address])
        data = {
            path: path,
            ratio: 5000,
        }
        await aggregator.addUniV3Strategy(USDT.address, USDC.address, data)

        data2 = {
            path: [USDT.address, USDC.address],
            ratio: 5000,
        }
        await aggregator.addUniV2Strategy(USDT.address, USDC.address, data2)
        //USDC-USDT
        path = ethers.utils.defaultAbiCoder.encode(type, [USDC.address, 100, USDT.address])
        data = {
            path: path,
            ratio: 5000,
        }
        await aggregator.addUniV3Strategy(USDC.address, USDT.address, data)

        data2 = {
            path: [USDC.address, USDT.address],
            ratio: 5000,
        }
        await aggregator.addUniV2Strategy(USDC.address, USDT.address, data2)
        //USDT-OP
        path = ethers.utils.defaultAbiCoder.encode(type, [OP.address, 100, USDT.address])
        data = {
            path: path,
            ratio: 5000,
        }
        await aggregator.addUniV3Strategy(USDT.address, OP.address, data)

        data2 = {
            path: [USDT.address, OP.address],
            ratio: 5000,
        }
        await aggregator.addUniV2Strategy(USDT.address, OP.address, data2)
        //OP-USDT
        path = ethers.utils.defaultAbiCoder.encode(type, [OP.address, 100, USDT.address])
        data = {
            path: path,
            ratio: 5000,
        }
        await aggregator.addUniV3Strategy(OP.address, USDT.address, data)

        data2 = {
            path: [OP.address, USDT.address],
            ratio: 5000,
        }
        await aggregator.addUniV2Strategy(OP.address, USDT.address, data2)
        //USDT-WETH
        path = ethers.utils.defaultAbiCoder.encode(type, [WETH.address, 100, USDT.address])
        data = {
            path: path,
            ratio: 5000,
        }
        await aggregator.addUniV3Strategy(USDT.address, WETH.address, data)

        data2 = {
            path: [USDT.address, WETH.address],
            ratio: 5000,
        }
        await aggregator.addUniV2Strategy(USDT.address, WETH.address, data2)
        //WETH-USDT
        path = ethers.utils.defaultAbiCoder.encode(type, [WETH.address, 100, USDT.address])
        data = {
            path: path,
            ratio: 5000,
        }
        await aggregator.addUniV3Strategy(WETH.address, USDT.address, data)

        data2 = {
            path: [WETH.address, USDT.address],
            ratio: 5000,
        }
        await aggregator.addUniV2Strategy(WETH.address, USDT.address, data2)
    }
    async function createFactory() {
        setStrategy();
        let initMpF = {
            eco: developer.address,
            dbr: dbr.address,
            dbrFarm: dbrfarm.address,
            frnft: fr.address,
            doubler: doublerPool.address,
            priceFeed: priceFeed.address,
            swapRouter: aggregator.address,
        }
        const MoonPoolFactory: MoonPoolFactory__factory = await ethers.getContractFactory('MoonPoolFactory', owner)
        factory = await MoonPoolFactory.deploy(initMpF, [USDT.address, USDC.address, DAI.address])
        await factory.deployed()
    }
    async function createDAIPool() {
        await createFactory()
        await doublerPool.connect(owner).createDoubler(USDT.address, 10000 * 10 ** 6);
        await doublerPool.connect(owner).createDoubler(USDC.address, 10000 * 10 ** 6);
        await doublerPool.connect(owner).createDoubler(OP.address, ether.mul(2500));
        let rules = [{
            asset: USDT.address,
            fallRatioMin: 100,
            fallRatioMax: 200,
            profitRatioMin: 50,
            profitRatioMax: 10000,
            rewardRatioMin: 50,
            rewardRatioMax: 10000,
            winnerRatioMin: 50,
            winnerRatioMax: 10000,
            tvl: 5,
            layerInputMax: ether.mul(10000),
        },
        {
            asset: USDC.address,
            fallRatioMin: 100,
            fallRatioMax: 200,
            profitRatioMin: 50,
            profitRatioMax: 10000,
            rewardRatioMin: 50,
            rewardRatioMax: 10000,
            winnerRatioMin: 50,
            winnerRatioMax: 10000,
            tvl: 10,
            layerInputMax: ether.mul(10000),
        },
        {
            asset: OP.address,
            fallRatioMin: 100,
            fallRatioMax: 200,
            profitRatioMin: 50,
            profitRatioMax: 10000,
            rewardRatioMin: 50,
            rewardRatioMax: 10000,
            winnerRatioMin: 50,
            winnerRatioMax: 10000,
            tvl: 5,
            layerInputMax: ether.mul(10000),
        }]
        await USDT.mint(1000 * 10 ** 6)
        await USDT.transfer(doublerPool.address, 1000 * 10 ** 6)
        await USDC.mint(1000 * 10 ** 6)
        await USDC.transfer(doublerPool.address, 1000 * 10 ** 6)
        await OP.mint(ether.mul(250))
        await OP.transfer(doublerPool.address, ether.mul(250))
        await DAI.connect(owner).approve(factory.address, ether.mul(100000))
        let add = {
            srcAsset: DAI.address,
            duration: 30 * 86400,
            cap: ether.mul(1000000),
            initAmount: ether.mul(100000),
            creatorRewardRatio: 1000,
            triggerRewardRatio: 100,
            sellLimitCapRatio: 3000,
        }
        await factory.connect(owner).createMoonPool(add, rules)
        expect(await factory.moonPoolTotal()).to.be.equal(1)
        let moonAddr = await factory.getMoonPoolAddress(1)
        moon = new ethers.Contract(moonAddr, MoonPoolABI, owner)
        expect(await moon.balanceOf(owner.address)).to.be.equal(ether.mul(100000))
    }
    async function buyDAI() {
        await createDAIPool();
        await DAI.connect(user1).approve(moon.address, ether.mul(100000))
        await moon.connect(user1).buy(ether.mul(100000), user1.address)
        expect(await moon.balanceOf(user1.address)).to.be.equal(ether.mul(100000))
    }
    async function sellDAI() {
        await buyDAI()
        await moon.connect(user1).sell(ether.mul(100000))
        expect(await moon.totalSupply()).to.be.equal(ether.mul(100000))
        expect(await DAI.balanceOf(user1.address)).to.be.equal(ether.mul(98000))
    }
    async function inputDAI(poolId: number) {
        await createDAIPool()
        await moon.connect(developer).input(poolId, { gasLimit: 1e6 })
        expect((await moon.poolInfo()).pendingValue).to.be.least(ether.mul(10000))
    }
    async function gainDAI(poolId: number) {
        await inputDAI(poolId)
        await moon.connect(user1).output(1, { gasLimit: 1e6 })
        expect(((await moon.poolInfo()).pendingValue)).to.be.equal(0)
        expect(await DAI.balanceOf(owner.address)).to.be.least(ether.mul(90))
    }
    async function createUSDTPool() {
        await createFactory()
        await doublerPool.connect(owner).createDoubler(USDC.address, 10000 * 10 ** 6);
        await doublerPool.connect(owner).createDoubler(OP.address, ether.mul(2500));
        await doublerPool.connect(owner).createDoubler(WETH.address, 5 * 10 ** 8);
        let rules = [{
            asset: USDC.address,
            fallRatioMin: 100,
            fallRatioMax: 200,
            profitRatioMin: 50,
            profitRatioMax: 10000,
            rewardRatioMin: 50,
            rewardRatioMax: 10000,
            winnerRatioMin: 50,
            winnerRatioMax: 10000,
            tvl: 5,
            layerInputMax: 10000 * 10 ** 6,
        },
        {
            asset: OP.address,
            fallRatioMin: 100,
            fallRatioMax: 200,
            profitRatioMin: 50,
            profitRatioMax: 10000,
            rewardRatioMin: 50,
            rewardRatioMax: 10000,
            winnerRatioMin: 50,
            winnerRatioMax: 10000,
            tvl: 10,
            layerInputMax: 10000 * 10 ** 6,
        },
        {
            asset: WETH.address,
            fallRatioMin: 100,
            fallRatioMax: 200,
            profitRatioMin: 50,
            profitRatioMax: 10000,
            rewardRatioMin: 50,
            rewardRatioMax: 10000,
            winnerRatioMin: 50,
            winnerRatioMax: 10000,
            tvl: 5,
            layerInputMax: 10000 * 10 ** 6,
        }]
        await WETH.mint(5 * 10 ** 8)
        await WETH.transfer(doublerPool.address, 5 * 10 ** 7)
        await USDC.mint(1000 * 10 ** 6)
        await USDC.transfer(doublerPool.address, 1000 * 10 ** 6)
        await OP.mint(ether.mul(250))
        await OP.transfer(doublerPool.address, ether.mul(250))
        await USDT.connect(owner).approve(factory.address, 100000 * 10 ** 6)
        let add = {
            srcAsset: USDT.address,
            duration: 30 * 86400,
            cap: 1000000 * 10 ** 6,
            initAmount: 100000 * 10 ** 6,
            creatorRewardRatio: 1000,
            triggerRewardRatio: 100,
            sellLimitCapRatio: 3000,
        }
        await factory.connect(owner).createMoonPool(add, rules)
        expect(await factory.moonPoolTotal()).to.be.equal(1)
        let moonAddr = await factory.getMoonPoolAddress(1)
        moon = new ethers.Contract(moonAddr, MoonPoolABI, owner)
        expect(await moon.balanceOf(owner.address)).to.be.equal(100000 * 10 ** 6)
    }
    async function buyUSDT() {
        await createUSDTPool();
        await USDT.connect(user1).approve(moon.address, 100000 * 10 ** 6)
        await moon.connect(user1).buy(100000 * 10 ** 6, user1.address)
        expect(await moon.balanceOf(user1.address)).to.be.equal(100000 * 10 ** 6)
    }
    async function sellUSDT() {
        await buyUSDT()
        await moon.connect(user1).sell(100000 * 10 ** 6)
        expect(await moon.totalSupply()).to.be.equal(100000 * 10 ** 6)
        expect(await USDT.balanceOf(user1.address)).to.be.equal(98000 * 10 ** 6)
    }
    async function inputUSDT(poolId: number) {
        await createUSDTPool()
        await moon.connect(developer).input(poolId, { gasLimit: 1e6 })
        expect((await moon.poolInfo()).pendingValue).to.be.least(10000 * 10 ** 6)
    }
    async function gainUSDT(poolId: number) {
        await inputUSDT(poolId)
        await moon.connect(developer).output(1, { gasLimit: 1e6 })
        expect(((await moon.poolInfo()).pendingValue)).to.be.equal(0)
        expect(await USDT.balanceOf(owner.address)).to.be.least(90 * 10 ** 6)
    }
})