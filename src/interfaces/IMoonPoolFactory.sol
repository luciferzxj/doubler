// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import './IMoonPool.sol';

interface IMoonPoolFactory {

    error E_asset(); 
    error E_initAmount();

    struct BaseConfig {
        address eco; // eco system
        address dbr; // dbr token
        address dbrFarm; //dbr farm
        address frnft;
        address doubler; // doubler 
        address priceFeed; 
        address swapRouter;
    }

    event UpdateAsset(address asset , bool isSupported);

    event CreateMoonPool(uint256 poolId, address moonPool, address asset, uint256 duration, uint256 cap, uint256 initAmount, uint256 rewardRatio);

    function baseConfig() external view returns (BaseConfig memory);

    function moonPools() external view returns (address[] memory _pools);
    
    function moonPool(uint128 _pooId) external view returns (address);

    function createMoonPool(
        address _srcAsset,
        IMoonPool.InputRule[] calldata _rules,
        uint256 _duration,
        uint256 _cap,
        uint256 _initAmount,
        uint256 _rewardRatio
    ) external ;
}
