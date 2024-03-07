// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ISwapRouter {
    struct RouterConfig {
        address uniswapV3Router;
        address uniswapV2Router;
    }

    struct UniV3Data {
        bytes path;
        uint256 ratio;
    }

    struct UniV2Data {
        address[] path;
        uint256 ratio;
    }

    struct Strategy {
        uint256 totalRatio;
        UniV2Data[] v2Data;
        UniV3Data[] v3Data;
    }

    function getSlippage() external view returns (uint256 slippage);

    function swapCustomIn(
        address tokenIn,
        uint256 amountInMax,
        address tokenOut,
        uint256 amountOut
    ) external returns (uint256 amountIn);

    function swapCustomOut(
         address tokenIn,
         uint256 amountIn,
         address tokenOut,
         uint256 amountOutMin
    ) external returns (uint256 amountOut);

    function updateSlippage(uint256 _newSlippage) external;

    function addUniV3Strategy(address tokenIn, address tokenOut, UniV3Data memory datas) external;

    function addUniV2Strategy(address tokenIn, address tokenOut, UniV2Data memory datas) external;

    function updateUniV3Strategy(
        address tokenIn,
        address tokenOut,
        UniV3Data memory datas,
        uint256 index
    ) external;

    function updateUniV2Strategy(
        address tokenIn,
        address tokenOut,
        UniV2Data memory datas,
        uint256 index
    ) external;
}
