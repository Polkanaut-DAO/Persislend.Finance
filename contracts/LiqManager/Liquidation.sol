// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../Core/Contracts/Manager.sol";

contract LiquidateManager {
    address payable owner;

    uint256 constant unifiedPoint = 10**18;

    Manager public ManagerContract;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = payable(msg.sender);
    }

    function setManagerContract(address _ManagerContract)
        external
        onlyOwner
        returns (bool)
    {
        ManagerContract = Manager(_ManagerContract);
        return true;
    }

    function checkLiquidation(address payable userAddr)
        external
        view
        returns (bool)
    {
        return _checkLiquidation(userAddr);
    }

    function _checkLiquidation(address payable userAddr)
        internal
        view
        returns (bool)
    {
        uint256 userBorrowAssetSum;
        uint256 liquidationLimitAssetSum;
        uint256 tokenListLength = ManagerContract.marketsLength();

        // we loop over all markets and get user deposit, user borrow, user margincall !
        // and add them to liquidationLimitAssetSum;
        for (uint256 ID; ID < tokenListLength; ID++) {
            if (ManagerContract.getMarketSupport(ID)) {
                uint256 depositAsset;
                uint256 borrowAsset;
                (depositAsset, borrowAsset) = ManagerContract
                    .getUpdatedInterestAmountsForUser(userAddr, ID);

                uint256 marginCallLimit = ManagerContract
                    .getMarketMarginCallLevel(ID);

                liquidationLimitAssetSum = add(
                    liquidationLimitAssetSum,
                    unifiedMul(depositAsset, marginCallLimit)
                );
                userBorrowAssetSum = add(userBorrowAssetSum, borrowAsset);
            }
        }

        // now we have user total borrowed ! and user total margin call lim or assets limit;
        // if user total borrowed become more than user liquidation limit, user should get red cart !

        if (liquidationLimitAssetSum <= userBorrowAssetSum) {
            return true;
            /* Margin call */
        }

        return false;
    }

    /* ******************* Safe Math ******************* */

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "add overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return _sub(a, b, "sub overflow");
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return _mul(a, b);
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return _div(a, b, "div by zero");
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return _mod(a, b, "mod by zero");
    }

    function _sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    function _mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require((c / a) == b, "mul overflow");
        return c;
    }

    function _div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    function _mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }

    function unifiedDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return _div(_mul(a, unifiedPoint), b, "unified div by zero");
    }

    function unifiedMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return _div(_mul(a, b), unifiedPoint, "unified mul by zero");
    }
}
