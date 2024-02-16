// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Base64.sol';
import './interfaces/IDoubler.sol';
import './interfaces/IFRNFT.sol';

contract FRNFT is AccessControlEnumerable, IERC721Enumerable, ERC721Pausable, ERC721Royalty, IFRNFT {
    using Strings for uint256;
    using Strings for uint32;
    using Strings for address;

    bytes32 public constant DOUBLER_ROLE = keccak256('DOUBLER_ROLE');
    bytes32 public constant ECO_ROLE = keccak256('ECO_ROLE');
    bytes32 public constant INIT_ROLE = keccak256('INIT_ROLE');

    bool private _initialized;
    uint256 private _lastTokenId;
    address private _doublerPool;
    mapping(uint256 => Traits) private _TraitsMap;
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;
    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;
    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
       _grantRole(INIT_ROLE, _msgSender());
    }

    function initialize(address doublerPool, address _initMultiSigWallet) external onlyRole(INIT_ROLE) {
        require(_initialized == false, 'initialized err');
        _initialized = true;
        _doublerPool = doublerPool;
        _grantRole(ECO_ROLE, _initMultiSigWallet);
        _grantRole(DOUBLER_ROLE, doublerPool);
        // todo test for remove
        _grantRole(DOUBLER_ROLE, _msgSender());
    }

    function getTraits(uint256 tokenId) external view returns (Traits memory) {
        require(_exists(tokenId), 'tokenId invalid');
        return _TraitsMap[tokenId];
    }

    function getTraitsList(uint256[] calldata tokenIds) external view returns (Traits[] memory TraitsList) {
        TraitsList = new Traits[](tokenIds.length);
        for (uint i = 0; i < tokenIds.length; ++i) {
            TraitsList[i] = _TraitsMap[tokenIds[i]];
        }
        return TraitsList;
    }

    function isTokenOwner(uint256 tokenId, address user) external view returns (bool) {
        bool isExists = _exists(tokenId);
        if (!isExists) {
            return false;
        }
        return ownerOf(tokenId) == user;
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }

    function mint(
        address to,
        uint256 poolId,
        uint32 layer,
        uint256 margin,
        uint256 amount,
        uint256 price,
        uint256 layerRanking
    ) external onlyRole(DOUBLER_ROLE) returns (uint256) {
        _lastTokenId += 1;
        _mint(to, _lastTokenId);
        Traits storage traits = _TraitsMap[_lastTokenId];
        traits.poolId = poolId;
        traits.layer = layer;
        traits.amount = amount;
        traits.price = price;
        traits.margin = margin;
        traits.layerRanking = layerRanking;
        emit Mint(_lastTokenId, to, poolId, layer, margin, amount, price, layerRanking);
        return _lastTokenId;
    }

    function burnFrom(address from, uint256 tokenId) external onlyRole(DOUBLER_ROLE) {
        require(_isApprovedOrOwner(from, tokenId), 'ERC721: caller is not owner nor approved');
        _burn(tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override(IERC721, ERC721) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override(IERC721, ERC721) {
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    function getAttributes(uint256 tokenId) internal view returns (string memory) {
        IDoubler.Pool memory pool = IDoubler(_doublerPool).getPool(_TraitsMap[tokenId].poolId);
        string memory assetName = getNormalAttribute('asset_symbol', IERC20Metadata(pool.asset).name());
        string memory asset = getNormalAttribute('asset', pool.asset.toHexString());
        string memory margin = getNumberAttribute('margin', _TraitsMap[tokenId].margin.toString());
        string memory amount = getNumberAttribute('amount', _TraitsMap[tokenId].amount.toString());
        string memory poolId = getNumberAttribute('pool_id', _TraitsMap[tokenId].poolId.toString());
        string memory layer = getNumberAttribute('layer', _TraitsMap[tokenId].layer.toString());
        string memory layerRanking = getNumberAttribute('ranking', _TraitsMap[tokenId].layerRanking.toString());
        string memory price = getNumberAttribute('price', _TraitsMap[tokenId].price.toString());
        string memory priceCecimals = getNumberAttribute('price_decimals', '18');
        return
            string(
                abi.encodePacked(assetName, asset, margin, amount, poolId, layer, layerRanking, price, priceCecimals)
            );
    }
    function getNormalAttribute(string memory key, string memory value) internal pure returns (string memory) {
        return string(abi.encodePacked('{"trait_type":"', key, '","value":"', value, '"},'));
    }

    function getNumberAttribute(string memory key, string memory value) internal pure returns (string memory) {
        return string(abi.encodePacked('{"trait_type":"', key, '","display_type": "number","value":"', value, '"},'));
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId));
        string memory name = string(abi.encodePacked('FR#', tokenId.toString()));
        string memory description = string(abi.encodePacked('Doubler Flexible Return Token'));
        string memory attributes = getAttributes(tokenId);
        return
            string(
                abi.encodePacked(
                    'data:application/json;base64,',
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name,
                                '", "description":"',
                                description,
                                '", "external_link":"',
                                'https://www.doubler.pro',
                                '", "attributes":[',
                                attributes,
                                ']}'
                            )
                        )
                    )
                )
            );
    }

    function setDefaultRoyaltyInfo(address receiver, uint96 feeNumerator) external onlyRole(ECO_ROLE) {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyRole(ECO_ROLE) {
        _deleteDefaultRoyalty();
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address recipient,
        uint96 fraction
    ) external onlyRole(ECO_ROLE) {
        _setTokenRoyalty(tokenId, recipient, fraction);
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyRole(ECO_ROLE) {
        _resetTokenRoyalty(tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721Royalty) {
        super._burn(tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, ERC721, ERC721Royalty, AccessControlEnumerable) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), 'ERC721Enumerable: owner index out of bounds');
        return _ownedTokens[owner][index];
    }

    function getTokenList(
        address owner,
        uint256 offset,
        uint256 limit
    ) public view virtual returns (TraitsView[] memory traitsView) {
        require(offset < ERC721.balanceOf(owner), 'ERC721Enumerable: owner index out of bounds');
        limit = (offset + limit) < ERC721.balanceOf(owner) ? limit : ERC721.balanceOf(owner) - offset;
        traitsView = new TraitsView[](limit);
        uint256 tokenId;
        for (uint256 i = 0; i < limit; i += 1) {
            tokenId = _ownedTokens[owner][offset];
            traitsView[i].tokenId = tokenId;
            traitsView[i].layer = _TraitsMap[tokenId].layer;
            traitsView[i].poolId = _TraitsMap[tokenId].poolId;
            traitsView[i].margin = _TraitsMap[tokenId].margin;
            traitsView[i].amount = _TraitsMap[tokenId].amount;
            traitsView[i].price = _TraitsMap[tokenId].price;
            traitsView[i].layerRanking = _TraitsMap[tokenId].layerRanking;
            offset++;
        }
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < totalSupply(), 'ERC721Enumerable: global index out of bounds');
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``"s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``"s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension"s ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension"s token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension"s ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from"s tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token"s index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension"s token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an "if" statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token"s index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}
