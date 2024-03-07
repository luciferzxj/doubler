// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;


import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '../interfaces/ISwapRouter.sol';
import '../interfaces/IDBR.sol';

contract MockSwapRouter is Context {

    function swapCustomIn(
       address tokenIn,
        uint256 amountInMax,
        address tokenOut,
        uint256 amountOut
    ) external  returns (uint256 spendAmount) {
        IDBR(tokenIn).transferFrom(_msgSender(), address(this), amountInMax);
        IDBR(tokenOut).mint(_msgSender(), amountOut);
        return amountInMax;
    }

    function swapCustomOut(
         address tokenIn,
         uint256 amountIn,
         address tokenOut,
         uint256 amountOutMin
    ) external  returns (uint256 returnAmount) {
        IDBR(tokenIn).transferFrom(_msgSender(), address(this), amountIn);
        IDBR(tokenOut).mint(_msgSender(), amountOutMin);
        return amountOutMin;
    }

    function getSlippage() external view returns (uint256 slippage) {
        return 80;
    }
}