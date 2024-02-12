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
}
