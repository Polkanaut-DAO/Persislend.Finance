// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface OracleInterface {
    function getLatestPrice() external view returns (int256);
}
