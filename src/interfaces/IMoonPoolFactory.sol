// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

// import './IMoonPoolBlast.sol';

interface IMoonPoolFactory {
    struct MoonPoolBaseConfig {
        address dev;
        address doubler;
        address dbr;
        address dbrFarm;
        address nft;
        address aggregator;
        address pricefeed;
    }

    function moonPools() external view returns (address[] memory _pools);

    function allMoonPoolLength() external view returns (uint);

    event UpdateAggregatorConfig(address router);
}
