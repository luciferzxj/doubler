pragma solidity ^0.8.12;
import "forge-std/Test.sol";
// import 'forge-std/StdCheats.sol';
import "forge-std/console.sol";
import "../src/MoonPool.sol";
// import '../src/Doubler.sol';
import "../src/FRNFT.sol";
import '../src/DBRFarm.sol';
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
contract DBRFarmTest is Test{
    //EOA
    address multiSig = makeAddr("multiSig");
    address user1 = makeAddr("user1");
    address farmWallet = makeAddr("farmWallet");
    address moon = makeAddr("moon");
    //token
    //mock
    address USDC = address(new Token("USDC", "USDC")); //6
    address USDT = address(new Token("USDT", "USDT"));
    address DAI = address(new Token("DAI", "DAI")); //6
    address OP = address(new Token("OP", "OP"));
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address WETH = address(new WETH9("WETH", "WETH"));

    Doubler doubler;
    Token dbr;
    FRNFT fr;
    DBRFarm dbrFarm;
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
        Token(USDT).transfer(user1, 100000 * 10 ** 6);
        Token(USDT).transfer(moon, 100000 * 10 ** 6);
        Token(WETH).mint(20 *10**8);
        Token(WETH).transfer(user1, 10 *10**8);
        Token(WETH).transfer(moon, 10 *10**8);
        Token(OP).mint(2000 ether);
        Token(OP).transfer(user1, 1000 ether);
        Token(OP).transfer(moon, 1000 ether);
        // deployUni();
        initPriceFeed();
        address[] memory tokens = new address[](6);
        tokens[0] = USDC;
        tokens[1] = DAI;
        tokens[2] = USDT;
        tokens[3] = OP;
        tokens[4] = ETH;
        tokens[5] = WETH;
        doubler = new Doubler(tokens);
        doubler.createDoubler(USDT,10000 *10**6);
        doubler.createDoubler(WETH,10 *10**8);
        doubler.createDoubler(OP,1000 ether);
        fr = new FRNFT("FRNFT", "FR");
        doubler.setNft(address(fr),address(priceFeed));
        dbr = new Token("DBR", "D");
        dbrFarm = new DBRFarm();
        fr.initialize(address(doubler), multiSig);
        dbrFarm.initialize();
        dbrFarm.initializeV2(address(dbr), address(doubler), address(fr), multiSig, farmWallet, address(this), 1*10**15, 1*10**14);
        dbrFarm.updateAssetPerBlock(USDT,1 * 10**16);
        dbrFarm.updateAssetPerBlock(WETH,1 * 10**16);
        dbrFarm.updateAssetPerBlock(OP,1 * 10**16);
        dbrFarm.addMoonPoolRole(moon);
        dbr.mint(100000 ether);
        dbr.transfer(farmWallet,100000 ether);
        vm.startPrank(farmWallet);
        dbr.approve(address(dbrFarm),type(uint256).max);
        vm.stopPrank();
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

    function testUSDTStake()public{
        vm.startPrank(user1);
        console.log("start USDT staking");
        Doubler.AddInput memory para;
        para.layer = 0;
        para.poolId = 0;
        para.margin = 10000 *10**6;
        para.multiple = 1;
        para.amount = 10000 * 10**6;
        Token(USDT).approve(address(doubler),10000 * 10**6);
        uint256 _tokenId = doubler.input(para);
        console.log("input USDT to doubler");
        fr.approve(address(dbrFarm), _tokenId);
        dbrFarm.staking(_tokenId);
        assertEq(dbrFarm.getDoubler(0).tvl, 10000 ether);
        console.log("end USDT staking");
        vm.stopPrank();
    }

    function testWETHStake()public{
        vm.startPrank(user1);
        console.log("start WETH staking");
        Doubler.AddInput memory para;
        para.layer = 0;
        para.poolId = 1;
        para.margin = 10 *10**8;
        para.multiple = 1;
        para.amount = 10 * 10**8;
        Token(WETH).approve(address(doubler),10 * 10**8);
        uint256 _tokenId = doubler.input(para);
        console.log("input WETH to doubler");
        fr.approve(address(dbrFarm), _tokenId);
        dbrFarm.staking(_tokenId);
        assertEq(dbrFarm.getDoubler(1).tvl, 20000 ether);
        console.log("end WETH staking");
        vm.stopPrank();
    }

    function testOPStake()public{
        vm.startPrank(user1);
        console.log("start OP staking");
        Doubler.AddInput memory para;
        para.layer = 0;
        para.poolId = 2;
        para.margin = 1000 ether;
        para.multiple = 1;
        para.amount = 1000 ether;
        Token(OP).approve(address(doubler),1000 ether);
        uint256 _tokenId = doubler.input(para);
        console.log("input OP to doubler");
        fr.approve(address(dbrFarm), _tokenId);
        dbrFarm.staking(_tokenId);
        assertEq(dbrFarm.getDoubler(2).tvl, 4000 ether);
        console.log("end OP staking");
        vm.stopPrank();
    }

    function testUSDTClaim()public{
        testUSDTStake();
        console.log("start USDT claim");
        vm.startPrank(user1);
        vm.roll(block.number + 100);
        dbrFarm.claim(1);
        assertEq(dbr.balanceOf(user1), 100 *10**16);
        console.log("stop USDT claim");
        vm.stopPrank();
    }

    function testWETHClaim()public{
        testUSDTStake();
        console.log("start WETH claim");
        vm.startPrank(user1);
        vm.roll(block.number + 1050);
        dbrFarm.claim(1);
        assertEq(dbr.balanceOf(user1), 1050 *10**16);
        console.log("stop WETH claim");
        vm.stopPrank();
    }

    function testOPClaim()public{
        testOPStake();
        console.log("start OP claim");
        vm.startPrank(user1);
        vm.roll(block.number + 5689);
        dbrFarm.claim(1);
        assertEq(dbr.balanceOf(user1), 5689 *10**16);
        console.log("stop OP claim");
        vm.stopPrank();
    }

    function testBatchStaking()public{
        vm.startPrank(user1);
        console.log("start batchStaking");
        uint256[] memory _tokenIds = new uint256[](3);
        Doubler.AddInput memory para;
        para.layer = 0;
        para.poolId = 0;
        para.margin = 10000 *10**6;
        para.multiple = 1;
        para.amount = 10000 * 10**6;
        Token(USDT).approve(address(doubler),10000 * 10**6);
        _tokenIds[0] = doubler.input(para);
        console.log("input USDT to doubler");
        para.poolId = 1;
        para.margin = 10 *10**8;
        para.amount = 10*10**8;
        Token(WETH).approve(address(doubler),10 * 10**8);
        console.log("input WETH to doubler");
        _tokenIds[1] = doubler.input(para);
        para.poolId = 2;
        para.margin = 1000 ether;
        para.amount = 1000 ether;
        Token(OP).approve(address(doubler),1000 ether);
        console.log("input OP to doubler");
        _tokenIds[2] = doubler.input(para);
        fr.approve(address(dbrFarm), _tokenIds[0]);
        fr.approve(address(dbrFarm), _tokenIds[1]);
        fr.approve(address(dbrFarm), _tokenIds[2]);
        dbrFarm.batchStaking(_tokenIds);
        assertEq(dbrFarm.getDoubler(0).tvl, 10000 ether);
        assertEq(dbrFarm.getDoubler(1).tvl, 20000 ether);
        assertEq(dbrFarm.getDoubler(2).tvl, 4000 ether);
        console.log("end batchStaking");
    }

    function testWithdraw()public{
        testBatchStaking();
        vm.startPrank(user1);
        vm.roll(block.number + 200);
        console.log("start all withdraw");
        dbrFarm.withdraw(1);
        dbrFarm.withdraw(2);
        dbrFarm.withdraw(3);
        assertEq(fr.balanceOf(user1),3);
        assertEq(dbr.balanceOf(user1),4254901000000000000);//((10000*200/34000)+(20000*200/24000)+200)*10**16
        console.log("end all withdraw");
    }

    function testUSDTJoin()public{
        vm.startPrank(moon);
        console.log("start USDT join");
        Doubler.AddInput memory para;
        para.layer = 0;
        para.poolId = 0;
        para.margin = 10000 *10**6;
        para.multiple = 1;
        para.amount = 10000 * 10**6;
        Token(USDT).approve(address(doubler),10000 * 10**6);
        uint256 _tokenId = doubler.input(para);
        console.log("input USDT to doubler");
        dbrFarm.join(_tokenId);
        assertEq(dbrFarm.getDoubler(0).tvl, 10000 ether);
        console.log("end USDT join");
        vm.stopPrank();
    }

    function testWETHJoin()public{
        vm.startPrank(moon);
        console.log("start WETH join");
        Doubler.AddInput memory para;
        para.layer = 0;
        para.poolId = 1;
        para.margin = 10 *10**8;
        para.multiple = 1;
        para.amount = 10 * 10**8;
        Token(WETH).approve(address(doubler),10 * 10**8);
        uint256 _tokenId = doubler.input(para);
        console.log("input WETH to doubler");
        dbrFarm.join(_tokenId);
        assertEq(dbrFarm.getDoubler(1).tvl, 20000 ether);
        console.log("end WETH join");
        vm.stopPrank();
    }

    function testOPJoin()public{
        vm.startPrank(moon);
        console.log("start OP join");
        Doubler.AddInput memory para;
        para.layer = 0;
        para.poolId = 2;
        para.margin = 1000 ether;
        para.multiple = 1;
        para.amount = 1000 ether;
        Token(OP).approve(address(doubler),1000 ether);
        uint256 _tokenId = doubler.input(para);
        console.log("input OP to doubler");
        dbrFarm.join(_tokenId);
        assertEq(dbrFarm.getDoubler(2).tvl, 4000 ether);
        console.log("end OP join");
        vm.stopPrank();
    }

    function testUSDTLeft()public{
        testUSDTJoin();
        console.log("start USDT left");
        vm.startPrank(moon);
        vm.roll(block.number + 100);
        dbrFarm.left(1);
        assertEq(dbr.balanceOf(moon), 100 *10**16);
        console.log("stop USDT left");
        vm.stopPrank();
    }

    function testWETHLeft()public{
        testUSDTJoin();
        console.log("start WETH left");
        vm.startPrank(moon);
        vm.roll(block.number + 1050);
        dbrFarm.claim(1);
        assertEq(dbr.balanceOf(moon), 1050 *10**16);
        console.log("stop WETH left");
        vm.stopPrank();
    }

    function testOPLeft()public{
        testOPJoin();
        console.log("start OP left");
        vm.startPrank(moon);
        vm.roll(block.number + 5689);
        dbrFarm.claim(1);
        assertEq(dbr.balanceOf(moon), 5689 *10**16);
        console.log("stop OP left");
        vm.stopPrank();
    }

    function testEndDoubler()public{
        testBatchStaking();
        vm.startPrank(user1);
        console.log("start endDoubler");
        vm.roll(block.number + 200);
        dbrFarm.endDoubler(0);
        dbrFarm.endDoubler(1);
        dbrFarm.endDoubler(2);
        console.log("start all withdraw");
        dbrFarm.withdraw(1);
        vm.roll(block.number + 200);
        dbrFarm.withdraw(2);
        vm.roll(block.number + 200);
        dbrFarm.withdraw(3);
        assertEq(fr.balanceOf(user1),3);
        assertEq(dbr.balanceOf(user1),4314901000000000000);//((10000*200/34000)+(20000*200/24000)+200)*10**16 + 600 * 10**14
        console.log("end all withdraw");
        console.log("end endDoubler");
    }
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
    uint256 _tvlTotal;
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
        uint256 decimals = Token(pool.asset).decimals();
        _tvlTotal +=_addInput.amount/(10** decimals)*curPrice;
    }
    function endPool(uint256 _doublerId) external{
        Pool storage pool = pools[_doublerId];
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
    function getPrivateVar()
        public
        view
        returns (uint16, uint16, uint16, uint256, uint256, address, address, address, address)
    {
        return (0, 0, 0, 0, _tvlTotal, address(0), address(0), address(0), address(0));
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
}