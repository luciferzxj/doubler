// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IFastPriceFeed.sol";
import "./interfaces/IFRNFT.sol";
import "./interfaces/IDoubler.sol";
import "./interfaces/IMoonPool.sol";
import "./interfaces/IDBRFarm.sol";
import "./interfaces/IUniswapV3SwapRouter.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/ISwapAggregator.sol";
contract MoonPool is
    IMoonPool,
    ERC20,
    AccessControlEnumerable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;
    using Strings for uint256;
    using Strings for uint32;

    uint256 private constant RATIO_PRECISION = 10000; // 100 * 100
    uint256 private constant KEEPER_REWARD_PRECENT = 100;
    uint256 private constant CREATOR_REWARD_MAX = 2000;
    uint256 private constant FEE = 200;
    uint256 private constant SCAN = 1e18;

    uint256 private creatorRewardRatio;

    uint256 private constant END_LIMIT = 30 days;

    uint256 private constant FALL_RADIO_MIN = 100;
    uint256 private constant FALL_RADIO_MAX = 200;

    address private factory;
    PoolConfig private _poolCfg;

    address[] public tokens;

    Pool private _pool;
    // map(doublerId => map(asset => InputRule))
    mapping(address => InputRule) private _ruleMap;
    // map(doublerId => map(tokenId => Bill))
    mapping(uint256 => InputRecord) private _inputRecord;
    // map(hash => bool) ; hash = keccak256(abi.encodePacked(pooid + doublerId + doublerLayer)）
    mapping(bytes32 => bool) private _inputLayer;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        factory = _msgSender();
    }
    function poolConfig() external view returns (PoolConfig memory cfg) {
        return _poolCfg;
    }

    function ruleMap(
        address asset
    ) external view returns (InputRule memory rule) {
        return _ruleMap[asset];
    }

    function poolInfo() external view returns (Pool memory pool) {
        return _pool;
    }

    function inputRecord(
        uint256 tokenId
    ) external view returns (InputRecord memory record) {
        return _inputRecord[tokenId];
    }

    function initialize(
        address _creator,
        address _dev,
        address dbrContract,
        address _doublerContract,
        address _dbrFarmContract,
        address _nft,
        address _router,
        address _srcAsset,
        address _pricefeed
    ) external {
        require(_msgSender() == factory, "can only init once");
        _poolCfg.creator = _creator;
        _poolCfg.developer = _dev;
        _poolCfg.asset = _srcAsset;
        _poolCfg.doubler = _doublerContract;
        _poolCfg.dbr = dbrContract;
        _poolCfg.dbrFarm = _dbrFarmContract;
        _poolCfg.FRNFT = _nft;
        _poolCfg.aggregator = _router;
        _poolCfg.pricefeed = _pricefeed;
    }

    function getFactory() external view returns (address) {
        return factory;
    }

    function start(
        InputRule[] calldata _rules,
        uint256 _duration,
        uint256 _cap,
        uint256 _initAmount,
        uint256 _rewardRatio
    ) external {
        require(!_pool.started && _msgSender() == factory, "pool is runing");
        require(
            _initAmount >=
                100000 * (10 ** IERC20Metadata(_poolCfg.asset).decimals()),
            "amount min err"
        );
        require(_duration >= END_LIMIT, "endTime err");
        require(_cap >= _initAmount, "cap err");
        require(_rewardRatio <= CREATOR_REWARD_MAX, "ratio too much");
        creatorRewardRatio = _rewardRatio;
        InputRule memory ir;
        IDoubler doubler = IDoubler(_poolCfg.doubler);
        require(_rules.length <= 3, "inputRules err");
        for (uint32 i = 0; i < _rules.length; ++i) {
            ir = _rules[i];
            ruleCheck(ir);
            require(
                doubler.getAssetConfigMap(ir.asset).isOpen == true,
                "asset status err"
            );
            require(
                _ruleMap[ir.asset].asset == address(0x0),
                "asset exits err"
            );
            _ruleMap[ir.asset] = ir;
            tokens.push(ir.asset);
        }
        // string memory srcAssetSym = IERC20Metadata(_poolCfg.asset).symbol();
        // string memory lpName = string.concat("MP-", srcAssetSym);
        _pool.endTime = block.timestamp + _duration;
        _pool.capMax = _cap;
        _pool.started = true;
        _deposite(_initAmount, _poolCfg.creator);
        emit NewPool(_msgSender(), address(this));
    }

    function ruleCheck(InputRule memory _ir) internal pure {
        require(
            _ir.fallRatioMin >= FALL_RADIO_MIN &&
                _ir.fallRatioMax <= FALL_RADIO_MAX,
            "fallRatio err"
        );
        require(
            _ir.profitRatioMin >= 50 && _ir.profitRatioMax <= RATIO_PRECISION,
            "profitRatio err"
        );
        require(_ir.rewardRatioMax <= RATIO_PRECISION, "rewardRatioMax err");
        require(_ir.winnerRatioMax <= RATIO_PRECISION, "winnerRatioMax err");
        require(_ir.tvl > 0, "tvl err");
        require(_ir.layerInputMax > 100, "layerInputMax err");
    }

    function updateRule(InputRule calldata _ir) external {
        require(_poolCfg.creator == _msgSender(), "creator err");
        require(
            _ir.fallRatioMin >= FALL_RADIO_MIN &&
                _ir.fallRatioMax <= FALL_RADIO_MAX,
            "fallRatio err"
        );
        ruleCheck(_ir);
        InputRule storage irs = _ruleMap[_ir.asset];
        irs.fallRatioMin = _ir.fallRatioMin;
        irs.fallRatioMax = _ir.fallRatioMax;
        emit UpdateInputRule(
            _ir.asset,
            _ir.fallRatioMin,
            _ir.fallRatioMax,
            _ir.profitRatioMin,
            _ir.profitRatioMax,
            _ir.rewardRatioMin,
            _ir.rewardRatioMin,
            _ir.winnerRatioMin,
            _ir.winnerRatioMax,
            _ir.tvl,
            _ir.layerInputMax
        );
    }

    function deposite(uint256 _amount) external {
        require(block.timestamp <= _pool.endTime, "_pool was ended");
        _deposite(_amount, _msgSender());
    }

    function _getLPValue() internal view returns (uint256) {
        uint256 lpTotal = totalSupply();
        if (lpTotal == 0) {
            return 10 ** decimals();
        }
        uint256 valueTotal = IERC20(_poolCfg.asset).balanceOf(address(this)) +
            _pool.pendingValue;
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
        uint256 valueTotal = IERC20(_poolCfg.asset).balanceOf(address(this)) +
            _pool.pendingValue;
        return (lpTotal * SCAN) / valueTotal;
    }

    function _deposite(uint256 _amount, address to) internal {
        require(
            IERC20(_poolCfg.asset).balanceOf(address(this)) +
                _pool.pendingValue +
                _amount <
                _pool.capMax,
            "capMax error"
        );
        _pool.inValue += _amount;
        uint256 uValue = _getUValue();
        uint256 extra;
        if (
            IERC20(_poolCfg.asset).balanceOf(address(this)) < _pool.capMax / 5
        ) {
            extra =
                ((
                    _pool.capMax /
                        5 -
                        IERC20(_poolCfg.asset).balanceOf(address(this)) >
                        _amount
                        ? _amount
                        : _pool.capMax /
                            5 -
                            IERC20(_poolCfg.asset).balanceOf(address(this))
                ) * 2) /
                100;
        }
        IERC20(_poolCfg.asset).safeTransferFrom(
            _msgSender(),
            address(this),
            _amount
        );

        _mint(to, (uValue * (_amount + extra)) / SCAN);
        emit Deposite(to, _amount, (uValue * (_amount + extra)) / SCAN);
    }

    function withdraw(uint256 _lpAmount) external {
        uint256 lpValue = _getLPValue();
        uint256 dbrValue = _getLPDbrValue();
        uint256 sendUAmount = (_lpAmount * lpValue) / SCAN;
        sendUAmount = sendUAmount >
            IERC20(_poolCfg.asset).balanceOf(address(this))
            ? IERC20(_poolCfg.asset).balanceOf(address(this))
            : sendUAmount;
        if (block.timestamp < _pool.endTime) {
            require(
                IERC20(_poolCfg.asset).balanceOf(address(this)) - sendUAmount >=
                    _pool.pendingValue,
                "sell lp limit error"
            );
        }
        _burn(_msgSender(), _lpAmount);
        _pool.outValue += sendUAmount;
        uint256 fee = (sendUAmount * FEE) / RATIO_PRECISION;
        IERC20(_poolCfg.asset).approve(address(this), sendUAmount);
        IERC20(_poolCfg.asset).safeTransferFrom(
            address(this),
            _msgSender(),
            sendUAmount - fee
        );
        IERC20(_poolCfg.asset).safeTransferFrom(
            address(this),
            _poolCfg.developer,
            fee
        );
        uint256 sendDbrAmount = (_lpAmount * dbrValue) / SCAN;
        sendDbrAmount = sendDbrAmount > _pool.dbrAmount
            ? _pool.dbrAmount
            : sendDbrAmount;
        _pool.dbrAmount -= sendDbrAmount;
        IERC20(_poolCfg.dbr).safeTransferFrom(
            address(this),
            _msgSender(),
            sendDbrAmount
        );
        emit Withdraw(_msgSender(), _lpAmount, sendUAmount, sendDbrAmount);
    }

    function checkDoubler(uint256 _doublerId) internal view returns (bool) {
        IDoubler.Pool memory doubler = IDoubler(_poolCfg.doubler).getPool(
            _doublerId
        );
        InputRule memory rule = _ruleMap[doubler.asset];
        if (
            doubler.fallRatio < rule.fallRatioMin ||
            doubler.fallRatio > rule.fallRatioMax
        ) {
            return false;
        }
        if (
            doubler.rewardRatio < rule.rewardRatioMin ||
            doubler.rewardRatio > rule.rewardRatioMax
        ) {
            return false;
        }
        if (
            doubler.winnerRatio < rule.winnerRatioMin ||
            doubler.winnerRatio > rule.winnerRatioMax
        ) {
            return false;
        }
        if (
            doubler.profitRatio < rule.profitRatioMin ||
            doubler.profitRatio > rule.profitRatioMax
        ) {
            return false;
        }
        if (doubler.tvl < rule.tvl) {
            return false;
        }
        return true;
    }

    function input(uint256 _doublerId, SignatureParams memory datas) external {
        IDoubler.Pool memory doubler = IDoubler(_poolCfg.doubler).getPool(
            _doublerId
        );
        // InputRule memory rule = _ruleMap[doubler.asset];
        // IDoubler.LayerData memory layer = IDoubler(_poolCfg.doubler).getLayerData(_doublerId, doubler.lastLayer);
        // // margin
        // uint256 margin = rule.layerInputMax > layer.cap - layer.tvl ? layer.cap - layer.tvl : rule.layerInputMax;
        // margin = margin * 90 / 100;
        // require(datas.amount <= rule.layerInputMax);
        require(block.timestamp <= _pool.endTime, "_pool was ended");
        require(checkDoubler(_doublerId), "rule err");
        bytes32 nhash = keccak256(
            abi.encodePacked(
                address(this),
                _doublerId.toString(),
                doubler.lastLayer.toString()
            )
        );
        require(_inputLayer[nhash] == false, "inputLayer had err");
        _inputLayer[nhash] = true;
        IERC20(_poolCfg.asset).approve(_poolCfg.aggregator, datas.maxAmountIn);
        uint256 spendAmount = ISwapAggregator(_poolCfg.aggregator).buy(
            _poolCfg.asset,
            doubler.asset,
            datas.amountOut,
            datas.maxAmountIn
        );
        {
            uint256 spenAmount = (spendAmount * 10 ** 18) /
                10 ** IERC20Metadata(_poolCfg.asset).decimals();
            uint256 feedPrice = IFastPriceFeed(_poolCfg.pricefeed).getPrice(
                doubler.asset
            );
            uint256 priceAmount = datas.amountOut * feedPrice;
            uint256 ratio = priceAmount > spenAmount
                ? priceAmount / (priceAmount - spenAmount)
                : priceAmount / (spenAmount - priceAmount);
            require(ratio >= 10, "price error");
        }
        IERC20(doubler.asset).approve(_poolCfg.doubler, datas.amountOut);
        _input(
            spendAmount,
            datas.amountOut,
            _doublerId,
            doubler,
            doubler.asset
        );
        // todo : transfer reward to keeper
        uint256 sendDbrAmount = (_pool.dbrAmount * KEEPER_REWARD_PRECENT) /
            RATIO_PRECISION;
        IERC20(_poolCfg.dbr).safeTransferFrom(
            address(this),
            _msgSender(),
            sendDbrAmount
        );
    }

    function _input(
        uint256 spendAmount,
        uint256 returnAmount,
        uint256 _doublerId,
        IDoubler.Pool memory doubler,
        address asset
    ) internal {
        IDoubler.AddInput memory addInput;
        addInput.poolId = _doublerId;
        addInput.layer = doubler.lastLayer;
        addInput.margin = returnAmount;
        addInput.multiple = 1;
        addInput.amount = returnAmount;
        uint256 tokenId = IDoubler(_poolCfg.doubler).input(addInput);
        _pool.pendingValue += spendAmount;
        _inputRecord[tokenId].spend = spendAmount;
        _inputRecord[tokenId].asset = asset;
        //deposite to dbr farm.
        IDBRFarm(_poolCfg.dbrFarm).join(tokenId);
        emit NewInput(
            _doublerId,
            doubler.lastLayer,
            tokenId,
            spendAmount,
            returnAmount
        );
    }

    function gain(uint256 _tokenId) external {
        IDoubler.Pool memory pool = IDoubler(_poolCfg.doubler).getPool(
            IFRNFT(_poolCfg.FRNFT).getTraits(_tokenId).poolId
        );
        InputRecord storage record = _inputRecord[_tokenId];
        require(record.spend > 0, "tokenId err");
        uint256 mintDbr = IDBRFarm(_poolCfg.dbrFarm).left(_tokenId);
        uint256 amount = IDoubler(_poolCfg.doubler).gain(_tokenId);
        _pool.pendingValue -= record.spend;
        _pool.dbrAmount += mintDbr;
        IERC20(pool.asset).approve(_poolCfg.aggregator, amount);
        uint256 feedPrice1 = IFastPriceFeed(_poolCfg.pricefeed).getPrice(
            pool.asset
        );
        uint256 feedPrice2 = IFastPriceFeed(_poolCfg.pricefeed).getPrice(
            _poolCfg.asset
        );
        uint256 priceAmount = (amount * feedPrice1) / feedPrice2;
        uint256 returnAmount = ISwapAggregator(_poolCfg.aggregator).sell(
            pool.asset,
            _poolCfg.asset,
            amount,
            (priceAmount * 90) / 100
        );
        if (returnAmount > record.spend) {
            IERC20(_poolCfg.asset).transfer(
                _poolCfg.creator,
                ((returnAmount - record.spend) * creatorRewardRatio) /
                    RATIO_PRECISION
            );
        }
        emit Gain(_tokenId, record.spend, returnAmount, mintDbr);
    }
}
