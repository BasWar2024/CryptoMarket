// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol" ;
import "@openzeppelin/contracts/access/Ownable.sol" ;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol" ;
interface IVeMIT is IERC20 {
    function mint(address to, uint256 amount) external ;
    function burnFrom(address account, uint256 amount) external ;
}
