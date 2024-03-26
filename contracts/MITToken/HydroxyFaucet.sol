// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol" ;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol" ;

contract HydroxylFaucet is Ownable {

    IERC20 public hydroxylToken ;

    uint256 public bindGift = 1500 ether ;
    uint256 public everydayBindGift = 1500 ether ;
    uint64  public bindGiftTimeSpace = 1 days ;
    mapping(address => uint64) public bindGiftTime ;

    uint256 public holderGift = 7500 ether ;
    uint256 public everydayHolderGift = 4500 ether ;
    uint64  public holderGiftTimeSpace = 1 days ;
    mapping(address => uint64) public holderGiftTime ;

    mapping(address => bool) public holderToken ;
    constructor(address hydroxylAddr) {
        hydroxylToken = IERC20(hydroxylAddr) ;
    }

    function setBindGift(uint256 bGift) external onlyOwner {
        bindGift = bGift ;
    }

    function setEverydayBindGift(uint256 eBindGift) external onlyOwner {
        everydayBindGift = eBindGift ;
    }

    function setBindGiftTime(uint64 bGiftTime) external onlyOwner {
        bindGiftTimeSpace = bGiftTime ;
    }

    function setHolderGift(uint256 hGift) external onlyOwner {
        holderGift = hGift ;
    }

    function setEverydayHolderGift(uint256 eHolderGift) external onlyOwner {
        everydayHolderGift = eHolderGift ;
    }

    function setHolderGiftTime(uint64 hGiftTime) external onlyOwner {
        holderGiftTimeSpace = hGiftTime ;
    }

    function putHolder(address [] memory players, bool value) external onlyOwner {
        for(uint256 i = 0; i < players.length; i++) {
            holderToken [ players[i] ] = value ;
        }
    }

    function claim() external {

        uint256 bind = bindBalance(_msgSender()) ;
        uint256 holder = holderBalance(_msgSender()) ;

        uint256 balance = bind + holder;
        require(balance > 0, "There is no Token to claim") ;

        uint64 current = uint64(block.timestamp) ;
        if( bind > 0) {
            bindGiftTime[ _msgSender() ] = current ;
        }
        if( holder > 0) {
            holderGiftTime[ _msgSender() ] = current ;
        }
        hydroxylToken.transfer(_msgSender(), balance) ;
    }

    function claimBalance(address player) external view returns(uint256) {
        return bindBalance(player) + holderBalance(player) ;
    }

    function bindBalance(address player) private view returns(uint256){
        uint64 preClaimTime = bindGiftTime[ player ] ;
        uint64 current = uint64(block.timestamp) ;
        if(current - preClaimTime >= bindGiftTimeSpace) {
            if(preClaimTime == 0) {
                return bindGift ;
            } else {
                return everydayBindGift ;
            }
        }
        return 0 ;
    }

    function holderBalance(address player) private view returns(uint256) {
        uint64 preClaimTime = holderGiftTime[ player ] ;
        uint64 current = uint64(block.timestamp) ;
        if(current - preClaimTime >= holderGiftTimeSpace && holderToken[ player ]) {
            if(preClaimTime == 0) {
                // first claim
                return holderGift ;
            } else {
                // last claim
                return everydayHolderGift;
            }
        }
        return 0 ;
    }

    function withdraw() external onlyOwner {
        uint256 amount = hydroxylToken.balanceOf(address (this));
        if(amount > 0) {
            hydroxylToken.transfer(_msgSender(), amount) ;
        }
    }
}
