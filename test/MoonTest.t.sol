pragma solidity ^0.8.12;
import 'forge-std/Test.sol';
// import 'forge-std/StdCheats.sol';
import 'forge-std/console.sol';
import '../src/MoonPool.sol';
// import '../src/Doubler.sol';
import '../src/FRNFT.sol';
import '../src/LP.sol';
import '../src/MoonPoolFactory.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
contract MoonTest is Test{
    //网络rpc
    string constant OP_TEST= 'https://opt-sepolia.g.alchemy.com/v2/vdFQmXEt1j8hW791DhizA5NdMlTQlAxC';
    string private OPT_RPC = 'https://opt-mainnet.g.alchemy.com/v2/jTyU-Rhb3RrfCDBAI2H1Jr6sgAeH0Fal';
    //EOA地址
    address signer = 0x56865ed38a0e9B4C517F1612057A90E6143FBD87;
    address developer = makeAddr('developer');
    address owner = makeAddr('owner');
    address user1 = makeAddr('user1');
    //代币地址
    address USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;//6
    address DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address USDT = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;//6
    address OP = 0x4200000000000000000000000000000000000042;
    address STG = 0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97;
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    //合约
    IOneInch aggregator = IOneInch(0x1111111254EEB25477B68fb85Ed929f73A960582);
    address executor = 0xB63AaE6C353636d66Df13b89Ba4425cfE13d10bA;
    Factory factory;
    address dbrFarm;
    Doubler doubler;
    Token dbr;
    FRNFT fr;
    IMoonPool moon;
    function setUp()public{
        //环境构造
        vm.createSelectFork(OPT_RPC);
        // deal(USDC,owner,100000 * 10**6);
        deal(USDT,owner,100000 * 10**6);
        deal(USDT,user1,100000 * 10**6);
        deal(DAI,owner,100000 ether);
        deal(DAI,user1,100000 ether);
        // assertEq(IERC20(USDT).balanceOf(owner),100000*10**6);
        // assertEq(IERC20(DAI).balanceOf(owner),100000 ether);
        // initializeMoon();
    }   


    // function initializeMoon()internal{
    //     vm.startPrank(owner);
    //     factory.createMoonPool(DAI);
    //     moon = IMoonPool(factory.moonPools()[0]);
    //     IMoonPool.InputRule[] memory rules = new IMoonPool.InputRule[](2);
    //     rules[0] = IMoonPool.InputRule(ETH,100,200,50,10000,50,10000,50,10000,5,200);
    //     rules[1] = IMoonPool.InputRule(WETH,110,190,100,5000,50,10000,200,9000,10,300);
    //     IERC20(DAI).approve(address(moon),100000 ether);
    //     // console.log(IERC20(DAI).balanceOf(owner));
    //     moon.start(rules,60 days,1000000 ether,100000 ether);
    //     vm.stopPrank();
    // }
    function testCreateFactory()public{
        vm.startPrank(owner);
        //合约创建
        address[] memory tokens = new address[](7);
        tokens[0]=USDC;
        tokens[1]=DAI;
        tokens[2]=USDT;
        tokens[3]=OP;
        tokens[4]=ETH;
        tokens[5]=WETH;
        tokens[6]=STG;
        doubler = new Doubler(tokens);
        fr = new FRNFT('FRNFT','FR');
        doubler.setNft(address(fr));
        dbr = new Token('DBR','D');
        dbrFarm = address(new DbrFarm(address(dbr)));
        fr.initialize(address(doubler),owner);
        Factory.MoonPoolBaseConfig memory cfg;
        cfg.dev = developer;
        cfg.signer = signer;
        cfg.doubler = address(doubler);
        cfg.dbr = address(dbr);
        cfg.dbrFarm = dbrFarm;
        cfg.nft = address(fr);
        cfg.oneInchAggregator = address(aggregator);
        cfg.oneInchExecutor = executor;
        factory = new Factory(cfg,DAI,USDC,USDT);
        vm.stopPrank();
    }
    //DAI池
    function testDaiCreatePool()public{
        testCreateFactory();
        vm.startPrank(owner);
        factory.createMoonPool(DAI);
        assertEq(factory.moonPools().length,1);
        moon = IMoonPool(factory.moonPools()[0]);
        vm.stopPrank();
    }

    function testDaiStart()public{
        testDaiCreatePool();
        vm.startPrank(owner);
        doubler.createDoubler(USDT);
        doubler.createDoubler(USDC);
        doubler.createDoubler(OP);
        IMoonPool.InputRule[] memory rules = new IMoonPool.InputRule[](3);
        rules[0] = IMoonPool.InputRule(USDT,100,200,50,10000,50,10000,50,10000,5,200);
        rules[1] = IMoonPool.InputRule(USDC,110,190,100,5000,50,10000,200,9000,10,300);
        rules[2] = IMoonPool.InputRule(OP,100,200,50,10000,50,10000,50,10000,5,200);
        IERC20(DAI).approve(address(moon),100000 ether);
        // console.log(IERC20(DAI).balanceOf(owner));
        moon.start(rules,60 days,1000000 ether,100000 ether);
        assertEq(IERC20(address(moon)).balanceOf(owner),102000 ether);
        vm.stopPrank();
    }

    function testDaiDeposit()public{
        testDaiStart();
        // testCreatePool();
        vm.startPrank(user1);
        IERC20(DAI).approve(address(moon),100000 ether);
        moon.deposite(100000 ether);
        assertEq(IERC20(address(moon)).balanceOf(user1),104040 ether);
        // console.log(IERC20(DAI).balanceOf(user1));
        vm.stopPrank();
    }

    function testDaiWithdraw()public{
        testDaiDeposit();
        vm.startPrank(user1);
        moon.withdraw(104040 ether);
        assertEq(IERC20(address(moon)).totalSupply(),102000 ether);
        assertEq(IERC20(address(DAI)).balanceOf(user1)/1 ether,98970);
        vm.stopPrank();
    }
    struct SignatureParams {
        uint256 amount;
        uint256 minReturnAmount;
        uint256 falgs;
        uint256 deadline;
        bytes32 mask;
        bytes data;
        bytes signature;
    }
    function testInputDAI1()public{
        testDaiDeposit();
        vm.startPrank(developer);
        MoonPool.SignatureParams memory para;
        bytes memory data = hex'00000000000000000000000000000000000000000000000000000000006300a0fbb7cd06809da11ff60bfc5af527f58fd61679c3ac98d040d9000000000000000000000100da10009cbd5d07dd0cecc66161fc93d7c9000da194b008aa00579c1307b0ef2c499ad98a8ce58e581111111254eeb25477b68fb85ed929f73a960582';
        para.amount = 100000 ether;
        para.minReturnAmount = 10;
        para.falgs = 4;
        para.deadline = 1806855972;
        para.mask = 0x4481f3b2a39e0be4ddbe366390d3aa160dd14cc8c982f458b5b0ccd8c5e2ea67;
        para.data = data;
        para.signature = hex'866ea4468e6b3988aa24eb17948b8b9b557660213d753dfc9b79ce06640e8a8f751a97e6038c501de3f7404957adfb83a646d6190e3085b812ab9e4abb60dd471c';
        moon.input(0,para);
        assertEq(moon.poolInfo().pendingValue,100000 ether);
        vm.stopPrank();
    }

    function testInputDAI2()public{
        testDaiDeposit();
        vm.startPrank(developer);
        MoonPool.SignatureParams memory para;
        bytes memory data = hex'00000000000000000000000000000000000000000000000000000000006300a0fbb7cd06809da11ff60bfc5af527f58fd61679c3ac98d040d9000000000000000000000100da10009cbd5d07dd0cecc66161fc93d7c9000da10b2c639c533813f4aa9d7837caf62653d097ff851111111254eeb25477b68fb85ed929f73a960582';
        para.amount = 100000 ether;
        para.minReturnAmount = 10;
        para.falgs = 4;
        para.deadline = 1806855972;
        para.mask = 0x4481f3b2a39e0be4ddbe366390d3aa160dd14cc8c982f458b5b0ccd8c5e2ea67;
        para.data = data;
        para.signature = hex'2343f652aef8e6bbc25015100a482266ee43a45f1d540510b49095e1cfc21f7e41d47ee2de6b7c2b1597268e7828859a55e3ae4083585415306a2e2ec6b75eed1c';
        // console.log(IERC20(DAI).balanceOf(address(moon)));
        moon.input(1,para);
        assertEq(moon.poolInfo().pendingValue,100000 ether);
        vm.stopPrank();
    }
    function testInputDAI3()public{
        testDaiDeposit();
        vm.startPrank(developer);
        MoonPool.SignatureParams memory para;
        bytes memory data = hex'0000000000000000000000000000000000000000000000000000000001505126a132dab612db5cb9fc9ac426a0cc215a3423f9c9da10009cbd5d07dd0cecc66161fc93d7c9000da10004f41766d80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000092e0404dc7ab93300000000000000000000000000000000000000000000000000000000000000a00000000000000000000000001111111254eeb25477b68fb85ed929f73a9605820000000000000000000000000000000000000000000000000000000066c1f0050000000000000000000000000000000000000000000000000000000000000001000000000000000000000000da10009cbd5d07dd0cecc66161fc93d7c9000da100000000000000000000000042000000000000000000000000000000000000420000000000000000000000000000000000000000000000000000000000000000';
        para.amount = 100000 ether;
        para.minReturnAmount = 10;
        para.falgs = 4;
        para.deadline = 1806855972;
        para.mask = 0x4481f3b2a39e0be4ddbe366390d3aa160dd14cc8c982f458b5b0ccd8c5e2ea67;
        para.data = data;
        para.signature = hex'de87ebca5f5221952b82d7e2714ffe3f7db44582b273431976abfe02c0e76bdd2955da284066100a1c2c34e2f708adadb8efd086c932b4a0adf6d0badfd7611c1b';
        // console.log(IERC20(DAI).balanceOf(address(moon)));
        moon.input(2,para);
        assertEq(moon.poolInfo().pendingValue,100000 ether);
        vm.stopPrank();
    }

    function testGainDai1()public{
        testInputDAI1();
        vm.startPrank(developer);
        MoonPool.SignatureParams memory para;
        bytes memory data = hex'0000000000000000000000000000000000000000000000f80000ca0000b051201337bedc9d22ecbe766df105c9623922a27963ec94b008aa00579c1307b0ef2c499ad98a8ce58e5800443df02124000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000486fe4195394e4c9f7e0020d6bdbf78da10009cbd5d07dd0cecc66161fc93d7c9000da180a06c4eca27da10009cbd5d07dd0cecc66161fc93d7c9000da11111111254eeb25477b68fb85ed929f73a960582';
        para.amount = 100000*10**6;
        para.minReturnAmount = 10;
        para.falgs = 4;
        para.deadline = 1806855972;
        para.mask = 0x4481f3b2a39e0be4ddbe366390d3aa160dd14cc8c982f458b5b0ccd8c5e2ea67;
        para.data = data;
        para.signature = hex'f01421892348679ce97c16a9976ae3c252858061a81245c306747ba6c66c3773160dc664beb4582e8cd55e45e8dbe15a899569d82e07a5e3b7a2cbba811170551b';
        // console.log(IERC20(DAI).balanceOf(address(moon)));
        moon.gain(1,para);
        assertEq(moon.poolInfo().pendingValue,0);
        vm.stopPrank();
    }
    function testGainDai2()public{
        testInputDAI2();
        vm.startPrank(developer);
        MoonPool.SignatureParams memory para;
        bytes memory data = hex'00000000000000000000000000000000000000000000000000000000006300a0fbb7cd06809da11ff60bfc5af527f58fd61679c3ac98d040d90000000000000000000001000b2C639c533813f4Aa9D7837CAf62653d097Ff85da10009cbd5d07dd0cecc66161fc93d7c9000da11111111254eeb25477b68fb85ed929f73a960582';
        para.amount = 100000*10**6;
        para.minReturnAmount = 10;
        para.falgs = 4;
        para.deadline = 1806855972;
        para.mask = 0x4481f3b2a39e0be4ddbe366390d3aa160dd14cc8c982f458b5b0ccd8c5e2ea67;
        para.data = data;
        para.signature = hex'8fd44582fd64b9b28a6338e7f68b2dbc980f37e707ff170764446607d91c6e043c741b653aec57596129e3d330aaf83604296d2fbf76befece0dbcd668180ba51b';
        // console.log(IERC20(DAI).balanceOf(address(moon)));
        moon.gain(1,para);
        assertEq(moon.poolInfo().pendingValue,0);
        vm.stopPrank();
    }
    function testGainDai3()public{
        testInputDAI3();
        vm.startPrank(developer);
        MoonPool.SignatureParams memory para;
        bytes memory data = hex'0000000000000000000000000000000000000000000001b500018700013d00a007e5c0d20000000000000000000000000000000000000000000001190000ff00004f02a00000000000000000000000000000000000000000000000000000000000e9f8dfee63c1e5011d751bc1a723accf1942122ca9aa82d49d08d2ae420000000000000000000000000000000000004251201337bedc9d22ecbe766df105c9623922a27963ec7f5c764cbc14f9669b88837ca1490cca17c3160700443df02124000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d478ef83654a7ad00020d6bdbf78da10009cbd5d07dd0cecc66161fc93d7c9000da100a0f2fa6b66da10009cbd5d07dd0cecc66161fc93d7c9000da1000000000000000000000000000000000000000000000000d8cefed9ab46c6770000000000000000453d756a9a75350b80a06c4eca27da10009cbd5d07dd0cecc66161fc93d7c9000da11111111254eeb25477b68fb85ed929f73a960582';
        para.amount = 100000*10**6;
        para.minReturnAmount = 10;
        para.falgs = 4;
        para.deadline = 1806855972;
        para.mask = 0x4481f3b2a39e0be4ddbe366390d3aa160dd14cc8c982f458b5b0ccd8c5e2ea67;
        para.data = data;
        para.signature = hex'c0fde45092595c84b826a8af50a6ec3bc8f844304fa897ad5e534a6dc4488eaf0b992ff320ac7ea6b275bc871c41bfabaaf0e32354384b64ce7062dcb9719a6a1b';
        // console.log(IERC20(DAI).balanceOf(address(moon)));
        moon.gain(1,para);
        assertEq(moon.poolInfo().pendingValue,0);
        vm.stopPrank();
    }


    //USDT池
    function testUSDTCreatePool()public{
        testCreateFactory();
        vm.startPrank(owner);
        factory.createMoonPool(USDT);
        moon = IMoonPool(factory.moonPools()[0]);
        vm.stopPrank();
    }

    function testUSDTStart()public{
        testUSDTCreatePool();
        vm.startPrank(owner);
        doubler.createDoubler(STG);
        doubler.createDoubler(OP);
        doubler.createDoubler(WETH);
        IMoonPool.InputRule[] memory rules = new IMoonPool.InputRule[](3);
        rules[0] = IMoonPool.InputRule(STG,100,200,50,10000,50,10000,50,10000,5,200);
        rules[1] = IMoonPool.InputRule(OP,110,190,100,5000,50,10000,200,9000,10,300);
        rules[2] = IMoonPool.InputRule(WETH,100,200,50,10000,50,10000,50,10000,5,200);
        IERC20(USDT).approve(address(moon),100000*10**6);
        // console.log(IERC20(DAI).balanceOf(owner));
        moon.start(rules,60 days,1000000*10**6,100000*10**6);
        assertEq(IERC20(address(moon)).balanceOf(owner),102000*10**6);
        vm.stopPrank();
    }

    function testUSDTDeposit()public{
        testUSDTStart();
        // testCreatePool();
        vm.startPrank(user1);
        IERC20(USDT).approve(address(moon),100000 *10**6);
        moon.deposite(100000 *10**6);
        assertEq(IERC20(address(moon)).balanceOf(user1),104040 *10**6);
        // console.log(IERC20(DAI).balanceOf(user1));
        vm.stopPrank();
    }

    function testUSDTWithdraw()public{
        testUSDTDeposit();
        vm.startPrank(user1);
        moon.withdraw(104040 *10**6);
        assertEq(IERC20(address(moon)).totalSupply(),102000 *10**6);
        assertEq(IERC20(address(USDT)).balanceOf(user1)/10**6,98970);
        vm.stopPrank();
    }

    function testInputUSDT1()public{
        testUSDTDeposit();
        vm.startPrank(developer);
        MoonPool.SignatureParams memory para;
        bytes memory data = hex'0000000000000000000000000000000000000000000000000000000001e300a007e5c0d20000000000000000000000000000000000000000000000000001bf00004f00a0fbb7cd06009da11ff60bfc5af527f58fd61679c3ac98d040d900000000000000000000010094b008aa00579c1307b0ef2c499ad98a8ce58e587f5c764cbc14f9669b88837ca1490cca17c316075126a062ae8a9c5e11aaa026fc2670b0d65ccc8b28587f5c764cbc14f9669b88837ca1490cca17c316070004cac88ea9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0c764b556a2dc82900000000000000000000000000000000000000000000000000000000000000a00000000000000000000000001111111254eeb25477b68fb85ed929f73a9605820000000000000000000000000000000000000000000000000000000066c340ae00000000000000000000000000000000000000000000000000000000000000010000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c31607000000000000000000000000296f55f8fb28e498b858d0bcda06d955b2cb3f970000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f1046053aa5682b4f9a81b5481394da16be5ff5a';
        para.amount = 100000*10**6;
        para.minReturnAmount = 10;
        para.falgs = 4;
        para.deadline = 1806855972;
        para.mask = 0x4481f3b2a39e0be4ddbe366390d3aa160dd14cc8c982f458b5b0ccd8c5e2ea67;
        para.data = data;
        para.signature = hex'4d9a7ff13d4c6a6ce70212d5e264592028f27baecfe29e6e9345bb2b07b468be2fa51a05ba847febc8863b59ad053834f2cdabd150666f08dddbdc6b0190c7191c';
        moon.input(0,para);
        assertEq(moon.poolInfo().pendingValue,100000*10**6);
        vm.stopPrank();
    }

    function testInputUSDT2()public{
        testUSDTDeposit();
        vm.startPrank(developer);
        MoonPool.SignatureParams memory para;
        bytes memory data = hex'00000000000000000000000000000000000000000000018d00006800004e802026678dcd94b008aa00579c1307b0ef2c499ad98a8ce58e58b4f34d09124b8c9712957b76707b42510041ecbb000000000000000000000000000000000000000000000000000000000000e47d0020d6bdbf7894b008aa00579c1307b0ef2c499ad98a8ce58e5800a007e5c0d200000000000000000000000000000000000000000000010100009e00004f02a000000000000000000000000000000000000000000000000190edf3231e27bbacee63c1e5018323d063b1d12acce4742f1e3ed9bc46d71f422294b008aa00579c1307b0ef2c499ad98a8ce58e5802a0000000000000000000000000000000000000000000000000002c6ad8abe018aaee63c1e50095d9d28606ee55de7667f0f176ebfc3215cfd9c0da10009cbd5d07dd0cecc66161fc93d7c9000da102a0000000000000000000000000000000000000000000000000867751abee522b41ee63c1e581fc1f3296458f9b2a27a0b91dd7681c4020e09d0542000000000000000000000000000000000000061111111254eeb25477b68fb85ed929f73a960582';
        para.amount = 100000*10**6;
        para.minReturnAmount = 10;
        para.falgs = 4;
        para.deadline = 1806855972;
        para.mask = 0x4481f3b2a39e0be4ddbe366390d3aa160dd14cc8c982f458b5b0ccd8c5e2ea67;
        para.data = data;
        para.signature = hex'39363544813d809cca156dfb839a23163fb6ddd448932823bf18e5c122a0bd5c3856e8165ad32c39df148dbc84179129ff6ca21f2847f143a1416c05ce9df2841c';
        moon.input(1,para);
        assertEq(moon.poolInfo().pendingValue,100000*10**6);
        vm.stopPrank();
    }
    function testInputUSDT3()public{
        testUSDTDeposit();
        vm.startPrank(developer);
        MoonPool.SignatureParams memory para;
        bytes memory data = hex'00000000000000000000000000000000000000000000044e0004200003d600a098aed105000000000000000006040000000000000000000000000000000000000000000000000003a800024c00a0bdb6942194b008aa00579c1307b0ef2c499ad98a8ce58e58b80d90fcf2ed0e4febe02d2a209109bf1f62df9500000000000000000000000000000000000000000000000014ff965280ab387b0000000000000000000000000000000000000000000000000000000001e000a007e5c0d20000000000000000000000000000000000000000000000000001bc00004f02a000000000000000000000000000000000000000000000000000000000d06812bdee63c1e500f1f199342687a7d78bcc16fce79fa2665ef870e194b008aa00579c1307b0ef2c499ad98a8ce58e5800a0c9e75c480000000000000000270b00000000000000000000000000000000000000000000000000013f00004f02a0000000000000000000000000000000000000000000000000049ea34998739d15ee63c1e50085149247691df622eaf1a8bd0cafd40bc45154a97f5c764cbc14f9669b88837ca1490cca17c316075120eaf1ac8e89ea0ae13e0f03634a4ff235025270247f5c764cbc14f9669b88837ca1490cca17c3160700447dc203820000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c31607000000000000000000000000420000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000001060f308e8379b66000000000000000000000000b63aae6c353636d66df13b89ba4425cfe13d10ba00000000000000000000000042f527f50f16a103b6ccab48bccca214500c102100a0bdb6942194b008aa00579c1307b0ef2c499ad98a8ce58e58b80d90fcf2ed0e4febe02d2a209109bf1f62df950000000000000000000000000000000000000000000000001f7f7444dd9dd2120000000000000000000000000000000000000000000000000000000000f05120eaf1ac8e89ea0ae13e0f03634a4ff2350252702494b008aa00579c1307b0ef2c499ad98a8ce58e5800447dc2038200000000000000000000000094b008aa00579c1307b0ef2c499ad98a8ce58e58000000000000000000000000420000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000001f7f7444dd9dd212000000000000000000000000b63aae6c353636d66df13b89ba4425cfe13d10ba00000000000000000000000042f527f50f16a103b6ccab48bccca214500c102100a0f2fa6b6642000000000000000000000000000000000000060000000000000000000000000000000000000000000000003506ca0d42cb126c00000000000000000007af5dc00b118d80a06c4eca2742000000000000000000000000000000000000061111111254eeb25477b68fb85ed929f73a960582';
        para.amount = 100000*10**6;
        para.minReturnAmount = 10;
        para.falgs = 4;
        para.deadline = 1806855972;
        para.mask = 0x4481f3b2a39e0be4ddbe366390d3aa160dd14cc8c982f458b5b0ccd8c5e2ea67;
        para.data = data;
        para.signature = hex'9444249155b2e925e0169d11cd79b6846a091f0b33fad326ab9009b80199582d52b93de1ea29eb1e6e6dbbed803f7ea582108467b7dd437057be92ce7ddd67ae1b';
        // console.log(IERC20(DAI).balanceOf(address(moon)));
        moon.input(2,para);
        assertEq(moon.poolInfo().pendingValue,100000*10**6);
        vm.stopPrank();
    }

    function testGainUSDT1()public{
        testInputUSDT1();
        vm.startPrank(developer);
        MoonPool.SignatureParams memory para;
        bytes memory data = hex'0000000000000000000000000000000000000000000000000000000001f700a007e5c0d20000000000000000000000000000000000000000000000000001d30001705126a062ae8a9c5e11aaa026fc2670b0d65ccc8b2858296f55f8fb28e498b858d0bcda06d955b2cb3f970004cac88ea90000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000184812900000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000b63aae6c353636d66df13b89ba4425cfe13d10ba0000000000000000000000000000000000000000000000000000000066c2f0040000000000000000000000000000000000000000000000000000000000000001000000000000000000000000296f55f8fb28e498b858d0bcda06d955b2cb3f970000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c316070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f1046053aa5682b4f9a81b5481394da16be5ff5a00a0fbb7cd06809da11ff60bfc5af527f58fd61679c3ac98d040d90000000000000000000001007f5c764cbc14f9669b88837ca1490cca17c3160794b008aa00579c1307b0ef2c499ad98a8ce58e581111111254eeb25477b68fb85ed929f73a960582';
        para.amount = 100000*10**6;
        para.minReturnAmount = 10;
        para.falgs = 4;
        para.deadline = 1806855972;
        para.mask = 0x4481f3b2a39e0be4ddbe366390d3aa160dd14cc8c982f458b5b0ccd8c5e2ea67;
        para.data = data;
        para.signature = hex'00b2a6ed4a13a5433ec9db2221d601593f48058ab758c1b970f292324901b34e37fc9fc21e565a6c31f91c3bcdbb7024cec1e8eb5fa9a786acf7990f1c325d381b';
        // console.log(IERC20(DAI).balanceOf(address(moon)));
        moon.gain(1,para);
        assertEq(moon.poolInfo().pendingValue,0);
        vm.stopPrank();
    }
    function testGainUSDT2()public{
        testInputUSDT2();
        vm.startPrank(developer);
        MoonPool.SignatureParams memory para;
        bytes memory data = hex'0000000000000000000000000000000000000000000000000000000000f05120eaf1ac8e89ea0ae13e0f03634a4ff23502527024420000000000000000000000000000000000004200447dc20382000000000000000000000000420000000000000000000000000000000000004200000000000000000000000094b008aa00579c1307b0ef2c499ad98a8ce58e58000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000118e3f000000000000000000000000001111111254eeb25477b68fb85ed929f73a96058200000000000000000000000042f527f50f16a103b6ccab48bccca214500c1021';
        para.amount = 100000*10**6;
        para.minReturnAmount = 10;
        para.falgs = 4;
        para.deadline = 1806855972;
        para.mask = 0x4481f3b2a39e0be4ddbe366390d3aa160dd14cc8c982f458b5b0ccd8c5e2ea67;
        para.data = data;
        para.signature = hex'8eab3d511340eda58b59aae931cb59d38209c436c0cdaae548ba1b90ccb40ef96a977942f28f087e8c0fcdbff66d84ff08ec65816a70c9a9a2d69e8ec0b0fd631c';
        // console.log(IERC20(DAI).balanceOf(address(moon)));
        moon.gain(1,para);
        assertEq(moon.poolInfo().pendingValue,0);
        vm.stopPrank();
    }
    function testGainUSDT3()public{
        testInputUSDT3();
        vm.startPrank(developer);
        MoonPool.SignatureParams memory para;
        bytes memory data = hex'0000000000000000000000000000000000000000000000000000000000f05120eaf1ac8e89ea0ae13e0f03634a4ff23502527024420000000000000000000000000000000000000600447dc20382000000000000000000000000420000000000000000000000000000000000000600000000000000000000000094b008aa00579c1307b0ef2c499ad98a8ce58e580000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000009c75db140000000000000000000000001111111254eeb25477b68fb85ed929f73a96058200000000000000000000000042f527f50f16a103b6ccab48bccca214500c1021';
        para.amount = 100000*10**6;
        para.minReturnAmount = 10;
        para.falgs = 4;
        para.deadline = 1806855972;
        para.mask = 0x4481f3b2a39e0be4ddbe366390d3aa160dd14cc8c982f458b5b0ccd8c5e2ea67;
        para.data = data;
        para.signature = hex'42204a076442991268d16b3213f44be4ed5c0d86b0334a562b1ee623d3b662314b54ae3475a9e1177fb011b3501e3d6123266737dcd35d2a8b3be6e0ce7c76ee1b';
        // console.log(IERC20(DAI).balanceOf(address(moon)));
        moon.gain(1,para);
        assertEq(moon.poolInfo().pendingValue,0);
        vm.stopPrank();
    }
}

