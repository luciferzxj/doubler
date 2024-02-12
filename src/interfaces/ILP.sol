// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

interface ILP is IERC20Metadata {
     function mint(address to, uint256 amount) external; 
     function burn(address from, uint256 amount) external;
}