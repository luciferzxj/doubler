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

contract MoonPool is IMoonPool, ERC20, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using Strings for uint256;
    using Strings for uint32;

    uint256 private constant RATIO_PRECISION = 10000; // 100 * 100
    
    uint256 private constant FEE = 200;
    uint256 private constant SCAN = 1e18;
    uint256 private constant END_LIMIT = 30 days;
    uint256 private constant FALL_RADIO_MIN = 10;
    uint256 private constant FALL_RADIO_MAX = 2000;
    uint256 private constant KEEPER_REWARD_PRECENT = 100;
    uint256 private constant CREATOR_REWARD_MAX = 2000;
    uint256 private constant PRICE_PRECISION_MAX = 11000;
    uint256 private constant PRICE_PRECISION_MIN = 9500;

    uint256 private _creatorRewardRatio;
    address private _factory;
    PoolConfig private _poolCfg;
    Pool private _pool;
    // map(doublerId => map(asset => InputRule))
    mapping(address => InputRule) private _ruleMap;
    // map(doublerId => map(tokenId => Bill))
    mapping(uint256 => InputRecord) private _inputRecord;
    // map(hash => bool) ; hash = keccak256(abi.encodePacked(pooid + doublerId + doublerLayer)）
    mapping(bytes32 => bool) private _inputLayer;

    mapping(bytes32 => bool) private _usedSignature;

    mapping(address => uint256) private tokenBal;

    uint256 public tokenMuch;

    constructor( string memory _name,   string memory _symbol, 
        PoolConfig memory _initPoolCfg, InputRule[] memory _rules, 
        uint256 _duration, uint256 _cap,uint256 _initAmount, uint256 _rewardRatio) ERC20(_name, _symbol) {
        if (_duration > END_LIMIT) revert E_duration();
        if (_cap < _initAmount) revert E_cap();
        if (_rewardRatio > CREATOR_REWARD_MAX) revert E_rewardRatio();
        // init some
        _factory = _msgSender();
        _poolCfg = _initPoolCfg;
        _creatorRewardRatio = _rewardRatio;
        _pool.endTime   = block.timestamp + _duration;
        _pool.capMax    = _cap;
        // init rule
        InputRule memory ir;
        IDoubler doubler = IDoubler(_poolCfg.doubler);
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
    
    function poolConfig() external view returns (PoolConfig memory cfg) {
        return _poolCfg;
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
        if (_ir.fallRatioMin < FALL_RADIO_MIN || _ir.fallRatioMax > FALL_RADIO_MAX) revert E_fallRatio();
        if (_ir.profitRatioMin < 50 || _ir.profitRatioMax > RATIO_PRECISION) revert E_profitRatio();
        if (_ir.rewardRatioMax > RATIO_PRECISION) revert E_rewardRatioMax();
        if (_ir.winnerRatioMax > RATIO_PRECISION) revert E_winnerRatioMax();
        if (_ir.tvl == 0) revert E_tvl();
         // require(_ir.layerInputMax > 100, 'layerInputMax err');
    }

    function updateRule(InputRule calldata _ir) external nonReentrant {
        if (_poolCfg.creator == _msgSender()) revert E_creator();
        if (_ir.fallRatioMin < FALL_RADIO_MIN || _ir.fallRatioMax > FALL_RADIO_MAX) revert E_fallRatio();
        if (_ruleMap[_ir.asset].asset == address(0x0)) revert E_asset();
        // todo for update some ?
        InputRule storage ir = _ruleMap[_ir.asset];
        ir.fallRatioMin = _ir.fallRatioMin;
        ir.fallRatioMax = _ir.fallRatioMax;
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

    function _getLPValue() internal view returns (uint256) {
        uint256 lpTotal = totalSupply();
        if (lpTotal == 0) {
            return 10 ** decimals();
        }
        uint256 valueTotal = IERC20(_poolCfg.asset).balanceOf(address(this)) + _pool.pendingValue;
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
        uint256 valueTotal = IERC20(_poolCfg.asset).balanceOf(address(this)) + _pool.pendingValue;
        return (lpTotal * SCAN) / valueTotal;
    }

    function _buy(uint256 _amount, address _to) internal returns(uint256 _lpAmount)  {
        if (IERC20(_poolCfg.asset).balanceOf(address(this)) + _pool.pendingValue + _amount > _pool.capMax) revert E_cap();
        // lower 20% and reward 
        uint256 extra;
        if (IERC20(_poolCfg.asset).balanceOf(address(this)) < _pool.capMax / 5) {
            extra =(
                    _pool.capMax / 5 - IERC20(_poolCfg.asset).balanceOf(address(this)) > _amount
                        ? _amount
                        : _pool.capMax / 5 - IERC20(_poolCfg.asset).balanceOf(address(this))
                   ) * 2 /100;
        }
        uint256 uValue = _getUValue();
        IERC20(_poolCfg.asset).safeTransferFrom(_msgSender(), address(this), _amount);
        _lpAmount = (uValue * (_amount + extra)) / SCAN;
        _mint(_to, _lpAmount);
        emit Buy(_to, _lpAmount, _amount);
        return _lpAmount;
    }

    function sell(uint256 _lpAmount) external nonReentrant returns(uint256 uAmount){
        uint256 lpValue = _getLPValue();
        uint256 dbrValue = _getLPDbrValue();
        uint256 sendUAmount = (_lpAmount * lpValue) / SCAN;
        sendUAmount = sendUAmount > IERC20(_poolCfg.asset).balanceOf(address(this))
            ? IERC20(_poolCfg.asset).balanceOf(address(this))
            : sendUAmount;
        if (block.timestamp < _pool.endTime) {
            // sell limit 50% of cap
            if (IERC20(_poolCfg.asset).balanceOf(address(this)) - sendUAmount < _pool.pendingValue) revert E_sell_limit();
        }
        _burn(_msgSender(), _lpAmount);
        uint256 fee = (sendUAmount * FEE) / RATIO_PRECISION;
        IERC20(_poolCfg.asset).safeTransfer(_msgSender(), sendUAmount - fee);
        IERC20(_poolCfg.asset).safeTransfer(_poolCfg.eco, fee);
        uint256 dbrAmount = (_lpAmount * dbrValue) / SCAN;
        dbrAmount = dbrAmount > _pool.dbrAmount ? _pool.dbrAmount : dbrAmount;
        _pool.dbrAmount -= dbrAmount;
        IERC20(_poolCfg.dbr).safeTransfer(_msgSender(), dbrAmount);
        emit Sell(_msgSender(), _lpAmount, sendUAmount - fee, fee, dbrAmount);
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
        if (block.timestamp >  _pool.endTime) revert E_pool_end();
        IDoubler.Pool memory doubler = IDoubler(_poolCfg.doubler).getPool(_doublerId);
        if (!checkDoubler(doubler)) revert E_pool_check();
        uint256 decimal1 = 1*10**IERC20Metadata(_poolCfg.asset).decimals();
        uint256 decimal2 = 1*10**IERC20Metadata(doubler.asset).decimals();
        InputRule memory rule = _ruleMap[doubler.asset];
        uint256 price = IFastPriceFeed(_poolCfg.priceFeed).getPrice(doubler.asset);
        IDoubler.LayerData memory layer = IDoubler(_poolCfg.doubler).getLayerData(_doublerId, doubler.lastLayer);
        uint256 margin = layer.cap - layer.amount;
        uint256 marginUValue = margin * price*decimal1 / 1e18/decimal2;

        uint256 poolUBalace = IERC20(_poolCfg.asset).balanceOf(address(this));
        uint256 spendAmount = poolUBalace >  rule.layerInputMax ?  rule.layerInputMax: poolUBalace;
        // todo for some improve
        if (marginUValue > spendAmount) {
           uint256 units = (spendAmount / price * 1e18) % doubler.unitSize;
           margin = units * doubler.unitSize;
        }
        spendAmount = marginUValue*PRICE_PRECISION_MAX/RATIO_PRECISION;
        IERC20(_poolCfg.asset).approve(_poolCfg.swapRouter,spendAmount);
        spendAmount = ISwapRouter(_poolCfg.swapRouter).buy(_poolCfg.asset, margin, doubler.asset, spendAmount);
        IERC20(doubler.asset).approve(_poolCfg.doubler,margin);
        _input(spendAmount, margin, _doublerId);

        // todo send dbr??
        // uint256 sendDbrAmount = (_pool.dbrAmount * KEEPER_REWARD_PRECENT) / RATIO_PRECISION;
        // IERC20(_poolCfg.dbr).safeTransferFrom(address(this), _msgSender(), sendDbrAmount);
    }

    function _input(
        uint256 _spendAmount,
        uint256 _margin,
        uint256 _doublerId
    ) internal {
        IDoubler.AddInput memory addInput;
        addInput.poolId = _doublerId;
        addInput.margin = _margin;
        addInput.multiple = 1;
        addInput.amount = _margin;
        uint256 tokenId = IDoubler(_poolCfg.doubler).input(addInput);
        _pool.pendingValue += _spendAmount;
        _inputRecord[tokenId].spend = _spendAmount;
        IDBRFarm(_poolCfg.dbrFarm).join(tokenId);
    }

    function gain(uint256 _tokenId) external nonReentrant {
        
        IDoubler.Pool memory doubler = IDoubler(_poolCfg.doubler).getPool(
            IFRNFT(_poolCfg.frnft).getTraits(_tokenId).poolId
        );

        uint256 mintDbr = IDBRFarm(_poolCfg.dbrFarm).left(_tokenId);
        uint256 amount = IDoubler(_poolCfg.doubler).gain(_tokenId);
        uint256 decimal1 = 1*10**IERC20Metadata(_poolCfg.asset).decimals();
        uint256 decimal2 = 1*10**IERC20Metadata(doubler.asset).decimals();

        uint256 price = IFastPriceFeed(_poolCfg.priceFeed).getPrice(doubler.asset);
        uint256 returnAmount =  amount * price *PRICE_PRECISION_MIN*decimal1 / 1e18/RATIO_PRECISION/decimal2;
        IERC20(doubler.asset).approve(_poolCfg.swapRouter,amount);
        returnAmount = ISwapRouter(_poolCfg.swapRouter).sell(doubler.asset, amount, _poolCfg.asset, returnAmount);

        InputRecord storage record = _inputRecord[_tokenId];
        record.income = returnAmount;
        
        _pool.pendingValue -= record.spend;
        _pool.dbrAmount += mintDbr;
        _pool.output += record.spend;
        _pool.input += record.income;

        if (returnAmount > record.spend) {
            IERC20(_poolCfg.asset).transfer(
                _poolCfg.creator,
                ((returnAmount - record.spend) * _creatorRewardRatio) / RATIO_PRECISION
            );
        }
        emit Gain(_tokenId, record.spend, returnAmount, mintDbr);
    }
}
