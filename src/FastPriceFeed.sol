// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

import './interfaces/IUniswapV3Pool.sol';
import './interfaces/IFastPriceFeed.sol';

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = a * b
        // Compute the product mod 2**256 and mod 2**256 - 1
        // then use the Chinese Remainder Theorem to reconstruct
        // the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2**256 + prod0
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division
        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        // Make sure the result is less than 2**256.
        // Also prevents denominator == 0
        require(denominator > prod1);

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0]
        // Compute remainder using mulmod
        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        // Subtract 256 bit number from 512 bit number
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator
        // Compute largest power of two divisor of denominator.
        // Always >= 1.
        uint256 twos = denominator & (~denominator + 1);
        // Divide denominator by power of two
        assembly {
            denominator := div(denominator, twos)
        }

        // Divide [prod1 prod0] by the factors of two
        assembly {
            prod0 := div(prod0, twos)
        }
        // Shift in bits from prod1 into prod0. For this we need
        // to flip `twos` such that it is 2**256 / twos.
        // If twos is zero, then it becomes one
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        // Invert denominator mod 2**256
        // Now that denominator is an odd number, it has an inverse
        // modulo 2**256 such that denominator * inv = 1 mod 2**256.
        // Compute the inverse by starting with a seed that is correct
        // correct for four bits. That is, denominator * inv = 1 mod 2**4
        uint256 inv = (3 * denominator) ^ 2;
        // Now use Newton-Raphson iteration to improve the precision.
        // Thanks to Hensel's lifting lemma, this also works in modular
        // arithmetic, doubling the correct bits in each step.
        inv *= 2 - denominator * inv; // inverse mod 2**8
        inv *= 2 - denominator * inv; // inverse mod 2**16
        inv *= 2 - denominator * inv; // inverse mod 2**32
        inv *= 2 - denominator * inv; // inverse mod 2**64
        inv *= 2 - denominator * inv; // inverse mod 2**128
        inv *= 2 - denominator * inv; // inverse mod 2**256

        // Because the division is now exact we can divide by multiplying
        // with the modular inverse of denominator. This will give us the
        // correct result modulo 2**256. Since the precoditions guarantee
        // that the outcome is less than 2**256, this is the final result.
        // We don't need to compute the high bits of the result and prod1
        // is no longer required.
        result = prod0 * inv;
        return result;
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }
}

/// @title Math library for computing sqrt prices from ticks and vice versa
/// @notice Computes sqrt price for ticks of size 1.0001, i.e. sqrt(1.0001^tick) as fixed point Q64.96 numbers. Supports
/// prices between 2**-128 and 2**128
library TickMath {
    /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
    uint24 internal constant MAX_TICK = 887272;

    /// @notice Calculates sqrt(1.0001^tick) * 2^96
    /// @dev Throws if |tick| > max tick
    /// @param tick The input tick for the above formula
    /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the ratio of the two assets (token1/token0)
    /// at the given tick
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
        require(absTick <= uint256(MAX_TICK), 'T');

        uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;

        // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
        // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
        // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
        sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }
}

