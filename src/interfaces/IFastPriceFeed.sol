// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IFastPriceFeed {

    enum Plan {
        DEX,
        CHAINLINK,
        PYTH,
        OTHER
    }

    struct PriceLimit {
        uint256 min;
        uint256 max;
    }

    event AddAsset(address asset, address assetOracles, uint32 twapInterval);
    event SetPriceLimit(address asset, PriceLimit prices);    

    event UpgradePlan(address asset, address _aggregator);
    event AssetClosed(address asset);
    event SetDexPriceFeed(address asset, address univ3Pool);
    event SetTwapInterval(address asset, uint32 previous, uint32 present);
    event SetChainlinkAggregator(address asset, address aggregator);
    event InitPyhonPriceFeed(address asset, address oracleAddr ,bytes32 priceFeed);
    
    function getPrice(address _asset) external  view returns (uint256 price);
}