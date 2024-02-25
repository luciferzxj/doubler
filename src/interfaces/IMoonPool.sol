// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

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
    
    struct Pool {
        uint256 pendingValue; // 
        uint256 output;
        uint256 input;
        uint256 capMax;
        uint256 dbrAmount;
        // uint256 startTime;
        uint256 endTime;
    }

    // map (pooId => map(asset => InputRule))
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
    }

    // map(pooId => map(tokenId => Bill))
    struct InputRecord {
        bool isWithdraw;
        uint256 spend;
        uint256 income;
    }

    struct PoolConfig {
        address creator;
        address eco;
        address asset;
        address doubler;
        address dbr;
        address dbrFarm;
        address frnft;
        address priceFeed;
        address swapRouter;
    }

    event Buy(address user, uint256 lpAmount, uint256 spendAmount);

    event Sell(address user, uint256 lpAmount, uint256 uAmount, uint256 fee,  uint256 dbrAmount);

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

    event NewInput(
        uint256 indexed doublerId,
        uint256 lastLayer,
        uint256 tokenId,
        uint256 spentAmount,
        uint256 inputAmount
    );

    event NftBill(uint256 indexed doublerId, uint256  indexed tokenId, uint256 output,  uint256 input,  uint256 dbr);

    event Gain(uint256 tokenId, uint256 spend, uint256 uSell, uint256 mintDbr);


    function updateRule(InputRule calldata _inputRule) external;

    function buy(uint256 _amount, address _to) external;

    function sell(uint256 _lpAmount)  external returns(uint256 uAmount) ;

    function input(uint256 _doublerId) external;

    function gain(uint256 _tokenId) external;

    function getFactory() external view returns (address);

    function inputRecord(uint256 _tokenId) external view returns (InputRecord memory record);

    function poolInfo() external view returns (Pool memory pool);
    
    function ruleMap(address _asset) external view returns (InputRule memory rule);

    function tokenMuch() external view returns (uint256);
}
