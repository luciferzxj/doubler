// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface IFRNFT is IERC721 {
    struct Traits {
        uint32 layer;
        uint256 poolId;
        uint256 margin;
        uint256 amount;
        uint256 price;
        uint256 layerRanking;
    }

    struct TraitsView {
        uint32 layer;
        uint256 tokenId;
        uint256 poolId;
        uint256 margin;
        uint256 amount;
        uint256 price;
        uint256 layerRanking;
    }

    event Mint(
        uint256 indexed tokenId,
        address indexed to,
        uint256 poolId,
        uint32 layer,
        uint256 margin,
        uint256 amount,
        uint256 price,
        uint256 layerRanking
    );
    function getTraits(uint256 tokenId) external view returns (Traits memory traits);
    function getTraitsList(uint256[] calldata tokenIds) external view returns (Traits[] memory additionList);
    function mint(
        address to,
        uint256 poolId,
        uint32 layer,
        uint256 margin,
        uint256 amount,
        uint256 price,
        uint256 layerRanking
    ) external returns (uint256);
    function burnFrom(address from, uint256 tokenId) external;
    function isTokenOwner(uint256 tokenId, address user) external view returns (bool);
}
