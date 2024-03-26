// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol" ;
import "@openzeppelin/contracts/security/Pausable.sol" ;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol" ;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol" ;
import "../Common/MyMath.sol";

contract BuyBack is AccessControlEnumerable, Pausable, ReentrancyGuard {

    IERC20 public MitToken ;
    IERC20 public USDTToken ;
    uint256 public price ;
    using MyMath for uint256 ;

    constructor(uint256 _price, IERC20 _MitToken,IERC20 _USDTToken) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        price = _price ;
        MitToken = _MitToken ;
        USDTToken = _USDTToken ;
    }

    function setMitToken(IERC20 newMitToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        MitToken = newMitToken ;
    }

    function setUSDTToken(IERC20 newUSDTToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        USDTToken = newUSDTToken ;
    }

    function setPrice(uint256 newPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        price = newPrice ;
    }

    // pause
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause() ;
    }

    // unpause
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause() ;
    }

    function withdrawMit() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 mitBalance = MitToken.balanceOf(address(this)) ;
        if(mitBalance > 0) {
            MitToken.transfer(_msgSender(), mitBalance) ;
        }
    }

    function withdrawUSDT() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 usdtBalance = USDTToken.balanceOf(address(this)) ;
        if(usdtBalance > 0) {
            USDTToken.transfer(_msgSender(), usdtBalance) ;
        }
    }

    function sell(uint256 amount) nonReentrant whenNotPaused external {
        // save transfer
        bool isOk = MitToken.transferFrom(_msgSender(), address(this), amount) ;
        require(isOk, "MIT token Transfer Failed") ;

        uint256 backUsdt = (amount.mul(price, "token price calculation error[mul]")).div(1 ether, "token price calculation error[div]") ;
        isOk = USDTToken.transfer(_msgSender(), backUsdt) ;
        require(isOk, "USDT token Transfer Failed") ;
    }
}
