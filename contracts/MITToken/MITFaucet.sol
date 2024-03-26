// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol" ;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol" ;

contract MITFaucet is Ownable {

    IERC20 public token ;

    uint256 public timeSpace = 1 days ;

    // address => claim time
    mapping(address => uint256) public accountTime ;

    // grade => amount
    mapping(uint256 => uint256) public gradeAmount ;

    // account => grade
    mapping(address => uint256) public accountGrade ;

    constructor(address mitAddr) {
        token = IERC20(mitAddr) ;
    }

    function setAccountGrade(address [] memory account, uint256 [] memory grades) external onlyOwner {
        for(uint256 i = 0; i < account.length; i++) {
            accountGrade[ account[i] ] = grades[i] ;
        }
    }

    function setGradeAmount(uint256 [] memory grades, uint256 [] memory amounts) external onlyOwner {
        for(uint256 i = 0; i < grades.length; i++) {
            gradeAmount[ grades[i] ] = amounts[i] ;
        }
    }

    function setTimespace(uint256 _timeSpace) external onlyOwner {
        timeSpace = _timeSpace ;
    }

    function faucet() external {
        require(block.timestamp - accountTime[_msgSender()] > timeSpace, "faucet too frequently") ;
        uint256 grade = accountGrade[_msgSender()] ;
        uint256 amount = gradeAmount[ grade ] ;
        require(amount > 0, "Insufficient test token collection quota") ;
        uint256 balance = token.balanceOf(address (this)) ;
        require(balance >= amount, "faucet amount insufficient") ;
        token.transfer(_msgSender(), amount) ;
        accountTime[_msgSender()] = block.timestamp ;
    }
}
