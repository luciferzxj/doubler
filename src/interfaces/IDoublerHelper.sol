// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IDoublerHelper {

    struct PoolView {
        bool isInput;
        address asset;
        address creator;
        uint16 fallRatio;
        uint16 profitRatio;
        uint16 rewardRatio;
        uint16 winnerRatio;
        uint16 lastLayerRewardRatio;
        uint32 double;
        uint32 lastLayer;
        uint256 tvl;
        uint256 id;
        uint256 unitSize;
        uint256 amount;
        uint256 maxRewardUnits;
        uint256 lastOpenPrice;
        uint256 winnerOffset;
        uint256 winnerRange;
        uint256 endPrice;
        uint256 hot;
        uint256 joins;
        uint256 lastCap;
        uint256 lastAmount;
        uint256 avgPrice;
        uint256 profitPrice;
        // uint256 dbrAmount;
    }

    struct LayerDataView {
        uint256 layerId;
        uint256 openPrice;
        uint256 amount;
        uint256 tvl;
        uint256 cap;
    }

    struct TokenProfitView {
        uint256 available;
        uint256 winnerReward;
        uint256 fee;
        uint256 dbrAmount;
    }

    struct TokenMeta {
        address token;
        string symbol;
        uint8 decimals;
        bytes32 priceFeed;
    }

    struct NftFullView {
        uint32 layer;
        uint256 tokenId;
        uint256 poolId;
        uint256 margin;
        uint256 amount;
        uint256 price;
        uint256 layerRanking;
        uint256 dbrAmount;
        bool doublerEnd;
    }

    struct UserLpView {
        uint128 id;
        address addr;
        uint256 lpAmount;
        uint256 price;
        uint256 value;
    }

    struct MoonPoolView {
        string symbol;
        uint128 id;
        address addr;
        address asset;
        uint256 tvl;
        uint256 output;
        uint256 input;
        uint256 lpPrice;
        uint256 buyLpLimit;
        uint256 sellLpLimit;
    }
    
    function getDoublerAllowAssets() external view returns (TokenMeta[] memory res);
    
    function getMoonPoolAllowAssets() external view returns (TokenMeta[] memory res);

    function getPoolView(uint256 _poolId) external view returns (PoolView memory pv);
    function getPoolList(uint256[] calldata _poolIds) external view returns (PoolView[] memory pools);
    function getLayerList(
        uint256 _poolId,
        uint32[] calldata _layerIds
    ) external view returns (LayerDataView[] memory layerList);
    function getTokenProfit(uint256 _tokenId) external view returns (TokenProfitView memory trView);
    function getTokenProfitList(
        uint256[] calldata _tokenIds
    ) external view returns (TokenProfitView[] memory trViewList);
    function getMaxMultiple(uint256 _poolId) external view returns (uint256);
    function getFarmNftList(
        address owner,
        uint256 offset,
        uint256 limit
    ) external view returns (NftFullView[] memory nftView);
    function userMoonPoolLpView(address from) external view returns(uint256 tvlTotal, UserLpView[] memory list);
    function getMoolPoolTvl() external view returns(uint256 tvl);
    function getMoolPoolList(uint128[] memory poolIds) external view returns(MoonPoolView[] memory pools);
    function getValidDoublerForMoonPool(address lpAddress, uint128[] memory doublerIds) external view returns (uint128[] memory retIds);
}
