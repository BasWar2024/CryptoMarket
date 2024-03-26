// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol" ;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol" ;
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol" ;
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol" ;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol" ;
import "./IVeMIT.sol";
import "../Common/MyMath.sol";

contract GalaxyDao is Pausable, ReentrancyGuard, EIP712,Ownable {
    using MyMath for uint256 ;
    IVeMIT public veMitToken ;
    uint256 public minVeMitAmount ;

    struct Proposal {
        uint256 id ;
        address owner ;
        uint64 start ;
        uint64 end ;
        bool active ;
    }
    Proposal [] public allProposals ;

    modifier onlySigner() {
        require(signers[_msgSender()], "onlySigner: caller is not the sign");
        _;
    }

    ///////////////////////////////////////////////
    //                  events
    ///////////////////////////////////////////////
    event CreateProposalEvent(address owner, uint256 start, uint256 end, uint256 id, uint256 pId) ;
    event CancelProposalEvent(address owner, address operator, uint256 id) ;
    event VoteEvent(address owner, uint256 id, uint256 item, uint256 voteShare, uint256 totalVote) ;

    // pId => index
    mapping(uint256 => uint256) public idIndex ;

    // (pId => (owner => vote count)
    mapping(uint256 => mapping(address => uint256)) public ownerVotes;

    // (sign => bool)
    mapping(address => bool) public signers ;

    // (id => exists)
    mapping(uint256 => bool) public idHasExists ;

    // (proposal => (item => voter count))
    mapping(uint256 => mapping(uint256 => uint256)) public recordProposalVoter ;

    constructor(address veMitTokenAddr, uint256 _minVeMitAmount, address sign) EIP712("GalaxyDao", "v1.0.0") {
        veMitToken = IVeMIT(veMitTokenAddr) ;
        minVeMitAmount = _minVeMitAmount ;
        signers[sign] = true;
    }

    function setVeMit(address veMitTokenAddr) external onlyOwner {
        veMitToken = IVeMIT(veMitTokenAddr) ;
    }

    function setMinVeMitAmount(uint256 newMinVeAmount) external onlyOwner {
        minVeMitAmount = newMinVeAmount ;
    }

    function setSign(address newSign, bool status) external onlyOwner {
        signers [newSign] = status ;
    }

    function createProposalOfficial(uint256 id, uint64 start, uint64 end) external onlySigner {
        _createProposal(id, start, end) ;
    }

    function createProposal(uint256 id, uint64 start, uint64 end, bytes memory signature) external {
        uint256 balance = veMitToken.balanceOf(_msgSender()) ;
        require(balance >= minVeMitAmount, "Insufficient voting rights required for the proposal") ;
        checkCreateProposalSign(id, start, end, signature) ;
        _createProposal(id, start, end) ;
    }

    function _createProposal(uint256 id, uint64 start, uint64 end) private whenNotPaused {
        require(idHasExists[id] == false, "Proposal Duplicate Submission") ;
        idIndex[id] = allProposals.length ;
        idHasExists[id] = true ;
        allProposals.push(Proposal({
            id: id,
            owner: _msgSender(),
            start: start,
            end: end,
            active: true
        })) ;

        emit CreateProposalEvent(_msgSender(), start, end, id, allProposals.length - 1) ;
    }

    function cancelProposal(uint256 [] memory ids) external {
        for(uint256 i = 0; i < ids.length; i++) {
            Proposal memory proposal = allProposals[idIndex[ids[i]]] ;
            require(proposal.owner == _msgSender() || signers[_msgSender()], "caller is not the owner") ;
            allProposals[idIndex[ids[i]]].active = false ;
            emit CancelProposalEvent(proposal.owner, _msgSender(), ids[i]) ;
        }
    }

    function vote(uint256 id, uint256 item, bytes memory signature) external whenNotPaused {
        Proposal memory proposal = allProposals[idIndex[id]] ;
        require(proposal.active, "Proposal has been suspended") ;
        require(block.timestamp >= proposal.start, "Proposal voting has not yet opened") ;
        require(block.timestamp <= proposal.end, "Proposal voting has closed") ;
        uint256 balance = veMitToken.balanceOf(_msgSender()) ;
        require(balance > ownerVotes[id][_msgSender()], "You do not have voting rights") ;
        uint256 voteShare = balance - ownerVotes[id][_msgSender()] ;
        checkVoteSign(id, item, signature) ;

        ownerVotes[id][_msgSender()] = balance ;
        recordProposalVoter[idIndex[id]][item] = recordProposalVoter[idIndex[id]][item].add(voteShare, "Error in counting votes") ;
        emit VoteEvent(_msgSender(), id, item, voteShare, balance) ;
    }

    function checkCreateProposalSign(uint256 id, uint64 start, uint64 end, bytes memory signature ) private view {
        // cal hash
        bytes memory encodeData = abi.encode(
            keccak256(abi.encodePacked("createProposal(uint256 id,uint64 start,uint64 end,address owner)")),
            id,
            start,
            end,
            _msgSender()
        ) ;

        (bool success,) = checkSign(encodeData, signature) ;
        require(success, "createProposal: The operation permission is wrong") ;
    }

    function checkVoteSign(uint256 id, uint256 item, bytes memory signature) private view {
        // cal hash
        bytes memory encodeData = abi.encode(
            keccak256(abi.encodePacked("VoteSign(uint256 id,uint256 item,address owner)")),
            id,
            item,
            _msgSender()
        ) ;

        (bool success,) = checkSign(encodeData, signature) ;
        require(success, "VoteSign: The operation permission is wrong") ;
    }

    function checkSign(bytes memory encodeData, bytes memory signature)
    internal view whenNotPaused returns(bool, address){
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(_hashTypedDataV4(keccak256(encodeData)), signature);
        return (signers[recovered] && error == ECDSA.RecoverError.NoError, recovered) ;
    }

    function proposalLen() external view returns(uint256) {
        return allProposals.length ;
    }

}
