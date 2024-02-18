// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract Token is ERC20, ERC20Burnable, Pausable, AccessControlEnumerable {

    bytes32 public constant MINT_ROLE = keccak256('MINT_ROLE');
    
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _grantRole(MINT_ROLE, _msgSender());
    }

    function mint(address to, uint256 amount) public onlyRole(MINT_ROLE)  {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
