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
// import 'hardhat/console.sol';

contract MoonPool is IMoonPool, ERC20, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using Strings for uint256;
    using Strings for uint32;

    uint256 private constant RATIO_PRECISION = 10000; // 100 * 100
    uint256 private constant FEE = 200;
    uint256 private constant SCAN = 1e18;
    uint256 private constant CREATOR_REWARD_MAX = 2000;
    
    address private _factory;
    // map(asset => InputRule)
    mapping(address => InputRule) private _ruleMap;
    // map(tokenId => Bill)
    mapping(uint256 => InputRecord) private _inputRecord;

    Pool private _pool;
    
    constructor( string memory _name,   string memory _symbol, 
        Pool memory _initPool, InputRule[] memory _rules, 
        uint256 _duration, uint256 _cap,uint256 _initAmount) ERC20(_name, _symbol) {
        if (_duration < 1 days) revert E_duration();
        if (_cap < _initAmount) revert E_cap();
        if (_initPool.creatorRewardRatio > CREATOR_REWARD_MAX) revert E_rewardRatio();
        // init some
        _factory = _msgSender();
        _pool = _initPool;
        // _creatorRewardRatio = _initCreatorRewardRatio;
        _pool.endTime   = block.timestamp + _duration;
        _pool.capMax    = _cap;
        // init rule
        InputRule memory ir;
        IDoubler doubler = IDoubler(_pool.doubler);
        for (uint32 i = 0; i < _rules.length; ++i) {
            ir = _rules[i];
            if (!doubler.getAssetConfigMap(ir.asset).isOpen) revert E_asset();
            ruleCheck(ir);
            _ruleMap[ir.asset] = ir;
            emit UpdateInputRule(
                ir.asset,
                ir.fallRatioMin,
                ir.fallRatioMax,
                ir.profitRatioMin,
                ir.profitRatioMax,
                ir.rewardRatioMin,
                ir.rewardRatioMin,
                ir.winnerRatioMin,
                ir.winnerRatioMax,
                ir.tvl,
                ir.layerInputMax
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

    function getFactory() external view returns (address) {
        return _factory;
    }

    function ruleCheck(InputRule memory _ir) internal pure {
        if (_ir.fallRatioMin > _ir.fallRatioMax || _ir.fallRatioMin < 50 || _ir.fallRatioMax >= 8000) revert E_fallRatio();
        if (_ir.profitRatioMin >  _ir.profitRatioMax || _ir.profitRatioMin < 50 || _ir.profitRatioMax > RATIO_PRECISION) revert E_profitRatio();
        if (_ir.rewardRatioMax > RATIO_PRECISION || _ir.rewardRatioMin > _ir.rewardRatioMax) revert E_rewardRatioMax();
        if (_ir.winnerRatioMax > RATIO_PRECISION || _ir.winnerRatioMin > _ir.winnerRatioMax) revert E_winnerRatioMax();
        if (_ir.tvl == 0) revert E_tvl();
        if (_ir.layerInputMax == 0) revert E_layerInput();
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
            ir.rewardRatioMin,
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

    function _getLPDbrValue() internal view returns (uint256) {
        uint256 lpTotal = totalSupply();
        return (_pool.dbrAmount * SCAN) / lpTotal;
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
         // lower  then reward 
        uint256 mpBalance = IERC20(_pool.asset).balanceOf(address(this));
        uint256 trigerReward = (IERC20(_pool.asset).balanceOf(address(this))  + _pool.pendingValue) * _pool.triggerRewardRatio /  RATIO_PRECISION;
        if (totalSupply() > 0 && mpBalance  < trigerReward ) {
            extra = (trigerReward - mpBalance > _amount ? _amount : trigerReward - mpBalance)* 2 /100;
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
        uint256 dbrValue = _getLPDbrValue();
        uint256 sendUAmount = (_lpAmount * lpValue) / SCAN;
        if (balanceOf(_msgSender()) < _lpAmount) revert E_balance();
        // if (allowance(_msgSender(), address(this)) < _lpAmount) revert E_Approve();
        uint256 mpBalance = IERC20(_pool.asset).balanceOf(address(this));
        if (sendUAmount > mpBalance) revert E_balance();
        if (block.timestamp < _pool.endTime) {
            if (mpBalance <  (mpBalance + _pool.pendingValue) * _pool.sellLimitCapRatio / RATIO_PRECISION)  revert E_sell_limit();
            if (mpBalance - (mpBalance + _pool.pendingValue) * _pool.sellLimitCapRatio / RATIO_PRECISION < sendUAmount) revert E_sell_limit();
            // if ((mpBalance - sendUAmount) * RATIO_PRECISION / (mpBalance + _pool.pendingValue - sendUAmount) < _pool.sellLimitCapRatio) revert E_sell_limit();
        }
        _burn(_msgSender(), _lpAmount);
        uint256 fee = (sendUAmount * FEE) / RATIO_PRECISION;
        IERC20(_pool.asset).safeTransfer(_msgSender(), sendUAmount - fee);
        IERC20(_pool.asset).safeTransfer(_pool.eco, fee);
        uint256 dbrAmount = (_lpAmount * dbrValue) / SCAN;
        dbrAmount = dbrAmount > _pool.dbrAmount ? _pool.dbrAmount : dbrAmount;
        _pool.dbrAmount -= dbrAmount;
        IERC20(_pool.dbr).safeTransfer(_msgSender(), dbrAmount);
        emit Sell(_msgSender(), _lpAmount, sendUAmount, fee, dbrAmount, IERC20(_pool.asset).balanceOf(address(this)), _pool.pendingValue, _getLPValue());
        return (sendUAmount - fee);
    }

    function checkDoubler(IDoubler.Pool memory doubler) internal view returns (bool) {
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
        if (!checkDoubler(doubler)) revert E_pool_check();
        InputRule memory rule = _ruleMap[doubler.asset];
        uint256 price = IFastPriceFeed(_pool.priceFeed).getPrice(doubler.asset);
        IDoubler.LayerData memory layer = IDoubler(_pool.doubler).getLayerData(_doublerId, doubler.lastLayer);
        uint256 margin = layer.cap - layer.amount;

        // new layer
        if (margin == 0) {
            uint256 lastClosePrice = doubler.lastOpenPrice * (RATIO_PRECISION-doubler.fallRatio) / (RATIO_PRECISION);
            if (price > lastClosePrice) revert E_layer_close();
            //use lastLayer cap
            if (doubler.kTotal >= 49) {
                 margin = layer.cap;
            } else {
                 uint256 k = (doubler.lastOpenPrice-price) * RATIO_PRECISION/ doubler.fallRatio /doubler.lastOpenPrice;
                 uint256 n = doubler.kTotal + k > 49 ? 49 - doubler.kTotal : k;
                 uint256 doubleV2 = doubler.double;
                 layer = IDoubler(_pool.doubler).getLayerData(_doublerId, doubler.lastLayer);
                 margin = layer.cap * (doubleV2 ** n);
            }
        }

        uint256 mpBalance = IERC20(_pool.asset).balanceOf(address(this));
        uint8  decimals = IERC20Metadata(_pool.asset).decimals();
        uint8  decimals2 = IERC20Metadata(doubler.asset).decimals();
        uint256 spendAmount = mpBalance >  rule.layerInputMax ?  rule.layerInputMax : mpBalance;
        uint256 units = (spendAmount * SCAN * 10 ** decimals2  * RATIO_PRECISION + _getSlippage() / (RATIO_PRECISION) / price / 10**decimals);  
        margin = margin > units ? units : margin;
        if (price * doubler.unitSize * (10 ** decimals)/SCAN/(10 ** decimals2) > rule.layerInputMax) revert E_input_max();
        spendAmount = margin * price * 10**decimals * (RATIO_PRECISION + _getSlippage()) / RATIO_PRECISION / SCAN /10**decimals2;
        IERC20(_pool.asset).approve(_pool.swapRouter, spendAmount);
        spendAmount = ISwapRouter(_pool.swapRouter).buy(_pool.asset, margin, doubler.asset, spendAmount);
        IERC20(doubler.asset).approve(_pool.doubler, margin);
        
        uint256 tokenId = _input(spendAmount, margin, _doublerId);
        emit CostBill(_doublerId, tokenId, 1, spendAmount, 0,  0, IERC20(_pool.asset).balanceOf(address(this)), _pool.pendingValue, _getLPValue());
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
        uint256 returnAmount =  amount * price * 10** decimals * (RATIO_PRECISION - _getSlippage()) /SCAN/ (10 ** decimals2) / RATIO_PRECISION;
        IERC20(doubler.asset).approve(_pool.swapRouter, amount);
        returnAmount = ISwapRouter(_pool.swapRouter).sell(doubler.asset, amount, _pool.asset, returnAmount);
        InputRecord storage record = _inputRecord[_tokenId];
        _pool.pendingValue -= record.spend;
        _pool.dbrAmount += mintDbr;
        _pool.output += record.spend;
        // profit part for creator reward
        if (returnAmount > record.spend) {
            uint256 creatorReward =  (returnAmount - record.spend) * _pool.creatorRewardRatio / RATIO_PRECISION;
            IERC20(_pool.asset).transfer(_pool.creator, creatorReward);
            returnAmount = returnAmount - creatorReward;
        }
        record.income = returnAmount;
        _pool.input += returnAmount;
        emit CostBill(doublerId, _tokenId, 2, record.spend, record.income, mintDbr, IERC20(_pool.asset).balanceOf(address(this)), _pool.pendingValue, _getLPValue());
    }

}
