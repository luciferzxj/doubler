pragma solidity ^0.8.12;
interface ISwapRouter{
    struct RouterConfig{
        address uniswapV3Router;
        address uniswapV2Router;
    }

    struct UniV3Data{
        bytes path;
        uint256 ratio;
    }

    struct UniV2Data{
        address[] path;
        uint256 ratio;
    }

    struct Strategy{
        uint256 totalRatio;
        UniV2Data[] v2Data;
        UniV3Data[] v3Data;
    }
    function buy(address spendAsset, uint256 buyAmount, address buyAsset, uint256 spendAssetMax) external returns (uint256 spendAmount);

    function sell(address sellAseet, uint256 sellAseetAmount, address returnAsset, uint256 returnAssetMin) external returns (uint256 returnAmount);
}