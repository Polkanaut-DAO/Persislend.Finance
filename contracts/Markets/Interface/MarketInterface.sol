// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface MarketInterface {
    function updateUserMarketInterest(address payable _userAddress)
        external
        returns (uint256, uint256);

    function getUpdatedInterestAmountsForUser(address payable _userAddress)
        external
        view
        returns (uint256, uint256);

    function getMarketMarginCallLimit() external view returns (uint256);

    function getMarketBorrowLimit() external view returns (uint256);

    function getAmounts(address payable _userAddress)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function getUserAmount(address payable _userAddress)
        external
        view
        returns (uint256, uint256);

    function getUserDepositAmount(address payable _userAddress)
        external
        view
        returns (uint256);

    function getUserBorrowAmount(address payable _userAddress)
        external
        view
        returns (uint256);

    function getMarketDepositTotalAmount() external view returns (uint256);

    function getMarketBorrowTotalAmount() external view returns (uint256);

    function updateRewardPerBlock(uint256 _rewardPerBlock)
        external
        returns (bool);

    function updateRewardManagerData(address payable _userAddress)
        external
        returns (bool);

    function getUpdatedUserRewardAmount(address payable _userAddress)
        external
        view
        returns (uint256);

    function claimRewardAmountUser(address payable userAddr)
        external
        returns (uint256);
}
