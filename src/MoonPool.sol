// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interfaces/IFastPriceFeed.sol';
import './interfaces/IFRNFT.sol';
import './interfaces/IDoubler.sol';
import './interfaces/IMoonPool.sol';
import './interfaces/IDBRFarm.sol';
import './interfaces/ISwapRouter.sol';
import './interfaces/IWETH.sol';
import 'hardhat/console.sol';

contract MoonPool is IMoonPool, ERC20, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using Strings for uint256;
    using Strings for uint32;

    uint256 private constant RATIO_PRECISION = 10000; // 100 * 100
    uint256 private constant FEE = 200;
    uint256 private constant SCAN = 1e18;
    
    // map(asset => InputRule)
    mapping(address => InputRule) private _ruleMap;
    // map(tokenId => Bill)
    mapping(uint256 => InputRecord) private _inputRecord;
    // map(doubleId => map(layerId => bool))
    mapping(uint256 => mapping(uint256 => bool) ) private _inputLayer;

    Pool private _pool;
    
    constructor( string memory _name,   string memory _symbol, 
        Pool memory _initPool, InputRule[] memory _rules) ERC20(_name, _symbol) {
        // init some
        _pool = _initPool;
        // init rule
        for (uint32 i = 0; i < _rules.length; ++i) {
            _ruleMap[_rules[i].asset] = _rules[i];
            emit UpdateInputRule(
                _rules[i].asset,
                _rules[i].fallRatioMin,
                _rules[i].fallRatioMax,
                _rules[i].profitRatioMin,
                _rules[i].profitRatioMax,
                _rules[i].rewardRatioMin,
                _rules[i].rewardRatioMax,
                _rules[i].winnerRatioMin,
                _rules[i].winnerRatioMax,
                _rules[i].tvl,
                _rules[i].layerInputMax
            );
        }
    }

    function ruleMap(address _asset) external view returns (InputRule memory rule) {
        return _ruleMap[_asset];
    }

    function poolInfo() external view returns (Pool memory pool) {
        return _pool;
    }

    function inputRecord(uint256 _tokenId) external view returns (InputRecord memory record) {
        return _inputRecord[_tokenId];
    }

    function inputLayer(uint256 _doubleId, uint256 _layerId) external view returns (bool) {
         return _inputLayer[_doubleId][_layerId];
    }

    function updateRule(InputRule calldata _ir) external nonReentrant {
        if (_pool.creator != _msgSender()) revert E_creator();
        if (_ruleMap[_ir.asset].asset == address(0x0)) revert E_asset();
        InputRule storage ir = _ruleMap[_ir.asset];
        ir.tvl = _ir.tvl;
        ir.layerInputMax = _ir.layerInputMax;
        emit UpdateInputRule(
            ir.asset,
            ir.fallRatioMin,
            ir.fallRatioMax,
            ir.profitRatioMin,
            ir.profitRatioMax,
            ir.rewardRatioMin,
            ir.rewardRatioMax,
            ir.winnerRatioMin,
            ir.winnerRatioMax,
            ir.tvl,
            ir.layerInputMax
        );
    }

    function buy(uint256 _amount, address _to) external nonReentrant {
        if (block.timestamp > _pool.endTime) revert E_poolend();
        _buy(_amount, _to);
    }

    function getLPValue () external view returns (uint256) {
        return _getLPValue();
    }

    function _getLPValue() internal view returns (uint256) {
        uint256 lpTotal = totalSupply();
        if (lpTotal == 0) {
            return 10 ** decimals();
        }
        uint256 valueTotal = IERC20(_pool.asset).balanceOf(address(this)) + _pool.pendingValue;
        return (valueTotal * SCAN) / lpTotal;
    }

    function _getDbrAmount() internal view   returns (uint256) {
        return IERC20(_pool.dbr).balanceOf(address(this));
    }

    function _getLPDbrValue() internal view returns (uint256) {
        return _pool.triggerDbrShare > 0 ? (_getDbrAmount() * SCAN) / _pool.triggerDbrShare : 0 ;
    }

    function _getUValue() internal view returns (uint256) {
        uint256 lpTotal = totalSupply();
        if (lpTotal == 0) {
            return 10 ** decimals();
        }
        uint256 valueTotal = IERC20(_pool.asset).balanceOf(address(this)) + _pool.pendingValue;
        return (lpTotal * SCAN) / valueTotal;
    }

    function _buy(uint256 _amount, address _to) internal returns(uint256 _lpAmount)  {
        if (IERC20(_pool.asset).balanceOf(address(this)) + _pool.pendingValue + _amount > _pool.capMax) revert E_cap();
        uint256 extra;
        uint256 mpBalance = IERC20(_pool.asset).balanceOf(address(this));
        uint256 trigerReward = _pool.pendingValue * _pool.triggerRewardRatio /  RATIO_PRECISION;
        if (totalSupply() > 0 && mpBalance  < trigerReward ) {
            extra = (trigerReward - mpBalance > _amount ? _amount : trigerReward - mpBalance) * 2 /100;
        }
        uint256 uValue = _getUValue();
        _lpAmount = (uValue * (_amount + extra)) / SCAN;
        IERC20(_pool.asset).safeTransferFrom(_msgSender(), address(this), _amount);
        _mint(_to, _lpAmount);
        emit Buy(_to, _lpAmount, _amount, IERC20(_pool.asset).balanceOf(address(this)), _pool.pendingValue, _getLPValue());
        return _lpAmount;
    }

    function sell(uint256 _lpAmount) external nonReentrant returns(uint256 uAmount){
        uint256 lpValue = _getLPValue();
        if (balanceOf(_msgSender()) < _lpAmount) revert E_balance();
        uint256 sendUAmount = (_lpAmount * lpValue) / SCAN;
        uint256 mpBalance = IERC20(_pool.asset).balanceOf(address(this));
        if (sendUAmount > mpBalance) revert E_balance();
        if (block.timestamp < _pool.endTime && _pool.pendingValue > 0) {
            if (mpBalance <  _pool.pendingValue * _pool.sellLimitCapRatio / RATIO_PRECISION)  revert E_sell_limit();
            if (mpBalance -  _pool.pendingValue * _pool.sellLimitCapRatio / RATIO_PRECISION < sendUAmount) revert E_sell_limit();
        }
        // dbr rewards 20% of users and is the last to sell
        uint256 dbrAmount;
        if (_pool.triggerDbrShare == 0 && block.timestamp >= _pool.endTime) {
            _pool.triggerDbrShare = totalSupply() / 5;  
        }
        if ( _pool.triggerDbrShare > 0 && (totalSupply() - _lpAmount) <  _pool.triggerDbrShare) {
            uint256 dbrValue = _getLPDbrValue();
            uint256 shareLpAmount = totalSupply() > _pool.triggerDbrShare ? _lpAmount - (totalSupply()-_pool.triggerDbrShare): _lpAmount;
            dbrAmount = shareLpAmount * dbrValue / SCAN;
            dbrAmount = dbrAmount > _getDbrAmount() ? _getDbrAmount() : dbrAmount;
            if (dbrAmount>0) {
                IERC20(_pool.dbr).safeTransfer(_msgSender(), dbrAmount);
            }
        }
        _burn(_msgSender(), _lpAmount);
        uint256 fee = (sendUAmount * FEE) / RATIO_PRECISION;
        IERC20(_pool.asset).safeTransfer(_msgSender(), sendUAmount - fee);
        IERC20(_pool.asset).safeTransfer(_pool.eco, fee);
        
        emit Sell(_msgSender(), _lpAmount, sendUAmount, fee, dbrAmount, IERC20(_pool.asset).balanceOf(address(this)), _pool.pendingValue, _getLPValue());
        return (sendUAmount - fee);
    }

    function _checkDoubler(IDoubler.Pool memory doubler) internal view returns (bool) {
        InputRule memory rule = _ruleMap[doubler.asset];
        if (doubler.fallRatio < rule.fallRatioMin || doubler.fallRatio > rule.fallRatioMax) {
            return false;
        }
        if (doubler.rewardRatio < rule.rewardRatioMin || doubler.rewardRatio > rule.rewardRatioMax) {
            return false;
        }
        if (doubler.winnerRatio < rule.winnerRatioMin || doubler.winnerRatio > rule.winnerRatioMax) {
            return false;
        }
        if (doubler.profitRatio < rule.profitRatioMin || doubler.profitRatio > rule.profitRatioMax) {
            return false;
        }
        if (doubler.tvl < rule.tvl) {
            return false;
        }
        return true;
    }

    function input(uint256 _doublerId) external nonReentrant {
        IDoubler.Pool memory doubler = IDoubler(_pool.doubler).getPool(_doublerId);
        if (block.timestamp >  _pool.endTime || doubler.endPrice > 0) revert E_pool_end();
        if (!_checkDoubler(doubler)) revert E_pool_check();
        InputRule memory rule = _ruleMap[doubler.asset];
        uint256 price = IFastPriceFeed(_pool.priceFeed).getPrice(doubler.asset);
        IDoubler.LayerData memory layer = IDoubler(_pool.doubler).getLayerData(_doublerId, doubler.lastLayer);
        uint256 margin = layer.cap - layer.amount;
        uint256 lastClosePrice = doubler.lastOpenPrice * (RATIO_PRECISION-doubler.fallRatio) / RATIO_PRECISION;
        if (!(price <= lastClosePrice || (price <= doubler.lastOpenPrice && layer.cap > layer.amount))) revert E_layer_close();
        uint256 lastLayer = doubler.lastLayer;
        if (margin == 0) { // if new layer
            if (doubler.kTotal >= 49) {
                 margin = layer.cap;
            } else {
                 uint256 k = (doubler.lastOpenPrice-price) * RATIO_PRECISION/ doubler.fallRatio /doubler.lastOpenPrice;
                 uint256 n = doubler.kTotal + k > 49 ? 49 - doubler.kTotal : k;
                 uint256 doubleV2 = doubler.double;
                 margin = layer.cap * (doubleV2 ** n);
            }
            lastLayer = lastLayer + 1;
        }
        if (_inputLayer[_doublerId][lastLayer]) revert E_input_layer();
        _inputLayer[_doublerId][lastLayer] = true;
        uint256 mpBalance = IERC20(_pool.asset).balanceOf(address(this));
        uint8  decimals = IERC20Metadata(_pool.asset).decimals();
        if (price * doubler.unitSize / (10 ** decimals) > rule.layerInputMax) revert E_input_max();
        uint256 spendAmount = mpBalance >  rule.layerInputMax ?  rule.layerInputMax : mpBalance;
        uint256 units = (spendAmount * (10 ** decimals) * RATIO_PRECISION / (RATIO_PRECISION + _getSlippage()) / price) / doubler.unitSize;  
        margin = margin > doubler.unitSize * units ? doubler.unitSize * units : margin;
        if (units == 0 || margin < doubler.unitSize ||  margin % doubler.unitSize != 0) revert E_input_mergin();
        // (margin / (10 ** decimals2))  * (price / SCAN * (10 ** decimals) * (RATIO_PRECISION + _getSlippage()) / RATIO_PRECISION
        spendAmount = margin * price * (10 ** decimals) * (RATIO_PRECISION + _getSlippage()) / SCAN / RATIO_PRECISION / (10 ** IERC20Metadata(doubler.asset).decimals());
        IERC20(_pool.asset).approve(_pool.swapRouter, spendAmount);
        spendAmount = ISwapRouter(_pool.swapRouter).swapCustomIn(_pool.asset, spendAmount, doubler.asset, margin);
        if (IERC20(doubler.asset).balanceOf(address(this)) < margin) revert E_input_balance();
        IERC20(doubler.asset).approve(_pool.doubler, margin);
        uint256 tokenId = _input(spendAmount, margin, _doublerId);
        emit CostBill(_doublerId, tokenId, 1, spendAmount, 0,  0, IERC20(_pool.asset).balanceOf(address(this)), _pool.pendingValue, _getLPValue(), 0);
    }

    function _input(
        uint256 _spendAmount,
        uint256 _margin,
        uint256 _doublerId
    ) internal returns (uint256 tokenId){
        IDoubler.AddInput memory addInput;
        addInput.poolId = _doublerId;
        addInput.margin = _margin;
        addInput.multiple = 1;
        addInput.amount = _margin;
        tokenId = IDoubler(_pool.doubler).input(addInput);
        _pool.pendingValue += _spendAmount;
        _inputRecord[tokenId].spend = _spendAmount;
        IDBRFarm(_pool.dbrFarm).join(tokenId);
    }

    function _getSlippage() internal view returns(uint256) {
        return ISwapRouter(_pool.swapRouter).getSlippage();
    }

    function output(uint256 _tokenId) external nonReentrant {
        uint256 doublerId = IFRNFT(_pool.frnft).getTraits(_tokenId).poolId;
        IDoubler.Pool memory doubler = IDoubler(_pool.doubler).getPool(doublerId);
        if (doubler.endPrice == 0) revert E_pool_end();
        uint256 mintDbr = IDBRFarm(_pool.dbrFarm).left(_tokenId);
        IFRNFT(_pool.frnft).approve(_pool.doubler, _tokenId);
        uint256 amount = IDoubler(_pool.doubler).gain(_tokenId);
        uint256 price = IFastPriceFeed(_pool.priceFeed).getPrice(doubler.asset);
        uint8  decimals = IERC20Metadata(_pool.asset).decimals();
        uint8  decimals2 = IERC20Metadata(doubler.asset).decimals();
        // (amount /(10 ** decimals2))  * price / SCAN * (10 ** decimals) * (1-Slippage) / RATIO_PRECISION
        uint256 returnAmount =  amount * price * (10 ** decimals) * (RATIO_PRECISION - _getSlippage()) /SCAN/ (10 ** decimals2) / RATIO_PRECISION;
        IERC20(doubler.asset).approve(_pool.swapRouter, amount);
        returnAmount = ISwapRouter(_pool.swapRouter).swapCustomOut(doubler.asset, amount, _pool.asset, returnAmount);
        InputRecord storage record = _inputRecord[_tokenId];
        _pool.pendingValue -= record.spend;
        _pool.output += record.spend;
        // profit part for creator reward
        uint256 creatorReward;
        if (returnAmount > record.spend) {
            creatorReward =  (returnAmount - record.spend) * _pool.creatorRewardRatio / RATIO_PRECISION;
            IERC20(_pool.asset).transfer(_pool.creator, creatorReward);
            returnAmount = returnAmount - creatorReward;
        }
        record.income = returnAmount;
        record.fee = creatorReward;
        _pool.input += returnAmount;
        emit CostBill(doublerId, _tokenId, 2, record.spend, record.income, mintDbr, IERC20(_pool.asset).balanceOf(address(this)), _pool.pendingValue, _getLPValue(), creatorReward);
    }

    // for test
    function testAddPendingValue(address _to, uint256 _lpAmount) external {
         _pool.pendingValue += _lpAmount;
         _mint(_to, _lpAmount);
    }
    // for test
    function testupdateEndTime(uint256 _newEndTime) external {
         _pool.endTime = _newEndTime;
    }
    
}
