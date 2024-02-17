pragma solidity ^0.8.12;
interface ISwapAggregator{
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
    function buy(address tokenIn,address tokenOut,uint256 amountOut,uint256 maxOutputAmount)external returns(uint256 spendAmount);
    function sell(address tokenIn,address tokenOut,uint256 amountIn,uint256 minAmountOut)external returns(uint256 returnAmount);
}