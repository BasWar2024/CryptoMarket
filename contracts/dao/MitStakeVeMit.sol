// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol" ;
import "@openzeppelin/contracts/security/Pausable.sol" ;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol" ;
import "@openzeppelin/contracts/access/Ownable.sol" ;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol" ;
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol" ;
import "../Common/MyMath.sol";
import "./IVeMIT.sol";

contract MitStakeVeMit is Pausable, ReentrancyGuard, Ownable, EIP712 {
    IERC20 public mitToken ;
    IVeMIT public veMitToken ;

    using MyMath for uint256 ;
    struct Config {
        uint64 spaceTime ;
        uint256 veMitRate ;
        bool active ;
    }
    Config [] public configs ;

    struct Wallet{
        address owner ;
        uint256 amount ;
        uint64 releaseTime ;
        uint256 cId ;
        uint256 claimed ;
    }
    Wallet [] public wallets ;
    mapping(address => bool) public signers ;

    uint256 public totalReward = 30000 ether;
    uint64 public  timespace ;
    uint256 public rewardRate ;
    uint256 public end ;
    uint256 public speed = 3 ;
    uint256 public lastUpdateRewardTime ;
    uint256 public total ;
    uint256 public lastAllRewardToken ;
    mapping(address => uint256) public ownerTokenAmount ;
    mapping(address => uint256) public ownerReward ;
    mapping(address => uint256) public accountLastAllRewardToken ;
    mapping(address => uint256) public ownerRewardClaim ;

    modifier onlySigner() {
        require(signers[_msgSender()], "onlySigner: caller is not the sign");
        _;
    }

    ////////////////////////////////////////////
    //               events
    ////////////////////////////////////////////
    event StakeVeMitEvent(address owner, uint256 cId, uint256 amount, uint256 veAmount, uint256 wId, uint256 start, uint256 end) ;
    event UnStakeVeMitEvent(address owner, uint256 total, uint256 claimed, uint256 current, uint256 wId, uint256 burnVe) ;
    event ClaimVeMitRewardEvent(address owner, uint256 claimed, uint256 totalClaimed) ;
    event VeMitConfigEvent(Config config, uint256 cId) ;

    constructor(address mitTokenAddr, address veMitTokenAddr, address signAddr, uint256 _totalReward, uint64 _timespace) EIP712("MitStakeVeMit", "v1.0.0"){
        mitToken = IERC20(mitTokenAddr) ;
        veMitToken = IVeMIT(veMitTokenAddr) ;
        signers[signAddr] = true ;
        totalReward = _totalReward ;
        timespace = _timespace ;
        calRewardRate() ;
    }

    modifier updateReward {
        if(lastUpdateRewardTime == 0){
            end = block.timestamp + timespace ;
        }
        (uint256 allRewardToken, uint256 ownerRewardLast, uint256 updateRewardTime) = rewardBalance(_msgSender()) ;
        lastUpdateRewardTime = updateRewardTime ;
        lastAllRewardToken = allRewardToken ;
        ownerReward[_msgSender()] = ownerRewardLast ;
        accountLastAllRewardToken[_msgSender()] = allRewardToken;
        _;
    }

    function calRewardRate() public onlyOwner {
        rewardRate = totalReward.mul(speed, "time speed fail").div(timespace, "cal reward fail") ;
    }

    function setRewardParam(uint256 _totalReward, uint64 _timespace, uint256 _speed) external onlyOwner {
        totalReward = _totalReward ;
        timespace = _timespace ;
        speed = _speed ;
        calRewardRate() ;
    }

    function rewardBalance(address owner) private view returns(uint256,uint256, uint256) {
        if(lastUpdateRewardTime == 0) {
            return (lastAllRewardToken, ownerReward[owner], block.timestamp);
        } else {
            if(block.timestamp > end) {
                return (lastAllRewardToken, ownerReward[owner], lastUpdateRewardTime);
            }
            uint256 timeSpace = (block.timestamp.sub(lastUpdateRewardTime, "Time interval calculation error!")).div(speed, "cal block count Fail") ;

            uint256 lastMintAmount = (timeSpace.mul(rewardRate, "mint token amount calculation error!")
            .mul(1e18, "Accuracy expansion failure!"))
            .div(total, "div total NFT count calculation error!");

            uint256 accountCount = ownerTokenAmount[owner];
            uint256 allRewardToken = lastAllRewardToken.add(lastMintAmount, "sum mint token amount calculation error!") ;
            uint256 accountMintSub = allRewardToken.sub(accountLastAllRewardToken[owner], "account mint token amount calculation error!") ;
            uint256 currentReward = accountCount.mul(accountMintSub, "account current mint token amount calculation error!").div(1e18, "Accuracy expansion failure!") ;
            uint256 ownerReward1 = currentReward.add(ownerReward[owner], "account mint token amount calculation error!") ;
            return (allRewardToken, ownerReward1, block.timestamp);
        }
    }

    function setSign(address signAddr, bool status) external onlyOwner {
        signers[signAddr] = status ;
    }

    function setAddr(address mitTokenAddr, address veMitTokenAddr) external onlyOwner {
        mitToken = IERC20(mitTokenAddr) ;
        veMitToken = IVeMIT(veMitTokenAddr) ;
    }

    function batchAddCfg(Config [] memory cfgs) external onlySigner {
        for(uint256 i = 0; i < cfgs.length; i++) {
            configs.push(cfgs[i]) ;
            emit VeMitConfigEvent(cfgs[i], configs.length - 1) ;
        }
    }

    function setCfg(uint256 cId, Config memory cfg) external onlySigner {
        configs[cId] = cfg ;
    }

    function stakeVeMit(uint256 cId, uint256 amount) external whenNotPaused nonReentrant updateReward {
        require(configs[cId].veMitRate > 0, "Staking pool parameters are incorrect") ;
        require(configs[cId].active, "mining pool failure") ;
        require(amount % 1 ether == 0, "Staking amount must be an integer number of MIT") ;

        // transfer
        bool isOk = mitToken.transferFrom(_msgSender(), address (this), amount) ;
        require(isOk, "Mit transfer fail") ;

        wallets.push(Wallet({
            owner: _msgSender(),
            amount: amount,
            releaseTime: uint64(block.timestamp) + configs[cId].spaceTime,
            cId: cId,
            claimed: 0
        })) ;

        // transfer veMitToken
        uint256 veMitAmount = amount.mul(configs[cId].veMitRate, "veMit token amount cal fail") ;
        veMitToken.mint(_msgSender(), veMitAmount) ;

        total = total.add(amount, "stake total amount Fail") ;
        ownerTokenAmount[_msgSender()] = ownerTokenAmount[_msgSender()].add(amount, "stake owner total Fail") ;
        emit StakeVeMitEvent(_msgSender(), cId, amount, veMitAmount, wallets.length - 1, block.timestamp, uint64(block.timestamp) + configs[cId].spaceTime) ;
    }

    function unStakeVeMit(uint256 [] memory wIds, uint256 [] memory amounts, bytes memory signature) external updateReward whenNotPaused nonReentrant {
        require(wIds.length > 0 && wIds.length == amounts.length, "Unstaking parameters are incorrect") ;

        // checkSign
        checkUnStakeVeMitSign(wIds, amounts, signature) ;

        uint256 burnVeMitAmount = 0 ;
        uint256 backMitAmount = 0 ;

        for(uint256 i = 0; i < wIds.length; i++) {
            require(wallets[wIds[i]].releaseTime > 0 && wallets[wIds[i]].releaseTime <= block.timestamp, "Not yet available time") ;
            require(wallets[wIds[i]].owner == _msgSender(), "caller is not the owner") ;
            require(wallets[wIds[i]].amount >= wallets[wIds[i]].claimed + amounts[i], "Exceed the available quantity") ;
            wallets[wIds[i]].claimed += amounts[i] ;
            uint256 cBurnVeMit = amounts[i].mul(configs[wallets[wIds[i]].cId].veMitRate, "cal burn VeMit token amount Fail") ;
            emit UnStakeVeMitEvent(_msgSender(), wallets[i].amount, wallets[i].claimed, amounts[i], wIds[i], cBurnVeMit) ;
            backMitAmount += amounts[i] ;
            burnVeMitAmount += cBurnVeMit;
        }

        // back reward
        _claim(_msgSender()) ;

        // back token
        bool isOk = mitToken.transfer(_msgSender(), backMitAmount) ;
        require(isOk, "Mit token back Fail") ;
        veMitToken.burnFrom(_msgSender(), burnVeMitAmount) ;

        // store
        total = total.sub(backMitAmount, "unstake mit token total fail") ;
        ownerTokenAmount[_msgSender()] = ownerTokenAmount[_msgSender()].sub(backMitAmount, "unstake mit token owner amount fail") ;
    }

    function checkUnStakeVeMitSign(uint256 [] memory wIds, uint256 [] memory amounts, bytes memory signature) public view {
        // cal hash
        bytes memory encodeData = abi.encode(
            keccak256(abi.encodePacked("UnStakeVeMit(uint256[] wIds,uint256[] amounts,address owner)")),
            keccak256(abi.encodePacked(wIds)),
            keccak256(abi.encodePacked(amounts)),
            _msgSender()
        ) ;

        (bool success,) = checkSign(encodeData, signature) ;
        require(success, "UnStakeVeMit: The operation permission is wrong") ;
    }

    function checkSign(bytes memory encodeData, bytes memory signature)
    internal view whenNotPaused returns(bool, address){
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(_hashTypedDataV4(keccak256(encodeData)), signature);
        return (signers[recovered] && error == ECDSA.RecoverError.NoError, recovered) ;
    }

    function claimReward() external updateReward whenNotPaused nonReentrant {
        require(ownerReward[_msgSender()] > 0, "Insufficient funds to withdraw") ;
        _claim(_msgSender()) ;
    }

    function _claim(address owner) private {
        if(ownerReward[owner] > 0) {
            uint256 balance = ownerReward[owner] ;
            bool isOk = mitToken.transfer(owner, balance) ;
            require(isOk, "back reward mit transfer fail") ;
            ownerRewardClaim[owner] = ownerRewardClaim[owner].add(balance, "cal claim reward Fail") ;
            ownerReward[owner] = 0;
            emit ClaimVeMitRewardEvent(owner, balance, ownerRewardClaim[owner]) ;
        }
    }

    function stakeInfo(address player) external view returns(uint256, uint256, uint256, uint256, uint256){
        (,uint256 currentReward,uint256 time) = rewardBalance(player) ;
        return (total, ownerTokenAmount[player], currentReward, ownerRewardClaim[player], time) ;
    }

    function chanageWallet(uint256 [] memory wIds, address srcAddr, address newAddr) external onlyOwner {
        require(wIds.length > 0, "wIds params has not empty") ;
        for(uint256 i = 0; i < wIds.length; i++) {
            require(wallets[wIds[i]].owner == srcAddr, "You are not the owner of this pledge record") ;
            wallets[wIds[i]].owner = newAddr ;
        }

        ownerTokenAmount[newAddr] = ownerTokenAmount[srcAddr] ;
        ownerReward[newAddr] = ownerReward[srcAddr] ;
        accountLastAllRewardToken[newAddr] = accountLastAllRewardToken[srcAddr] ;
        ownerRewardClaim[newAddr]= ownerRewardClaim[srcAddr] ;

        // VeMIT transfer
        uint256 balance = veMitToken.balanceOf(srcAddr) ;
        bool isOk = veMitToken.transferFrom(srcAddr, newAddr, balance) ;
        require(isOk, "transfer VeMit fail") ;
    }

    function withdraw() external onlyOwner {
        uint256 balance = mitToken.balanceOf(address(this)) ;
        require(balance > 0, "No mit available for extraction") ;
        mitToken.transfer(_msgSender(), balance) ;
    }

    function walletLen() external view returns(uint256) {
        return wallets.length ;
    }

    function dfgLen() external view returns(uint256) {
        return configs.length ;
    }


}
