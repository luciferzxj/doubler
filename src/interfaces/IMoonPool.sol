// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
// import './IOneInch.sol';

interface IMoonPool {
    // map (pooId => Pool)
    struct Pool {
        bool started;
        uint256 inValue;
        uint256 pendingValue;
        uint256 outValue;
        uint256 capMax;
        uint256 dbrAmount;
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
        address asset;
        uint256 spend;
        uint256 income;
    }

    struct PoolConfig {
        address creator;
        address developer;
        address asset;
        address doubler;
        address dbr;
        address dbrFarm;
        address FRNFT;
        address aggregator;
        address pricefeed;
    }

    struct SignatureParams {
        uint256 amountOut;
        uint256 maxAmountIn;
    }

    event NewPool(address creator, address lp);
    event Start();
    event Deposite(address buyer, uint256 amount, uint256 lp);
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

    event Withdraw(
        address buyer,
        uint256 lpAmount,
        uint256 uAmount,
        uint256 dbrAmount
    );
    event NewInput(
        uint256 indexed doublerId,
        uint256 lastLayer,
        uint256 tokenId,
        uint256 spentAmount,
        uint256 inputAmount
    );
    event Gain(uint256 tokenIds, uint256 spend, uint256 uSell, uint256 mintDbr);

    function initialize(
        address _creator,
        address _dev,
        address dbrContract,
        address _doublerContract,
        address _dbrFarmContract,
        address _nft,
        address _router,
        address _srcAsset,
        address _pricefeed
    ) external;

    function start(
        InputRule[] calldata _rules,
        uint256 _duration,
        uint256 _cap,
        uint256 _initAmount,
        uint256 _rewardRatio
    ) external;

    function updateRule(InputRule calldata _inputRule) external;

    function deposite(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function input(uint256 _doublerId, SignatureParams memory datas) external;

    function gain(uint256 _tokenId) external;

    function getFactory() external view returns (address);

    function inputRecord(
        uint256 tokenId
    ) external view returns (InputRecord memory record);

    function poolInfo() external view returns (Pool memory pool);

    function ruleMap(
        address asset
    ) external view returns (InputRule memory rule);
}