contract Doubler{
    struct Asset {
        bool isOpen;
    }
    struct Pool {
        address asset;
        address creator;
        address terminator;
        uint16 fallRatio;//100-200
        uint16 profitRatio;//50-10000
        uint16 rewardRatio;//0-10000
        uint16 winnerRatio;//0-10000
        uint32 double;
        uint32 lastLayer;
        uint256 tokenId;
        uint256 unitSize;
        uint256 maxRewardUnits;
        uint256 winnerOffset;
        uint256 endPrice;
        uint256 lastOpenPrice;
        uint256 tvl;//>0
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
    mapping(address => Asset)public tokens;
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    Pool[] pools;
    IFRNFT fr;
    function getAssetConfigMap(address token)public view returns(Asset memory){
        return tokens[token];
    }

    function getPool(uint256 poolId)public view returns(Pool memory){
        return pools[poolId];
    }

    function createDoubler(address token)public{
        Pool memory pool;
        pool.asset = token;
        pool.creator = msg.sender;
        pool.fallRatio = 150;
        pool.profitRatio = 3000;
        pool.rewardRatio = 5000;
        pool.winnerRatio = 5000;
        pool.tvl = 10000;
        pools.push(pool);
    }

    constructor(address[] memory _tokens){
        for(uint i =0;i<_tokens.length;i++){
            tokens[_tokens[i]].isOpen = true;
        }
    }

    function input(AddInput memory _addInput) external payable returns (uint256 tokenId){
        Pool memory pool = pools[_addInput.poolId];
        if (pool.asset==ETH){
            require(msg.value>=_addInput.margin,'insufficient ETH');
        }else{
            if (IERC20(pool.asset).allowance(msg.sender, address(this)) < _addInput.margin) revert();
            if (IERC20(pool.asset).balanceOf(msg.sender) < _addInput.margin) revert();
        }

        IERC20(pool.asset).transferFrom(msg.sender, address(this), _addInput.margin);
        tokenId = fr.mint(
            msg.sender,
            _addInput.poolId,
            _addInput.layer,
            _addInput.margin,
            _addInput.amount,
            _addInput.curPrice,
            0
        );
    }
    function setNft(address _fr)public{
        fr = IFRNFT(_fr);
    }
    function gain(uint256 _tokenId) external returns(uint256 amount) {
        FRNFT.Traits memory nft = fr.getTraits(_tokenId);
        Pool memory pool = pools[nft.poolId];
        if (pool.asset==ETH){
            amount = address(this).balance;
            payable(msg.sender).call{value : amount}('');
        }else{
            amount = IERC20(pool.asset).balanceOf(address(this));
            IERC20(pool.asset).transfer(msg.sender,amount);
        }
    }
}
contract DbrFarm{
    Token dbr;
    constructor(address _dbr){
        dbr = Token(_dbr);
    }
    function join(uint256 _tokenId) external{}
    function left(uint256 _tokenId) external returns(uint256 claimAmount){
        dbr.mint(10 ether);
        dbr.transfer(msg.sender,10 ether);
        claimAmount = 10 ether;
    }
}
contract Token is ERC20,Ownable{
    constructor(string memory name,string memory symbol)ERC20(name,symbol){}

    function mint(uint256 amount)public{
        
        _mint(msg.sender,amount);
    }
}