//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../Data/Data.sol";
import "../../IntresetModel/InterestModel.sol";
import "../../Core/Contracts/Manager.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenMarket {
    address payable Owner;

    string marketName;
    uint256 marketID;

    uint256 constant unifiedPoint = 10**18;
    uint256 unifiedTokenDecimal;
    uint256 underlyingTokenDecimal;

    MarketData DataStorageContract;
    InterestModel InterestModelContract;
    Manager ManagerContract;

    IERC20 IERC20TokenContract;

    modifier OnlyOwner() {
        require(msg.sender == Owner, "OnlyOwner");
        _;
    }

    modifier OnlyManagerContract() {
        require(msg.sender == address(ManagerContract), "OnlyManagerContract");
        _;
    }

    constructor(address _DAIErc20) {
        Owner = payable(msg.sender);
        IERC20TokenContract = IERC20(_DAIErc20);
    }

    function setManagerContract(address _ManagerContract)
        external
        OnlyOwner
        returns (bool)
    {
        ManagerContract = Manager(_ManagerContract);
        return true;
    }

    function setDataStorageContract(address _DataStorageContract)
        external
        OnlyOwner
        returns (bool)
    {
        DataStorageContract = MarketData(_DataStorageContract);
        return true;
    }

    function setInterestModelContract(address _InterestModelContract)
        external
        OnlyOwner
        returns (bool)
    {
        InterestModelContract = InterestModel(_InterestModelContract);
        return true;
    }

    function setMarketName(string memory _marketName)
        external
        OnlyOwner
        returns (bool)
    {
        marketName = _marketName;
        return true;
    }

    function setMarketID(uint256 _marketID) external OnlyOwner returns (bool) {
        marketID = _marketID;
        return true;
    }

    function deposit(uint256 _amountToDeposit) external returns (bool) {
        address payable _userAddress = payable(msg.sender);

        require(_amountToDeposit > 0);

        // calculate intreset params for user and market
        ManagerContract.applyInterestHandlers(_userAddress, marketID);

        DataStorageContract.addDepositAmount(_userAddress, _amountToDeposit);

        IERC20TokenContract.transferFrom(
            _userAddress,
            address(this),
            _amountToDeposit
        );

        return true;
    }

    function repay(uint256 _amountToRepay) external returns (bool) {
        address payable _userAddress = payable(msg.sender);
        require(_amountToRepay > 0);

        // calculate intreset params for user and market
        ManagerContract.applyInterestHandlers(_userAddress, marketID);

        uint256 userBorrowAmount = DataStorageContract.getUserBorrowAmount(
            _userAddress
        );

        if (userBorrowAmount < _amountToRepay) {
            _amountToRepay = userBorrowAmount;
        }

        DataStorageContract.subBorrowAmount(_userAddress, _amountToRepay);

        IERC20TokenContract.transferFrom(
            _userAddress,
            address(this),
            _amountToRepay
        );
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

        IERC20TokenContract.transfer(_userAddress, adjustedAmount);

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

        uint256 adjustedAmount = _getUserMaxAmountToBorrowInBorrowFunc(
            _amountToBorrow,
            userLiquidityAmount
        );

        require(
            unifiedMul(adjustedAmount, price) <=
                DataStorageContract.getMarketLimitOfAction()
        );

        DataStorageContract.addBorrowAmount(_userAddress, adjustedAmount);

        IERC20TokenContract.transfer(_userAddress, adjustedAmount);

        return true;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////// APPLY INTEREST
    function updateUserMarketInterest(address payable _userAddress)
        external
        returns (uint256, uint256)
    {
        return _updateUserMarketInterest(_userAddress);
    }

    function _updateUserMarketInterest(address payable _userAddress)
        internal
        returns (uint256, uint256)
    {
        _checkIfUserIsNew(_userAddress);
        _checkIfThisIsFirstAction();
        return _getUpdatedInterestParams(_userAddress);
    }

    function _checkIfUserIsNew(address payable _userAddress)
        internal
        returns (bool)
    {
        if (DataStorageContract.getUserIsAccessed(_userAddress)) {
            return false;
        }

        DataStorageContract.setUserAccessed(_userAddress, true);

        (uint256 gDEXR, uint256 gBEXR) = DataStorageContract
            .getGlDepositBorrowEXR();
        DataStorageContract.updateUserEXR(_userAddress, gDEXR, gBEXR);
        return true;
    }

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

    function _getUpdatedInterestParams(address payable _userAddress)
        internal
        returns (uint256, uint256)
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
        uint256 _totalDepositAmount;
        uint256 _userDepositAmount;
        uint256 _totalBorrowAmount;
        uint256 _userBorrowAmount;

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

    function getUserMaxAmountToBorrow(address payable _userAddress)
        external
        view
        returns (uint256)
    {
        return _getUserMaxAmountToBorrow(_userAddress);
    }

    function _getUserMaxAmountToBorrow(address payable _userAddress)
        internal
        view
        returns (uint256)
    {
        uint256 _marketLiquidityLimit = _getMarketLIQAfterInterestUpdateWithLimit(
                _userAddress
            );

        uint256 _howMuchUserCanBorrow = ManagerContract.getHowMuchUserCanBorrow(
            _userAddress,
            marketID
        );
        uint256 _freeToBorrow = _howMuchUserCanBorrow;
        if (_marketLiquidityLimit < _freeToBorrow) {
            _freeToBorrow = _marketLiquidityLimit;
        }

        return _freeToBorrow;
    }

    function _getUserMaxAmountToBorrowInBorrowFunc(
        uint256 _requestedToBorrow,
        uint256 _userLiq
    ) internal view returns (uint256) {
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
        uint256 _userUpdatedDepositAmountWithInterest;
        uint256 _userUpdatedBorrowAmountWithInterest;
        (
            _userUpdatedDepositAmountWithInterest,
            _userUpdatedBorrowAmountWithInterest
        ) = _getUpdatedInterestAmountsForUser(_userAddress);

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
        uint256 _totalDepositAmount;
        uint256 _totalBorrowAmount;
        (
            _totalDepositAmount,
            _totalBorrowAmount
        ) = _getUpdatedInterestAmountsForMarket(_userAddress);

        if (_totalDepositAmount == 0) {
            return 0;
        }

        if (_totalDepositAmount < _totalBorrowAmount) {
            return 0;
        }

        return sub(_totalDepositAmount, _totalBorrowAmount);
    }

    function _getMarketLIQAfterInterestUpdateWithLimit(
        address payable _userAddress
    ) internal view returns (uint256) {
        uint256 _totalDepositAmount;
        uint256 _totalBorrowAmount;
        (
            _totalDepositAmount,
            _totalBorrowAmount
        ) = _getUpdatedInterestAmountsForMarket(_userAddress);

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

    function _getMarketLiquidity() internal view returns (uint256) {
        uint256 _totalDepositAmount = DataStorageContract
            .getMarketDepositTotalAmount();
        uint256 _totalBorrowAmount = DataStorageContract
            .getMarketBorrowTotalAmount();

        if (_totalDepositAmount == 0) {
            return 0;
        }

        if (_totalDepositAmount < _totalBorrowAmount) {
            return 0;
        }

        return sub(_totalDepositAmount, _totalBorrowAmount);
    }

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
