// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IDBRFarm {

    struct ComPool{
        uint256 perBlock;
        uint256 lastBlockNo;
        uint256 rewardAmount;
        uint256 sendAmount;
    }

    struct Doubler {
        bool isBoost;
        uint256 hot;
        uint256 tvl;
        uint256 endBlockNo;
        uint256 endPerShare;
    }

    struct NFTDeposit {
        address from;
        uint256 lastPerShare;
        uint256 sendTotal;
    }

    struct AssetPool {
        uint256 perBlock; // per block reward
        uint256 lastRewardBlockNo;
        uint256 perShareTotal;
        uint256 startBlockNo;
        uint256 endBlockNo;
    }

    event Deposit(uint256 indexed tokenId, address depositor, uint256 addTvl);
    event EndDoubler(uint256 indexed doublerId, address from, uint256 reward);
    event Claim(uint256 indexed doublerId, address to, uint256  tokenId, uint256 claimAmount);
    event UpdateEndReward(uint16 _newEndReward);
    event UpdateAssetPerBlock(address _asset, uint256 _perBlock);
    event Hot(uint256 doublerId, uint256 amount);

    function deposit(uint256 _tokenId) external;
    function claim(uint256 _tokenId) external;
    function withdraw(uint256 _tokenId) external;
    function join(uint256 _tokenId) external ;
    function left(uint256 _tokenId) external returns(uint256 claimAmount);
    function endDoubler(uint256 _doublerId) external;
    function hot(uint256 _doublerId, uint256 _amount) external;
    function getNftPendingTotal(uint256 _tokenId) external view returns (uint256 peending, uint256 boostReward, uint256 lastLayerReward);
    function getDoubler(uint256 _doublerId) external view returns (Doubler memory);
    function balanceOf(address _user) external view returns(uint256);
    function getTokenIds(address _user, uint256 _offset, uint256 _limit) external view  returns (uint256[] memory tokenIds);
}
