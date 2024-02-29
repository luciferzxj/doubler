// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
// import './IOneInch.sol';

interface IMoonPool {

    error E_duration();
    error E_cap();
    error E_rewardRatio();
    error E_rules();
    error E_fallRatio();
    error E_profitRatio();
    error E_rewardRatioMax();
    error E_winnerRatioMax();
    error E_tvl();
    error E_sell_limit();
    error E_pool_end();
    error E_pool_check();
    error E_creator();
    error E_asset();
    error E_poolend();
    error E_layerInput();
    error E_balance();
    error E_layer_close();
    error E_Approve();
    error E_input_max();
    
    
    struct Pool {
        // config 
        uint16 creatorRewardRatio;
        uint16 triggerRewardRatio;
        uint16 sellLimitCapRatio;
        address creator;
        address eco;
        address asset;
        address doubler;
        address dbr;
        address dbrFarm;
        address frnft;
        address priceFeed;
        address swapRouter;
        // update value
        uint256 pendingValue; 
        uint256 output;
        uint256 input;
        uint256 capMax;
        uint256 dbrAmount;
        uint256 endTime;
    }

    struct InputRule {
        address asset;
        uint16 fallRatioMin;
        uint16 fallRatioMax;
        uint16 profitRatioMin;
        uint16 profitRatioMax;
        uint16 rewardRatioMin;
        uint16 rewardRatioMax;
        uint16 winnerRatioMin;
        uint16 winnerRatioMax;
        uint256 tvl;
        uint256 layerInputMax;
        // uint24 fee;
    }

    struct InputRecord {
        bool isWithdraw;
        uint256 spend;
        uint256 income;
    }

    event Buy(address user, uint256 lpAmount, uint256 spendAmount, uint256 balance, uint256 pending,  uint256 lpPrice);

    event Sell(address user, uint256 lpAmount, uint256 uAmount, uint256 fee,  uint256 dbrAmount, uint256 balance, uint256 pending,  uint256 lpPrice);

    event UpdateInputRule(
        address asset,
        uint16 fallRatioMin,
        uint16 fallRatioMax,
        uint16 profitRatioMin,
        uint16 profitRatioMax,
        uint16 rewardRatioMin,
        uint16 rewardRatioMax,
        uint16 winnerRatioMin,
        uint16 winnerRatioMax,
        uint256 tvl,
        uint256 layerInputMax
    );
    
    event CostBill(uint256 indexed doublerId, uint256  indexed tokenId, uint8 billType,  uint256 output,  uint256 input, uint256 dbr, uint256 balance, uint256 pending,  uint256 lpPrice);

    function updateRule(InputRule calldata _inputRule) external;

    function buy(uint256 _amount, address _to) external;

    function sell(uint256 _lpAmount)  external returns(uint256 uAmount) ;

    function input(uint256 _doublerId) external;
    
    function output(uint256 _tokenId) external;

    function getFactory() external view returns (address);

    function inputRecord(uint256 _tokenId) external view returns (InputRecord memory record);

    function poolInfo() external view returns (Pool memory pool);
    
    function ruleMap(address _asset) external view returns (InputRule memory rule);

    function getLPValue () external view returns (uint256);
}
