// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol" ;
import "@openzeppelin/contracts/security/Pausable.sol" ;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol" ;
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol" ;

contract MITStakeOGPassNFT is Pausable, ReentrancyGuard, AccessControlEnumerable  {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    enum STAKE_STATUS { NONE, STAKE, UNSTAKE }

    // mit contract
    IERC20 public erc20Token ;

    // min stake token
    uint256 public minStakeAssert = 1000 ether ;

    // max stake token
    uint256 public maxStakeAssert = 10000 ether ;

    // start open stake
    STAKE_STATUS public stakeStatus = STAKE_STATUS.NONE;

    // stake info
    struct StakeRecord {
        // account
        address account ;

        // stake time
        uint256 stakeTime ;

        // stake amount
        uint256 amount ;
    }

    // store record
    mapping(address => StakeRecord) public accountStakeRecord;

    //////////////////////////////////////////////////
    //              events
    //////////////////////////////////////////////////
    event MITStakeOnOGNFTEvent(address owner, uint256 amount) ;
    event MITUnStakeOnOGNFTEvent(address owner, uint256 amount) ;

    constructor(address mitToken, address manager)  {
        erc20Token = IERC20(mitToken) ;
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(MANAGER_ROLE, manager);
        _setupRole(PAUSER_ROLE, manager);
    }

    // setter
    function setErc20Token(address newAddr) external onlyRole(MANAGER_ROLE) {
        erc20Token = IERC20(newAddr) ;
    }

    function setMinStake(uint256 minStake) external onlyRole(MANAGER_ROLE) {
        minStakeAssert = minStake ;
    }

    function setMaxStake(uint256 maxStake) external onlyRole(MANAGER_ROLE) {
        maxStakeAssert = maxStake ;
    }

    function setStartStake(STAKE_STATUS newStatus) external onlyRole(MANAGER_ROLE) {
        stakeStatus = newStatus ;
    }

    function pause() external virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "MITStakeOGPassNFT: must have pauser role to pause");
        _pause();
    }

    function unpause() external virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "MITStakeOGPassNFT: must have pauser role to unpause");
        _unpause();
    }

    function stake(uint256 amount) whenNotPaused nonReentrant external {
        require(stakeStatus == STAKE_STATUS.STAKE, "Stake status invalid") ;
        require((amount % 1 ether) == 0, "Stake amount accuracy is incorrect (minimum 1 MIT)") ;
        require(accountStakeRecord[_msgSender()].amount >= minStakeAssert || amount >= minStakeAssert, "Not enough collateral tokens") ;
        require((accountStakeRecord[_msgSender()].amount + amount) <= maxStakeAssert, "Exceed the maximum collateral amount") ;

        // transfer mit
        bool isOK = erc20Token.transferFrom(_msgSender(), address(this), amount) ;
        require(isOK, "transfer mit failed") ;

        if(accountStakeRecord[_msgSender()].amount > 0) {
            accountStakeRecord[_msgSender()].amount += amount ;
        } else {
            accountStakeRecord[_msgSender()] = StakeRecord({ account: _msgSender(), stakeTime: block.timestamp, amount: amount }) ;
        }
        emit MITStakeOnOGNFTEvent(_msgSender(), amount) ;
    }

    function unStake() whenNotPaused nonReentrant external {
        require(stakeStatus == STAKE_STATUS.UNSTAKE, "UnStake status invalid") ;
        require(accountStakeRecord[_msgSender()].amount > 0, "There is no record of the pledge") ;

        // transfer
        uint256 amount = accountStakeRecord[_msgSender()].amount ;
        erc20Token.transfer(_msgSender(), amount) ;

        // delete recode
        delete accountStakeRecord[_msgSender()] ;
        emit MITUnStakeOnOGNFTEvent(_msgSender(), amount) ;
    }

}