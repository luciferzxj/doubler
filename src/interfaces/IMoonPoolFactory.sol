// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import './IMoonPool.sol';

interface IMoonPoolFactory {

    error E_asset(); 
    error E_initAmount();
    error E_sellLimit();
    error E_triggerReward();
    error E_tvl();
    error E_layerInput();
    error E_rewardRatioMax();
    error E_winnerRatioMax();
    error E_fallRatio();
    error E_profitRatio();
    error E_duration();
    error E_cap();
    error E_rewardRatio();
    error E_sigWallet();

    struct BaseConfig {
        address eco; // eco system
        address dbr; // dbr token
        address dbrFarm; //dbr farm
        address frnft;
        address doubler; // doubler 
        address priceFeed; 
        address swapRouter;
        uint256 initAmountMin;
    }

    struct AddMoonPool {
        address srcAsset;
        uint256 duration;
        uint256 cap;
        uint256 initAmount;
        uint16  creatorRewardRatio;
        uint16  triggerRewardRatio;
        uint16  sellLimitCapRatio;
    }
    
    event UpdateAsset(address asset , bool isSupported);

    event  UpdateInitAmountMin(uint256 newInitAmountMin);

    event CreateMoonPool(uint256 poolId, address moonPool, address asset, uint256 duration, uint256 cap, uint256 initAmount, uint256 rewardRatio);

    function baseConfig() external view returns (BaseConfig memory);

    function moonPoolTotal() external view returns (uint256);
    
    function getMoonPoolAddress(uint128 _pooId) external view returns (address);

    function createMoonPool(
        AddMoonPool calldata _addPool,
        IMoonPool.InputRule[] calldata _rules
    ) external;

    function updateAssets(address _asset, bool isSupport) external;
    
    function updateInitAmountMin(uint256 _newInitAmountMin) external;
}
