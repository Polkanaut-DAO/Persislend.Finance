// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../Data/Data.sol";
import "../../IntresetModel/InterestModel.sol";

import "../../Core/Contracts/Manager.sol";

// import "../../RewardManager/Contract/RewardManager.sol";

contract ETHMarket {
    // address payable Owner;

    string marketName;
    uint256 marketID;

    uint256 constant unifiedPoint = 10**18;
    uint256 unifiedTokenDecimal;
    uint256 underlyingTokenDecimal;

    MarketData DataStorageContract;
    InterestModel InterestModelContract;

    Manager ManagerContract;

    // RewardManager RewardManagerContract;

    // modifier OnlyOwner() {
    //     require(msg.sender == Owner, "OnlyOwner");
    //     _;
    // }

    // modifier OnlyManagerContract() {
    //     require(msg.sender == address(ManagerContract), "OnlyManagerContract");
    //     _;
    // }

    constructor() {
        // Owner = payable(msg.sender);
    }

    // function setRewardManagerContract(address _RewardManagerContract)
    //     external
    //     returns (bool)
    // {
    //     RewardManagerContract = RewardManager(_RewardManagerContract);
    //     return true;
    // }

    function setManagerContract(address _ManagerContract)
        external
        returns (bool)
    {
        ManagerContract = Manager(_ManagerContract);
        return true;
    }

    function setDataStorageContract(address _DataStorageContract)
        external
        returns (bool)
    {
        DataStorageContract = MarketData(_DataStorageContract);
        return true;
    }

    function setInterestModelContract(address _InterestModelContract)
        external
        returns (bool)
    {
        InterestModelContract = InterestModel(_InterestModelContract);
        return true;
    }

    function setMarketName(string memory _marketName) external returns (bool) {
        marketName = _marketName;
        return true;
    }

    function setMarketID(uint256 _marketID) external returns (bool) {
        marketID = _marketID;
        return true;
    }

    // deposit function in platform
    function deposit(uint256 _amountToDeposit) external payable returns (bool) {
        // get user address as payable
        address payable _userAddress = payable(msg.sender);

        // require amount to deposit is more than 0 to stop wasting gas;
        require(
            _amountToDeposit > 0 && msg.value > 0,
            "You have to deposit more than 0 amount"
        );
        // require input is same as msg.value;
        require(
            msg.value == _amountToDeposit,
            "MSG value should be same as input value"
        );

        // calculate intreset params for user and market
        ManagerContract.applyInterestHandlers(_userAddress, marketID);

        // update amount to user and market data
        DataStorageContract.addDepositAmount(_userAddress, _amountToDeposit);

        return true;
    }

    function repay(uint256 _amountToRepay) external payable returns (bool) {
        address payable _userAddress = payable(msg.sender);

        require(_amountToRepay > 0);
        require(msg.value == _amountToRepay);

        // RewardManagerContract.updateRewardManagerData(_userAddress);
        _updateUserMarketInterest(_userAddress);

        ManagerContract.applyInterestHandlers(_userAddress, marketID);

        uint256 userBorrowAmount = DataStorageContract.getUserBorrowAmount(
            _userAddress
        );

        if (userBorrowAmount < _amountToRepay) {
            _amountToRepay = userBorrowAmount;
        }

        DataStorageContract.subBorrowAmount(_userAddress, _amountToRepay);
        return true;
    }

    function withdraw(uint256 _amountToWithdraw) external returns (bool) {
        address payable _userAddress = payable(msg.sender);

        uint256 userLiquidityAmount;
        uint256 userCollateralizableAmount;
        uint256 price;
        (
            userLiquidityAmount,
            userCollateralizableAmount,
            ,
            ,
            ,
            price
        ) = ManagerContract.applyInterestHandlers(_userAddress, marketID);

        require(
            unifiedMul(_amountToWithdraw, price) <=
                DataStorageContract.getMarketLimitOfAction()
        );

        uint256 adjustedAmount = _getUserMaxAmountToWithdrawInWithdrawFunc(
            _userAddress,
            _amountToWithdraw,
            userCollateralizableAmount
        );

        DataStorageContract.subDepositAmount(_userAddress, adjustedAmount);

        _userAddress.transfer(adjustedAmount);

        return true;
    }

    function borrow(uint256 _amountToBorrow) external returns (bool) {
        address payable _userAddress = payable(msg.sender);

        uint256 userLiquidityAmount;
        uint256 userCollateralizableAmount;
        uint256 price;
        (
            userLiquidityAmount,
            userCollateralizableAmount,
            ,
            ,
            ,
            price
        ) = ManagerContract.applyInterestHandlers(_userAddress, marketID);

        require(
            unifiedMul(_amountToBorrow, price) <=
                DataStorageContract.getMarketLimitOfAction()
        );

        uint256 adjustedAmount = _getUserMaxAmountToBorrowInBorrowFunc(
            _amountToBorrow,
            userLiquidityAmount
        );

        DataStorageContract.addBorrowAmount(_userAddress, adjustedAmount);

        _userAddress.transfer(adjustedAmount);

        return true;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////// APPLY INTEREST
    /// in this process, we we get connected to intreset model contract;
    /// we will calc delta blocks ! last time platform get updated ;
    /// and with this delta blocks we update and calc our exchange rate, global exchange rate; action exchange rate; user exchange rate;
    /// we will calc Annual Borrow/Deposit Interest Rate with total deposit and total borrow;
    // we will delta params with user deposit and borrow balance;

    // update user and market intreset params;
    function updateUserMarketInterest(address payable _userAddress)
        external
        returns (uint256, uint256)
    {
        return _updateUserMarketInterest(_userAddress);
    }

    // update user and market intreset params;
    function _updateUserMarketInterest(address payable _userAddress)
        internal
        returns (uint256, uint256)
    {
        // check if user is new , to ser user access and update user deposit and borrow exchange rate with global exchange rate;
        _checkIfUserIsNew(_userAddress);
        // this is function to know and get information about how many blocks, platform is not updated !
        _checkIfThisIsFirstAction();
        return _getUpdatedInterestParams(_userAddress);
    }

    function _checkIfUserIsNew(address payable _userAddress)
        internal
        returns (bool)
    {
        // check user access on platform;
        if (DataStorageContract.getUserIsAccessed(_userAddress)) {
            return false;
        }

        // if user is new we set user access to true;
        DataStorageContract.setUserAccessed(_userAddress, true);

        // get global exchange rate for deposit and borrow from platform;
        (uint256 gDEXR, uint256 gBEXR) = DataStorageContract
            .getGlDepositBorrowEXR();
        // set exchange rate to user;
        DataStorageContract.updateUserEXR(_userAddress, gDEXR, gBEXR);
        return true;
    }

    // this is function to know and get information about how many blocks, platform is not updated !
    // we use this delta blocks to update uur exhcnage rate;
    function _checkIfThisIsFirstAction() internal returns (bool) {
        uint256 _LastTimeBlockUpdated = DataStorageContract
            .getLastTimeBlockUpdated();
        uint256 _currentBlock = block.number;
        uint256 _deltaBlock = sub(_currentBlock, _LastTimeBlockUpdated);

        if (_deltaBlock > 0) {
            DataStorageContract.updateBlocks(_currentBlock, _deltaBlock);
            DataStorageContract.syncActionGlobalEXR();
            return true;
        }

        return false;
    }

    // this is how we update intreset model of our box ; :)
    function _getUpdatedInterestParams(address payable _userAddress)
        internal
        returns (uint256, uint256)
    {
        // get updated intreset params from intreset model contract / this is for user !
        // there is delta amount between deposit and borrow for user ?
        bool _depositIsNegative;
        uint256 _depositDeltaAmount;
        uint256 _glDepositEXR;

        bool _borrowIsNegative;
        uint256 _borrowDeltaAmount;
        uint256 _glBorrowEXR;
        (
            _depositIsNegative,
            _depositDeltaAmount,
            _glDepositEXR,
            _borrowIsNegative,
            _borrowDeltaAmount,
            _glBorrowEXR
        ) = InterestModelContract.getUpdatedInterestParams(
            _userAddress,
            address(DataStorageContract),
            false
        );

        // update user exchange rates with new global exchange rates;
        DataStorageContract.updateUserEXR(
            _userAddress,
            _glDepositEXR,
            _glBorrowEXR
        );

        return
            _interestGetAndUpdate(
                _userAddress,
                _depositIsNegative,
                _depositDeltaAmount,
                _borrowIsNegative,
                _borrowDeltaAmount
            );
    }

    function _interestGetAndUpdate(
        address payable _userAddress,
        bool _depositIsNegative,
        uint256 _depositDeltaAmount,
        bool _borrowIsNegative,
        uint256 _borrowDeltaAmount
    ) internal returns (uint256, uint256) {
        // in this function we get current and saved market data and user data about deposit and borrow;
        uint256 _totalDepositAmount;
        uint256 _userDepositAmount;
        uint256 _totalBorrowAmount;
        uint256 _userBorrowAmount;

        // now we update this data by new delta and negative params;
        (
            _totalDepositAmount,
            _userDepositAmount,
            _totalBorrowAmount,
            _userBorrowAmount
        ) = _getUpdatedInterestAmounts(
            _userAddress,
            _depositIsNegative,
            _depositDeltaAmount,
            _borrowIsNegative,
            _borrowDeltaAmount
        );

        // after calc new data , we update market and user amount ! new deposit and borrow data;
        DataStorageContract.updateAmounts(
            _userAddress,
            _totalDepositAmount,
            _totalBorrowAmount,
            _userDepositAmount,
            _userBorrowAmount
        );

        return (_userDepositAmount, _userBorrowAmount);
    }

    function _getUpdatedInterestAmounts(
        address payable _userAddress,
        bool _depositIsNegative,
        uint256 _depositDeltaAmount,
        bool _borrowIsNegative,
        uint256 _borrowDeltaAmount
    )
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        // get current amount for user and market !
        uint256 _totalDepositAmount;
        uint256 _userDepositAmount;
        uint256 _totalBorrowAmount;
        uint256 _userBorrowAmount;
        (
            _totalDepositAmount,
            _totalBorrowAmount,
            _userDepositAmount,
            _userBorrowAmount
        ) = DataStorageContract.getAmounts(_userAddress);

        // by condition if there is delta amount for data , we make update and return new data;
        if (_depositIsNegative) {
            _totalDepositAmount = sub(_totalDepositAmount, _depositDeltaAmount);
            _userDepositAmount = sub(_userDepositAmount, _depositDeltaAmount);
        } else {
            _totalDepositAmount = add(_totalDepositAmount, _depositDeltaAmount);
            _userDepositAmount = add(_userDepositAmount, _depositDeltaAmount);
        }

        if (_borrowIsNegative) {
            _totalBorrowAmount = sub(_totalBorrowAmount, _borrowDeltaAmount);
            _userBorrowAmount = sub(_userBorrowAmount, _borrowDeltaAmount);
        } else {
            _totalBorrowAmount = add(_totalBorrowAmount, _borrowDeltaAmount);
            _userBorrowAmount = add(_userBorrowAmount, _borrowDeltaAmount);
        }

        return (
            _totalDepositAmount,
            _userDepositAmount,
            _totalBorrowAmount,
            _userBorrowAmount
        );
    }

    function getUpdatedInterestAmountsForUser(address payable _userAddress)
        external
        view
        returns (uint256, uint256)
    {
        return _getUpdatedInterestAmountsForUser(_userAddress);
    }

    // update intreset params and get updated data for user !
    function _getUpdatedInterestAmountsForUser(address payable _userAddress)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 _totalDepositAmount;
        uint256 _userDepositAmount;
        uint256 _totalBorrowAmount;
        uint256 _userBorrowAmount;
        (
            _totalDepositAmount,
            _userDepositAmount,
            _totalBorrowAmount,
            _userBorrowAmount
        ) = _calcAmountWithInterest(_userAddress);

        return (_userDepositAmount, _userBorrowAmount);
    }

    // update intreset params and get updated data for market !
    function _getUpdatedInterestAmountsForMarket(address payable _userAddress)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 _totalDepositAmount;
        uint256 _userDepositAmount;
        uint256 _totalBorrowAmount;
        uint256 _userBorrowAmount;
        (
            _totalDepositAmount,
            _userDepositAmount,
            _totalBorrowAmount,
            _userBorrowAmount
        ) = _calcAmountWithInterest(_userAddress);

        return (_totalDepositAmount, _totalBorrowAmount);
    }

    // get updated intreset params and get updated data for user and market !
    function _calcAmountWithInterest(address payable _userAddress)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        bool _depositIsNegative;
        uint256 _depositDeltaAmount;
        uint256 _glDepositEXR;

        bool _borrowIsNegative;
        uint256 _borrowDeltaAmount;
        uint256 _glBorrowEXR;

        (
            _depositIsNegative,
            _depositDeltaAmount,
            _glDepositEXR,
            _borrowIsNegative,
            _borrowDeltaAmount,
            _glBorrowEXR
        ) = InterestModelContract.getUpdatedInterestParams(
            _userAddress,
            address(DataStorageContract),
            false
        );

        return
            _getUpdatedInterestAmounts(
                _userAddress,
                _depositIsNegative,
                _depositDeltaAmount,
                _borrowIsNegative,
                _borrowDeltaAmount
            );
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////// USER MAX ACTIONS

    // BORROW //////////////////////////////////////////////

    // how much user can borrow from platform ? we use this func in front !
    function getUserMaxAmountToBorrow(address payable _userAddress)
        external
        view
        returns (uint256)
    {
        return _getUserMaxAmountToBorrow(_userAddress);
    }

    // how much user can borrow from platform ?
    function _getUserMaxAmountToBorrow(address payable _userAddress)
        internal
        view
        returns (uint256)
    {
        // get free liquidityDeposit of user with correct decimals and struct !
        uint256 _marketLiquidityLimit = _getMarketLIQAfterInterestUpdateWithLimit(
                _userAddress
            );

        // now make some calc in manager contract ! we get how many asset user can borrow based on free liq of user !
        uint256 _howMuchUserCanBorrow = ManagerContract.getHowMuchUserCanBorrow(
            _userAddress,
            marketID
        );

        // main free to borrow is _howMuchUserCanBorrow;
        uint256 _freeToBorrow = _howMuchUserCanBorrow;
        if (_marketLiquidityLimit < _freeToBorrow) {
            _freeToBorrow = _marketLiquidityLimit;
        }

        return _freeToBorrow;
    }

    // we use this function in our platform !
    function _getUserMaxAmountToBorrowInBorrowFunc(
        uint256 _requestedToBorrow,
        uint256 _userLiq
    ) internal view returns (uint256) {
        // market liq limit is total dep * liqlim (1 ether or 1 * 10 ** 18) - total borr !
        uint256 _marketLiquidityLimit = _getMarketLiquidityWithLimit();

        uint256 _freeToBorrow = _requestedToBorrow;

        if (_freeToBorrow > _marketLiquidityLimit) {
            _freeToBorrow = _marketLiquidityLimit;
        }

        if (_freeToBorrow > _userLiq) {
            _freeToBorrow = _userLiq;
        }

        return _freeToBorrow;
    }

    // WITHDRAW //////////////////////////////////////////////

    function getUserMaxAmountToWithdraw(address payable _userAddress)
        external
        view
        returns (uint256)
    {
        return _getUserMaxAmountToWithdraw(_userAddress);
    }

    function _getUserMaxAmountToWithdraw(address payable _userAddress)
        internal
        view
        returns (uint256)
    {
        // for get user withdrawable amount ! we should first update user and market intreset params and data !
        uint256 _userUpdatedDepositAmountWithInterest;
        uint256 _userUpdatedBorrowAmountWithInterest;

        // we first make update in intreset params for user and market and them we user user data;
        (
            _userUpdatedDepositAmountWithInterest,
            _userUpdatedBorrowAmountWithInterest
        ) = _getUpdatedInterestAmountsForUser(_userAddress);

        // for get user withdrawable amount ! we should first update user and market intreset params and data !
        // we first make update in intreset params for user and market and them we user market data;
        uint256 _marketLIQAfterInterestUpdate = _getMarketLIQAfterInterestUpdate(
                _userAddress
            );

        uint256 _userFreeToWithdraw = ManagerContract.getUserFreeToWithdraw(
            _userAddress,
            marketID
        );

        uint256 _freeToWithdraw = _userUpdatedDepositAmountWithInterest;

        if (_freeToWithdraw > _userFreeToWithdraw) {
            _freeToWithdraw = _userFreeToWithdraw;
        }

        if (_freeToWithdraw > _marketLIQAfterInterestUpdate) {
            _freeToWithdraw = _marketLIQAfterInterestUpdate;
        }

        return _freeToWithdraw;
    }

    function _getUserMaxAmountToWithdrawInWithdrawFunc(
        address payable _userAddress,
        uint256 _requestedToWithdraw,
        uint256 _userWithdrawableAmount
    ) internal view returns (uint256) {
        uint256 _userDeposit = DataStorageContract.getUserDepositAmount(
            _userAddress
        );

        uint256 _marketLiq = _getMarketLiquidity();

        uint256 _freeToWithdraw = _userDeposit;

        if (_freeToWithdraw > _requestedToWithdraw) {
            _freeToWithdraw = _requestedToWithdraw;
        }

        if (_freeToWithdraw > _userWithdrawableAmount) {
            _freeToWithdraw = _userWithdrawableAmount;
        }

        if (_freeToWithdraw > _marketLiq) {
            _freeToWithdraw = _marketLiq;
        }

        return _freeToWithdraw;
    }

    // REPAY //////////////////////////////////////////////

    function getUserMaxAmountToRepay(address payable _userAddress)
        external
        view
        returns (uint256)
    {
        uint256 _userDepositAmountAfterInterestUpdate;
        uint256 _userBorrowAmountAfterInterestUpdate;
        (
            _userDepositAmountAfterInterestUpdate,
            _userBorrowAmountAfterInterestUpdate
        ) = _getUpdatedInterestAmountsForUser(_userAddress);

        return _userBorrowAmountAfterInterestUpdate;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////// MARKET TOOLS

    function getUpdatedMarketSIRAndBIR()
        external
        view
        returns (uint256, uint256)
    {
        uint256 _totalDepositAmount = DataStorageContract
            .getMarketDepositTotalAmount();
        uint256 _totalBorrowAmount = DataStorageContract
            .getMarketBorrowTotalAmount();

        return
            InterestModelContract.getSIRBIR(
                _totalDepositAmount,
                _totalBorrowAmount
            );
    }

    function getMarketLIQAfterInterestUpdate(address payable _userAddress)
        external
        view
        returns (uint256)
    {
        return _getMarketLIQAfterInterestUpdate(_userAddress);
    }

    function _getMarketLIQAfterInterestUpdate(address payable _userAddress)
        internal
        view
        returns (uint256)
    {
        // first we get market total balance for deposit and borrow after update intreset params for user and market in intresetModel contract;
        uint256 _totalDepositAmount;
        uint256 _totalBorrowAmount;
        (
            _totalDepositAmount,
            _totalBorrowAmount
        ) = _getUpdatedInterestAmountsForMarket(_userAddress);

        // now deposit amount should be more than 0 and more than borrow amount;
        if (_totalDepositAmount == 0) {
            return 0;
        }

        if (_totalDepositAmount < _totalBorrowAmount) {
            return 0;
        }

        // now we return D-B
        return sub(_totalDepositAmount, _totalBorrowAmount);
    }

    // in this function we make calc for return how much user can borrow
    function _getMarketLIQAfterInterestUpdateWithLimit(
        address payable _userAddress
    ) internal view returns (uint256) {
        // we get user total deposit and borrow from data contract
        uint256 _totalDepositAmount;
        uint256 _totalBorrowAmount;
        (
            _totalDepositAmount,
            _totalBorrowAmount
        ) = _getUpdatedInterestAmountsForMarket(_userAddress);

        // if user deposit is 0; so user can't borrow any amount and we will return 0 !
        if (_totalDepositAmount == 0) {
            return 0;
        }

        // we get liquidityDeposit , it's user deposit amount mul start point or 1 * 10 ** 18; for get correct uint with correct decimals !
        uint256 liquidityDeposit = unifiedMul(
            _totalDepositAmount,
            DataStorageContract.getMarketLiquidityLimit()
        );

        // if userdeposit is < borrow so user can't borrow any money and again we will return 0;
        if (liquidityDeposit < _totalBorrowAmount) {
            return 0;
        }

        // now we return liq amount sub total borrow ! for example 10 - 0 ! is 10 ! this is free liquidity of user;
        return sub(liquidityDeposit, _totalBorrowAmount);
    }

    // we use this function to get delta between deposit and borrow !
    function _getMarketLiquidity() internal view returns (uint256) {
        uint256 _totalDepositAmount = DataStorageContract
            .getMarketDepositTotalAmount();
        uint256 _totalBorrowAmount = DataStorageContract
            .getMarketBorrowTotalAmount();

        // if deposit in market is 0; we return 0;
        if (_totalDepositAmount == 0) {
            return 0;
        }

        // if deposit is < borrow / calc is wrong and we should return 0;
        if (_totalDepositAmount < _totalBorrowAmount) {
            return 0;
        }

        return sub(_totalDepositAmount, _totalBorrowAmount);
    }

    // this is similarly to _getMarketLiquidity, but here we use MarketLiquidityLimit to get currect number of free liq ! total deposit * 10 ** 18;
    function _getMarketLiquidityWithLimit() internal view returns (uint256) {
        uint256 _totalDepositAmount = DataStorageContract
            .getMarketDepositTotalAmount();
        uint256 _totalBorrowAmount = DataStorageContract
            .getMarketBorrowTotalAmount();

        if (_totalDepositAmount == 0) {
            return 0;
        }

        uint256 liquidityDeposit = unifiedMul(
            _totalDepositAmount,
            DataStorageContract.getMarketLiquidityLimit()
        );

        if (liquidityDeposit < _totalBorrowAmount) {
            return 0;
        }

        return sub(liquidityDeposit, _totalBorrowAmount);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////// INTERFACE FUNCTIONS

    function getMarketMarginCallLimit() external view returns (uint256) {
        return DataStorageContract.getMarketMarginCallLimit();
    }

    function getMarketBorrowLimit() external view returns (uint256) {
        return DataStorageContract.getMarketBorrowLimit();
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
        return DataStorageContract.getAmounts(_userAddress);
    }

    function getUserAmount(address payable _userAddress)
        external
        view
        returns (uint256, uint256)
    {
        uint256 depositAmount = DataStorageContract.getUserDepositAmount(
            _userAddress
        );
        uint256 borrowAmount = DataStorageContract.getUserBorrowAmount(
            _userAddress
        );

        return (depositAmount, borrowAmount);
    }

    function getUserDepositAmount(address payable _userAddress)
        external
        view
        returns (uint256)
    {
        return DataStorageContract.getUserDepositAmount(_userAddress);
    }

    function getUserBorrowAmount(address payable _userAddress)
        external
        view
        returns (uint256)
    {
        return DataStorageContract.getUserBorrowAmount(_userAddress);
    }

    function getMarketDepositTotalAmount() external view returns (uint256) {
        return DataStorageContract.getMarketDepositTotalAmount();
    }

    function getMarketBorrowTotalAmount() external view returns (uint256) {
        return DataStorageContract.getMarketBorrowTotalAmount();
    }

    // function updateRewardPerBlock(uint256 _rewardPerBlock)
    //     external
    //     OnlyManagerContract
    //     returns (bool)
    // {
    //     return RewardManagerContract.updateRewardPerBlock(_rewardPerBlock);
    // }

    // function updateRewardManagerData(address payable _userAddress)
    //     external
    //     returns (bool)
    // {
    //     return RewardManagerContract.updateRewardManagerData(_userAddress);
    // }

    // function getUpdatedUserRewardAmount(address payable _userAddress)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     return RewardManagerContract.getUpdatedUserRewardAmount(_userAddress);
    // }

    // function claimRewardAmountUser(address payable userAddr)
    //     external
    //     returns (uint256)
    // {
    //     return RewardManagerContract.claimRewardAmountUser(userAddr);
    // }

    /* ******************* Safe Math ******************* */
    // from: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol
    // Subject to the MIT license.
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
