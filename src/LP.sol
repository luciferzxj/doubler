// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/ILP.sol';

contract LP is ILP, ERC20, Ownable {
    
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // null
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
