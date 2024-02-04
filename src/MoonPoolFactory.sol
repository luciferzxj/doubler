// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Context.sol';

import './MoonPool.sol';
import './interfaces/IMoonPool.sol';
import './interfaces/IMoonPoolFactory.sol';

contract Factory is Context, IMoonPoolFactory {
    using Strings for uint256;

    address[] private _moonPools;
    MoonPoolBaseConfig private _cfg;

    mapping(address => bool) public isSupported;

    function developer() external view returns (address) {
        return _cfg.dev;
    }

    function dbr() external view returns (address) {
        return _cfg.dbr;
    }

    function doubler() external view returns (address) {
        return _cfg.doubler;
    }

    function dbrFarm() external view returns (address) {
        return _cfg.dbrFarm;
    }

    function oneInchConfig() external view returns (address aggragator, address executor) {
        return (_cfg.oneInchAggregator, _cfg.oneInchExecutor);
    }

    function updateOneInchConfig(address _newOneInch, address _newExecutor) public {
        require(_msgSender() == _cfg.dev, 'only dev');
        _cfg.oneInchAggregator = _newOneInch;
        _cfg.oneInchExecutor = _newExecutor;
        emit UpdateOneInchConfig(_newOneInch, _newExecutor);
    }

    function moonPools() external view returns (address[] memory _pools) {
        _pools=_moonPools;
    }

    function allMoonPoolLength() external view returns (uint) {
        return _moonPools.length;
    }

    constructor(MoonPoolBaseConfig memory cfg, address dai, address usdc, address usdt) {
        _cfg = cfg;
        isSupported[dai] = true;
        isSupported[usdc] = true;
        isSupported[usdt] = true;
    }

    function createMoonPool(address _srcAsset,MoonPool.InputRule[] calldata _rules, uint256 _duration, uint256 _cap, uint256 _initAmount) external {
        require(isSupported[_srcAsset], '');
        _init(_srcAsset);
        {
            IMoonPool pool = IMoonPool(_moonPools[_moonPools.length-1]);
            IERC20(_srcAsset).transferFrom(msg.sender,address(this),_initAmount);
            IERC20(_srcAsset).approve(address(pool),_initAmount);
        }
        
        // {string memory lpName = string.concat('MP-', (_moonPools.length + 1).toString());
        
        // // string memory lpName = string.concat('MP-', (_moonPools.length + 1).toString());
        
        // MoonPool pool = new MoonPool(lpName, lpName, _cfg.signer,1000);
        // _moonPools.push(address(pool));
        // pool.initialize(
        //     _msgSender(),
        //     _cfg.dev,
        //     _cfg.dbr,
        //     _cfg.doubler,
        //     _cfg.dbrFarm,
        //     _cfg.nft,
        //     _cfg.oneInchAggregator,
        //     _cfg.oneInchExecutor,
        //     _srcAsset
        // );
        // }

        _start(
            _rules,
            _duration,
            _cap,
            _initAmount
        );
        
    }
    function _start(MoonPool.InputRule[] calldata _rules, uint256 _duration, uint256 _cap, uint256 _initAmount)internal{
        IMoonPool pool = IMoonPool(_moonPools[_moonPools.length-1]);
        
        pool.start(
            _rules,
            _duration,
            _cap,
            _initAmount
        );
    }

    function _init(address _srcAsset)internal{
        string memory lpName = string.concat('MP-', (_moonPools.length + 1).toString());
        // string memory lpName = string.concat('MP-', (_moonPools.length + 1).toString());
        MoonPool pool = new MoonPool(lpName, lpName, _cfg.signer,1000);
        _moonPools.push(address(pool));
        pool.initialize(
            _msgSender(),
            _cfg.dev,
            _cfg.dbr,
            _cfg.doubler,
            _cfg.dbrFarm,
            _cfg.nft,
            _cfg.oneInchAggregator,
            _cfg.oneInchExecutor,
            _srcAsset
        );
    }
}
