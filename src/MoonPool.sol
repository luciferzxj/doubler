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
import './interfaces/IUniswapV3SwapRouter.sol';
import './interfaces/IWETH.sol';

contract MoonPool is IMoonPool, ERC20, AccessControlEnumerable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Strings for uint256;
    using Strings for uint32;

    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    uint256 private constant RATIO_PRECISION = 10000; // 100 * 100
    uint256 private constant KEEPER_REWARD_PRECENT = 100;
    uint256 private constant CREATOR_REWARD_MAX = 2000;
    uint256 private constant FEE = 200;
    uint256 private constant SCAN = 1e18;

    // address private _developer;
    address private _signer;
    uint256 private _creatorRewardRatio;

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

    mapping(bytes32 => bool) private _usedSignature;

    mapping(address => uint256) private tokenBal;

    uint256 public tokenMuch;

    constructor(string memory name, string memory symbol, address singer) ERC20(name, symbol) {
        factory = _msgSender();
        _signer = singer;
    }

    receive() external payable {
        require(msg.sender == WETH || msg.sender == _poolCfg.doubler);
    }

    fallback() external payable {
        revert();
    }

    function poolConfig() external view returns (PoolConfig memory cfg) {
        return _poolCfg;
    }

    function ruleMap(address asset) external view returns (InputRule memory rule) {
        return _ruleMap[asset];
    }

    function poolInfo() external view returns (Pool memory pool) {
        return _pool;
    }

    function inputRecord(uint256 tokenId) external view returns (InputRecord memory record) {
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
        address _srcAsset
    ) external {
        require(_msgSender() == factory, 'can only init once');
        _poolCfg.creator = _creator;
        _poolCfg.developer = _dev;
        _poolCfg.asset = _srcAsset;
        _poolCfg.doubler = _doublerContract;
        _poolCfg.dbr = dbrContract;
        _poolCfg.dbrFarm = _dbrFarmContract;
        _poolCfg.FRNFT = _nft;
        _poolCfg.uniswapV3Router = _router;
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
        require(!_pool.started && _msgSender() == _poolCfg.creator, 'pool is runing');
        require(_initAmount >= 100000 * (10 ** IERC20Metadata(_poolCfg.asset).decimals()), 'amount min err');
        require(_duration >= END_LIMIT, 'endTime err');
        require(_cap >= _initAmount, 'cap err');
        require(_rewardRatio <= CREATOR_REWARD_MAX, 'ratio too much');
        _creatorRewardRatio = _rewardRatio;
        InputRule memory ir;
        IDoubler doubler = IDoubler(_poolCfg.doubler);
        require(_rules.length <= 3, 'inputRules err');
        for (uint32 i = 0; i < _rules.length; ++i) {
            ir = _rules[i];
            ruleCheck(ir);
            require(doubler.getAssetConfigMap(ir.asset).isOpen == true, 'asset status err');
            require(_ruleMap[ir.asset].asset == address(0x0), 'asset exits err');
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
        require(_ir.fallRatioMin >= FALL_RADIO_MIN && _ir.fallRatioMax <= FALL_RADIO_MAX, 'fallRatio err');
        require(_ir.profitRatioMin >= 50 && _ir.profitRatioMax <= RATIO_PRECISION, 'profitRatio err');
        require(_ir.rewardRatioMax <= RATIO_PRECISION, 'rewardRatioMax err');
        require(_ir.winnerRatioMax <= RATIO_PRECISION, 'winnerRatioMax err');
        require(_ir.tvl > 0, 'tvl err');
        require(_ir.layerInputMax > 100, 'layerInputMax err');
    }

    function updateRule(InputRule calldata _ir) external {
        require(_poolCfg.creator == _msgSender(), 'creator err');
        require(_ir.fallRatioMin >= FALL_RADIO_MIN && _ir.fallRatioMax <= FALL_RADIO_MAX, 'fallRatio err');
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
        require(block.timestamp <= _pool.endTime, '_pool was ended');
        _deposite(_amount, _msgSender());
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

    function _deposite(uint256 _amount, address to) internal {
        require(
            IERC20(_poolCfg.asset).balanceOf(address(this)) + _pool.pendingValue + _amount < _pool.capMax,
            'capMax error'
        );
        _pool.inValue += _amount;
        uint256 uValue = _getUValue();
        uint256 extra;
        if (IERC20(_poolCfg.asset).balanceOf(address(this)) < _pool.capMax / 5) {
            extra =
                ((
                    _pool.capMax / 5 - IERC20(_poolCfg.asset).balanceOf(address(this)) > _amount
                        ? _amount
                        : _pool.capMax / 5 - IERC20(_poolCfg.asset).balanceOf(address(this))
                ) * 2) /
                100;
        }
        IERC20(_poolCfg.asset).safeTransferFrom(_msgSender(), address(this), _amount);

        _mint(to, (uValue * (_amount + extra)) / SCAN);
        emit Deposite(to, _amount, (uValue * (_amount + extra)) / SCAN);
    }

    function withdraw(uint256 _lpAmount) external {
        uint256 lpValue = _getLPValue();
        uint256 dbrValue = _getLPDbrValue();
        uint256 sendUAmount = (_lpAmount * lpValue) / SCAN;
        sendUAmount = sendUAmount > IERC20(_poolCfg.asset).balanceOf(address(this))
            ? IERC20(_poolCfg.asset).balanceOf(address(this))
            : sendUAmount;
        if (block.timestamp < _pool.endTime) {
            require(
                IERC20(_poolCfg.asset).balanceOf(address(this)) - sendUAmount >= _pool.pendingValue,
                'sell lp limit error'
            );
        }
        _burn(_msgSender(), _lpAmount);
        _pool.outValue += sendUAmount;
        uint256 fee = (sendUAmount * FEE) / RATIO_PRECISION;
        IERC20(_poolCfg.asset).approve(address(this), sendUAmount);
        IERC20(_poolCfg.asset).safeTransferFrom(address(this), _msgSender(), sendUAmount - fee);
        IERC20(_poolCfg.asset).safeTransferFrom(address(this), _poolCfg.developer, fee);
        uint256 sendDbrAmount = (_lpAmount * dbrValue) / SCAN;
        sendDbrAmount = sendDbrAmount > _pool.dbrAmount ? _pool.dbrAmount : sendDbrAmount;
        _pool.dbrAmount -= sendDbrAmount;
        IERC20(_poolCfg.dbr).safeTransferFrom(address(this), _msgSender(), sendDbrAmount);
        emit Withdraw(_msgSender(), _lpAmount, sendUAmount, sendDbrAmount);
    }

    function checkDoubler(uint256 _doublerId) internal view returns (bool) {
        IDoubler.Pool memory doubler = IDoubler(_poolCfg.doubler).getPool(_doublerId);
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

    function input(uint256 _doublerId, SignatureParams memory datas) external {
        IDoubler.Pool memory doubler = IDoubler(_poolCfg.doubler).getPool(_doublerId);
        require(block.timestamp <= _pool.endTime, '_pool was ended');
        require(checkDoubler(_doublerId), 'rule err');
        bytes32 nhash = keccak256(abi.encodePacked(address(this), _doublerId.toString(), doubler.lastLayer.toString()));
        require(_inputLayer[nhash] == false, 'inputLayer had err');
        ISwapRouter.ExactInputSingleParams memory desc;
        desc.tokenIn = _poolCfg.asset;
        if (doubler.asset == ETH) {
            desc.tokenOut = WETH;
        } else {
            desc.tokenOut = doubler.asset;
        }
        desc.recipient = payable(address(this));
        desc.deadline = datas.deadline;
        desc.fee = _ruleMap[desc.tokenOut].fee;
        desc.amountIn = datas.amount;
        desc.amountOutMinimum = datas.minReturnAmount;
        desc.sqrtPriceLimitX96 = 0;
        _inputLayer[nhash] = true;
        uint256 returnAmount = mySwap(desc, datas);
        if (doubler.asset == ETH) {
            IWETH(WETH).withdraw(returnAmount);
            payable(_poolCfg.doubler).call{ value: desc.amountOutMinimum }('');
        } else {
            IERC20(desc.tokenOut).approve(_poolCfg.doubler, returnAmount);
        }
        _input(desc.amountIn, desc.amountOutMinimum, _doublerId, doubler, doubler.asset);
        if (returnAmount - desc.amountOutMinimum > 0) {
            tokenBal[doubler.asset] += returnAmount - desc.amountOutMinimum;
            if (doubler.asset == ETH && doubler.asset == WETH) {
                if (doubler.asset == ETH) {
                    IWETH(WETH).deposit{ value: tokenBal[doubler.asset] }();
                }
                if (tokenBal[doubler.asset] >= 1 ether) {
                    desc.tokenIn = WETH;
                    desc.tokenOut = _poolCfg.asset;
                    desc.amountIn = tokenBal[doubler.asset];
                    desc.amountOutMinimum = 10;
                    returnAmount = inSwap(desc);
                }
            } else {
                if (tokenBal[doubler.asset] >= 100 * 10 ** IERC20Metadata(doubler.asset).decimals()) {
                    desc.tokenIn = doubler.asset;
                    desc.tokenOut = _poolCfg.asset;
                    desc.amountIn = tokenBal[doubler.asset];
                    desc.amountOutMinimum = 10;
                    returnAmount = inSwap(desc);
                }
            }
            tokenBal[doubler.asset] = 0;
            tokenMuch += returnAmount;
        }
        uint256 sendDbrAmount = (_pool.dbrAmount * KEEPER_REWARD_PRECENT) / RATIO_PRECISION;
        IERC20(_poolCfg.dbr).safeTransferFrom(address(this), _msgSender(), sendDbrAmount);
    }

    function mySwap(
        ISwapRouter.ExactInputSingleParams memory desc,
        SignatureParams memory datas
    ) internal returns (uint256 returnAmount) {
        require(datas.deadline >= block.number, 'Signature has expired');
        if (address(desc.tokenIn) != ETH) {
            IERC20(desc.tokenIn).approve(address(_poolCfg.uniswapV3Router), desc.amountIn);
        }
        bytes32 hash = keccak256(
            abi.encodePacked(datas.amount, datas.minReturnAmount, datas.data, datas.mask, datas.deadline, msg.sender)
        );
        // console.log(msg.sender);
        require(!_usedSignature[hash], 'used signature');
        address signator = recover(hash, datas.signature);
        require(signator == _signer, 'wrong signature');

        returnAmount = ISwapRouter(_poolCfg.uniswapV3Router).exactInputSingle(desc);

        _usedSignature[hash] = true;
    }

    function inSwap(ISwapRouter.ExactInputSingleParams memory desc) internal returns (uint256 returnAmount) {
        if (address(desc.tokenIn) != ETH) {
            IERC20(desc.tokenIn).approve(address(_poolCfg.uniswapV3Router), desc.amountIn);
        }

        returnAmount = ISwapRouter(_poolCfg.uniswapV3Router).exactInputSingle(desc);

        // _usedSignature[hash] = true;
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
        emit NewInput(_doublerId, doubler.lastLayer, tokenId, spendAmount, returnAmount);
    }

    function recover(bytes32 hash, bytes memory sig) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        if (sig.length != 65) {
            return address(0x0);
        }

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := and(mload(add(sig, 65)), 255)
        }
        if (v < 27) {
            v += 27;
        }

        if (v != 27 && v != 28) {
            return address(0x0);
        }

        bytes memory prefix = '\x19Ethereum Signed Message:\n32';
        hash = keccak256(abi.encodePacked(prefix, hash));

        return ecrecover(hash, v, r, s);
    }

    function gain(uint256 _tokenId, SignatureParams memory datas) external {
        ISwapRouter.ExactInputSingleParams memory desc;
        IDoubler.Pool memory pool = IDoubler(_poolCfg.doubler).getPool(
            IFRNFT(_poolCfg.FRNFT).getTraits(_tokenId).poolId
        );
        if (pool.asset == ETH) {
            desc.tokenIn = WETH;
        } else {
            desc.tokenIn = pool.asset;
        }
        desc.tokenOut = _poolCfg.asset;
        desc.fee = _ruleMap[desc.tokenIn].fee;
        desc.deadline = datas.deadline;
        desc.recipient = payable(address(this));
        desc.sqrtPriceLimitX96 = 0;
        InputRecord storage record = _inputRecord[_tokenId];
        require(record.spend > 0, 'tokenId err');
        uint256 mintDbr = IDBRFarm(_poolCfg.dbrFarm).left(_tokenId);
        uint256 amount = IDoubler(_poolCfg.doubler).gain(_tokenId);
        if (pool.asset == ETH) {
            IWETH(WETH).deposit{ value: amount }();
        }
        desc.amountIn = amount;
        desc.amountOutMinimum = datas.minReturnAmount;
        _pool.pendingValue -= record.spend;
        _pool.dbrAmount += mintDbr;
        uint256 returnAmount = mySwap(desc, datas);
        if (returnAmount > record.spend) {
            IERC20(_poolCfg.asset).transfer(
                _poolCfg.creator,
                ((returnAmount - record.spend) * _creatorRewardRatio) / RATIO_PRECISION
            );
        }
        emit Gain(_tokenId, record.spend, returnAmount, mintDbr);
    }
}
