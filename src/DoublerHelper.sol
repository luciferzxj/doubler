// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './interfaces/IFRNFT.sol';
import './interfaces/IDoubler.sol';
import './interfaces/IDBRFarm.sol';
import './interfaces/IDoublerHelper.sol';
import './interfaces/IFastPriceFeed.sol';
import 'hardhat/console.sol';

// import Upgradeable
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';

contract DoublerHelper is
    IDoublerHelper,
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    using SafeMath for uint256;
    using SafeMath for uint32;
    using SafeMath for uint16;
    using SafeERC20 for IERC20;

    uint256 private constant RATIO_PRECISION = 100 * 100;

    bool private _initialized;
    address private _doublerAddress;
    address private _FRNFT;
    address private _fastPriceFeed;
    address private _dbrFarm;

    // for update
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initializeHelper(
        address _initDoublerAddress,
        address _initFRNFT,
        address _initFastPriceFeed,
        address _initDbrFarm
    ) external onlyOwner {
        require(_initialized == false, 'initialized err');
        _initialized = true;
        _doublerAddress = _initDoublerAddress;
        _FRNFT = _initFRNFT;
        _fastPriceFeed = _initFastPriceFeed;
        _dbrFarm = _initDbrFarm;
    }

    function getAddrView() external view returns (address, address, address, address) {
        return (_doublerAddress, _FRNFT, _fastPriceFeed, _dbrFarm);
    }

    function updateAddr(string memory _updateType, address _newAddr) external onlyOwner {
        if (keccak256(bytes(_updateType)) == keccak256(bytes('_fastPriceFeed'))) {
            _fastPriceFeed = _newAddr;
        }
        if (keccak256(bytes(_updateType)) == keccak256(bytes('_dbrFarm'))) {
            _dbrFarm = _newAddr;
        }
    }

    function getPoolView(uint256 _poolId) public view returns (PoolView memory pv) {
        IDoubler.Pool memory pool = IDoubler(_doublerAddress).getPool(_poolId);
        uint8 decimals = IERC20Metadata(pool.asset).decimals();
        IDoubler doublerPool = IDoubler(_doublerAddress);
        uint256 price = IFastPriceFeed(_fastPriceFeed).getPrice(pool.asset);
        uint256 winRange = doublerPool.getWinnerRange(_poolId);
        IDBRFarm.Doubler memory dbrFarm = IDBRFarm(_dbrFarm).getDoubler(_poolId);
        IDoubler.LayerData memory layerData = doublerPool.getLayerData(_poolId, pool.lastLayer);
        pv.id = _poolId;
        pv.asset = pool.asset;
        pv.creator = pool.creator;
        pv.fallRatio = pool.fallRatio;
        pv.profitRatio = pool.profitRatio;
        pv.rewardRatio = pool.rewardRatio;
        pv.winnerRatio = pool.winnerRatio;
        pv.double = pool.double;
        pv.lastLayer = pool.lastLayer;
        pv.tvl = pool.tvl;
        pv.unitSize = pool.unitSize;
        pv.amount = pool.amount;
        pv.maxRewardUnits = pool.maxRewardUnits;
        pv.lastOpenPrice = pool.lastOpenPrice;
        pv.endPrice = pool.endPrice;
        pv.joins = pool.joins;
        pv.winnerRange = winRange;
        pv.lastAmount = layerData.amount;
        pv.lastCap = layerData.cap;
        if (winRange > 0) {
            pv.winnerOffset = pool.endPrice > 0 ? pool.winnerOffset : doublerPool.getWinnerOffset(_poolId);
        }
        if (pool.amount > 0) {
            pv.avgPrice = pool.tvl.mul(10 ** decimals).div(pool.amount);
            pv.profitPrice = pv.avgPrice.mul(RATIO_PRECISION + pool.profitRatio).div(RATIO_PRECISION);
        }
        pv.hot = dbrFarm.hot;
        uint256 lastClosePrice = pool.lastOpenPrice.mul(RATIO_PRECISION.sub(pool.fallRatio)).div(RATIO_PRECISION);
        if (pv.endPrice == 0 && price <= lastClosePrice) {
            pv.isInput = true;
        } else if (pv.endPrice == 0 && price <= pool.lastOpenPrice && layerData.cap > layerData.amount) {
            pv.isInput = true;
        }
    }

    function getPoolList(uint256[] calldata _poolIds) external view returns (PoolView[] memory pools) {
        pools = new PoolView[](_poolIds.length);
        for (uint i = 0; i < _poolIds.length; ++i) {
            pools[i] = getPoolView(_poolIds[i]);
        }
        return pools;
    }

    function _getLayerDataView(
        uint256 _layerId,
        IDoubler.LayerData memory _ld
    ) internal pure returns (LayerDataView memory dv) {
        dv.layerId = _layerId;
        dv.openPrice = _ld.openPrice;
        dv.amount = _ld.amount;
        dv.tvl = _ld.tvl;
        dv.cap = _ld.cap;
    }

    function getLayerList(
        uint256 _poolId,
        uint32[] calldata _layerIds
    ) external view returns (LayerDataView[] memory layerList) {
        layerList = new LayerDataView[](_layerIds.length);
        IDoubler doublerPool = IDoubler(_doublerAddress);
        for (uint32 i = 0; i < _layerIds.length; ++i) {
            layerList[i] = _getLayerDataView(_layerIds[i], doublerPool.getLayerData(_poolId, _layerIds[i]));
        }
    }

    function getTokenProfit(uint256 _tokenId) external view returns (TokenProfitView memory trView) {
        IDoubler doublerPool = IDoubler(_doublerAddress);
        (, trView.available, trView.winnerReward, trView.fee) = doublerPool.getTokenProfit(_tokenId);
        // trView.dbrAmount = IDBRFarm(_dbrFarm).getNftTokenMintCount(_tokenId);
    }

    function getTokenProfitList(
        uint256[] calldata _tokenIds
    ) external view returns (TokenProfitView[] memory trViewList) {
        IDoubler doublerPool = IDoubler(_doublerAddress);
        trViewList = new TokenProfitView[](_tokenIds.length);
        TokenProfitView memory trView;
        IFRNFT.Traits memory nft;

        for (uint32 i = 0; i < _tokenIds.length; ++i) {
            nft = IFRNFT(_FRNFT).getTraits(_tokenIds[i]);
            (, trView.available, trView.winnerReward, trView.fee) = doublerPool.getTokenProfit(_tokenIds[i]);
            // trView.dbrAmount = IDBRFarm(_dbrFarm).getNftTokenMintCount(_tokenIds[i]);
            trViewList[i] = trView;
        }
    }

    function getMaxMultiple(uint256 _poolId) external view returns (uint256 multiple) {
        multiple = IDoubler(_doublerAddress).getMaxMultiple(_poolId);
    }
}
