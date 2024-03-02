// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

// import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './interfaces/IFRNFT.sol';
import './interfaces/IDBR.sol';
import './interfaces/IDoubler.sol';
import './interfaces/IDBRFarm.sol';
// import 'forge-std/console.sol';

// import Upgradeable
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';

contract DBRFarm is
    IDBRFarm,
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using SafeMath for uint32;

    bool private _initialized;
    uint32 private constant RATIO_PRECISION = 10000;
    uint256 private constant MUl = 1e10;
    
    uint256 private _tvlTotal;
    address private _dbrAsset;
    address private _doubler;
    address private _FRNFT;
    address private _farmWallet;

    ComPool private _boostPool;
    ComPool private _lastLayerRewardPool;

    mapping(address => AssetPool) private _assetPoolMap;
    mapping(uint256 => Doubler) private _doublerMap;
    mapping(uint256 => NFTDeposit) private _depositrMap;

    mapping(address => mapping (uint256=>uint256)) private _ownedTokensIndex;
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    mapping(address => uint256) private _userBlance;

    bytes32 public constant DOUBLER_ROLE = keccak256('DOUBLER_ROLE');
    bytes32 public constant MOONPOOL_ROLE = keccak256('MOONPOOL_ROLE');
    bytes32 public constant INIT_ROLE = keccak256('INIT_ROLE');

    // for update
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        _grantRole(INIT_ROLE, _msgSender());
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initializeV2(
        address _initDBRAsset,
        address _initDoubler,
        address _initFRNNFT,
        address _initMultiSigWallet,
        address _initFarmWallet,
        address _initMoonPoolFactory,
        uint256 _initBoostPer,
        uint256 _initLastlayerPer
    ) external onlyRole(INIT_ROLE) {
        require(_initialized == false, 'initialized err');
        _dbrAsset = _initDBRAsset;
        _doubler = _initDoubler;
        _FRNFT = _initFRNNFT;
        _farmWallet = _initFarmWallet;
        _boostPool.lastBlockNo = block.number;
        _boostPool.perBlock = _initBoostPer; 
        _lastLayerRewardPool.lastBlockNo = block.number;
        _lastLayerRewardPool.perBlock = _initLastlayerPer;
        _grantRole(DEFAULT_ADMIN_ROLE, _initMultiSigWallet);
        _grantRole(DEFAULT_ADMIN_ROLE, _initMoonPoolFactory);
        _grantRole(DOUBLER_ROLE, _initDoubler);
        // for test to remove 
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function addMoonPoolRole(address _moonpool) external onlyRole(DEFAULT_ADMIN_ROLE) {
         _grantRole(MOONPOOL_ROLE, _moonpool);
    }

    
    function updateAssetPerBlock(address _asset, uint256 _perBlock) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateAssetPool(_asset);
        _assetPoolMap[_asset].perBlock = _perBlock;
        if(_perBlock == 0) {
            _assetPoolMap[_asset].endBlockNo = block.number;
        }
        if (_perBlock > 0) {
            if (_assetPoolMap[_asset].endBlockNo > 0 || _assetPoolMap[_asset].startBlockNo == 0) {
                _assetPoolMap[_asset].startBlockNo = block.number;
            }
            _assetPoolMap[_asset].endBlockNo = 0;
        }
        emit UpdateAssetPerBlock(_asset, _perBlock);
    }

    function staking(uint256 _tokenId) external nonReentrant {
        require(IFRNFT(_FRNFT).ownerOf(_tokenId) == _msgSender(), 'owner err');
        bool joined = _staking(_tokenId);
        if (joined) {
            IFRNFT(_FRNFT).transferFrom(_msgSender(), address(this), _tokenId);
            _addTokenIdToPool(_msgSender(), _tokenId);
        }
    }

    function batchStaking(uint256[] calldata _tokenIds) external nonReentrant {
         uint256 tokenId ;
         for (uint i = 0; i < _tokenIds.length; ++i) {
            tokenId = _tokenIds[i];
            require(IFRNFT(_FRNFT).ownerOf(tokenId) == _msgSender(), 'owner err');
            bool joined = _staking(tokenId);
            if (joined) {
                IFRNFT(_FRNFT).transferFrom(_msgSender(), address(this), tokenId);
                _addTokenIdToPool(_msgSender(), tokenId);
            }
         }  
    }

    function join(uint256 _tokenId) external onlyRole(MOONPOOL_ROLE) {
        require(IFRNFT(_FRNFT).ownerOf(_tokenId) == _msgSender(), 'owner err');
        _staking(_tokenId);
    }

    function left(uint256 _tokenId) external onlyRole(MOONPOOL_ROLE) returns(uint256 claimAmount) {
        require(IFRNFT(_FRNFT).ownerOf(_tokenId) == _msgSender(), 'owner err');
        if (_depositrMap[_tokenId].from != _msgSender()) {
            return 0;
        }
        claimAmount = _claimToken(_tokenId, true);
    }

    function _staking(uint256 _tokenId) internal returns(bool){
        IFRNFT.Traits memory nft = IFRNFT(_FRNFT).getTraits(_tokenId);
        IDoubler.Pool memory pool = IDoubler(_doubler).getPool(nft.poolId);
        require(pool.endPrice == 0, 'doubler end err');
        if (_assetPoolMap[pool.asset].perBlock == 0) {
            return false;
        }
        _updateAssetPool(pool.asset);
        uint8 decimals = IERC20Metadata(pool.asset).decimals();
        uint256 addTvl = nft.amount.mul(nft.price).div(10 ** decimals);
        _doublerMap[nft.poolId].tvl += addTvl;
        _depositrMap[_tokenId].lastPerShare = _assetPoolMap[pool.asset].perShareTotal;
        _depositrMap[_tokenId].from = _msgSender();
        _tvlTotal += addTvl;
        emit Staking(_tokenId, _msgSender(), addTvl);
        return true;
    }

    function claim(uint256 _tokenId) external nonReentrant {
        require(_depositrMap[_tokenId].from == _msgSender(), 'owner err');
        _claimToken(_tokenId, false);
    }

    function _claimToken(uint256 _tokenId, bool _isEndMint) internal returns(uint256 claimAmount) {
        if (_depositrMap[_tokenId].endClaim == true) {
            return 0;
        }
        IFRNFT.Traits memory nft = IFRNFT(_FRNFT).getTraits(_tokenId);
        IDoubler.Pool memory pool = IDoubler(_doubler).getPool(nft.poolId);
        _updateAssetPool(pool.asset);
        uint8 decimals = IERC20Metadata(pool.asset).decimals();
        uint256 addTvl = nft.amount.mul(nft.price).div(10 ** decimals);
        if(_isEndMint) {
            _doublerMap[nft.poolId].tvl -= addTvl;
            if (_doublerMap[nft.poolId].endPerShare ==0) {
                 _tvlTotal -= addTvl;
            }
        }
        uint256 curlPerShareTotal = _doublerMap[nft.poolId].endPerShare > 0 ? _doublerMap[nft.poolId].endPerShare : _assetPoolMap[pool.asset].perShareTotal;
        uint256 peending = addTvl *  (curlPerShareTotal - _depositrMap[_tokenId].lastPerShare);
        _depositrMap[_tokenId].lastPerShare = curlPerShareTotal;
        claimAmount += peending;
        uint256 lastReward;
        uint256 boostReward;
        if (_doublerMap[nft.poolId].endPerShare >0) {
            uint256 mintTotal = _depositrMap[_tokenId].sendTotal + peending;
            // is lastlayer
            if(nft.layer == pool.lastLayer) {
                lastReward = mintTotal  * 2;
                _updateLayerRewardPool();
                lastReward = _lastLayerRewardPool.rewardAmount - _lastLayerRewardPool.sendAmount < lastReward ? _lastLayerRewardPool.rewardAmount - _lastLayerRewardPool.sendAmount : lastReward;
                _lastLayerRewardPool.sendAmount += lastReward;
                claimAmount += lastReward;
            }
            // is boost
            if (_doublerMap[nft.poolId].isBoost == true) {
                boostReward = mintTotal * 2;
                _updateBoostRewardPool();
                boostReward = _boostPool.rewardAmount - _boostPool.sendAmount < boostReward ? _boostPool.rewardAmount - _boostPool.sendAmount : boostReward;
                _boostPool.sendAmount += boostReward;
                claimAmount += boostReward;
            }
            _depositrMap[_tokenId].endClaim = true;
        }
        // ensure tokenid withdraw
        claimAmount = claimAmount.div(MUl) >  IERC20(_dbrAsset).balanceOf(_farmWallet) ?  IERC20(_dbrAsset).balanceOf(_farmWallet) : claimAmount.div(MUl);
        if (claimAmount >0) {
            _depositrMap[_tokenId].sendTotal += claimAmount.mul(MUl);
            IERC20(_dbrAsset).safeTransferFrom(_farmWallet, _msgSender(),  claimAmount);
        }
        emit Claim(nft.poolId, _msgSender(), _tokenId, claimAmount);
    }

    function withdraw(uint256 _tokenId) external nonReentrant {
        require(_depositrMap[_tokenId].from == _msgSender(), 'owner err');
        _depositrMap[_tokenId].from = address(0x0);
        _claimToken(_tokenId, true);
        IFRNFT(_FRNFT).transferFrom(address(this), _msgSender(), _tokenId);
        _removeTokenIdFromPool(_msgSender(), _tokenId);
        emit Withdraw(_tokenId);
    }

    function getNftPendingTotal(uint256 _tokenId) external view returns (uint256 peending, uint256 boostReward, uint256 lastLayerReward) {
        if (_depositrMap[_tokenId].endClaim == true) {
            return (0,0,0);
        }
        IFRNFT.Traits memory nft = IFRNFT(_FRNFT).getTraits(_tokenId);
        IDoubler.Pool memory pool = IDoubler(_doubler).getPool(nft.poolId);
        uint8 decimals = IERC20Metadata(pool.asset).decimals();
        uint256 addTvl = nft.amount.mul(nft.price).div(10 ** decimals);
        uint256 curlPerShareTotal = _doublerMap[nft.poolId].endPerShare > 0 ? _doublerMap[nft.poolId].endPerShare : _getPerShare(pool.asset);
        peending = addTvl *  (curlPerShareTotal - _depositrMap[_tokenId].lastPerShare);
        if (_doublerMap[nft.poolId].endPerShare >0) {
            uint256 mintTotal = _depositrMap[_tokenId].sendTotal + peending;
            if(nft.layer == pool.lastLayer) {
                boostReward = mintTotal;
            }
            if (_doublerMap[nft.poolId].isBoost == true) {
                lastLayerReward = mintTotal;
            }
        }
        if (peending > 0) {
            peending = peending.div(MUl);
        }
        if (boostReward > 0) {
            boostReward = boostReward.div(MUl);
        }
        if (lastLayerReward > 0) {
            lastLayerReward = lastLayerReward.div(MUl);
        }
    }

    function endDoubler(uint256 _doublerId) external nonReentrant {
        require(_doublerMap[_doublerId].endBlockNo == 0, 'endBlockNo err');
        IDoubler.Pool memory pool = IDoubler(_doubler).getPool(_doublerId);
        if (pool.endPrice == 0) {
            IDoubler(_doubler).endPool(_doublerId);
        }
        _updateAssetPool(pool.asset);
        _tvlTotal = _tvlTotal - _doublerMap[_doublerId].tvl;
        (,,,,uint256 tvlTotal,,,,) = IDoubler(_doubler).getPrivateVar();
        if (pool.tvl * 10 >= tvlTotal) {
           _doublerMap[_doublerId].isBoost = true; 
        }
        _doublerMap[_doublerId].endBlockNo = block.number;
        _doublerMap[_doublerId].endPerShare = _getPerShare(pool.asset);
        emit EndDoubler(_doublerId, _msgSender());
    }

    function _updateAssetPool(address _asset) internal  {
        AssetPool storage pool = _assetPoolMap[_asset];
        if (block.number <= pool.lastRewardBlockNo) { // in one block
            return;
        }
        pool.perShareTotal = _getPerShare(_asset);
        pool.lastRewardBlockNo = block.number;
    }

    function _updateLayerRewardPool() internal  {
        if (_lastLayerRewardPool.lastBlockNo >= block.number) {
            return ;
        }
        _lastLayerRewardPool.rewardAmount += (block.number - _lastLayerRewardPool.lastBlockNo) * _lastLayerRewardPool.perBlock * MUl;
        _lastLayerRewardPool.lastBlockNo = block.number;
    }

    function _updateBoostRewardPool() internal  {
        if (_boostPool.lastBlockNo >= block.number) {
            return ;
        }
        _boostPool.rewardAmount += (block.number - _boostPool.lastBlockNo) * _boostPool.perBlock * MUl;
        _boostPool.lastBlockNo = block.number;
    }

    function _getMultiplier(address _asset) internal view returns (uint256) {
        uint256 fromBlockNo = _assetPoolMap[_asset].lastRewardBlockNo > _assetPoolMap[_asset].startBlockNo ? _assetPoolMap[_asset].lastRewardBlockNo : _assetPoolMap[_asset].startBlockNo;
        uint256 toBlckNo = _assetPoolMap[_asset].endBlockNo > 0 ? _assetPoolMap[_asset].endBlockNo : block.number;
        if (fromBlockNo >= toBlckNo) {
            return 0;
        }
        return toBlckNo - fromBlockNo;
    }

    function _getPerShare(address _poolAsset) internal view returns (uint256 perShare) {
        if (_tvlTotal > 0) {
            perShare = (_getMultiplier(_poolAsset) * _assetPoolMap[_poolAsset].perBlock * MUl) / _tvlTotal;
        }
        perShare = _assetPoolMap[_poolAsset].perShareTotal + perShare;
    }

    function getDoubler(uint256 _doublerId) external view returns (Doubler memory) {
        return _doublerMap[_doublerId];
    }

    function hot(uint256 _doublerId, uint256 _amount) external {
        require(_doublerMap[_doublerId].endBlockNo == 0, 'endBlockNo err');
        IDBR(_dbrAsset).burnFrom(_msgSender(), _amount);
        _doublerMap[_doublerId].hot += _amount;
        emit Hot(_doublerId, _amount);
    }

    function _removeTokenIdFromPool(address _from, uint256 _tokenId) private {
        uint256 lastTokenIndex = _userBlance[_from] - 1;
        uint256 tokenIndex = _ownedTokensIndex[_from][_tokenId];
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[_from][lastTokenIndex];
            _ownedTokens[_from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[_from][lastTokenId] = tokenIndex; // Update the moved token's index
        }
        _userBlance[_from] -=1;
        delete _ownedTokensIndex[_from][_tokenId];
        delete _ownedTokens[_from][lastTokenIndex];
    }

    function _addTokenIdToPool(address _to, uint256 _tokenId) private {
        uint256 length = _userBlance[_to];
        _ownedTokensIndex[_to][_tokenId] = length;
        _ownedTokens[_to][length] = _tokenId;
        _userBlance[_to] +=1;
    }

    function getTokenIds(address _user, uint256 _offset, uint256 _limit) public view  returns (uint256[] memory tokenIds)  {
        if (_userBlance[_user] == 0 ) {
            return tokenIds;
        }
        _limit = (_offset + _limit) < _userBlance[_user] ? _limit : _userBlance[_user] - _offset;
        tokenIds = new uint256[](_limit);
        for (uint i = 0; i < _limit; ++i) {
             tokenIds[i] = _ownedTokens[_user][_offset];
             _offset ++;
        }
        return tokenIds;
    }

    function balanceOf(address _user) external view returns(uint256) {
        return _userBlance[_user];
    }

    function getBoostPool() external view returns (ComPool memory) {
        return _boostPool;
    }

    function getLastLayerRewardPool() external view returns (ComPool memory) {
        return _lastLayerRewardPool;
    }

    function getTvlTotal() external view returns (uint256) {
        return _tvlTotal;
    }
    
    function getPrivateVar() external view returns(uint256 tvlTotal, address dbrAsset, address doubler, address frnft, address farmWallet){
        return (_tvlTotal , _dbrAsset, _doubler, _FRNFT, _farmWallet);
    }

}
