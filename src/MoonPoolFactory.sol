// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Context.sol';

import './MoonPool.sol';
import './interfaces/IMoonPool.sol';
import './interfaces/IDBRFarm.sol';
import './interfaces/IMoonPoolFactory.sol';

contract MoonPoolFactory is IMoonPoolFactory,  ReentrancyGuard {

     using SafeERC20 for IERC20;
    using Strings for uint256;

    address[] private _moonPools;
    BaseConfig private _cfg;
    mapping(address => bool) private _isSupported;

    function baseConfig() external view returns (BaseConfig memory ) {
            return _cfg;
    }

    function moonPoolTotal() external view returns (uint256) {
        return _moonPools.length;
    }

    function getMoonPoolAddress(uint128 _pooId) external view returns (address) {
        return _moonPools[_pooId - 1];
    }

    function supported(address _asset) external view returns (bool) {
        return _isSupported[_asset];
    }

    constructor(BaseConfig memory _initCfg, address[] memory _initAssets) {
        _cfg = _initCfg;
        for (uint i=0; i < _initAssets.length; i++) {
            _isSupported[_initAssets[i]] = true;
            emit UpdateAsset(_initAssets[i], true);
        }
    }

    function createMoonPool(
        AddMoonPool calldata _addPool,
        IMoonPool.InputRule[] calldata _rules
    ) external nonReentrant {
        if (!_isSupported[_addPool.srcAsset]) revert E_asset();
        uint8 decimals = IERC20Metadata(_addPool.srcAsset).decimals();
        if (_addPool.initAmount < 100000 * (10 ** decimals)) revert E_initAmount();
        // _sellLimitCapRatio 20%-50%
        if (_addPool.sellLimitCapRatio < 2000 || _addPool.sellLimitCapRatio > 5000) revert E_sellLimit();
         // triggerRewardRatio: 0-20%
        if (_addPool.triggerRewardRatio > 2000) revert E_triggerReward();
        // create pool
        string memory lpName = string.concat('MP-', (_moonPools.length + 1).toString());
        IMoonPool.Pool memory pcfg;
        pcfg.creator = msg.sender;
        pcfg.eco = _cfg.eco;
        pcfg.dbr = _cfg.dbr;
        pcfg.doubler = _cfg.doubler;
        pcfg.dbrFarm = _cfg.dbrFarm;
        pcfg.frnft = _cfg.frnft;
        pcfg.priceFeed = _cfg.priceFeed;
        pcfg.swapRouter = _cfg.swapRouter;
        pcfg.asset = _addPool.srcAsset;
        pcfg.creatorRewardRatio = _addPool.creatorRewardRatio;
        pcfg.triggerRewardRatio = _addPool.triggerRewardRatio;
        pcfg.sellLimitCapRatio = _addPool.sellLimitCapRatio;
        {   
            // create
            MoonPool pool = new MoonPool(lpName, lpName, pcfg, _rules, _addPool.duration, _addPool.cap, _addPool.initAmount);
            _moonPools.push(address(pool));
            // for test.
            IDBRFarm(_cfg.dbrFarm).addMoonPoolRole(address(pool));
            emit CreateMoonPool(_moonPools.length, address(pool), _addPool.srcAsset, _addPool.duration, _addPool.cap, _addPool.initAmount, _addPool.creatorRewardRatio);

            // buy lp
            IERC20(_addPool.srcAsset).safeTransferFrom(msg.sender, address(this), _addPool.initAmount);
            IERC20(_addPool.srcAsset).approve(address(pool), _addPool.initAmount);
            pool.buy(_addPool.initAmount, pcfg.creator);
        }
        
    }
}
