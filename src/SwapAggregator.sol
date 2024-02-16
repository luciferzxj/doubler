// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interfaces/IUniswapV3SwapRouter.sol';
import './interfaces/IUniswapV2Router.sol';
import './interfaces/ISwapAggregator.sol';
contract Aggregator is ISwapAggregator,Ownable{
    uint256 constant BASE_RATIO = 10000;
    mapping(bytes32 => Strategy) public strategys;
    RouterConfig cfg;
    constructor(RouterConfig memory _cfg){
        cfg = _cfg;
    }

    // modifier onlyMoonPool(){
    //     require(msg.sender==moonpool,"just pool");
    //     _;
    // }

    function addUniV3Strategy(address tokenIn,address tokenOut,UniV3Data memory datas)external onlyOwner{
        bytes32 hash = keccak256(abi.encodePacked(tokenIn,tokenOut));
        Strategy storage str = strategys[hash];
        str.v3Data.push(datas);
        str.totalRatio+=datas.ratio;
        // require(totalRatio == 10000,"strategy error");
    }

    function addUniV2Strategy(address tokenIn,address tokenOut,UniV2Data memory datas)external onlyOwner{
        bytes32 hash = keccak256(abi.encodePacked(tokenIn,tokenOut));
        Strategy storage str = strategys[hash];
        str.v2Data.push(datas);
        str.totalRatio+=datas.ratio;
        // require(totalRatio == 10000,"strategy error");
    }

    function updateUniV3Strategy(address tokenIn,address tokenOut,UniV3Data memory datas,uint256 index)external onlyOwner{
        bytes32 hash = keccak256(abi.encodePacked(tokenIn,tokenOut));
        Strategy storage str = strategys[hash];
        str.totalRatio -= str.v3Data[index].ratio;
        str.v3Data[index] = datas;
        str.totalRatio += datas.ratio;
    }
    function updateUniV2Strategy(address tokenIn,address tokenOut,UniV2Data memory datas,uint256 index)external onlyOwner{
        bytes32 hash = keccak256(abi.encodePacked(tokenIn,tokenOut));
        Strategy storage str = strategys[hash];
        str.totalRatio -= str.v2Data[index].ratio;
        str.v2Data[index] = datas;
        str.totalRatio += datas.ratio;
    }
    function outputSwap(address tokenIn,address tokenOut,uint256 amountOut,uint256 maxOutputAmount)external returns(uint256 spendAmount) {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn,tokenOut));
        Strategy memory str = strategys[hash];
        require(str.totalRatio == 10000,"total ratio incorrect");
        IERC20(tokenIn).transferFrom(msg.sender, address(this), maxOutputAmount);
        if(str.v2Data.length>0){
            IERC20(tokenIn).approve(cfg.uniswapV2Router, maxOutputAmount);
            spendAmount+=_uniV2OutputSwap(str,amountOut,maxOutputAmount);
        }
        if(str.v3Data.length>0){
            IERC20(tokenIn).approve(cfg.uniswapV3Router, maxOutputAmount);
            spendAmount+=_uniV3OutputSwap(str, amountOut, maxOutputAmount);
        }
        IERC20(tokenIn).transfer(msg.sender,maxOutputAmount-spendAmount);
    }

    function inputSwap(address tokenIn,address tokenOut,uint256 amountIn,uint256 minAmountOut)external returns(uint256 returnAmount) {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn,tokenOut));
        Strategy memory str = strategys[hash];
        require(str.totalRatio == 10000,"total ratio incorrect");
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        if(str.v2Data.length>0){
            IERC20(tokenIn).approve(cfg.uniswapV2Router, amountIn);
            returnAmount +=_uniV2InputSwap(str, amountIn, minAmountOut);
        }
        if(str.v3Data.length>0){
            IERC20(tokenIn).approve(cfg.uniswapV3Router, amountIn);
            returnAmount +=_uniV3InputSwap(str, amountIn, minAmountOut);
        }
    }

    function _uniV3OutputSwap(Strategy memory str,uint256 amountOut,uint256 maxOutputAmount)internal returns(uint256 spendAmount){
        ISwapRouter.ExactOutputParams memory para;
        for(uint i =0;i<str.v3Data.length;i++){
            para.path = str.v3Data[i].path;
            para.recipient = msg.sender;
            para.deadline = block.timestamp + 1 days;
            para.amountOut = amountOut* str.v3Data[i].ratio/BASE_RATIO;
            para.amountInMaximum = maxOutputAmount* str.v3Data[i].ratio/BASE_RATIO;
            spendAmount+=ISwapRouter(cfg.uniswapV3Router).exactOutput(para);
        }

    }

    function _uniV2OutputSwap(Strategy memory str,uint256 amountOut,uint256 maxOutputAmount)internal returns(uint256 spendAmount){
        for(uint i =0;i<str.v2Data.length;i++){
            amountOut = amountOut*str.v2Data[i].ratio/BASE_RATIO;
            spendAmount += IUniswapV2Router(cfg.uniswapV2Router).swapTokensForExactTokens(amountOut, maxOutputAmount, str.v2Data[i].path, msg.sender, block.timestamp + 1 days)[0];
        }
    }
    function _uniV3InputSwap(Strategy memory str,uint256 amountIn,uint256 minAmountOut)internal returns(uint256 returnAmount){
        ISwapRouter.ExactInputParams memory para;
        for(uint i =0;i<str.v3Data.length;i++){
            para.path = str.v3Data[i].path;
            para.recipient = msg.sender;
            para.deadline = block.timestamp + 1 days;
            para.amountIn = amountIn * str.v3Data[i].ratio/BASE_RATIO;
            para.amountOutMinimum = minAmountOut* str.v3Data[i].ratio/BASE_RATIO;
            returnAmount += ISwapRouter(cfg.uniswapV3Router).exactInput(para);
        }

    }

    function _uniV2InputSwap(Strategy memory str,uint256 amountIn,uint256 minAmountOut)internal returns(uint256 returnAmount){
        for(uint i =0;i<str.v2Data.length;i++){
            amountIn = amountIn*str.v2Data[i].ratio/BASE_RATIO;
            uint[] memory amounts = IUniswapV2Router(cfg.uniswapV2Router).swapExactTokensForTokens(amountIn, minAmountOut, str.v2Data[i].path, msg.sender, block.timestamp + 1 days);
            returnAmount += amounts[amounts.length-1];
        }
    }
}