// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

// import './IMoonPoolBlast.sol';

interface IMoonPoolFactory {
    struct MoonPoolBaseConfig {
        address dev;
        address signer;
        address doubler;
        address dbr;
        address dbrFarm;
        address nft;
        address uniswapV3Router;
    }

    function moonPools() external view returns (address[] memory _pools);

    function allMoonPoolLength() external view returns (uint);

    event UpdateUniswapConfig(address router);
}
