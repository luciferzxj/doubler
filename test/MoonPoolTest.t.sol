pragma solidity ^0.8.12;
import "forge-std/Test.sol";
// import 'forge-std/StdCheats.sol';
import "forge-std/console.sol";
import "../src/MoonPool.sol";
// import '../src/Doubler.sol';
import "../src/FRNFT.sol";
// import '../src/LP.sol';
import "../src/interfaces/IUniswapV3Factory.sol";
import "../src/interfaces/IUniswapV3Pool.sol";
// import "../src/interfaces/IUniswapV3SwapRouter.sol";
import "../src/Aggregator.sol";
import "../src/MoonPoolFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import '../src/uniswapV3/libraries/LiquidityAmounts.sol';
// import '../src/uniswapV3/libraries/TickMath.sol';
import "../src/test/FastPriceFeedTest.sol";
import "../src/test/UniswapRouterV2V3.sol";
contract MoonTest is Test {
    //rpc
    string private OPT_RPC =
        "https://opt-mainnet.g.alchemy.com/v2/jTyU-Rhb3RrfCDBAI2H1Jr6sgAeH0Fal";
    //EOA
    address developer = makeAddr("developer");
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    //token
    //mock
    address USDC = address(new Token("USDC", "USDC")); //6
    address USDT = address(new Token("USDT", "USDT"));
    address DAI = address(new Token("DAI", "DAI")); //6
    address OP = address(new Token("OP", "OP"));
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address WETH = address(new WETH9("WETH", "WETH"));
    //op
    // address USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;//6
    // address DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    // address USDT = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;//6
    // address OP = 0x4200000000000000000000000000000000000042;
    // address constant WETH = 0x4200000000000000000000000000000000000006;
    Aggregator aggregator;
    MoonPoolFactory factory;
    address dbrFarm;
    Doubler doubler;
    Token dbr;
    FRNFT fr;
    IMoonPool moon;
    //op
    // IUniV3SwapRouter uniV3Router = IUniV3SwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    //mock
    UniV2Router uniV2Router;
    swapRouter uniV3Router;
    FastPriceFeedTest priceFeed;
    function setUp() public {
        //op
        // vm.createSelectFork(OPT_RPC);
        // deal(USDT,owner,100000 * 10**6);
        // deal(USDT,user1,100000 * 10**6);
        // deal(DAI,owner,100000 ether);
        // deal(DAI,user1,100000 ether);
        //mock
        Token(USDT).mint(200000 * 10 ** 6);
        Token(USDT).transfer(owner, 100000 * 10 ** 6);
        Token(USDT).transfer(user1, 100000 * 10 ** 6);
        Token(DAI).mint(200000 ether);
        Token(DAI).transfer(owner, 100000 ether);
        Token(DAI).transfer(user1, 100000 ether);
        deployUni();
        initPriceFeed();
    }
    function initPriceFeed() internal {
        priceFeed = new FastPriceFeedTest();
        priceFeed.initialize();
        priceFeed.setAssetPrice(USDT, 1 *10**6, 6);
        priceFeed.setAssetPrice(USDC, 1 *10**6, 6);
        priceFeed.setAssetPrice(DAI, 1 ether, 18);
        priceFeed.setAssetPrice(WETH, 2000 *10**8, 8);
        priceFeed.setAssetPrice(OP, 4 ether, 18 );
    }
    function deployUni() internal {
        //deploy V2
        uniV2Router = new UniV2Router();
        createV2Pair();
        //deploy V3
        uniV3Router = new swapRouter();
        createV3Pair();
    }
    function createV2Pair() internal {
        Token(USDT).mint(4000000 * 10 ** 6);
        Token(DAI).mint(3000000 ether);
        Token(USDC).mint(2000000 * 10 ** 6);
        Token(OP).mint(500000 ether);
        Token(WETH).mint(500 * 10 ** 8);
        address pair = uniV2Router.createPair(DAI, USDT);
        IERC20(DAI).transfer(pair, 1000000 ether);
        IERC20(USDT).transfer(pair, 1000000 * 10 ** 6);
        UniswapV2Pair(pair).sync();
        pair = uniV2Router.createPair(DAI, USDC);
        IERC20(DAI).transfer(pair, 1000000 ether);
        IERC20(USDC).transfer(pair, 1000000 * 10 ** 6);
        UniswapV2Pair(pair).sync();
        pair = uniV2Router.createPair(DAI, OP);
        IERC20(DAI).transfer(pair, 1000000 ether);
        IERC20(OP).transfer(pair, 250000 ether);
        UniswapV2Pair(pair).sync();
        pair = uniV2Router.createPair(USDC, USDT);
        IERC20(USDC).transfer(pair, 1000000 * 10 ** 6);
        IERC20(USDT).transfer(pair, 1000000 * 10 ** 6);
        UniswapV2Pair(pair).sync();
        pair = uniV2Router.createPair(OP, USDT);
        IERC20(OP).transfer(pair, 250000 ether);
        IERC20(USDT).transfer(pair, 1000000 * 10 ** 6);
        UniswapV2Pair(pair).sync();
        pair = uniV2Router.createPair(WETH, USDT);
        IERC20(WETH).transfer(pair, 500 * 10 ** 8);
        IERC20(USDT).transfer(pair, 1000000 * 10 ** 6);
        UniswapV2Pair(pair).sync();
    }

    function createV3Pair() internal {
        Token(USDT).mint(400000 * 10 ** 6);
        Token(DAI).mint(300000 ether);
        Token(USDC).mint(200000 * 10 ** 6);
        Token(OP).mint(50000 ether);
        Token(WETH).mint(50 * 10 ** 8);
        address pair = uniV3Router.createPair(DAI, USDT);
        IERC20(DAI).transfer(pair, 100000 ether);
        IERC20(USDT).transfer(pair, 100000 * 10 ** 6);
        UniswapV3Pair(pair).sync();
        pair = uniV3Router.createPair(DAI, USDC);
        IERC20(DAI).transfer(pair, 100000 ether);
        IERC20(USDC).transfer(pair, 100000 * 10 ** 6);
        UniswapV3Pair(pair).sync();
        pair = uniV3Router.createPair(DAI, OP);
        IERC20(DAI).transfer(pair, 100000 ether);
        IERC20(OP).transfer(pair, 25000 ether);
        UniswapV3Pair(pair).sync();
        pair = uniV3Router.createPair(USDC, USDT);
        IERC20(USDC).transfer(pair, 100000 * 10 ** 6);
        IERC20(USDT).transfer(pair, 100000 * 10 ** 6);
        UniswapV3Pair(pair).sync();
        pair = uniV3Router.createPair(OP, USDT);
        IERC20(OP).transfer(pair, 25000 ether);
        IERC20(USDT).transfer(pair, 100000 * 10 ** 6);
        UniswapV3Pair(pair).sync();
        pair = uniV3Router.createPair(WETH, USDT);
        IERC20(WETH).transfer(pair, 50 * 10 ** 8);
        IERC20(USDT).transfer(pair, 100000 * 10 ** 6);
        UniswapV3Pair(pair).sync();
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        (address token1, address token2) = abi.decode(data, (address, address));
        Token(token1).mint(amount0Owed);
        IERC20(token1).transfer(msg.sender, amount0Owed);
        Token(token2).mint(amount1Owed);
        IERC20(token2).transfer(msg.sender, amount1Owed);
    }
    function testCreateFactory() public {
        vm.startPrank(owner);
        console.log("start create moonpool factory");
        address[] memory tokens = new address[](6);
        tokens[0] = USDC;
        tokens[1] = DAI;
        tokens[2] = USDT;
        tokens[3] = OP;
        tokens[4] = ETH;
        tokens[5] = WETH;
        doubler = new Doubler(tokens);
        fr = new FRNFT("FRNFT", "FR");
        doubler.setNft(address(fr),address(priceFeed));
        dbr = new Token("DBR", "D");
        dbrFarm = address(new DbrFarm(address(dbr)));
        Aggregator.RouterConfig memory temp;
        temp.uniswapV3Router = address(uniV3Router);
        temp.uniswapV2Router = address(uniV2Router);
        aggregator = new Aggregator(temp,owner);
        aggregator.updateSlippage(600);
        fr.initialize(address(doubler), owner);
        MoonPoolFactory.BaseConfig memory cfg;
        cfg.eco = developer;
        cfg.doubler = address(doubler);
        cfg.dbr = address(dbr);
        cfg.dbrFarm = dbrFarm;
        cfg.frnft = address(fr);
        cfg.swapRouter = address(aggregator);
        cfg.priceFeed = address(priceFeed);
        address[] memory token = new address[](3);
        token[0] = DAI;
        token[1] = USDC;
        token[2] = USDT;
        factory = new MoonPoolFactory(cfg, token);
        console.log("end create moonpool factory");
        setStrategy();
        vm.stopPrank();
    }
    function setStrategy() internal {
        Aggregator.UniV3Data memory data;
        Aggregator.UniV2Data memory data2;
        //OP
        //DAI-USDT
        // data.path = abi.encodePacked(USDT,uint24(100),DAI);
        // data.ratio = 10000;
        // aggregator.addUniV3Strategy(DAI, USDT, data);

        // data.path = abi.encodePacked(USDT,uint24(100),DAI);
        // data.ratio = 10000;
        // aggregator.addUniV3Strategy(USDT, DAI, data);

        // //DAI-USDC
        // data.path = abi.encodePacked(USDC,uint24(100),DAI);
        // data.ratio = 10000;
        // aggregator.addUniV3Strategy(DAI, USDC, data);

        // data.path = abi.encodePacked(USDC,uint24(100),DAI);
        // data.ratio = 10000;
        // aggregator.addUniV3Strategy(USDC, DAI, data);
        // //DAI-OP
        // data.path = abi.encodePacked(OP,uint24(10000),DAI);
        // data.ratio = 10000;
        // aggregator.addUniV3Strategy(DAI, OP, data);

        // data.path = abi.encodePacked(OP,uint24(10000),DAI);
        // data.ratio = 10000;
        // aggregator.addUniV3Strategy(OP, DAI, data);
        // //USDT-USDC
        // data.path = abi.encodePacked(USDC,uint24(100),USDT);
        // data.ratio = 10000;
        // aggregator.addUniV3Strategy(USDT, USDC, data);

        // data.path = abi.encodePacked(USDC,uint24(100),USDT);
        // data.ratio = 10000;
        // aggregator.addUniV3Strategy(USDC, USDT, data);
        // //USDT-OP
        // data.path = abi.encodePacked(OP,uint24(3000),USDT);
        // data.ratio = 10000;
        // aggregator.addUniV3Strategy(USDT, OP, data);

        // data.path = abi.encodePacked(OP,uint24(3000),USDT);
        // data.ratio = 10000;
        // aggregator.addUniV3Strategy(OP, USDT, data);
        // //USDT-WETH
        // data.path = abi.encodePacked(WETH,uint24(500),USDT);
        // data.ratio = 10000;
        // aggregator.addUniV3Strategy(USDT, WETH, data);

        // data.path = abi.encodePacked(WETH,uint24(500),USDT);
        // data.ratio = 10000;
        // aggregator.addUniV3Strategy(WETH, USDT, data);
        //本地mock
        //DAI-USDT
        data.path = abi.encode(USDT, uint24(100), DAI);
        data.ratio = 5000;
        aggregator.addUniV3Strategy(DAI, USDT, data);

        data.path = abi.encode(USDT, uint24(100), USDC, uint24(100), DAI);
        data.ratio = 2000;
        aggregator.addUniV3Strategy(DAI, USDT, data);

        data2.path = new address[](2);
        data2.path[0] = DAI;
        data2.path[1] = USDT;
        data2.ratio = 3000;
        aggregator.addUniV2Strategy(DAI, USDT, data2);
        //USDT-DAI
        data.path = abi.encode(USDT, uint24(100), DAI);
        data.ratio = 4000;
        aggregator.addUniV3Strategy(USDT, DAI, data);

        data2.path = new address[](2);
        data2.path[0] = USDT;
        data2.path[1] = DAI;
        data2.ratio = 4000;
        aggregator.addUniV2Strategy(USDT, DAI, data2);

        data2.path = new address[](3);
        data2.path[0] = USDT;
        data2.path[1] = USDC;
        data2.path[2] = DAI;
        data2.ratio = 2000;
        aggregator.addUniV2Strategy(USDT, DAI, data2);

        //DAI-USDC
        data.path = abi.encode(USDC, uint24(100), DAI);
        data.ratio = 5000;
        aggregator.addUniV3Strategy(DAI, USDC, data);

        data2.path = new address[](2);
        data2.path[0] = DAI;
        data2.path[1] = USDC;
        data2.ratio = 5000;
        aggregator.addUniV2Strategy(DAI, USDC, data2);
        //USDC-DAI
        data.path = abi.encode(USDC, uint24(100), DAI);
        data.ratio = 5000;
        aggregator.addUniV3Strategy(USDC, DAI, data);

        data2.path = new address[](2);
        data2.path[0] = USDC;
        data2.path[1] = DAI;
        data2.ratio = 5000;
        aggregator.addUniV2Strategy(USDC, DAI, data2);
        //DAI-OP
        data.path = abi.encode(OP, uint24(10000), DAI);
        data.ratio = 5000;
        aggregator.addUniV3Strategy(DAI, OP, data);

        data2.path = new address[](2);
        data2.path[0] = DAI;
        data2.path[1] = OP;
        data2.ratio = 5000;
        aggregator.addUniV2Strategy(DAI, OP, data2);
        //OP-DAI
        data.path = abi.encode(OP, uint24(10000), DAI);
        data.ratio = 5000;
        aggregator.addUniV3Strategy(OP, DAI, data);

        data2.path = new address[](2);
        data2.path[0] = OP;
        data2.path[1] = DAI;
        data2.ratio = 5000;
        aggregator.addUniV2Strategy(OP, DAI, data2);
        //USDT-USDC
        data.path = abi.encode(USDC, uint24(100), USDT);
        data.ratio = 5000;
        aggregator.addUniV3Strategy(USDT, USDC, data);

        data2.path = new address[](2);
        data2.path[0] = USDT;
        data2.path[1] = USDC;
        data2.ratio = 5000;
        aggregator.addUniV2Strategy(USDT, USDC, data2);
        //USDC-USDT
        data.path = abi.encode(USDC, uint24(100), USDT);
        data.ratio = 5000;
        aggregator.addUniV3Strategy(USDC, USDT, data);

        data2.path = new address[](2);
        data2.path[0] = USDC;
        data2.path[1] = USDT;
        data2.ratio = 5000;
        aggregator.addUniV2Strategy(USDC, USDT, data2);
        //USDT-OP
        data.path = abi.encode(OP, uint24(3000), USDT);
        data.ratio = 5000;
        aggregator.addUniV3Strategy(USDT, OP, data);

        data2.path = new address[](2);
        data2.path[0] = USDT;
        data2.path[1] = OP;
        data2.ratio = 5000;
        aggregator.addUniV2Strategy(USDT, OP, data2);
        //OP-USDT
        data.path = abi.encode(OP, uint24(3000), USDT);
        data.ratio = 5000;
        aggregator.addUniV3Strategy(OP, USDT, data);

        data2.path = new address[](2);
        data2.path[0] = OP;
        data2.path[1] = USDT;
        data2.ratio = 5000;
        aggregator.addUniV2Strategy(OP, USDT, data2);
        //USDT-WETH
        data.path = abi.encode(WETH, uint24(500), USDT);
        data.ratio = 5000;
        aggregator.addUniV3Strategy(USDT, WETH, data);

        data2.path = new address[](2);
        data2.path[0] = USDT;
        data2.path[1] = WETH;
        data2.ratio = 5000;
        aggregator.addUniV2Strategy(USDT, WETH, data2);
        //WETH-USDT
        data.path = abi.encode(WETH, uint24(500), USDT);
        data.ratio = 5000;
        aggregator.addUniV3Strategy(WETH, USDT, data);

        data2.path = new address[](2);
        data2.path[0] = WETH;
        data2.path[1] = USDT;
        data2.ratio = 5000;
        aggregator.addUniV2Strategy(WETH, USDT, data2);

        console.log("set swap startegy end");
    }
    //DAI池
    function testDaiCreatePool() public {
        testCreateFactory();
        vm.startPrank(owner);
        console.log("start create DAI moonpool");
        doubler.createDoubler(USDT,10000 *10**6);
        doubler.createDoubler(USDC,10000 *10**6);
        doubler.createDoubler(OP,1000 ether);
        IMoonPool.InputRule[] memory rules = new IMoonPool.InputRule[](3);
        rules[0] = IMoonPool.InputRule(
            USDT,
            100,
            200,
            50,
            10000,
            50,
            10000,
            50,
            10000,
            5,
            10000 ether
        );
        rules[1] = IMoonPool.InputRule(
            USDC,
            110,
            190,
            100,
            5000,
            50,
            10000,
            200,
            9000,
            10,
            10000 ether
        );
        rules[2] = IMoonPool.InputRule(
            OP,
            100,
            200,
            50,
            10000,
            50,
            10000,
            50,
            10000,
            5,
            10000 ether
        );
        deal(USDC, address(doubler), 1000 * 10 ** 6);
        deal(USDT, address(doubler), 1000 * 10 ** 6);
        deal(OP, address(doubler), 100 ether);
        IERC20(DAI).approve(address(factory), 100000 ether);
        MoonPoolFactory.AddMoonPool memory add;
        add.srcAsset=DAI;
        add.duration = 30 days;
        add.cap = 1000000 ether;
        add.initAmount = 100000 ether;
        add.creatorRewardRatio = 1000;
        add.triggerRewardRatio = 100;
        add.sellLimitCapRatio =3000;
        factory.createMoonPool(
            add,
            rules
        );
        assertEq(factory.moonPoolTotal(), 1);
        moon = IMoonPool(factory.getMoonPoolAddress(1));
        assertEq(IERC20(address(moon)).balanceOf(owner), 100000 ether);
        console.log("end create DAI moonpool");
        vm.stopPrank();
    }

    function testDaiDeposit() public {
        testDaiCreatePool();
        vm.startPrank(user1);
        console.log("start buy DAI");
        IERC20(DAI).approve(address(moon), 100000 ether);
        moon.buy(100000 ether,user1);
        assertEq(IERC20(address(moon)).balanceOf(user1), 100000 ether);
        console.log("end buy DAI");
        vm.stopPrank();
    }

    function testDaiWithdraw() public {
        testDaiDeposit();
        vm.startPrank(user1);
        console.log("start sell DAI");
        moon.sell(100000 ether);
        assertEq(IERC20(address(moon)).totalSupply(), 100000 ether);
        assertEq(IERC20(address(DAI)).balanceOf(user1) / 1 ether, 98000);
        console.log("end sell DAI");
        vm.stopPrank();
    }
    function testInputDAI1() public {
        testDaiDeposit();
        console.log("start input DAI to USDT doubler");
        vm.startPrank(developer);
        moon.input(0);
        assertGt(moon.poolInfo().pendingValue, 10000 ether);
        console.log("end input DAI to USDT doubler");
        vm.stopPrank();
    }

    function testInputDAI2() public {
        testDaiDeposit();
        vm.startPrank(developer);
        console.log("start input DAI to USDC doubler");
        moon.input(1);
        assertGt(moon.poolInfo().pendingValue, 10000 ether);
        console.log("end input DAI to USDc doubler");
        vm.stopPrank();
    }
    function testInputDAI3() public {
        testDaiDeposit();
        vm.startPrank(developer);
        console.log("start input DAI to OP doubler");
        moon.input(2);
        assertGt(moon.poolInfo().pendingValue, 4000 ether);
        console.log("start end DAI to OP doubler");
        vm.stopPrank();
    }

    function testGainDAI1() public {
        testInputDAI1();
        vm.startPrank(developer);
        console.log("start gain USDT doubler");
        moon.output(1);
        assertEq(moon.poolInfo().pendingValue, 0);
        assertGt(IERC20(DAI).balanceOf(owner),90 ether);
        console.log("end gain USDT doubler");
        vm.stopPrank();
    }
    function testGainDAI2() public {
        testInputDAI2();
        vm.startPrank(developer);
        console.log("start gain USDC doubler");
        moon.output(1);
        assertEq(moon.poolInfo().pendingValue, 0);
        assertGt(IERC20(DAI).balanceOf(owner),90 ether);
        console.log("end gain USDC doubler");
        vm.stopPrank();
    }
    function testGainDAI3() public {
        testInputDAI3();
        vm.startPrank(developer);
        console.log("start gain OP doubler");
        moon.output(1);
        assertEq(moon.poolInfo().pendingValue, 0);
        assertGt(IERC20(DAI).balanceOf(owner),35 ether);
        console.log("end gain OP doubler");
        vm.stopPrank();
    }

    //USDT
    function testUSDTCreatePool() public {
        testCreateFactory();
        vm.startPrank(owner);
        console.log("start create USDT moonpool");
        doubler.createDoubler(USDC,10000 *10**6);
        doubler.createDoubler(OP,1000 ether);
        doubler.createDoubler(WETH,5 *10**8);
        IMoonPool.InputRule[] memory rules = new IMoonPool.InputRule[](3);
        rules[0] = IMoonPool.InputRule(
            USDC,
            100,
            200,
            50,
            10000,
            50,
            10000,
            50,
            10000,
            5,
            10000 *10**6
        );
        rules[1] = IMoonPool.InputRule(
            OP,
            110,
            190,
            100,
            5000,
            50,
            10000,
            200,
            9000,
            10,
            10000 *10**6
        );
        rules[2] = IMoonPool.InputRule(
            WETH,
            100,
            200,
            50,
            10000,
            50,
            10000,
            50,
            10000,
            5,
            10000*10**6
        );
        deal(WETH, address(doubler), 1 * 10 ** 8);
        deal(OP, address(doubler), 100 ether);
        IERC20(USDT).approve(address(factory), 100000 * 10 ** 6);
        MoonPoolFactory.AddMoonPool memory add;
        add.srcAsset=USDT;
        add.duration = 30 days;
        add.cap = 1000000 *10**6;
        add.initAmount = 100000*10**6;
        add.creatorRewardRatio = 1000;
        add.triggerRewardRatio = 100;
        add.sellLimitCapRatio =3000;
        factory.createMoonPool(
            add,
            rules
        );
        assertEq(factory.moonPoolTotal(), 1);
        moon = IMoonPool(factory.getMoonPoolAddress(1));
        assertEq(IERC20(address(moon)).balanceOf(owner), 100000 * 10 ** 6);
        console.log("end create USDT moonpool");
        vm.stopPrank();
    }

    function testUSDTDeposit() public {
        testUSDTCreatePool();
        console.log("start buy USDT");
        vm.startPrank(user1);
        IERC20(USDT).approve(address(moon), 100000 * 10 ** 6);
        moon.buy(100000 * 10 ** 6, user1);
        assertEq(IERC20(address(moon)).balanceOf(user1), 100000 * 10 ** 6);
        console.log("end buy USDT");
        vm.stopPrank();
    }

    function testUSDTWithdraw() public {
        testUSDTDeposit();
        vm.startPrank(user1);
        console.log("start sell USDT");
        moon.sell(100000 * 10 ** 6);
        assertEq(IERC20(address(moon)).totalSupply(), 100000 * 10 ** 6);
        assertEq(IERC20(address(USDT)).balanceOf(user1) / 10 ** 6, 98000);
        console.log("end sell USDT");
        vm.stopPrank();
    }

    function testInputUSDT1() public {
        testUSDTDeposit();
        vm.startPrank(developer); 
        console.log("start input USDT to USDC doubler");
        moon.input(0);
        assertGt(moon.poolInfo().pendingValue, 10000 * 10 ** 6);
        console.log("end input USDT to USDC doubler");
        vm.stopPrank();
    }

    function testInputUSDT2() public {
        testUSDTDeposit();
        vm.startPrank(developer);
        console.log("start input USDT to OP doubler");
        moon.input(1);
        assertGt(moon.poolInfo().pendingValue, 4000 * 10 ** 6);
        console.log("end input USDT to OP doubler");
        vm.stopPrank();
    }
    function testInputUSDT3() public {
        testUSDTDeposit();
        vm.startPrank(developer);
        console.log("start input USDT to WETH doubler");
        moon.input(2);
        assertGt(moon.poolInfo().pendingValue, 10000 * 10 ** 6);
        console.log("end input USDT to WETH doubler");
        vm.stopPrank();
    }

    function testGainUSDT1() public {
        testInputUSDT1();
        vm.startPrank(developer);
        console.log("start gain USDC doubler");
        moon.output(1);
        assertEq(moon.poolInfo().pendingValue, 0);
        assertEq(IERC20(USDT).balanceOf(owner),0);
        console.log("end gain USDC doubler");
        vm.stopPrank();
    }
    function testGainUSDT2() public {
        testInputUSDT2();
        vm.startPrank(developer);
        console.log("start gain OP doubler");
        moon.output(1);
        assertEq(moon.poolInfo().pendingValue, 0);
        assertGt(IERC20(USDT).balanceOf(owner),38 *10**6);
        console.log("end gain OP doubler");
        vm.stopPrank();
    }
    function testGainUSDT3() public {
        testInputUSDT3();
        vm.startPrank(developer);
        console.log("start gain WETH doubler");
        moon.output(1);
        assertEq(moon.poolInfo().pendingValue, 0);
        assertGt(IERC20(USDT).balanceOf(owner),195 *10**6);
        console.log("end gain WETH doubler");
        vm.stopPrank();
    }
}

