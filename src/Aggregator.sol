// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interfaces/IUniswapV3SwapRouter.sol';
import './interfaces/IUniswapV2Router.sol';
import './interfaces/ISwapRouter.sol';

contract Aggregator is ISwapRouter, Ownable, AccessControlEnumerable {
    address private _multiSigWallet;
    uint256 private _slippage = 50;
    uint256 constant BASE_RATIO = 10000;
    uint256 constant DEADLINE = 1 minutes;
    mapping(bytes32 => Strategy) public strategys;
    RouterConfig cfg;

    event UpdateSlippage(uint256 _newSlippage);

    constructor(RouterConfig memory _cfg, address _initMultiSigWallet) {
        cfg = _cfg;
        _multiSigWallet = _initMultiSigWallet;
    }

    function updateSlippage(uint256 _newSlippage) external {
        require(_multiSigWallet == msg.sender, 'wallet error');
        require(_slippage < 100, 'slippage < 1%');
        _slippage = _newSlippage;
        emit UpdateSlippage(_newSlippage);
    }

    function addUniV3Strategy(address tokenIn, address tokenOut, UniV3Data memory datas) external onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        Strategy storage str = strategys[hash];
        str.v3Data.push(datas);
        str.totalRatio += datas.ratio;
    }

    function addUniV2Strategy(address tokenIn, address tokenOut, UniV2Data memory datas) external onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        Strategy storage str = strategys[hash];
        str.v2Data.push(datas);
        str.totalRatio += datas.ratio;
    }

    function updateUniV3Strategy(
        address tokenIn,
        address tokenOut,
        UniV3Data memory datas,
        uint256 index
    ) external onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        Strategy storage str = strategys[hash];
        str.totalRatio -= str.v3Data[index].ratio;
        str.v3Data[index] = datas;
        str.totalRatio += datas.ratio;
    }

    function updateUniV2Strategy(
        address tokenIn,
        address tokenOut,
        UniV2Data memory datas,
        uint256 index
    ) external onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        Strategy storage str = strategys[hash];
        str.totalRatio -= str.v2Data[index].ratio;
        str.v2Data[index] = datas;
        str.totalRatio += datas.ratio;
    }

    function swapCustomIn(
        address tokenIn,
        uint256 amountInMax,
        address tokenOut,
        uint256 amountOut
    ) external returns (uint256 amountIn) {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        Strategy memory str = strategys[hash];
        require(str.totalRatio == 10000, 'total ratio incorrect');
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountInMax);
        if (str.v2Data.length > 0) {
            IERC20(tokenIn).approve(cfg.uniswapV2Router, amountInMax);
            amountIn += _uniV2OutputSwap(str, amountOut, amountInMax);
        }
        if (str.v3Data.length > 0) {
            IERC20(tokenIn).approve(cfg.uniswapV3Router, amountInMax);
            amountIn += _uniV3OutputSwap(str, amountOut, amountInMax);
        }
        IERC20(tokenIn).transfer(msg.sender, amountInMax - amountIn);
    }

    function swapCustomOut(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin
    ) external returns (uint256 returnAmount) {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        Strategy memory str = strategys[hash];
        require(str.totalRatio == 10000, 'total ratio incorrect');
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        if (str.v2Data.length > 0) {
            IERC20(tokenIn).approve(cfg.uniswapV2Router, amountIn);
            returnAmount += _uniV2InputSwap(str, amountIn, amountOutMin);
        }
        if (str.v3Data.length > 0) {
            IERC20(tokenIn).approve(cfg.uniswapV3Router, amountIn);
            returnAmount += _uniV3InputSwap(str, amountIn, amountOutMin);
        }
    }

    function _uniV3OutputSwap(
        Strategy memory str,
        uint256 amountOut,
        uint256 amountInMax
    ) internal returns (uint256 spendAmount) {
        IUniV3SwapRouter.ExactOutputParams memory para;
        for (uint i = 0; i < str.v3Data.length; i++) {
            para.path = str.v3Data[i].path;
            para.recipient = msg.sender;
            para.deadline = block.timestamp + DEADLINE;
            para.amountOut = (amountOut * str.v3Data[i].ratio) / BASE_RATIO;
            para.amountInMaximum = (amountInMax * str.v3Data[i].ratio) / BASE_RATIO;
            spendAmount += IUniV3SwapRouter(cfg.uniswapV3Router).exactOutput(para);
        }
    }

    function _uniV2OutputSwap(
        Strategy memory str,
        uint256 amountOut,
        uint256 amountInMax
    ) internal returns (uint256 spendAmount) {
        for (uint i = 0; i < str.v2Data.length; i++) {
            amountOut = (amountOut * str.v2Data[i].ratio) / BASE_RATIO;
            spendAmount += IUniswapV2Router(cfg.uniswapV2Router).swapTokensForExactTokens(
                amountOut,
                amountInMax * str.v2Data[i].ratio / BASE_RATIO,
                str.v2Data[i].path,
                msg.sender,
                block.timestamp + DEADLINE
            )[0];
        }
    }

    function _uniV3InputSwap(
        Strategy memory str,
        uint256 amountIn,
        uint256 amountOutMin
    ) internal returns (uint256 returnAmount) {
        IUniV3SwapRouter.ExactInputParams memory para;
        for (uint i = 0; i < str.v3Data.length; i++) {
            para.path = str.v3Data[i].path;
            para.recipient = msg.sender;
            para.deadline = block.timestamp + DEADLINE;
            para.amountIn = (amountIn * str.v3Data[i].ratio) / BASE_RATIO;
            para.amountOutMinimum = (amountOutMin * str.v3Data[i].ratio) / BASE_RATIO;
            returnAmount += IUniV3SwapRouter(cfg.uniswapV3Router).exactInput(para);
        }
    }

    function _uniV2InputSwap(
        Strategy memory str,
        uint256 amountIn,
        uint256 amountOutMin
    ) internal returns (uint256 returnAmount) {
        for (uint i = 0; i < str.v2Data.length; i++) {
            uint[] memory amounts = IUniswapV2Router(cfg.uniswapV2Router).swapExactTokensForTokens(
                (amountIn * str.v2Data[i].ratio) / BASE_RATIO,
                (amountOutMin * str.v2Data[i].ratio) / BASE_RATIO,
                str.v2Data[i].path,
                msg.sender,
                block.timestamp + DEADLINE
            );
            returnAmount += amounts[amounts.length - 1];
        }
    }

    function getSlippage() external view returns (uint256 slippage) {
        return _slippage;
    }
}
