// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;


import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '../interfaces/ISwapRouter.sol';
import '../interfaces/IDBR.sol';

contract MockSwapRouter is Context,ISwapRouter {

    function buy(
        address buyAsset,
        uint256 buyAmount,
        address spendAsset,
        uint256 spendAssetMax
    ) external override returns (uint256 spendAmount) {
        IDBR(spendAsset).transferFrom(_msgSender(), address(this), spendAssetMax);
        IDBR(buyAsset).mint(_msgSender(), buyAmount);
        return spendAssetMax;
    }

    function sell(
        address sellAseet,
        uint256 sellAseetAmount,
        address returnAsset,
        uint256 returnAssetMax
    ) external override returns (uint256 returnAmount) {
        IDBR(sellAseet).transferFrom(_msgSender(), address(this), sellAseetAmount);
        IDBR(returnAsset).mint(_msgSender(), returnAssetMax);
        return returnAssetMax;
    }
}