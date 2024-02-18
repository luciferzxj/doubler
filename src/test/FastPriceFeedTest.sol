// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import '../interfaces/IFastPriceFeed.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

// import Upgradeable
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';

contract FastPriceFeedTest is
    IFastPriceFeed,
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    struct TokenMeta {
        address token;
        string symbol;
        uint8 decimals;
        bytes32 priceFeed;
    }

    // event UpdatePriceFeedMap(address token, address priceFeed);
    // event UpdatePythPriceFeedMap(address token, bytes32 priceFeed);
    // event SetAssetPrice(address asset, uint256 price);

    bytes32 public constant FEED_ROLE = keccak256('FEED_ROLE');
    mapping(address => uint256) private _assetPriceMap;
    mapping(address => address) private _priceFeedMap;
    address[] private _keys;
    uint256 private constant _priceDecimals = 1e18;

    // for update
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(FEED_ROLE, _msgSender());
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getTokens() external view returns (TokenMeta[] memory res) {
        res = new TokenMeta[](_keys.length);
        for (uint i = 0; i < _keys.length; i++) {
            TokenMeta memory r = res[i];
            r.token = _keys[i];
            r.decimals = IERC20Metadata(r.token).decimals();
            r.symbol = IERC20Metadata(r.token).symbol();
        }
    }

    function getPrice(address _asset) external view returns (uint256 price) {
        // (, price, ) = getLatestPrice(_asset);
        // address priceFeed = _priceFeedMap[_asset];
        // uint32 decimals = uint32(AggregatorV3Interface(priceFeed).decimals());
        // return (price * (1e18)) / decimals;
        return _assetPriceMap[_asset];
    }

    function setAssetPrice(address _asset, uint256 _price, uint32 _decimals) external nonReentrant onlyRole(FEED_ROLE) {
        require(_price > 0, 'price error');
        require(_decimals > 0, 'decimals error');
        _assetPriceMap[_asset] = (_price * _priceDecimals) / (10 ** _decimals);
        // emit SetAssetPrice(_asset, _price);
    }

    function updatePriceFeedMap(address _asset, address _priceFeed) external nonReentrant onlyRole(FEED_ROLE) {
        _priceFeedMap[_asset] = _priceFeed;
        _keys.push(_asset);
        // emit UpdatePriceFeedMap(_asset, _priceFeed);
    }

    function latestPriceByFeed(address _priceFeed) external view returns (uint256 price, uint32 decimals) {
        (uint80 roundID, int256 price, uint startedAt, uint timeStamp, uint80 answeredInRound) = AggregatorV3Interface(
            _priceFeed
        ).latestRoundData();
        decimals = uint32(AggregatorV3Interface(_priceFeed).decimals());
        return (uint256(price), decimals);
    }

    function getLatestPriceV2(address _token) public view returns (uint256, uint256, uint32) {
        address priceFeed = _priceFeedMap[_token];
        (, int256 price, , uint256 timeStamp, ) = AggregatorV3Interface(priceFeed).latestRoundData();
        uint32 decimals = uint32(AggregatorV3Interface(priceFeed).decimals());
        return (timeStamp, uint256(price), decimals);
    }

    function getLatestPrice(address _token) public view returns (uint256 timeStamp, uint256 price, uint256 decimals) {
        price = _assetPriceMap[_token];
        decimals = 1e18;
        timeStamp = block.timestamp;
        return (timeStamp, price, decimals);
    }
}
