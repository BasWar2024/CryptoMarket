// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol" ;
import "@openzeppelin/contracts/access/Ownable.sol" ;

contract VeMIT is ERC20PresetMinterPauser,Ownable  {

    mapping(address => bool) public fromWl ;
    mapping(address => bool) public toWl ;
    mapping(address => bool) public burnWl ;
    bool public hasFilter = true ;

    constructor() ERC20PresetMinterPauser("VoterMIT", "VeMIT") {
        fromWl[address (0x00)] = true ;
        toWl[address (0x00)] = true ;
        burnWl[_msgSender()] = true ;
        fromWl[_msgSender()] = true ;
        toWl[_msgSender()] = true ;
    }

    function setFromWl(address addr, bool status) external onlyOwner {
        fromWl[addr] = status ;
    }

    function setToWl(address addr, bool status) external onlyOwner {
        toWl[addr] = status ;
    }

    function setFilter(bool filter) external onlyOwner {
        hasFilter = filter ;
    }

    function setBurnWl(address addr, bool status) external onlyOwner {
        burnWl[addr] = status ;
    }

    function burnFrom(address account, uint256 amount) public override(ERC20Burnable) virtual {
        require(burnWl[_msgSender()], "Voting rights are not allowed to be destroyed privately") ;
        _burn(account, amount) ;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20PresetMinterPauser) {
        require(hasFilter == false || fromWl[from] || toWl[to] || fromWl[_msgSender()] || toWl[_msgSender()], "unfair voting rights") ;
        super._beforeTokenTransfer(from, to, amount);
    }
}
