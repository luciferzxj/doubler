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
import './interfaces/IMoonPoolFactory.sol';

contract MoonPoolFactory is IMoonPoolFactory, AccessControlEnumerable, ReentrancyGuard {

     using SafeERC20 for IERC20;
    using Strings for uint256;

    address[] private _moonPools;
    BaseConfig private _cfg;
    mapping(address => bool) private _isSupported;

    function baseConfig() external view returns (BaseConfig memory ) {
            return _cfg;
    }

    function moonPools() external view returns (address[] memory _pools) {
        _pools = _moonPools;
    }

    function moonPool(uint128 _pooId) external view returns (address) {
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
        address _srcAsset,
        IMoonPool.InputRule[] calldata _rules,
        uint256 _duration,
        uint256 _cap,
        uint256 _initAmount,
        uint256 _rewardRatio
    ) external nonReentrant {
        if (!_isSupported[_srcAsset]) revert E_asset();
        uint8 decimals = IERC20Metadata(_srcAsset).decimals();
        if (_initAmount < 100000 * (10 ** decimals)) revert E_initAmount();
        // create pool
        string memory lpName = string.concat('MP-', (_moonPools.length + 1).toString());
        IMoonPool.PoolConfig memory pcfg;
        pcfg.creator = _msgSender();
        pcfg.eco = _cfg.eco;
        pcfg.dbr = _cfg.dbr;
        pcfg.doubler = _cfg.doubler;
        pcfg.dbrFarm = _cfg.dbrFarm;
        pcfg.frnft = _cfg.frnft;
        pcfg.swapRouter = _cfg.swapRouter;
        pcfg.asset = _srcAsset;
        pcfg.priceFeed = _cfg.priceFeed;
        MoonPool pool = new MoonPool(lpName, lpName, pcfg, _rules, _duration, _cap, _initAmount, _rewardRatio);
        _moonPools.push(address(pool));
        emit CreateMoonPool(_moonPools.length, address(pool), _srcAsset, _duration, _cap, _initAmount, _rewardRatio);
        // buy lp
        IERC20(_srcAsset).safeTransferFrom(_msgSender(), address(this), _initAmount);
        IERC20(_srcAsset).approve(address(pool), _initAmount);
        pool.buy(_initAmount, pcfg.creator);
    }
}
