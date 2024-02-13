// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import '../interfaces/IFastPriceFeed.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

// import Upgradeable
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@pythnetwork/pyth-sdk-solidity/IPyth.sol';
import '@pythnetwork/pyth-sdk-solidity/PythStructs.sol';

contract FastPriceFeedPyth is
    IFastPriceFeed,
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    using SafeMath for uint256;
    bytes32 public constant FEED_ROLE = keccak256('FEED_ROLE');
    mapping(address => uint256) private _assetPriceMap;
    IPyth _pyth;
    mapping(address => bytes32) internal _priceFeedMap;
    address[] private _keys;
    uint256 private constant _priceDecimals = 1e18;


    event UpdatePriceFeedMap(address token, address priceFeed);
    event UpdatePythPriceFeedMap(address token, bytes32 priceFeed);
    event SetAssetPrice(address _asset, uint256 _price);

    // for update
    function initialize(address _pythContract) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(FEED_ROLE, _msgSender());
        _pyth = IPyth(_pythContract);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}


    function getPrice(address _asset) external view returns (uint256 price) {
        price = _assetPriceMap[_asset];
        if (price == 0) {
            (, price, ) = getLatestPriceV2(_asset);
        }
        return price;
    }

    function setAssetPrice(address _asset, uint256 _price, uint32 _decimals) external nonReentrant onlyRole(FEED_ROLE) {
        // require(_price > 0, 'price error');
        require(_decimals > 0, 'decimals error');
        _assetPriceMap[_asset] = (_price * _priceDecimals) / (10 ** _decimals);
        emit SetAssetPrice(_asset, _price);
    }

    function updatePriceFeedMap(address _asset, bytes32 _priceFeed) external nonReentrant onlyRole(FEED_ROLE) {
        _priceFeedMap[_asset] = _priceFeed;
        _keys.push(_asset);
        emit UpdatePythPriceFeedMap(_asset, _priceFeed);
    }

    function latestPriceByFeed(address _priceFeed) external view returns (uint256 price, uint32 decimals) {
        (uint80 roundID, int256 price, uint startedAt, uint timeStamp, uint80 answeredInRound) = AggregatorV3Interface(
            _priceFeed
        ).latestRoundData();
        decimals = uint32(AggregatorV3Interface(_priceFeed).decimals());
        return (uint256(price), decimals);
    }

    function getLatestPriceV2(address _token) public view returns (uint256 timeStamp, uint256 price, uint256 decimals) {
        bytes32 priceFeed = _priceFeedMap[_token];
        PythStructs.Price memory _price = _pyth.getPriceUnsafe(priceFeed);
        uint32 expo = uint32(_price.expo < 0 ? -_price.expo : _price.expo);
        uint64 pythPrice = uint64(_price.price > 0 ? _price.price : -_price.price);
        return (_price.publishTime, _priceDecimals.mul(pythPrice).div(10 ** expo), _priceDecimals);
    }

    function getLatestPrice(address _token) public view returns (uint256 timeStamp, uint256 price, uint256 decimals) {
        price = _assetPriceMap[_token];
        decimals = 1e18;
        timeStamp = block.timestamp;
        return (timeStamp, price, decimals);
    }
}
