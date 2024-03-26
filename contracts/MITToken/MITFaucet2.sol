// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol" ;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol" ;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol" ;
contract MITFaucet2 is Ownable, ReentrancyGuard {

    IERC20 public token ;
    uint256 public bindGift = 9000 ether ;
    mapping(address => bool) public bindClaimAccount;

    constructor(address mitAddr){
        token = IERC20(mitAddr) ;
    }

    function setMitToken(address tokenAddr) external onlyOwner {
        token = IERC20(tokenAddr) ;
    }

    function setBindGift(uint256 newBindGift) external onlyOwner {
        bindGift = newBindGift ;
    }

    function faucet() external nonReentrant {
        require(!bindClaimAccount[_msgSender()], "The account binding comprehension has been received") ;
        bool isOk = token.transfer(_msgSender(), bindGift) ;
        require(isOk, "faucet mit token failed") ;
        bindClaimAccount[_msgSender()] = true ;
    }

    function getGift(address owner) external view returns (uint256){
        return bindClaimAccount[owner] ? 0 : bindGift ;
    }

    function withdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address (this)) ;
        if(balance > 0) {
            token.transfer(_msgSender(), balance) ;
        }
    }

    function setBindClaim(address [] memory owner, bool status) external onlyOwner {
        for(uint256 i = 0; i < owner.length; i++) {
            bindClaimAccount[owner[i]] = status ;
        }
    }
}
