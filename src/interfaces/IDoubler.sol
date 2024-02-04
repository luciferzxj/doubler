// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import './IFRNFT.sol';

interface IDoubler {
    error E_Type();
    error E_Approve();
    error E_Balance();
    error E_Owner();

    error E_Initialized();
    error E_Asset();
    error E_Units();
    error E_FallRatio();
    error E_Double();
    error E_ProfitRatio();
    error E_RewardRatio();
    error E_MaxRewardUnits();
    error E_WinnerRatio();
    error E_LastLayerRewardRatio();
    error E_UnitSize();
    error E_PollStatus();
    error E_PriceLimit();

    error E_Margin();
    error E_Multiple();
    error E_MultipleLimit();
    error E_LayerCap();
    error E_FeedPrice();
    error E_PoolUnstart();
    error E_PoolNotEnd();
    error E_PoolEnd();
    error E_PoolLastLayer();
    error E_PoolEndOne();
    error E_PoolEndPrice();
    error E_PoolAssetBalance();
    
    struct Pool {
        address asset;
        address creator;
        address terminator;
        uint16 fallRatio;
        uint16 profitRatio;
        uint16 rewardRatio;
        uint16 winnerRatio;
        uint32 double;
        uint32 lastLayer;
        uint256 tokenId;
        uint256 unitSize;
        uint256 maxRewardUnits;
        uint256 winnerOffset;
        uint256 endPrice;
        uint256 lastOpenPrice;
        uint256 tvl;
        uint256 amount;
        uint256 margin;
        uint256 joins;
        uint256 lastInputBlockNo;
        uint256 kTotal;
    }
    struct AddPool {
        address asset;
        uint16 fallRatio;
        uint16 profitRatio;
        uint16 rewardRatio;
        uint16 winnerRatio;
        uint32 double;
        uint256 unitSize;
        uint256 maxRewardUnits;
        uint256 units;
    }

    struct AddInput {
        uint32 layer;
        uint256 poolId;
        uint256 margin;
        uint256 multiple;
        uint256 amount;
        uint256 curPrice;
    }

    struct Asset {
        bool isOpen;
    }

    struct LayerData {
        uint256 openPrice; // open layer price
        uint256 amount;
        uint256 tvl;
        uint256 cap;
    }

    struct WinnerResult {
        bool isWinner;
        uint256 rewardUnits;
        uint256 winnerRange;
    }

    struct PoolProfit {
        uint256 profitAmount;
        uint256 rewardAmount;
        uint256 rewardEcoFee;
    }

    event UpdateAssetConfig(address to, bool isOpen);
    event NewPool(
        uint256 indexed poolId,
        address creator,
        address asset,
        uint16 fallRatio,
        uint16 profitRatio,
        uint16 rewardRatio,
        uint16 winnerRatio,
        uint32 double,
        uint256 unitSize,
        uint256 maxRewardUnits
    );
    event UpgradeDbrPool(address upDbrPool);
    event UpgradePriceFeed(address upgFastPriceFeed);
    event Initialize(
        address initTeam,
        address initFastPriceFeed,
        address initDoublerNFT,
        address initDbrTokenAddress,
        address initMultiSigWallet
    );
    event UpgradeReceiver(uint8 _type, address _receiver);
    event Withdraw(uint256 indexed tokenId, uint256 indexed poolId, address indexed owner, uint256 amount, uint256 fee);
    event NewInput(
        uint256 indexed tokenId,
        uint256 indexed poolId,
        address indexed inputer,
        uint32 layer,
        uint256 margin,
        uint256 amount,
        uint256 price
    );
    event NewLayer(uint256 indexed poolId, uint32 indexed layer, uint256 price, uint256 cap);

    event PoolStream(
        uint256 indexed poolId,
        uint256 tvl,
        uint256 amount,
        uint256 units,
        uint256 avgPrice,
        uint256 profitPrice
    );

    event Gain(
        uint256 indexed tokenId,
        uint256 indexed poolId,
        address indexed owner,
        uint256 available,
        uint256 reward,
        uint256 fee
    );

    event EndPool(
        uint256 indexed poolId,
        uint256 tvl,
        uint256 amount,
        uint256 profitPrice,
        uint256 profitAmount,
        uint256 reward,
        uint256 teamR,
        uint256 creatorReward,
        uint256 winRange,
        uint256 winnerOffset
    );

    function newPool(AddPool calldata _addPool) external;
    function input(AddInput memory _addInput) external returns (uint256 tokenId);
    function forceWithdraw(uint256 _tokenId) external;
    function endPool(uint256 _poolId) external;
    function gains(uint256[] memory _tokenIds) external;
    function gain(uint256 _tokenId) external returns(uint256 amount);
    function getLayerCount(uint256 _poolId) external view returns (uint256);
    function getPool(uint256 _poolId) external view returns (Pool memory);
    function getLayerData(uint256 _poolId, uint32 _layer) external view returns (LayerData memory);
    function getWinnerRange(uint256 _poolId) external view returns (uint256);
    function getWinnerOffset(uint256 _poolId) external view returns (uint256);
    function getTokenProfit(
        uint256 _tokenId
    ) external view returns (uint256 leftAmount, uint256 available, uint256 winnerReward, uint256 fee);
    function getMaxMultiple(uint256 _poolId) external view returns (uint256);
    function getAssetConfigMap(address _asset) external view returns(Asset memory);
    function getPrivateVar()
        external
        view
        returns (
            uint16 ecoFeeRatio,
            uint16 feeRatio,
            uint16 protectBlock,
            uint256 lastPoolId,
            uint256 tvlTotal,
            address fastPriceFeed,
            address frNFT,
            address team,
            address eco
        );

}
