// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/FastPriceFeed.sol";
import "../src/interfaces/IFastPriceFeed.sol";
contract priceFeedTest is Test{
    //make addr
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    string private OPT_RPC = "https://opt-mainnet.g.alchemy.com/v2/jTyU-Rhb3RrfCDBAI2H1Jr6sgAeH0Fal";
    address constant LINK = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6;
    address constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address constant USDT = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
    address constant OP = 0x4200000000000000000000000000000000000042;
    address constant WLD = 0xdC6fF44d5d932Cbd77B52E5612Ba0529DC6226F1;
    address constant ONE = 0x68Ac1AfFe00cf64EbC71e7E835A6871A379C5587;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant WBTC = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;
    address constant SUSD = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;
    address constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address constant DOGE = 0xbA2aE424d960c26247Dd6c32edC70B295c744C43;
    FastPriceFeed oracle;
    IFastPriceFeed.Plan public plan;
    address pyth = 0xff1a0f4744e8582DF1aE09D5611b887B6a12925C;
    function setUp()public{
        vm.createSelectFork(OPT_RPC);
        oracle = new FastPriceFeed(owner);

    }
    function testAll()public{
        console.log("start testWETH");
        testWETH();
        console.log("end testWETH");
        console.log("");

        console.log("start testWLD");
        testWLD();
        console.log("end testWLD");
        console.log("");

        console.log("start testOP");
        testOP();
        console.log("end testOP");
        console.log("");

        console.log("start testUSDC");
        testUSDC();
        console.log("end testUSDC");
        console.log("");

        console.log("start testWBTC");
        testWBTC();
        console.log("end testWBTC");
        console.log("");

        console.log("start testDAI");
        testDAI();
        console.log("end testDAI");
        console.log("");

        console.log("start testUSDT");
        testUSDT();
        console.log("end testUSDT");
        console.log("");

        console.log("start testLINK");
        testLINK();
        console.log("end testLINK");
        console.log("");

        console.log("start testSUSD");
        testSUSD();
        console.log("end testSUSD");
        console.log("");

        console.log("start testDOGE");
        testDOGE();
        console.log("end testDOGE");
        console.log("");

        console.log("start testONE");
        testONE();
        console.log("end testONE");
    }
    function testWETH()public{

        vm.startPrank(owner);
        address univ3pool = 0x03aF20bDAaFfB4cC0A521796a223f7D85e2aAc31;//WETH-DAI
        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = WETH;
        limit[0] = IFastPriceFeed.PriceLimit(3200*10**18,3800*10**18);


        plan = IFastPriceFeed.Plan.DEX;
        oracle.newAsset(WETH,univ3pool,bytes32(0),5 minutes,plan,0);
        console.log("newAsset end");
        oracle.batchSetAssetPriceLimit(token,limit);
        console.log("batchSetAssetPriceLimit end");
        uint256 priceDex = oracle.getPrice(WETH);
        console.log("WETH Uniswap price :",priceDex);

        vm.stopPrank();
    }

    function testWLD()public{

        vm.startPrank(owner);
        address chainlink = 0x4e1C6B168DCFD7758bC2Ab9d2865f1895813D236;
        address univ3pool = 0xD1F1baD4c9E6c44DeC1e9bF3B94902205c5Cd6C3;
        bytes32 pythId = 0xd6835ad1f773de4a378115eb6824bd0c0e42d84d1c84d9750e853fb6b6c7794a;
        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = WLD;
        limit[0] = IFastPriceFeed.PriceLimit(7*10**18,10*10**18);


        plan = IFastPriceFeed.Plan.DEX;
        oracle.newAsset(WLD,univ3pool,bytes32(0),5 minutes,plan,0);
        console.log("newAsset end");
        oracle.batchSetAssetPriceLimit(token,limit);
        console.log("batchSetAssetPriceLimit end");

        uint256 priceDex = oracle.getPrice(WLD);
        console.log("WLD Uniswap price :",priceDex);
        
        plan = IFastPriceFeed.Plan.CHAINLINK;
        oracle.upgradePlan(WLD,chainlink,plan,bytes32(0),0);
        console.log("upgradePlan end1");
        uint256 priceChainlink = oracle.getPrice(WLD);
        console.log("WLD Chainlink price :",priceChainlink);

        plan = IFastPriceFeed.Plan.PYTH;
        oracle.upgradePlan(WLD,pyth,plan,pythId,1 days);
        console.log("upgradePlan end2");
        uint256 pricePyth = oracle.getPrice(WLD);
        console.log("WLD Pyth price :",pricePyth);
        
        vm.stopPrank();
    }

    function testOP()public{
        vm.startPrank(owner);
        address chainlink = 0x0D276FC14719f9292D5C1eA2198673d1f4269246;
        address univ3pool = 0x1C3140aB59d6cAf9fa7459C6f83D4B52ba881d36;
        bytes32 pythId = 0x385f64d993f7b77d8182ed5003d97c60aa3361f3cecfe711544d2d59165e9bdf;

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = OP;
        limit[0] = IFastPriceFeed.PriceLimit(3*10**18,5*10**18);


        plan = IFastPriceFeed.Plan.DEX;
        oracle.newAsset(OP,univ3pool,bytes32(0),5 minutes,plan,0);
        console.log("newAsset end");
        oracle.batchSetAssetPriceLimit(token,limit);
        console.log("batchSetAssetPriceLimit end");

        uint256 priceChainlink = oracle.getPrice(OP);
        console.log("OP Uniswap price :",priceChainlink);
        
        plan = IFastPriceFeed.Plan.CHAINLINK;
        oracle.upgradePlan(OP,chainlink,plan,bytes32(0),0);
        console.log("upgradePlan end1");
        uint256 priceDex = oracle.getPrice(OP);
        console.log("OP Chainlink price :",priceDex);

        plan = IFastPriceFeed.Plan.PYTH;
        oracle.upgradePlan(OP,pyth,plan,pythId,1 days);
        console.log("upgradePlan end2");
        uint256 pricePyth = oracle.getPrice(OP);
        console.log("OP Pyth price :",pricePyth);

        vm.stopPrank();
    }

    function testUSDC()public{

        vm.startPrank(owner);
        address chainlink = 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3;
        address univ3pool = 0xA73C628eaf6e283E26A7b1f8001CF186aa4c0E8E;
        bytes32 pythId = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = USDC;
        limit[0] = IFastPriceFeed.PriceLimit(9*10**17,1.1*10**18);


        plan = IFastPriceFeed.Plan.DEX;
        oracle.newAsset(USDC,univ3pool,bytes32(0),5 minutes,plan,0);
        console.log("newAsset end");
        oracle.batchSetAssetPriceLimit(token,limit);
        console.log("batchSetAssetPriceLimit end");

        uint256 priceDex = oracle.getPrice(USDC);
        console.log("USDC Uniswap price :",priceDex);
        
        plan = IFastPriceFeed.Plan.CHAINLINK;
        oracle.upgradePlan(USDC,chainlink,plan,bytes32(0),0);
        console.log("upgradePlan end1");
        uint256 priceChainlink = oracle.getPrice(USDC);
        console.log("USDC Chainlink price :",priceChainlink);

        plan = IFastPriceFeed.Plan.PYTH;
        oracle.upgradePlan(USDC,pyth,plan,pythId,200 days);
        console.log("upgradePlan end2");
        uint256 pricePyth = oracle.getPrice(USDC);
        console.log("USDC Pyth price :",pricePyth);

        vm.stopPrank();
    }

    function testWBTC()public{

        vm.startPrank(owner);
        address chainlink = 0x718A5788b89454aAE3A028AE9c111A29Be6c2a6F;
        bytes32 pythId = 0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33;

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = WBTC;
        limit[0] = IFastPriceFeed.PriceLimit(50000*10**18,65000*10**18);
        // DoublerOracle.Plan plan;

        plan = IFastPriceFeed.Plan.CHAINLINK;
        oracle.newAsset(WBTC,chainlink,bytes32(0),5 minutes,plan,0);
        console.log("newAsset end");
        oracle.batchSetAssetPriceLimit(token,limit);
        console.log("batchSetAssetPriceLimit end");

        uint256 priceChainlink = oracle.getPrice(WBTC);
        console.log("WBTC Chainlink price :",priceChainlink);

        // plan = IFastPriceFeed.Plan.PYTH;
        // oracle.upgradePlan(WBTC,pyth,plan,pythId,200 days);
        // uint256 pricePyth = oracle.getPrice(WBTC);
        // console.log("WBTC Pyth price :",pricePyth);

        vm.stopPrank();
    }
    function testUSDT()public{

        vm.startPrank(owner);
        address chainlink = 0xECef79E109e997bCA29c1c0897ec9d7b03647F5E;
        address univ3pool = 0xA73C628eaf6e283E26A7b1f8001CF186aa4c0E8E;
        bytes32 pythId = 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b;

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = USDT;
        limit[0] = IFastPriceFeed.PriceLimit(9*10**17,1.1*10**18);


        plan = IFastPriceFeed.Plan.DEX;
        oracle.newAsset(USDT,univ3pool,bytes32(0),5 minutes,plan,0);
        console.log("newAsset end");
        oracle.batchSetAssetPriceLimit(token,limit);
        console.log("batchSetAssetPriceLimit end");
        uint256 priceDex = oracle.getPrice(USDT);
        console.log("USDT Uniswap price :",priceDex);
        
        plan = IFastPriceFeed.Plan.CHAINLINK;
        oracle.upgradePlan(USDT,chainlink,plan,bytes32(0),0);
        console.log("upgradePlan end1");
        uint256 priceChainlink = oracle.getPrice(USDT);
        console.log("USDT Chainlink price :",priceChainlink);

        plan = IFastPriceFeed.Plan.PYTH;
        oracle.upgradePlan(USDT,pyth,plan,pythId,100 days);
        console.log("upgradePlan end2");
        uint256 pricePyth = oracle.getPrice(USDT);
        console.log("USDT Pyth price :",pricePyth);

        vm.stopPrank();
    }

    function testSUSD()public{

        vm.startPrank(owner);
        address chainlink = 0x7f99817d87baD03ea21E05112Ca799d715730efe;
        address univ3pool = 0xAdb35413eC50E0Afe41039eaC8B930d313E94FA4;

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = SUSD;
        limit[0] = IFastPriceFeed.PriceLimit(9*10**17,1.1*10**18);


        plan = IFastPriceFeed.Plan.DEX;
        oracle.newAsset(SUSD,univ3pool,bytes32(0),5 minutes,plan,0);
        console.log("newAsset end");
        oracle.batchSetAssetPriceLimit(token,limit);
        console.log("batchSetAssetPriceLimit end");
        uint256 priceDex = oracle.getPrice(SUSD);
        console.log("SUSD Uniswap price :",priceDex);
        
        plan = IFastPriceFeed.Plan.CHAINLINK;
        oracle.upgradePlan(SUSD,chainlink,plan,bytes32(0),0);
        console.log("upgradePlan end");
        uint256 priceChainlink = oracle.getPrice(SUSD);
        console.log("SUSD Chainlink price :",priceChainlink);

        vm.stopPrank();
    }

    function testDAI()public{

        vm.startPrank(owner);
        address chainlink = 0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6;
        address univ3pool = 0x100bdC1431A9b09C61c0EFC5776814285f8fB248;
        bytes32 pythId = 0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd;

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = DAI;
        limit[0] = IFastPriceFeed.PriceLimit(9*10**17,1.1*10**18);


        plan = IFastPriceFeed.Plan.DEX;
        oracle.newAsset(DAI,univ3pool,bytes32(0),5 minutes,plan,0);
        console.log("newAsset end");
        oracle.batchSetAssetPriceLimit(token,limit);
        console.log("batchSetAssetPriceLimit end");
        uint256 priceDex = oracle.getPrice(DAI);
        console.log("DAI Uniswap price :",priceDex);
        
        plan = IFastPriceFeed.Plan.CHAINLINK;
        oracle.upgradePlan(DAI,chainlink,plan,bytes32(0),0);
        console.log("upgradePlan end1");
        uint256 priceChainlink = oracle.getPrice(DAI);
        console.log("DAI Chainlink price :",priceChainlink);

        plan = IFastPriceFeed.Plan.PYTH;
        oracle.upgradePlan(DAI,pyth,plan,pythId,1000 days);
        console.log("upgradePlan end2");
        uint256 pricePyth = oracle.getPrice(DAI);
        console.log("DAI Pyth price :",pricePyth);

        vm.stopPrank();
    }

    function testDOGE()public{
        vm.startPrank(owner);
        address chainlink = 0xC6066533917f034Cf610c08e1fe5e9c7eADe0f54;
        bytes32 pythId = 0xdcef50dd0a4cd2dcc17e45df1676dcb336a11a61c69df7a0299b0150c672d25c;

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = DOGE;
        limit[0] = IFastPriceFeed.PriceLimit(1*10**17,2*10**17);

        plan = IFastPriceFeed.Plan.CHAINLINK;
        oracle.newAsset(DOGE,chainlink,bytes32(0),5 minutes,plan,0);
        console.log("newAsset end");
        oracle.batchSetAssetPriceLimit(token,limit);
        console.log("batchSetAssetPriceLimit end");

        uint256 priceChainlink = oracle.getPrice(DOGE);
        console.log("DOGE Chainlink price :",priceChainlink);

        plan = IFastPriceFeed.Plan.PYTH;
        oracle.upgradePlan(DOGE,pyth,plan,pythId,1 days);
        console.log("upgradePlan end");
        uint256 pricePyth = oracle.getPrice(DOGE);
        console.log("DOGE Pyth price :",pricePyth);

        vm.stopPrank();
    }

    function testLINK()public{
        vm.startPrank(owner);
        address chainlink = 0xCc232dcFAAE6354cE191Bd574108c1aD03f86450;
        bytes32 pythId = 0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221;

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = LINK;
        limit[0] = IFastPriceFeed.PriceLimit(18*10**18,20*10**18);
        // DoublerOracle.Plan plan;

        plan = IFastPriceFeed.Plan.CHAINLINK;
        oracle.newAsset(LINK,chainlink,bytes32(0),5 minutes,plan,0);
        console.log("newAsset end");
        oracle.batchSetAssetPriceLimit(token,limit);
        console.log("batchSetAssetPriceLimit end");
        // oracle.getLastedDataFromChainlink(LINK);
        uint256 priceChainlink = oracle.getPrice(LINK);
        console.log("LINK Chainlink price :",priceChainlink);

        plan = IFastPriceFeed.Plan.PYTH;
        oracle.upgradePlan(LINK,pyth,plan,pythId,1 days);
        console.log("upgradePlan end");
        uint256 pricePyth = oracle.getPrice(LINK);
        console.log("LINK Pyth price :",pricePyth);

        vm.stopPrank();
    }

    function testONE()public{
        vm.startPrank(owner);
        address chainlink = 0x7CFB4fac1a2FDB1267F8bc17FADc12804AC13CFE;

        address[] memory token = new address[](1);
        IFastPriceFeed.PriceLimit[] memory limit = new IFastPriceFeed.PriceLimit[](1);
        token[0] = ONE;
        limit[0] = IFastPriceFeed.PriceLimit(1*10**15,9*10**16);
        
        plan = IFastPriceFeed.Plan.CHAINLINK;
        oracle.newAsset(ONE,chainlink,bytes32(0),5 minutes,plan,0);
        console.log("newAsset end");
        oracle.batchSetAssetPriceLimit(token,limit);
        console.log("batchSetAssetPriceLimit end");

        uint256 priceChainlink = oracle.getPrice(ONE);
        console.log("ONE Chainlink price :",priceChainlink);

        vm.stopPrank();
    }

}