contract Doubler {
    struct Asset {
        bool isOpen;
    }
    struct Pool {
        address asset;
        address creator;
        address terminator;
        uint16 fallRatio;
        uint16 profitRatio;
        uint16 rewardRatio;
        uint16 winnerRatio;
        uint32 double;
        uint32 lastLayer;
        uint256 tokenId;
        uint256 unitSize;
        uint256 maxRewardUnits;
        uint256 winnerOffset;
        uint256 endPrice;
        uint256 lastOpenPrice;
        uint256 tvl;
        uint256 amount;
        uint256 margin;
        uint256 joins;
        uint256 lastInputBlockNo;
        uint256 kTotal;
    }
    struct AddInput {
        uint32 layer;
        uint256 poolId;
        uint256 margin;
        uint256 multiple;
        uint256 amount;
        uint256 curPrice;
    }
    struct LayerData {
        uint256 openPrice; // open layer price
        uint256 amount;
        uint256 tvl;
        uint256 cap;
    }
    mapping(address => Asset) public tokens;
    mapping(uint256 => LayerData) public layers;
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    Pool[] pools;
    IFRNFT fr;
    FastPriceFeedTest feed;
    function getAssetConfigMap(
        address token
    ) public view returns (Asset memory) {
        return tokens[token];
    }

    function getPool(uint256 poolId) public view returns (Pool memory) {
        return pools[poolId];
    }
    function getLayerData(uint256 _poolId, uint32 _layer) external view returns (LayerData memory){
        return layers[_poolId];
        
    }
    function setLayerData()public{

    }
    function createDoubler(address token,uint256 cap) public {
        Pool memory pool;
        pool.asset = token;
        pool.creator = msg.sender;
        pool.fallRatio = 150;
        pool.profitRatio = 3000;
        pool.rewardRatio = 5000;
        pool.winnerRatio = 5000;
        pool.tvl = 10000;
        pool.unitSize = 1 *10**Token(token).decimals();
        // pool.endPrice = 10;
        pools.push(pool);

        LayerData storage layer = layers[pools.length-1];
        layer.cap = cap;

    }

    constructor(address[] memory _tokens) {
        for (uint i = 0; i < _tokens.length; i++) {
            tokens[_tokens[i]].isOpen = true;
        }
    }

    function input(
        AddInput memory _addInput
    ) external payable returns (uint256 tokenId) {
        Pool storage pool = pools[_addInput.poolId];
        if (
            IERC20(pool.asset).allowance(msg.sender, address(this)) <
            _addInput.margin
        ) revert();
        if (IERC20(pool.asset).balanceOf(msg.sender) < _addInput.margin)
            revert();
        IERC20(pool.asset).transferFrom(
            msg.sender,
            address(this),
            _addInput.margin
        );
        uint256 curPrice = feed.getPrice(pool.asset);
        tokenId = fr.mint(
            msg.sender,
            _addInput.poolId,
            _addInput.layer,
            _addInput.margin,
            _addInput.amount,
            curPrice,
            0
        );
        pool.endPrice = 10;
    }
    function setNft(address _fr,address priceFeed) public {
        fr = IFRNFT(_fr);
        feed = FastPriceFeedTest(priceFeed);
    }
    function gain(uint256 _tokenId) external returns (uint256 amount) {
        FRNFT.Traits memory nft = fr.getTraits(_tokenId);
        Pool memory pool = pools[nft.poolId];
        amount = IERC20(pool.asset).balanceOf(address(this));
        IERC20(pool.asset).transfer(msg.sender, amount);
    }
}
contract DbrFarm {
    Token dbr;
    constructor(address _dbr) {
        dbr = Token(_dbr);
    }
    function join(uint256 _tokenId) external {}
    function left(uint256 _tokenId) external returns (uint256 claimAmount) {
        dbr.mint(10 ether);
        dbr.transfer(msg.sender, 10 ether);
        claimAmount = 10 ether;
    }
    function addMoonPoolRole(address _moonpool) external{}
}
contract Token is ERC20, Ownable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        if (
            keccak256(bytes(name())) == keccak256(bytes("USDT")) ||
            keccak256(bytes(name())) == keccak256(bytes("USDC"))
        ) {
            return 6;
        } else {
            return 18;
        }
    }
}

contract WETH9 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function decimals() public view virtual override returns (uint8) {
        return 8;
    }
    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }
    function withdraw(uint256 amount) public {
        _burn(msg.sender, amount);
        payable(msg.sender).call{value: amount}("");
    }
    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
