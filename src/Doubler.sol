// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './interfaces/IFastPriceFeed.sol';
import './interfaces/IFRNFT.sol';
import './interfaces/IDoubler.sol';
import 'hardhat/console.sol';

contract Doubler is IDoubler, AccessControlEnumerable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint32;
    using SafeMath for uint16;
    using SafeERC20 for IERC20;

    bytes32 public constant INIT_ROLE = keccak256('INIT_ROLE');
    uint256 private constant RATIO_PRECISION = 10000; // 100 * 100

    bool private _initialized;
    uint16 private _ecoFeeRatio;
    uint16 private _feeRatio;
    uint16 private _protectBlock;
    uint256 private _lastPoolId;
    uint256 private _tvlTotal;
    address private _dbrAsset;
    address private _fastPriceFeed;
    address private _FRNFT;
    address private _team;
    address private _eco;

    mapping(uint256 => Pool) private _poolMap;
    mapping(address => Asset) private _assetConfigMap;
    mapping(uint256 => mapping(uint32 => LayerData)) private _layerDataMap;

    constructor() {
        _grantRole(INIT_ROLE, _msgSender());
    }

    function initialize(
        address _initTeam,
        address _initEco,
        address _initFastPriceFeed,
        address _initDoublerNFT,
        address _initDbrTokenAddress,
        address _initMultiSigWallet,
        uint16 _initProtectBlock
    ) external onlyRole(INIT_ROLE) {
        if (_initialized == true) revert E_Initialized();
        _initialized = true;
        _team = _initTeam;
        _eco = _initEco;
        _fastPriceFeed = _initFastPriceFeed;
        _FRNFT = _initDoublerNFT;
        _ecoFeeRatio = 2000; // 20% * 100
        _feeRatio = 20; // 0.2% * 100
        _protectBlock = _initProtectBlock;
        _grantRole(DEFAULT_ADMIN_ROLE, _initMultiSigWallet);
        emit Initialize(_initTeam, _initFastPriceFeed, _initDoublerNFT, _initDbrTokenAddress, _initMultiSigWallet);
    }

    function updateAssetConfig(address _to, bool _isOpen) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        _assetConfigMap[_to].isOpen = _isOpen;
        emit UpdateAssetConfig(_to, _isOpen);
    }

    function upgradeReceiver(uint8 _type, address _receiver) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_type == 1) {
            _team = _receiver;
        } else if (_type == 2) {
            _eco = _receiver;
        } else {
            revert E_Type();
        }
        emit UpgradeReceiver(_type, _receiver);
    }

    function newPool(AddPool calldata _newPool) external nonReentrant {
        _lastPoolId = _lastPoolId.add(1);
        Asset memory tokenConfig = _assetConfigMap[_newPool.asset];
        uint8 decimals = IERC20Metadata(_newPool.asset).decimals();
        if (tokenConfig.isOpen == false) revert E_Asset();
        if (_newPool.unitSize == 0 || _newPool.units == 0) revert E_Units();
        if (_newPool.fallRatio < 50 || _newPool.fallRatio >= 8000) revert E_FallRatio();
        if (_newPool.double < 2 || _newPool.double > 5) revert E_Double();
        if (_newPool.profitRatio < 50 || _newPool.profitRatio > RATIO_PRECISION) revert E_ProfitRatio();
        if (_newPool.rewardRatio > RATIO_PRECISION) revert E_RewardRatio();
        if (_newPool.maxRewardUnits == 0) revert E_MaxRewardUnits();
        if (_newPool.winnerRatio > RATIO_PRECISION) revert E_WinnerRatio();

        Pool storage pool = _poolMap[_lastPoolId];
        pool.creator = _msgSender();
        pool.asset = _newPool.asset;
        pool.unitSize = _newPool.unitSize;
        pool.fallRatio = _newPool.fallRatio;
        pool.double = _newPool.double;
        pool.maxRewardUnits = _newPool.maxRewardUnits;
        pool.profitRatio = _newPool.profitRatio;
        pool.rewardRatio = _newPool.rewardRatio;
        pool.winnerRatio = _newPool.winnerRatio;

        AddInput memory addInput;
        addInput.poolId = _lastPoolId;
        addInput.multiple = 1;
        addInput.margin = _newPool.units * _newPool.unitSize;
        addInput.amount = addInput.margin;
        addInput.curPrice = _getPrice(_newPool.asset);
        if (_newPool.unitSize.mul(addInput.curPrice).div(10 ** decimals) < 10 * 1e18) revert E_UnitSize();

        emit NewPool(
            _lastPoolId,
            _msgSender(),
            _newPool.asset,
            _newPool.fallRatio,
            _newPool.profitRatio,
            _newPool.rewardRatio,
            _newPool.winnerRatio,
            _newPool.double,
            _newPool.unitSize,
            _newPool.maxRewardUnits
        );
        pool.tokenId = _input(addInput, decimals);
    }

    function input(AddInput memory _addInput) external nonReentrant returns (uint256 tokenId)  {
        if (_poolMap[_addInput.poolId].endPrice > 0 || _poolMap[_addInput.poolId].lastOpenPrice == 0)
            revert E_PollStatus();
        _addInput.curPrice = _getPrice(_poolMap[_addInput.poolId].asset);
        uint8 decimals = IERC20Metadata(_poolMap[_addInput.poolId].asset).decimals();
        tokenId = _input(_addInput, decimals);
    }

    function _getLastLayer(uint256 _poolId, uint256 _curPrice, uint256 _amount) internal returns (uint32 curLayer) {
        Pool storage pool = _poolMap[_poolId];
        if (pool.lastOpenPrice == 0) {
            // layer 0
            _layerDataMap[_poolId][pool.lastLayer].cap = _amount;
        } else {
            if (pool.amount > 0 && pool.tvl > 0) {
                uint8 decimals = IERC20Metadata(pool.asset).decimals();
                uint256 profitPrice = _getProfitPrice(pool.tvl, pool.amount, decimals, pool.profitRatio);
                if ( _curPrice >= profitPrice) revert E_PriceLimit();
            }
            if (_curPrice > pool.lastOpenPrice ) revert E_PriceLimit();
            // inut [openPirce , closeprice)
            uint256 lastClosePrice = pool.lastOpenPrice.mul(RATIO_PRECISION.sub(pool.fallRatio)).div(RATIO_PRECISION);
            if (_curPrice > lastClosePrice) {
                return pool.lastLayer;
            }
            // new layer
            uint256 doubleV2 = pool.double;
            uint256 k = pool.lastOpenPrice.sub(_curPrice).mul(RATIO_PRECISION).div(pool.fallRatio).div(
                pool.lastOpenPrice
            );
            pool.lastLayer = pool.lastLayer + 1;
            if (pool.kTotal >= 49) {
                _layerDataMap[_poolId][pool.lastLayer].cap = _layerDataMap[_poolId][pool.lastLayer - 1].cap;
            } else {
                uint256 n = pool.kTotal + k > 49 ? 49 - pool.kTotal : k;
                _layerDataMap[_poolId][pool.lastLayer].cap = _layerDataMap[_poolId][pool.lastLayer - 1].cap.mul(
                    doubleV2 ** n
                );
            }
            pool.kTotal = pool.kTotal + k;
        }
        pool.lastOpenPrice = _curPrice;
        _layerDataMap[_poolId][pool.lastLayer].openPrice = _curPrice;
        return pool.lastLayer;
    }

    function getMaxMultiple(uint256 _poolId) external view returns (uint256) {
        Pool memory pool = _poolMap[_poolId];
        uint256 curPrice = _getPrice(pool.asset);
        uint8 decimals = IERC20Metadata(pool.asset).decimals();
        return _getMaxMultiple(pool, curPrice, decimals);
    }

    function _getMaxMultiple(Pool memory _pool, uint256 _curPrice, uint8 _decimals) internal pure returns (uint256) {
        if (_pool.amount == 0) return 1;
        uint256 profitPrice = _getProfitPrice(_pool.tvl, _pool.amount, _decimals, _pool.profitRatio);
        uint256 multiple = 0;
        if (_curPrice >= profitPrice) return 1;
        //  multiple * (0.8 - fallRatio)
        multiple = profitPrice.mul(8000 - _pool.fallRatio).div(profitPrice.sub(_curPrice)).div(RATIO_PRECISION);
        multiple = multiple > 20 ? 20 : multiple;
        return multiple > 0 ? multiple : 1;
    }

    function _input(AddInput memory _addInput, uint8 _decimals) internal returns (uint256 tokenId) {
        Pool memory pool = _poolMap[_addInput.poolId];
        if (_addInput.margin == 0 || _addInput.margin > _addInput.amount || _addInput.margin.mod(pool.unitSize) != 0)
            revert E_Margin();
        if (IERC20(pool.asset).allowance(_msgSender(), address(this)) < _addInput.margin) revert E_Approve();
        if (IERC20(pool.asset).balanceOf(_msgSender()) < _addInput.margin) revert E_Balance();
        if (_addInput.multiple < 1 || _addInput.margin.mul(_addInput.multiple) != _addInput.amount) revert E_Multiple();
        if (_addInput.multiple > 1 && _addInput.multiple > _getMaxMultiple(pool, _addInput.curPrice, _decimals))
            revert E_MultipleLimit();
        _addInput.layer = _getLastLayer(_addInput.poolId, _addInput.curPrice, _addInput.amount);
        LayerData memory layer = _layerDataMap[_addInput.poolId][_addInput.layer];
        if (layer.amount >= layer.cap) revert E_LayerCap();
        if (layer.cap.sub(layer.amount) < _addInput.margin) {
            _addInput.margin = _addInput.amount = layer.cap.sub(layer.amount);
        } else {
            _addInput.amount = layer.cap.sub(layer.amount) < _addInput.amount
                ? layer.cap.sub(layer.amount)
                : _addInput.amount;
        }
        IERC20(pool.asset).safeTransferFrom(_msgSender(), address(this), _addInput.margin);
        uint256 layerAmount = _addTvl(_addInput);
        uint256 layerRanking = layerAmount.div(pool.unitSize);
        tokenId = IFRNFT(_FRNFT).mint(
            _msgSender(),
            _addInput.poolId,
            _addInput.layer,
            _addInput.margin,
            _addInput.amount,
            _addInput.curPrice,
            layerRanking
        );
        emit NewInput(
            tokenId,
            _addInput.poolId,
            _msgSender(),
            _addInput.layer,
            _addInput.margin,
            _addInput.amount,
            _addInput.curPrice
        );
    }

    function _addTvl(AddInput memory _addInput) internal returns (uint256) {
        Pool storage pool = _poolMap[_addInput.poolId];
        uint8 decimals = IERC20Metadata(pool.asset).decimals();
        LayerData storage layer = _layerDataMap[_addInput.poolId][_addInput.layer];
        uint256 addTvl = _addInput.amount.mul(_addInput.curPrice).div(10 ** decimals);
        pool.amount = pool.amount.add(_addInput.amount);
        pool.tvl = pool.tvl.add(addTvl);
        pool.lastInputBlockNo = block.number;
        pool.joins += 1;
        pool.margin += _addInput.margin;
        layer.tvl = layer.tvl.add(addTvl);
        layer.amount = layer.amount.add(_addInput.amount);
        _tvlTotal = _tvlTotal.add(addTvl);
        uint256 avgPrice = pool.tvl.mul(10 ** decimals).div(pool.amount);
        uint256 profitPrice = _getProfitPrice(pool.tvl, pool.amount, decimals, pool.profitRatio);
        emit PoolStream(_addInput.poolId, pool.tvl, pool.amount, pool.amount.div(pool.unitSize), avgPrice, profitPrice);
        return layer.amount;
    }

    function _getPrice(address _token) internal view returns (uint256 price) {
        price = IFastPriceFeed(_fastPriceFeed).getPrice(_token);
        if (price == 0) revert E_FeedPrice();
    }

    function _getProfitPrice(
        uint256 _tvl,
        uint256 _amount,
        uint8 _decimals,
        uint16 _profitRatio
    ) internal pure returns (uint256) {
        return _tvl.mul(10 ** _decimals).div(_amount).mul(RATIO_PRECISION.add(_profitRatio)).div(RATIO_PRECISION);
    }

    function forceWithdraw(uint256 _tokenId) external nonReentrant {
        if (IFRNFT(_FRNFT).ownerOf(_tokenId) != _msgSender()) revert E_Owner();
        if (IFRNFT(_FRNFT).getApproved(_tokenId) != address(this)) revert E_Approve();
        IFRNFT.Traits memory nft = IFRNFT(_FRNFT).getTraits(_tokenId);
        Pool memory pool = _poolMap[nft.poolId];
        if (pool.endPrice > 0) revert E_PoolEnd();
        if (pool.joins > 1 && pool.lastLayer == nft.layer) revert E_PoolLastLayer();
        (uint256 withDrawAmount, uint256 fee) = _subTvl(nft);
        IFRNFT(_FRNFT).burnFrom(_msgSender(), _tokenId);
        emit Withdraw(_tokenId, nft.poolId, _msgSender(), withDrawAmount, fee);
    }

    function _subTvl(IFRNFT.Traits memory _nft) internal returns (uint256 available, uint256 fee) {
        Pool storage pool = _poolMap[_nft.poolId];
        uint256 leftAmount;
        uint256 assetPrice = _getPrice(pool.asset);
        (leftAmount, available, , fee) = _getTokenProfit(_nft, assetPrice);
        uint8 decimals = IERC20Metadata(pool.asset).decimals();
        if (available > 0) {
            IERC20(pool.asset).safeTransfer(_team, fee);
            IERC20(pool.asset).safeTransfer(_msgSender(), available.sub(fee));
        }
        uint256 reductTvlAmount = _nft.amount.mul(_nft.price).div(10 ** decimals);
        pool.tvl = pool.tvl.sub(reductTvlAmount);
        pool.amount = pool.amount.sub(_nft.amount).add(leftAmount);
        pool.margin = pool.margin.sub(available);
        pool.joins = pool.joins.sub(1);
        _tvlTotal = _tvlTotal.sub(reductTvlAmount);
        _layerDataMap[_nft.poolId][_nft.layer].tvl -= reductTvlAmount;
        _layerDataMap[_nft.poolId][_nft.layer].amount = _layerDataMap[_nft.poolId][_nft.layer]
            .amount
            .sub(_nft.amount)
            .add(leftAmount);
        uint256 avgPrice = pool.amount > 0 ? pool.tvl.mul(10 ** decimals).div(pool.amount) : 0;
        uint256 profitPrice = pool.amount > 0 ? _getProfitPrice(pool.tvl, pool.amount, decimals, pool.profitRatio) : 0;
        emit PoolStream(_nft.poolId, pool.tvl, pool.amount, pool.amount.div(pool.unitSize), avgPrice, profitPrice);
    }

    function endPool(uint256 _poolId) external nonReentrant {
        Pool storage pool = _poolMap[_poolId];
        uint256 curPrice = _getPrice(pool.asset);
        uint8 decimals = IERC20Metadata(pool.asset).decimals();
        if (pool.endPrice > 0) revert E_PoolEnd();
        if (pool.joins <= 1) revert E_PoolEndOne();
        pool.terminator = _msgSender();
        uint256 profitPrice = _getProfitPrice(pool.tvl, pool.amount, decimals, pool.profitRatio);
        if (curPrice < profitPrice) revert E_PoolEndPrice();
        PoolProfit memory poolProfit = _getPoolProfitAmount(pool, decimals, profitPrice);
        uint256 creatorReward = poolProfit
            .rewardAmount
            .sub(poolProfit.rewardEcoFee)
            .mul(RATIO_PRECISION - pool.winnerRatio)
            .div(RATIO_PRECISION);
        _updateEndPool(
            _poolId,
            poolProfit.profitAmount,
            poolProfit.rewardAmount,
            poolProfit.rewardEcoFee,
            creatorReward,
            profitPrice
        );
    }

    function getWinnerOffset(uint256 _poolId) external view returns (uint256) {
        Pool memory pool = _poolMap[_poolId];
        uint256 winRange = _getWinnerRange(_poolId, pool.lastLayer, pool.maxRewardUnits);
        return _getWinnerOffset(_poolId, pool.lastLayer, pool.lastInputBlockNo, winRange);
    }

    function _getWinnerOffset(
        uint256 _poolId,
        uint32 _lastLayer,
        uint256 _lastInputBlockNo,
        uint256 _winRange
    ) internal view returns (uint256) {
        if (block.number - _lastInputBlockNo <= _protectBlock) {
            return _layerDataMap[_poolId][_lastLayer].amount.div(_poolMap[_poolId].unitSize);
        }
        return ((block.number - _lastInputBlockNo) / 30) % _winRange;
    }

    function _updateEndPool(
        uint256 _poolId,
        uint256 _profitAmount,
        uint256 _rewardAmount,
        uint256 _rewardecoFee,
        uint256 _creatorReward,
        uint256 _profitPrice
    ) internal {
        Pool storage pool = _poolMap[_poolId];
        if (_rewardecoFee > 0) {
            IERC20(pool.asset).safeTransfer(_eco, _rewardecoFee);
        }
        if (_creatorReward > 0) {
            address creatRewarder = _eco;
            if (IFRNFT(_FRNFT).isTokenOwner(pool.tokenId, pool.creator)) {
                creatRewarder = pool.creator;
            }
            uint256 fee = _creatorReward.mul(_feeRatio).div(RATIO_PRECISION);
            IERC20(pool.asset).safeTransfer(_team, fee);
            IERC20(pool.asset).safeTransfer(creatRewarder, _creatorReward.sub(fee));
        }
        uint256 winRange = _getWinnerRange(_poolId, pool.lastLayer, pool.maxRewardUnits);
        pool.endPrice = _profitPrice;
        pool.winnerOffset = _getWinnerOffset(_poolId, pool.lastLayer, pool.lastInputBlockNo, winRange);
        pool.margin = pool.margin.sub(_rewardecoFee + _creatorReward);
        emit EndPool(
            _poolId,
            pool.tvl,
            pool.amount,
            _profitPrice,
            _profitAmount,
            _rewardAmount,
            _rewardecoFee,
            _creatorReward,
            winRange,
            pool.winnerOffset
        );
    }

    function _getPoolProfitAmount(
        Pool memory _pool,
        uint8 _decimals,
        uint256 _profitPrice
    ) internal view returns (PoolProfit memory poolProfit) {
        uint256 profitMarketTvl = _pool.amount.mul(_profitPrice).div(10 ** _decimals);
        poolProfit.profitAmount = profitMarketTvl.sub(_pool.tvl).mul(10 ** _decimals).div(_profitPrice);
        poolProfit.rewardAmount = poolProfit.profitAmount.mul(_pool.rewardRatio).div(RATIO_PRECISION);
        poolProfit.rewardEcoFee = poolProfit.rewardAmount.mul(_ecoFeeRatio).div(RATIO_PRECISION);
    }

    function _countWithdrawAmount(
        IFRNFT.Traits memory _nft
    ) internal view returns (uint256 available, uint256 winAmount) {
        Pool memory pool = _poolMap[_nft.poolId];
        uint8 decimals = IERC20Metadata(pool.asset).decimals();
        PoolProfit memory poolProfit = _getPoolProfitAmount(pool, decimals, pool.endPrice);
        uint256 userAmount = _nft.amount.mul(_nft.price).div(pool.endPrice);
        uint256 shareProfitAmount = poolProfit
            .profitAmount
            .sub(poolProfit.rewardAmount)
            .mul(_nft.amount.mul(_nft.price).div(10 ** decimals))
            .div(pool.tvl);
        if (_nft.layer == pool.lastLayer) {
            WinnerResult memory winRes = _countWinner(
                _nft.poolId,
                pool,
                _nft.amount.div(pool.unitSize),
                _nft.layerRanking
            );
            if (winRes.isWinner) {
                // (rewardAmount - rewardEcoFee) * winnerRatio * rewardUnits/winnerRange
                winAmount = poolProfit
                    .rewardAmount
                    .sub(poolProfit.rewardEcoFee)
                    .mul(pool.winnerRatio)
                    .div(RATIO_PRECISION)
                    .mul(winRes.rewardUnits)
                    .div(winRes.winnerRange);
            }
        }
        available = userAmount.add(shareProfitAmount) - (_nft.amount - _nft.margin);
    }

    function _getWithdrawAmount(
        uint256 _joins,
        uint256 _price,
        uint256 _targetPrice,
        uint256 _margin,
        uint256 _amount
    ) internal pure returns (uint256 leftAmount, uint256 available) {
        if (_joins == 0 || _price >= _targetPrice) {
            return (0, _margin);
        }
        uint256 reduce = _amount.sub(_amount.mul(_price).div(_targetPrice));
        available = reduce > _margin ? 0 : _margin - reduce;
        leftAmount = _margin.sub(available);
    }

    function getTokenProfit(
        uint256 _tokenId
    ) external view returns (uint256 leftAmount, uint256 available, uint256 winnerReward, uint256 fee) {
        IFRNFT.Traits memory nft = IFRNFT(_FRNFT).getTraits(_tokenId);
        Pool memory pool = _poolMap[nft.poolId];
        uint256 assetPrice = _getPrice(pool.asset);
        (leftAmount, available, winnerReward, fee) = _getTokenProfit(nft, assetPrice);
    }

    function _getTokenProfit(
        IFRNFT.Traits memory _nft,
        uint256 assetPrice
    ) internal view returns (uint256 leftAmount, uint256 available, uint256 winnerReward, uint256 fee) {
        Pool memory pool = _poolMap[_nft.poolId];
        if (pool.endPrice > 0) {
            (available, winnerReward) = _countWithdrawAmount(_nft);
            leftAmount = 0;
        } else if (pool.joins == 1) {
            available = _nft.margin;
            leftAmount = 0;
        } else {
            LayerData memory lastlayer = _layerDataMap[_nft.poolId][pool.lastLayer];
            uint256 targetPrice;
            uint256 lastClosePrice = pool.lastOpenPrice.mul(RATIO_PRECISION.sub(pool.fallRatio)).div(RATIO_PRECISION);
            if (
                assetPrice <= lastClosePrice || (assetPrice <= pool.lastOpenPrice && lastlayer.cap > lastlayer.amount)
            ) {
                targetPrice = pool.tvl.mul(10 ** IERC20Metadata(pool.asset).decimals()).div(pool.amount);
            } else {
                targetPrice = _getProfitPrice(
                    pool.tvl,
                    pool.amount,
                    IERC20Metadata(pool.asset).decimals(),
                    pool.profitRatio
                );
            }
            (leftAmount, available) = _getWithdrawAmount(pool.joins, _nft.price, targetPrice, _nft.margin, _nft.amount);
        }
        // borrowing fee
        uint256 borrowFee = _nft.amount > _nft.margin
            ? _nft.amount.sub(_nft.margin).mul(_feeRatio).div(RATIO_PRECISION)
            : 0;
        // fee = borrowFee + withdrawFee
        fee = borrowFee + available.add(winnerReward).mul(_feeRatio).div(RATIO_PRECISION);
    }

    function gains(uint256[] memory _tokenIds) external nonReentrant {
        for (uint32 i = 0; i < _tokenIds.length; ++i) {
            _gain(_tokenIds[i]);
        }
    }

    function gain(uint256 _tokenId) external returns(uint256 amount) {
        return  _gain(_tokenId);
    }

    function _gain(uint256 _tokenId) internal returns(uint256 amount) {
        if (IFRNFT(_FRNFT).ownerOf(_tokenId) != _msgSender()) revert E_Owner();
        IFRNFT.Traits memory nft = IFRNFT(_FRNFT).getTraits(_tokenId);
        Pool storage pool = _poolMap[nft.poolId];
        if (pool.endPrice == 0) revert E_PoolNotEnd();
        uint256 assetPrice = _getPrice(pool.asset);
        (, uint256 available, uint256 winnerReward, uint256 fee) = _getTokenProfit(nft, assetPrice);
        available = available.add(winnerReward);
        if (pool.joins == 1) {
            available = pool.margin;
        }
        pool.joins = pool.joins.sub(1);
        pool.margin = pool.margin.sub(available);
        if (available > 0) {
            IERC20(pool.asset).safeTransfer(_team, fee);
            IERC20(pool.asset).safeTransfer(_msgSender(), available.sub(fee));
        }
        IFRNFT(_FRNFT).burnFrom(_msgSender(), _tokenId);
        emit Gain(_tokenId, nft.poolId, _msgSender(), available.sub(winnerReward), winnerReward, fee);
        return available.sub(fee);
    }

    function getWinnerRange(uint256 _poolId) external view returns (uint256) {
        return _getWinnerRange(_poolId, _poolMap[_poolId].lastLayer, _poolMap[_poolId].maxRewardUnits);
    }

    function _getWinnerRange(
        uint256 _poolId,
        uint32 _lastLayer,
        uint256 _maxRewardUnits
    ) internal view returns (uint256) {
        uint256 lastLayerUnits = _layerDataMap[_poolId][_lastLayer].amount.div(_poolMap[_poolId].unitSize);
        uint256 winnerRange = _layerDataMap[_poolId][_lastLayer].cap.div(_poolMap[_poolId].unitSize) / 2 >
            _maxRewardUnits
            ? _maxRewardUnits
            : _layerDataMap[_poolId][_lastLayer].cap.div(_poolMap[_poolId].unitSize) / 2;
        winnerRange = winnerRange > lastLayerUnits ? lastLayerUnits : winnerRange;
        return winnerRange;
    }

    function _getHitSpan(
        uint256 _header,
        uint256 _tail,
        uint256 _offset,
        uint256 _len
    ) internal pure returns (bool isWinner, uint256 winSpan) {
        uint256 end = _offset - _len;
        if (_offset >= _tail && _offset <= _header) {
            return (true, _offset - _tail > _len ? _len : _offset - _tail);
        }
        if (end >= _tail && end <= _header) {
            return (true, _header - end > _len ? _len : _header - end);
        }
        return (false, 0);
    }

    function _countWinner(
        uint256 _poolId,
        Pool memory _pool,
        uint256 _ownUnits,
        uint256 _fromUnitRanking
    ) internal view returns (WinnerResult memory winRes) {
        winRes.winnerRange = _getWinnerRange(_poolId, _pool.lastLayer, _pool.maxRewardUnits);
        uint256 d1s = 0; // train header
        uint256 d1e = 0;
        uint256 d2s = 0;
        uint256 d2e = 0;
        d1s = _pool.winnerOffset;
        d1e = _pool.winnerOffset >= winRes.winnerRange ? _pool.winnerOffset - winRes.winnerRange : 0;
        if (_pool.winnerOffset < winRes.winnerRange) {
            d2s = _layerDataMap[_poolId][_pool.lastLayer].amount.div(_pool.unitSize);
            d2e = d2s.sub(winRes.winnerRange.sub(d1s));
        }
        bool isWinner;
        uint256 addRewardUnits;
        (isWinner, addRewardUnits) = _getHitSpan(d1s, d1e, _fromUnitRanking, _ownUnits);
        winRes.isWinner = isWinner ? isWinner : winRes.isWinner;
        winRes.rewardUnits = winRes.rewardUnits + addRewardUnits;
        (isWinner, addRewardUnits) = _getHitSpan(d2s, d2e, _fromUnitRanking, _ownUnits);
        winRes.isWinner = isWinner ? isWinner : winRes.isWinner;
        winRes.rewardUnits = winRes.rewardUnits + addRewardUnits;
    }

    function getPool(uint256 _poolId) public view returns (Pool memory) {
        return _poolMap[_poolId];
    }

    function getLayerCount(uint256 _poolId) external view returns (uint256) {
        return _poolMap[_poolId].lastLayer + 1;
    }

    function getLayerData(uint256 _poolId, uint32 _layer) external view returns (LayerData memory) {
        return _layerDataMap[_poolId][_layer];
    }

    function getAssetConfigMap(address _asset) external view returns(Asset memory)  {
        return _assetConfigMap[_asset];
    }

    function getPrivateVar()
        public
        view
        returns (uint16, uint16, uint16, uint256, uint256, address, address, address, address)
    {
        return (_ecoFeeRatio, _feeRatio, _protectBlock, _lastPoolId, _tvlTotal, _fastPriceFeed, _FRNFT, _team, _eco);
    }
    // todo for test and remove
    function _testSetPool(uint256 _poolId, Pool memory pool) internal {
        _poolMap[_poolId] = pool;
    }
    // todo for test and remove
    function _testSetLayerData(uint256 _poolId, uint32 _layer, LayerData memory _layerData) internal {
        _layerDataMap[_poolId][_layer] = _layerData;
    }
}
