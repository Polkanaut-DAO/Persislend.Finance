// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../Utils/Utils/SafeMath.sol";
import "../Markets/Data/Data.sol";

contract InterestModel {
    using SafeMath for uint256;

    MarketData marketDataStorage;

    address payable Owner;

    uint256 blocksPerYear;
    uint256 constant startPoint = 10**18;

    uint256 marketMinRate;
    uint256 marketBasicSen;
    uint256 marketJPoint;
    uint256 marketJSen;
    uint256 marketSpreadPoint;

    modifier OnlyOwner() {
        require(msg.sender == Owner, "OnlyOwner");
        _;
    }

    struct userInterestModel {
        uint256 SIR;
        uint256 BIR;
        uint256 depositTotalAmount;
        uint256 borrowTotalAmount;
        uint256 userDepositAmount;
        uint256 userBorrowAmount;
        uint256 deltaDepositAmount;
        uint256 deltaBorrowAmount;
        uint256 globalDepositEXR;
        uint256 globalBorrowEXR;
        uint256 userDepositEXR;
        uint256 userBorrowEXR;
        uint256 actionDepositEXR;
        uint256 actionBorrowEXR;
        uint256 deltaDepositEXR;
        uint256 deltaBorrowEXR;
        bool depositNegativeFlag;
        bool borrowNegativeFlag;
    }

    constructor(
        uint256 _marketMinRate,
        uint256 _marketJPoint,
        uint256 _marketBasicSen,
        uint256 _marketJSen,
        uint256 _marketSpreadPoint
    ) {
        Owner = payable(msg.sender);
        marketMinRate = _marketMinRate;
        marketBasicSen = _marketBasicSen;
        marketJPoint = _marketJPoint;
        marketJSen = _marketJSen;
        marketSpreadPoint = _marketSpreadPoint;
    }

    // get last updated intreset params for user account and market;
    function getUpdatedInterestParams(
        address payable _userAddress,
        address _marketDataAddress,
        bool _isView
    )
        external
        view
        returns (
            bool,
            uint256,
            uint256,
            bool,
            uint256,
            uint256
        )
    {
        if (_isView) {
            return _viewUpdatedInterestParams(_userAddress, _marketDataAddress);
        } else {
            return _updateInterestParams(_userAddress, _marketDataAddress);
        }
    }

    function viewUpdatedInterestParams(
        address payable _userAddress,
        address _marketDataAddress
    )
        external
        view
        returns (
            bool,
            uint256,
            uint256,
            bool,
            uint256,
            uint256
        )
    {
        return _viewUpdatedInterestParams(_userAddress, _marketDataAddress);
    }

    function _viewUpdatedInterestParams(
        address payable _userAddress,
        address _marketDataAddress
    )
        internal
        view
        returns (
            bool,
            uint256,
            uint256,
            bool,
            uint256,
            uint256
        )
    {
        // create contract instance from given market id; DATA contract
        MarketData _marketDataStorage = MarketData(_marketDataAddress);

        // get current block number;
        uint256 currentBlockNumber = block.number;
        // get last time / block that match market get updated;
        uint256 LastTimeBlockUpdated = _marketDataStorage
            .getLastTimeBlockUpdated();

        // calc delta block; how many blocks market is not updated;
        uint256 _DeltaBlocks = currentBlockNumber.sub(LastTimeBlockUpdated);

        // now get deposit and borrow action exchange rate ! we updated this on every deposit action !
        uint256 _DepositActionEXR;
        uint256 _BorrowActionEXR;

        (_DepositActionEXR, _BorrowActionEXR) = _marketDataStorage
            .getActionEXR();

        // noew calc intreset params and return data;
        return
            _calcInterestModelForUser(
                _userAddress,
                _marketDataAddress,
                _DeltaBlocks,
                _DepositActionEXR,
                _BorrowActionEXR
            );
    }

    // update data for user account in given market;
    function _updateInterestParams(
        address payable _userAddress,
        address _marketDataAddress
    )
        internal
        view
        returns (
            bool,
            uint256,
            uint256,
            bool,
            uint256,
            uint256
        )
    {
        MarketData _marketDataStorage = MarketData(_marketDataAddress);

        uint256 _DeltaBlock = _marketDataStorage.getInactiveBlocks();

        (
            uint256 _DepositActionEXR,
            uint256 _BorrowActionEXR
        ) = _marketDataStorage.getActionEXR();

        return
            _calcInterestModelForUser(
                _userAddress,
                _marketDataAddress,
                _DeltaBlock,
                _DepositActionEXR,
                _BorrowActionEXR
            );
    }

    // game is happening here :)
    function _calcInterestModelForUser(
        address payable _userAddress,
        address _marketDataAddress,
        uint256 _Delta,
        uint256 _DepositEXR,
        uint256 _BorrowEXR
    )
        internal
        view
        returns (
            bool,
            uint256,
            uint256,
            bool,
            uint256,
            uint256
        )
    {
        // create memory model from intreset model;
        userInterestModel memory _userInterestModel;
        // create contract instance from given market address; data contract;
        MarketData _marketDataStorage = MarketData(_marketDataAddress);

        // get all balance details for market and user from data contract;
        (
            _userInterestModel.depositTotalAmount,
            _userInterestModel.borrowTotalAmount,
            _userInterestModel.userDepositAmount,
            _userInterestModel.userBorrowAmount
        ) = _marketDataStorage.getAmounts(_userAddress);

        // get user exchange rate from data contract/ we set this on deposit action;
        (
            _userInterestModel.userDepositEXR,
            _userInterestModel.userBorrowEXR
        ) = _marketDataStorage.getUserEXR(_userAddress);

        // calc Annual Deposit / Borrow Interest Rate
        (_userInterestModel.SIR, _userInterestModel.BIR) = _getSIRandBIRonBlock(
            _userInterestModel.depositTotalAmount,
            _userInterestModel.borrowTotalAmount
        );

        // *** DEPOSIT
        // calc new global exchange rate;
        _userInterestModel.globalDepositEXR = _getNewDepositGlobalEXR(
            _DepositEXR,
            _userInterestModel.SIR,
            _Delta
        );

        // calc delta amount !
        (
            _userInterestModel.depositNegativeFlag,
            _userInterestModel.deltaDepositAmount
        ) = _getNewDeltaRate(
            _userInterestModel.userDepositAmount,
            _userInterestModel.userDepositEXR,
            _userInterestModel.globalDepositEXR
        );

        // *** BORROW
        _userInterestModel.globalBorrowEXR = _getNewDepositGlobalEXR(
            _BorrowEXR,
            _userInterestModel.BIR,
            _Delta
        );

        (
            _userInterestModel.borrowNegativeFlag,
            _userInterestModel.deltaBorrowAmount
        ) = _getNewDeltaRate(
            _userInterestModel.userBorrowAmount,
            _userInterestModel.userBorrowEXR,
            _userInterestModel.globalBorrowEXR
        );

        return (
            _userInterestModel.depositNegativeFlag,
            _userInterestModel.deltaDepositAmount,
            _userInterestModel.globalDepositEXR,
            _userInterestModel.borrowNegativeFlag,
            _userInterestModel.deltaBorrowAmount,
            _userInterestModel.globalBorrowEXR
        );
    }

    // calc Annual Deposit / Borrow Interest Rate
    function getSIRBIR(uint256 _depositTotalAmount, uint256 _borrowTotalAmount)
        external
        view
        returns (uint256, uint256)
    {
        return _getSIRandBIRonBlock(_depositTotalAmount, _borrowTotalAmount);
    }

    function _getSIRandBIRonBlock(
        uint256 _depositTotalAmount,
        uint256 _borrowTotalAmount
    ) internal view returns (uint256, uint256) {
        uint256 _SIR;
        uint256 _BIR;

        //calc Annual Deposit / Borrow Interest Rate
        (_SIR, _BIR) = _getSIRandBIR(_depositTotalAmount, _borrowTotalAmount);

        // calc Deposit / Borrow Interest Rate / Block
        uint256 _finalSIR = _SIR / blocksPerYear;
        uint256 _finalBIR = _BIR / blocksPerYear;

        return (_finalSIR, _finalBIR);
    }

    function _getSIRandBIR(
        uint256 _depositTotalAmount,
        uint256 _borrowTotalAmount
    ) internal view returns (uint256, uint256) {
        // calc market Utilization Rate ==> Borrow / Deposit  + Borrow
        uint256 _marketRate = _getMarketRate(
            _depositTotalAmount,
            _borrowTotalAmount
        );

        uint256 _BIR;

        // Annual Borrow Interest Rate = minimum intreset rate + _marketRate * marketBasicSen
        if (_marketRate < marketJPoint) {
            _BIR = _marketRate.unifiedMul(marketBasicSen).add(marketMinRate);
        } else {
            _BIR = marketMinRate
                .add(marketJPoint.unifiedMul(marketBasicSen))
                .add(_marketRate.sub(marketJPoint).unifiedMul(marketJSen));
        }

        // Annual Deposit Interest Rate = BIR * _marketRate
        uint256 _SIR = _marketRate.unifiedMul(_BIR).unifiedMul(
            marketSpreadPoint
        );
        return (_SIR, _BIR);
    }

    // calc market Utilization Rate ==> Borrow / Deposit  + Borrow
    function _getMarketRate(
        uint256 _depositTotalAmount,
        uint256 _borrowTotalAmount
    ) internal pure returns (uint256) {
        if ((_depositTotalAmount == 0) && (_borrowTotalAmount == 0)) {
            return 0;
        }

        return _borrowTotalAmount.unifiedDiv(_depositTotalAmount);
    }

    function _getNewDepositGlobalEXR(
        uint256 _DepositActionEXR,
        uint256 _userInterestModelSIR,
        uint256 _Delta
    ) internal pure returns (uint256) {
        return
            _userInterestModelSIR.mul(_Delta).add(startPoint).unifiedMul(
                _DepositActionEXR
            );
    }

    function _getNewDeltaRate(
        uint256 _userAmount,
        uint256 _userEXR,
        uint256 _globalEXR
    ) internal pure returns (bool, uint256) {
        uint256 _DeltaEXR;
        uint256 _DeltaAmount;
        bool _negativeFlag;

        if (_userAmount != 0) {
            (_negativeFlag, _DeltaEXR) = _getDeltaEXR(_globalEXR, _userEXR);
            _DeltaAmount = _userAmount.unifiedMul(_DeltaEXR);
        }

        return (_negativeFlag, _DeltaAmount);
    }

    function _getDeltaEXR(uint256 _globalEXR, uint256 _userEXR)
        internal
        pure
        returns (bool, uint256)
    {
        uint256 EXR = _globalEXR.unifiedDiv(_userEXR);
        if (EXR >= startPoint) {
            return (false, EXR.sub(startPoint));
        }

        return (true, startPoint.sub(EXR));
    }

    function setBlocksPerYear(uint256 _blocksPerYear)
        external
        OnlyOwner
        returns (bool)
    {
        blocksPerYear = _blocksPerYear;
        return true;
    }
}
