// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import '../Doubler.sol';
import '../interfaces/IFRNFT.sol';
import 'hardhat/console.sol';

contract DoublerTest is Doubler {
    bool public isMultiSign = false;

    function setPool(uint256 _poolId, Pool memory pool) external {
        _testSetPool(_poolId, pool);
    }

    function setLayerData(uint256 _poolId, uint32 _layer, LayerData memory _layerData) external {
        _testSetLayerData(_poolId, _layer, _layerData);
    }

    function getLastLayer(uint256 _poolId, uint256 curPrice, uint256 amount) external {
        _getLastLayer(_poolId, curPrice, amount);
    }

    function testCountWinner(
        uint256 _poolId,
        uint256 _fromUnits,
        uint256 _fromUnitRanking
    ) public view returns (WinnerResult memory winRes) {
        Pool memory _pool = getPool(_poolId);
        return _countWinner(_poolId, _pool, _fromUnits, _fromUnitRanking);
    }

    function TestcountWithdrawAmount(uint256 _tokenId) external view returns (uint256 available, uint256 winAmount) {
        (, , , , , , address frnft, , ) = getPrivateVar();
        IFRNFT.Traits memory nft = IFRNFT(frnft).getTraits(_tokenId);
        (available, winAmount) = _countWithdrawAmount(nft);
    }

    function setMultiSign(bool _multiSign) external {
        isMultiSign = _multiSign;
    }
}
