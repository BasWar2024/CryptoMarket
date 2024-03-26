// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol" ;
import "@openzeppelin/contracts/security/Pausable.sol" ;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol" ;
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol" ;
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "../MITNFT/IMITNft.sol" ;
import "../Common/MyMath.sol";

contract NFTStakingMIT2 is Pausable, ReentrancyGuard, AccessControlEnumerable, IERC721Receiver {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    enum KIND { NONE, SPACESHIP, HERO, DEFENSIVEFACILITY, SUIT }

    using MyMath for uint256 ;

    // MIT token contract address
    IERC20 public MITToken ;

    // Spaceship contract
    IMITNft public spaceship ;

    // DefensiveFacility contract
    IMITNft public defensiveFacility ;

    // hero contract
    IMITNft public hero ;

    // hash rate
    uint256 [] public hashRate = [10, 20, 45, 100, 250];

    // active start
    uint256 public start ;

    // active end
    uint256 public end ;

    // block reward
    uint256 public rewardRate = 0.02 ether;

    // owner rate
    mapping(address => uint256) public ownerHashRate ;

    // owner reward
    mapping(address => uint256) public ownerReward ;

    // owner => Last settlement reward
    mapping(address => uint256) public ownerLastAllRewardToken ;

    // owner aleadly claimed reward
    mapping(address => uint256) public ownerClaimedReward ;

    // KIND => (tokenId => quality)
    mapping(KIND => mapping(uint256 => uint256)) public kindNftQuality ;

    // address => count
    mapping(address => uint256) public ownerNftCount ;

    // total rate
    uint256 public totalHashRate ;

    // lastUpdateRewardTime
    uint256 public lastUpdateRewardTime = 0;
    uint256 public lastAllRewardToken = 0 ;

    // nft record
    mapping(KIND => mapping(uint256 => address)) public stakingNftOwner ;

    ////////////////////////////////////////////////////////////
    //                      events
    ////////////////////////////////////////////////////////////
    event nftStake2Event(uint256 [] sTids, uint256 [] dTids, uint256 [] hTids, address owner) ;
    event nftUnStake2Event(uint256 [] sTids, uint256 [] dTids, uint256 [] hTids, address owner) ;
    event MITClaimEvent2(address owner,uint256 current, uint256 claimed) ;

    constructor(address MITTokenAddr, address spaceshipAddr, address defensiveFacilityAddr, address heroAddr,uint256 _start,uint256 _end) {
        MITToken = IERC20(MITTokenAddr) ;
        spaceship = IMITNft(spaceshipAddr) ;
        defensiveFacility = IMITNft(defensiveFacilityAddr) ;
        hero = IMITNft(heroAddr) ;
        start = _start ;
        end = _end ;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    function setNftAddr(address spaceshipAddr, address defensiveFacilityAddr, address heroAddr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        spaceship = IMITNft(spaceshipAddr) ;
        defensiveFacility = IMITNft(defensiveFacilityAddr) ;
        hero = IMITNft(heroAddr) ;
    }

    function setHashRate(uint256 [] memory newHashRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        hashRate = newHashRate ;
    }

    function setStart(uint256 sTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        start = sTime ;
    }

    function setEnd(uint256 eTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        end = eTime ;
    }

    function setRewardRate(uint256 newReward) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardRate = newReward ;
    }

    function setMitTokenAddr(address mitAddr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        MITToken = IERC20(mitAddr) ;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function onERC721Received(address, address , uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function decodeGene(uint256 gene) private pure returns (uint16 [] memory) {
        // quality-race-style
        uint16 [] memory rst = new uint16[](3);
        for(uint256 i = 0; i < 3; i++) {
            rst[2 - i] = uint16(gene & uint256(type(uint16).max));
            gene = gene >> 16;
        }
        return rst;
    }

    modifier updateReward() {
        (uint256 currentRewardTime, uint256 lastAllReward, uint256 currentReward) = calReward(_msgSender()) ;
        lastUpdateRewardTime = currentRewardTime ;
        lastAllRewardToken = lastAllReward ;
        ownerLastAllRewardToken[_msgSender()] = lastAllReward ;
        uint256 accountSrcReward = ownerReward[_msgSender()] ;
        ownerReward[_msgSender()] = currentReward.add(accountSrcReward, "account mint token amount calculation error!") ;
        _;
    }

    function calReward(address owner) private view returns(uint256, uint256, uint256){
        uint256 currentRewardTime = (end == 0 || block.number < end) ? block.number : end ;
        uint256 lastUpRewardTime = lastUpdateRewardTime < start ? start : lastUpdateRewardTime ;
        uint256 timeSpace = currentRewardTime.sub(lastUpRewardTime, "Time interval calculation error!") ;

        uint256 lastAllReward = 0 ;
        uint256 currentReward = 0 ;
        if(totalHashRate > 0) {
            uint256 lastMintAmount = (timeSpace.mul(rewardRate, "mint token amount calculation error!")
            .mul(1e18, "Accuracy expansion failure!"))
            .div(totalHashRate, "div total Hash Rate calculation error!");
            lastAllReward = lastAllRewardToken.add(lastMintAmount, "sum mint token amount calculation error!") ;
            uint256 accountCount = ownerHashRate[owner];
            uint256 accountMintSub = lastAllReward.sub(ownerLastAllRewardToken[owner], "account mint token amount calculation error!") ;
            currentReward = accountCount.mul(accountMintSub, "account current mint token amount calculation error!").div(1e18, "Accuracy expansion failure!") ;
        }
        return (currentRewardTime, lastAllReward, currentReward);
    }

    function nftStake2(uint256 [] memory sTids, uint256 [] memory dTids, uint256 [] memory hTids) external whenNotPaused nonReentrant updateReward {
        require(end == 0 || block.number < end, "The pledge has ended") ;
        require((sTids.length > 0 || dTids.length > 0 || hTids.length > 0), "tIds has empty") ;

        // check MITToken info
        uint256 newHashRate = 0 ;
        newHashRate += checkNFTGensAndOwner(sTids, spaceship, KIND.SPACESHIP) ;
        newHashRate += checkNFTGensAndOwner(dTids, defensiveFacility, KIND.DEFENSIVEFACILITY) ;
        newHashRate += checkNFTGensAndOwner(hTids, hero, KIND.HERO) ;

        // transfer
        transferNft(spaceship, _msgSender(), address (this), sTids) ;
        transferNft(defensiveFacility, _msgSender(), address(this), dTids) ;
        transferNft(hero, _msgSender(), address(this), hTids) ;

        // update store
        ownerHashRate[_msgSender()] += newHashRate ;
        totalHashRate += newHashRate ;

        for(uint256 i = 0; i < sTids.length; i++) {
            stakingNftOwner[KIND.SPACESHIP][sTids[i]] = _msgSender() ;
        }

        for(uint256 i = 0; i < dTids.length; i++) {
            stakingNftOwner[KIND.DEFENSIVEFACILITY][dTids[i]] = _msgSender() ;
        }

        for(uint256 i = 0; i < hTids.length; i++) {
            stakingNftOwner[KIND.HERO][hTids[i]] = _msgSender() ;
        }

        ownerNftCount[_msgSender()] += sTids.length ;
        ownerNftCount[_msgSender()] += dTids.length ;
        ownerNftCount[_msgSender()] += hTids.length ;

        emit nftStake2Event(sTids, dTids, hTids, _msgSender()) ;
    }

    function transferNft(IMITNft nft,address from, address to, uint256 [] memory tIds) private {
        if(tIds.length < 1) {
            return ;
        }
        bool isOk = nft.safeBatchTransferFrom(from, to, tIds) ;
        require(isOk, "nft transfer fail") ;
    }

    function checkNFTGensAndOwner(uint256 [] memory tIds, IMITNft nft, KIND kind) private returns(uint256){
        if(tIds.length < 1) {
            return 0;
        }
        (uint256 [] memory genes, address [] memory owners) = nft.getNftOwnerGensByIds(tIds) ;
        require(genes.length == owners.length, "nft owner has not equal") ;
        uint256 hashRateVal = 0 ;
        for(uint256 i = 0; i < genes.length; i++) {
            // check
            require(owners[i] == _msgSender(), "caller is not the owner") ;
            uint16 [] memory gene = decodeGene(genes[i]) ;
            require(genes[i] > 0 && gene[ 0 ] > 0 && hashRate[ gene[ 0 ] - 1] > 0, "quality mismatching") ;
            hashRateVal += hashRate[ gene[ 0 ] - 1] ;
            kindNftQuality[kind][tIds[i]] = gene[ 0 ] ;
        }
        return hashRateVal;
    }

    function nftUnStake2(uint256 [] memory sTids, uint256 [] memory dTids, uint256 [] memory hTids) external whenNotPaused nonReentrant updateReward {
        require((sTids.length > 0 || dTids.length > 0 || hTids.length > 0), "tIds has empty") ;

        // check owner
        uint256 subHashRate = 0;
        subHashRate += checkNftOwner(KIND.SPACESHIP, sTids) ;
        subHashRate += checkNftOwner(KIND.DEFENSIVEFACILITY, dTids) ;
        subHashRate += checkNftOwner(KIND.HERO, hTids) ;

        // store hashRate
        totalHashRate -= subHashRate ;
        ownerHashRate[_msgSender()] -= subHashRate ;

        // back nft
        transferNft(spaceship, address (this), _msgSender(), sTids) ;
        transferNft(defensiveFacility, address (this), _msgSender(), dTids) ;
        transferNft(hero, address (this), _msgSender(), hTids) ;

        // back mit reward
        _claim() ;

        // clear nft owner rate
        for(uint256 i = 0; i < sTids.length; i++) {
            delete stakingNftOwner[KIND.SPACESHIP][sTids[i]] ;
        }

        for(uint256 i = 0; i < dTids.length; i++) {
            delete stakingNftOwner[KIND.DEFENSIVEFACILITY][dTids[i]] ;
        }

        for(uint256 i = 0; i < hTids.length; i++) {
            delete stakingNftOwner[KIND.HERO][hTids[i]] ;
        }

        ownerNftCount[_msgSender()] -= sTids.length ;
        ownerNftCount[_msgSender()] -= dTids.length ;
        ownerNftCount[_msgSender()] -= hTids.length ;

        emit nftUnStake2Event(sTids, dTids, hTids, _msgSender()) ;
    }

    function _claim() private {
        if(ownerReward[_msgSender()] > 0) {
            bool isOk = MITToken.transfer(_msgSender(), ownerReward[_msgSender()]) ;
            require(isOk, "MIT transfer failed") ;
            ownerClaimedReward[_msgSender()] += ownerReward[_msgSender()];
            emit MITClaimEvent2(_msgSender(), ownerReward[_msgSender()], ownerClaimedReward[_msgSender()]) ;
            ownerReward[_msgSender()] = 0;
        }
    }

    function checkNftOwner(KIND kind, uint256 [] memory tIds) private view returns(uint256){
        uint256 subHashRate = 0;
        for(uint256 i = 0; i < tIds.length; i++) {
            require(stakingNftOwner[kind][tIds[i]] == _msgSender(), "caller is not the owner") ;
            subHashRate += hashRate[kindNftQuality[kind][tIds[i]] - 1] ;
        }
        return subHashRate ;
    }

    function nftRewardClaim2() external updateReward nonReentrant whenNotPaused {
        require(ownerLastAllRewardToken[_msgSender()] > 0, "Insufficient MIT") ;
        _claim() ;
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = MITToken.balanceOf(address (this)) ;
        require(balance > 0, "Insufficient MIT") ;
        MITToken.transfer(_msgSender(), balance) ;
    }

    function withdrawNFT(uint256 [] memory sTids, uint256 [] memory dTids, uint256 [] memory hTids) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for(uint256 i = 0; i < sTids.length; i++) {
            spaceship.transferFrom(address(this), stakingNftOwner[KIND.SPACESHIP][sTids[i]], sTids[i]) ;
        }
        for(uint256 i = 0; i < dTids.length; i++) {
            defensiveFacility.transferFrom(address(this), stakingNftOwner[KIND.DEFENSIVEFACILITY][dTids[i]], dTids[i]) ;
        }
        for(uint256 i = 0; i < hTids.length; i++) {
            hero.transferFrom(address(this), stakingNftOwner[KIND.HERO][hTids[i]], hTids[i]) ;
        }
    }

    function poolInfo(address player) external view returns(uint256,uint256,uint256,uint256,uint256) {
        (,, uint256 currentReward) = calReward(player) ;
        return (totalHashRate, ownerHashRate[player], ownerNftCount[player], ownerReward[player] + currentReward, ownerClaimedReward[player]) ;
    }

    function getHashRate() external view returns (uint256 [] memory) {
        uint256 [] memory srcHashRate = new uint256[](hashRate.length) ;
        for(uint256 i = 0; i < hashRate.length; i++) {
            srcHashRate[i] = hashRate[i] ;
        }
        return srcHashRate ;
    }
}