contract FastPriceFeed is IFastPriceFeed, AccessControlEnumerable {
    using SafeMath for uint256;

    uint32 public constant MIN_INTERVA = 5 minutes;
    uint32 public constant MAX_INTERVA = 4 hours;
    uint256 private constant _priceDecimals = 1e18;

    mapping(address => bool) private _isSupported;
    mapping(address => uint32) private _twapIntervals;
    mapping(address => address) private _assetFeedMap;
    mapping(address => Plan) private _plans;
    mapping(address => PriceLimit) private _priceLimits;

    constructor(address _initMultiSigWallet) {
        _grantRole(DEFAULT_ADMIN_ROLE, _initMultiSigWallet);
    }

    modifier isSupportedToken(address _asset) {
        require(_isSupported[_asset], "invalid token");
        _;
    }

    function getIsSupported(address _asset) external view returns(bool) {
        return _isSupported[_asset];
    }
    
    function getTwapIntervals(address _asset) external view returns(uint32) {
        return _twapIntervals[_asset];
    }

    function getAssetFeedMap(address _asset) external view returns(address) {
        return _assetFeedMap[_asset];
    }

    function getPlans(address _asset) external view returns(Plan) {
        return _plans[_asset];
    }

    function getPriceLimits(address _asset) external view returns(PriceLimit memory) {
        return _priceLimits[_asset];
    }

    function closeAsset(address _asset) external isSupportedToken(_asset) onlyRole(DEFAULT_ADMIN_ROLE) {
        _isSupported[_asset] = false;
        emit AssetClosed(_asset);
    }

    function batchSetAssetPriceLimit(address[] memory _assets, PriceLimit[] memory _prices) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_assets.length == _prices.length, "invalid params");
        for(uint32 i = 0; i < _assets.length; i++){
            require(_isSupported[_assets[i]], "invalid token");
            _priceLimits[_assets[i]] = _prices[i];
            emit SetPriceLimit(_assets[i], _prices[i]);
        }
    }

    function newAsset(
        address _asset,
        address _assetPriceFeed,
        uint32 _twapInterval,
        Plan _plan
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _isSupported[_asset] = true;
        _plans[_asset] = _plan;
        if (_plan == Plan.DEX) {
            initDexPriceFeed(_asset, _assetPriceFeed);
            _twapIntervals[_asset] = _twapInterval;
        } else {
            initChainlinkPriceFeed(_asset, _assetPriceFeed);
        }
        emit AddAsset(_asset, _assetPriceFeed, _twapInterval);
    }

    function updatePriceAggregator(address _asset, address _aggregator) external  isSupportedToken(_asset) onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_plans[_asset] == Plan.DEX) {
            initDexPriceFeed(_asset, _aggregator);
        } else {
            initChainlinkPriceFeed(_asset, _aggregator);
        }
    }

    function upgradePlan(address _asset, address _aggregator, Plan _plan) external isSupportedToken(_asset) onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_plans[_asset] == Plan.DEX, "only DEX mode");
        require(_aggregator != address(0), "zero address");
        initChainlinkPriceFeed(_asset, _aggregator);
        _plans[_asset] = _plan;
        emit UpgradePlan(_asset, _aggregator);
    }

    function initChainlinkPriceFeed(address _asset, address _chainlink) internal {
        require(_chainlink != address(0), "zero address");
        checkChainlinkAggregatorVallid(_chainlink);
        _assetFeedMap[_asset] = _chainlink;
        emit SetChainlinkAggregator(_asset, _chainlink);
    }

    function initDexPriceFeed(address _asset, address _univ3Pool) internal {
        require(_univ3Pool != address(0), 'UniV3 Pool: zore address is not allowed');
        _assetFeedMap[_asset] = _univ3Pool;
        emit SetDexPriceFeed(_asset, _univ3Pool);
    }

    function checkChainlinkAggregatorVallid(address _pythAggregator) internal view {
        AggregatorV3Interface aggregator = AggregatorV3Interface(_pythAggregator);
        (, int256 newPrice_, , , ) = aggregator.latestRoundData();
        require(newPrice_ > 0, 'Price Feed: invalid Oracle');
    }

    function setTwapInterval(address _asset, uint32 _twapInterval) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_isSupported[_asset], 'Oracle: do not support this token');
        require(_plans[_asset] == Plan.DEX, "setTwapInterval: Only dex _asset");
        require(
            MAX_INTERVA >= _twapIntervals[_asset] && _twapIntervals[_asset] >= MIN_INTERVA,
            'setTwapInterval: Invalid twapInterval'
        );
        emit SetTwapInterval(_asset, _twapIntervals[_asset], _twapInterval);
        _twapIntervals[_asset] = _twapInterval;
    }

    function getPriceFromDex(address _asset) internal view returns (uint256 price) {
        require(_isSupported[_asset], 'UniV3: oracle in mainnet not initialized yet!');
        address uniswapV3Pool = _assetFeedMap[_asset];
        uint32 twapInterval = _twapIntervals[_asset];
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Pool);
        IUniswapV3Pool.Slot0 memory slot0;
        IUniswapV3Pool.Observation memory obs;
        slot0 = pool.slot0();
        obs = pool.observations((slot0.observationIndex + 1) % slot0.observationCardinality);
        require(obs.initialized, "UNIV3: Pair did't initialized");
        uint32 delta = uint32(block.timestamp) - obs.blockTimestamp;
        require(delta >= twapInterval, 'UniV3: token pool does not have enough transaction history in mainnet');
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapInterval;
        secondsAgos[1] = 0;
        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
            int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapInterval)))
        );
        (uint256 price0, uint256 price1) = mockDexPrice(pool, sqrtPriceX96);
        return pool.token0() == _asset ? price0 : price1;
    }

    function mockDexPrice(
        IUniswapV3Pool _pool,
        uint160 _sqrtPriceX96
    ) internal view returns (uint256 price0, uint256 price1) {
        address token0 = _pool.token0();
        address token1 = _pool.token1();
        uint8 decimal0 = ERC20(token0).decimals();
        uint8 decimal1 = ERC20(token1).decimals();
        uint256 temp = FullMath.mulDiv(uint256(_sqrtPriceX96), uint256(_sqrtPriceX96), 1);
        price0 = FullMath.mulDiv(temp >> 96, (10 ** decimal0).mul(1e18), 10 ** decimal1) >> 96;
        price1 = uint256(1e36).div(price0);
    }

    function getLastedDataFromChainlink(address _asset) internal view returns (uint256 price) {
        AggregatorV3Interface aggregator = AggregatorV3Interface(_assetFeedMap[_asset]);
        require(address(aggregator) != address(0), 'Price Feed: invalid aggregator');
        (, int256 newPrice, , uint256 updatedAt, ) = aggregator.latestRoundData();
        require(newPrice > 0 && block.timestamp > updatedAt, 'Price Feed: invalid Oracle');
        uint8 decimals = uint8(AggregatorV3Interface(aggregator).decimals());
        price = mockPrice(uint256(newPrice), decimals);
    }

    function getPrice(address _asset) external isSupportedToken(_asset)  view returns (uint256 price) {
        Plan pl = _plans[_asset];
        if (pl == Plan.CHAINLINK) {
            price = getLastedDataFromChainlink(_asset);
            if(price < _priceLimits[_asset].min || price > _priceLimits[_asset].max) {
                pl = Plan.DEX;
            }
        }
        if (pl == Plan.DEX) {
            price = getPriceFromDex(_asset);
            if(price < _priceLimits[_asset].min || price > _priceLimits[_asset].max) {
                revert();
            }
        }
        if (_plans[_asset] == Plan.OTHER) {
            revert();
        }
    }

    function mockPrice(uint256 originPrice, uint8 decimals) internal pure returns (uint256) {
        return (originPrice * _priceDecimals) / (10 ** decimals);
    }

    function isSupported(address _token) external view returns (bool) {
        return _isSupported[_token];
    }



}