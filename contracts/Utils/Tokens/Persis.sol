//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract Persis is ERC20 {
    constructor() ERC20("PERSIS", "PERSIS", 18) {}
}
