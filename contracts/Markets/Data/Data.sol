// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract MarketData {
    // address payable Owner;

    address MarketContract;
    address InterestModelContract;

    uint256 lastTimeBlockUpdated;
    uint256 inactiveBlocks;

    uint256 acDepositEXR;
    uint256 acBorrowEXR;

    uint256 glDepositEXR;
    uint256 glBorrowEXR;

    uint256 marketDepositTotalAmount;
    uint256 marketBorrowTotalAmount;

    uint256 constant startPoint = 10**18;
    uint256 public liquidityLimit = startPoint;
    uint256 public limitOfAction = 100000 * startPoint;

    struct MarketInterestModel {
        uint256 _marketBorrowLimit;
        uint256 _marketMarginCallLimit;
        uint256 _marketMinInterestRate;
        uint256 _marketLiquiditySen;
    }
    MarketInterestModel MarketInterestModelInstance;

    struct UserModel {
        bool _userIsAccessed;
        uint256 _userDepositAmount;
        uint256 _userBorrowAmount;
        uint256 _userDepositEXR;
        uint256 _userBorrowEXR;
    }
    mapping(address => UserModel) UserModelMapping;

    // modifier OnlyOwner() {
    //     require(msg.sender == Owner, "OnlyOwner");
    //     _;
    // }

    // modifier OnlyMyContracts() {
    //     address msgSender = msg.sender;
    //     require(
    //         (msgSender == MarketContract) ||
    //             (msgSender == InterestModelContract) ||
    //             (msgSender == Owner)
    //     );
    //     _;
    // }

    constructor(
        uint256 _borrowLimit,
        uint256 _marginCallLimit,
        uint256 _minimumInterestRate,
        uint256 _liquiditySensitivity
    ) {
        // Owner = payable(msg.sender);

        _initializeEXR();

        MarketInterestModel
            memory _MarketInterestModel = MarketInterestModelInstance;

        _MarketInterestModel._marketBorrowLimit = _borrowLimit;
        _MarketInterestModel._marketMarginCallLimit = _marginCallLimit;
        _MarketInterestModel._marketMinInterestRate = _minimumInterestRate;
        _MarketInterestModel._marketLiquiditySen = _liquiditySensitivity;
        MarketInterestModelInstance = _MarketInterestModel;
    }

    function _initializeEXR() internal {
        uint256 currectBlockNumber = block.number;
        acDepositEXR = startPoint;
        acBorrowEXR = startPoint;
        glDepositEXR = startPoint;
        glBorrowEXR = startPoint;
        lastTimeBlockUpdated = currectBlockNumber - 1;
        inactiveBlocks = lastTimeBlockUpdated;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////// SETTER FUNCTIONS

    function setMarketContract(address _MarketContract)
        external
        returns (bool)
    {
        MarketContract = _MarketContract;
        return true;
    }

    function setInterestModelContract(address _InterestModelContract)
        external
        returns (bool)
    {
        InterestModelContract = _InterestModelContract;
        return true;
    }

    function setupNewUser(address payable _userAddress)
        external
        returns (bool)
    {
        UserModelMapping[_userAddress]._userIsAccessed = true;
        UserModelMapping[_userAddress]._userDepositAmount = startPoint;
        UserModelMapping[_userAddress]._userBorrowAmount = startPoint;

        return true;
    }

    function setUserAccessed(address payable _userAddress, bool _isAccess)
        external
        returns (bool)
    {
        UserModelMapping[_userAddress]._userIsAccessed = _isAccess;

        return true;
    }

    function updateAmounts(
        address payable _userAddress,
        uint256 _marketDepositTotalAmount,
        uint256 _marketBorrowTotalAmount,
        uint256 _userDepositAmount,
        uint256 _userBorrowAmount
    ) external returns (bool) {
        marketDepositTotalAmount = _marketDepositTotalAmount;
        marketBorrowTotalAmount = _marketBorrowTotalAmount;
        UserModelMapping[_userAddress]._userDepositAmount = _userDepositAmount;
        UserModelMapping[_userAddress]._userBorrowAmount = _userBorrowAmount;

        return true;
    }

    function addAmountToTotalDeposit(uint256 _amountToAdd)
        external
        returns (bool)
    {
        marketDepositTotalAmount = add(marketDepositTotalAmount, _amountToAdd);

        return true;
    }

    function subAmountToTotalDeposit(uint256 _amountToSub)
        external
        returns (bool)
    {
        marketDepositTotalAmount = sub(marketDepositTotalAmount, _amountToSub);

        return true;
    }

    function addAmountToTotalBorrow(uint256 _amountToAdd)
        external
        returns (bool)
    {
        marketBorrowTotalAmount = add(marketBorrowTotalAmount, _amountToAdd);

        return true;
    }

    function subAmountToTotalBorrow(uint256 _amountToSub)
        external
        returns (bool)
    {
        marketBorrowTotalAmount = sub(marketBorrowTotalAmount, _amountToSub);

        return true;
    }

    function addAmountToUserDeposit(
        address payable _userAddress,
        uint256 _amountToAdd
    ) external returns (bool) {
        UserModelMapping[_userAddress]._userDepositAmount = add(
            UserModelMapping[_userAddress]._userDepositAmount,
            _amountToAdd
        );

        return true;
    }

    function subAmountToUserDeposit(
        address payable _userAddress,
        uint256 _amountToSub
    ) external returns (bool) {
        UserModelMapping[_userAddress]._userDepositAmount = sub(
            UserModelMapping[_userAddress]._userDepositAmount,
            _amountToSub
        );

        return true;
    }

    function addAmountToUserBorrow(
        address payable _userAddress,
        uint256 _amountToAdd
    ) external returns (bool) {
        UserModelMapping[_userAddress]._userBorrowAmount = add(
            UserModelMapping[_userAddress]._userBorrowAmount,
            _amountToAdd
        );

        return true;
    }

    function subAmountToUserBorrow(
        address payable _userAddress,
        uint256 _amountToSub
    ) external returns (bool) {
        UserModelMapping[_userAddress]._userBorrowAmount = sub(
            UserModelMapping[_userAddress]._userBorrowAmount,
            _amountToSub
        );

        return true;
    }

    function addDepositAmount(
        address payable _userAddress,
        uint256 _amountToAdd
    ) external returns (bool) {
        marketDepositTotalAmount = add(marketDepositTotalAmount, _amountToAdd);

        UserModelMapping[_userAddress]._userDepositAmount = add(
            UserModelMapping[_userAddress]._userDepositAmount,
            _amountToAdd
        );

        return true;
    }

    function subDepositAmount(
        address payable _userAddress,
        uint256 _amountToSub
    ) external returns (bool) {
        marketDepositTotalAmount = sub(marketDepositTotalAmount, _amountToSub);

        UserModelMapping[_userAddress]._userDepositAmount = sub(
            UserModelMapping[_userAddress]._userDepositAmount,
            _amountToSub
        );

        return true;
    }

    function addBorrowAmount(address payable _userAddress, uint256 _amountToAdd)
        external
        returns (bool)
    {
        marketBorrowTotalAmount = add(marketBorrowTotalAmount, _amountToAdd);

        UserModelMapping[_userAddress]._userBorrowAmount = add(
            UserModelMapping[_userAddress]._userBorrowAmount,
            _amountToAdd
        );

        return true;
    }

    function subBorrowAmount(address payable _userAddress, uint256 _amountToSub)
        external
        returns (bool)
    {
        marketBorrowTotalAmount = sub(marketBorrowTotalAmount, _amountToSub);

        UserModelMapping[_userAddress]._userBorrowAmount = sub(
            UserModelMapping[_userAddress]._userBorrowAmount,
            _amountToSub
        );

        return true;
    }

    function updateBlocks(
        uint256 _lastTimeBlockUpdated,
        uint256 _inactiveBlocks
    ) external returns (bool) {
        lastTimeBlockUpdated = _lastTimeBlockUpdated;
        inactiveBlocks = _inactiveBlocks;

        return true;
    }

    function setLastTimeBlockUpdated(uint256 _lastTimeBlockUpdated)
        external
        returns (bool)
    {
        lastTimeBlockUpdated = _lastTimeBlockUpdated;

        return true;
    }

    function setInactiveBlocks(uint256 _inactiveBlocks)
        external
        returns (bool)
    {
        inactiveBlocks = _inactiveBlocks;

        return true;
    }

    function syncActionGlobalEXR() external returns (bool) {
        acDepositEXR = glDepositEXR;
        acBorrowEXR = glBorrowEXR;

        return true;
    }

    function updateActionEXR(uint256 _acDepositEXR, uint256 _acBorrowEXR)
        external
        returns (bool)
    {
        acDepositEXR = _acDepositEXR;
        acBorrowEXR = _acBorrowEXR;

        return true;
    }

    function updateUserGlobalEXR(
        address payable _userAddress,
        uint256 _glDepositEXR,
        uint256 _glBorrowEXR
    ) external returns (bool) {
        glDepositEXR = _glDepositEXR;
        glBorrowEXR = _glBorrowEXR;

        UserModelMapping[_userAddress]._userDepositEXR = _glDepositEXR;
        UserModelMapping[_userAddress]._userBorrowEXR = _glBorrowEXR;

        return true;
    }

    function updateUserEXR(
        address payable _userAddress,
        uint256 _userDepositEXR,
        uint256 _userBorrowEXR
    ) external returns (bool) {
        UserModelMapping[_userAddress]._userDepositEXR = _userDepositEXR;
        UserModelMapping[_userAddress]._userBorrowEXR = _userBorrowEXR;

        return true;
    }

    function setMarketBorrowLimit(uint256 _marketBorrowLimit)
        external
        returns (bool)
    {
        MarketInterestModelInstance._marketBorrowLimit = _marketBorrowLimit;

        return true;
    }

    function setMarketMarginCallLimit(uint256 _marketMarginCallLimit)
        external
        returns (bool)
    {
        MarketInterestModelInstance
            ._marketMarginCallLimit = _marketMarginCallLimit;

        return true;
    }

    function setMinimumInterestRate(uint256 _marketMinInterestRate)
        external
        returns (bool)
    {
        MarketInterestModelInstance
            ._marketMinInterestRate = _marketMinInterestRate;

        return true;
    }

    function setMarketLiquiditySensitivity(uint256 _marketLiquiditySen)
        external
        returns (bool)
    {
        MarketInterestModelInstance._marketLiquiditySen = _marketLiquiditySen;

        return true;
    }

    function setLimitOfAction(uint256 _limitOfAction) external returns (bool) {
        limitOfAction = _limitOfAction;
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////// GETTER FUNCTIONS

    function getMarketAmounts() external view returns (uint256, uint256) {
        return (marketDepositTotalAmount, marketBorrowTotalAmount);
    }

    function getUserAmounts(address payable _userAddress)
        external
        view
        returns (uint256, uint256)
    {
        return (
            UserModelMapping[_userAddress]._userDepositAmount,
            UserModelMapping[_userAddress]._userBorrowAmount
        );
    }

    function getAmounts(address payable _userAddress)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            marketDepositTotalAmount,
            marketBorrowTotalAmount,
            UserModelMapping[_userAddress]._userDepositAmount,
            UserModelMapping[_userAddress]._userBorrowAmount
        );
    }

    function getUserEXR(address payable _userAddress)
        external
        view
        returns (uint256, uint256)
    {
        return (
            UserModelMapping[_userAddress]._userDepositEXR,
            UserModelMapping[_userAddress]._userBorrowEXR
        );
    }

    function getActionEXR() external view returns (uint256, uint256) {
        return (acDepositEXR, acBorrowEXR);
    }

    function getGlBorrowEXR() external view returns (uint256) {
        return glBorrowEXR;
    }

    function getGlDepositEXR() external view returns (uint256) {
        return glDepositEXR;
    }

    function getGlDepositBorrowEXR() external view returns (uint256, uint256) {
        return (glDepositEXR, glBorrowEXR);
    }

    function getMarketDepositTotalAmount() external view returns (uint256) {
        return marketDepositTotalAmount;
    }

    function getMarketBorrowTotalAmount() external view returns (uint256) {
        return marketBorrowTotalAmount;
    }

    function getUserDepositAmount(address payable _userAddress)
        external
        view
        returns (uint256)
    {
        return UserModelMapping[_userAddress]._userDepositAmount;
    }

    function getUserBorrowAmount(address payable _userAddress)
        external
        view
        returns (uint256)
    {
        return UserModelMapping[_userAddress]._userBorrowAmount;
    }

    function getUserIsAccessed(address payable _userAddress)
        external
        view
        returns (bool)
    {
        return UserModelMapping[_userAddress]._userIsAccessed;
    }

    function getLastTimeBlockUpdated() external view returns (uint256) {
        return lastTimeBlockUpdated;
    }

    function getInactiveBlocks() external view returns (uint256) {
        return inactiveBlocks;
    }

    function getMarketLimits() external view returns (uint256, uint256) {
        return (
            MarketInterestModelInstance._marketBorrowLimit,
            MarketInterestModelInstance._marketMarginCallLimit
        );
    }

    function getMarketBorrowLimit() external view returns (uint256) {
        return MarketInterestModelInstance._marketBorrowLimit;
    }

    function getMarketMarginCallLimit() external view returns (uint256) {
        return MarketInterestModelInstance._marketMarginCallLimit;
    }

    function getMarketMinimumInterestRate() external view returns (uint256) {
        return MarketInterestModelInstance._marketMinInterestRate;
    }

    function getMarketLiquiditySensitivity() external view returns (uint256) {
        return MarketInterestModelInstance._marketLiquiditySen;
    }

    function getMarketLiquidityLimit() external view returns (uint256) {
        return liquidityLimit;
    }

    function getMarketLimitOfAction() external view returns (uint256) {
        return limitOfAction;
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
        return _div(_mul(a, startPoint), b, "unified div by zero");
    }

    function unifiedMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return _div(_mul(a, b), startPoint, "unified mul by zero");
    }

    function signedAdd(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require(
            ((b >= 0) && (c >= a)) || ((b < 0) && (c < a)),
            "SignedSafeMath: addition overflow"
        );
        return c;
    }

    function signedSub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require(
            ((b >= 0) && (c <= a)) || ((b < 0) && (c > a)),
            "SignedSafeMath: subtraction overflow"
        );
        return c;
    }
}
