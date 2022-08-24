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

    // in this function we calculate Annual Interest Rate for our platform, there is 2 type of Annual Interest Rate for us;
    // Annual Interest Rate YEAR; Annual Interest Rate BLOCK ==> Annual Interest Rate / blocks per year;

    // there is utilization rate of market factor , that is borrow total / borrow total + deposit total;
    // borrow Annual Interest Rate = minimum intreset rate + utilization factor * Liquidity sensitivity;
    // supply Annual Interest Rate = borrow Annual Interest Rate * utilization factor;

    // now we calculated the year Annual Interest Rate, but in our platform we have Annual Interest Rate per block;
    // Supply Interest Rate / blocks per year ; Borrow Interest Rate / blocks per year;

    // ** deltaBlocks * intresetRate + 1 * action Exchange rate

    // we can't store exchange rate for every block and we need this rate for all block ! so we calc exchange rate from block i to block j;
    // exchange rate from block i to j * 1 + intresetRate

    // so for calc intresetRate from block 1 to block 10; for deposit amount 1000; 1000 * ( EXR 10 / EXR1);

    // ** as we said , for every block EXR is => actionEXR * ( 1 + intresetRate );

    // ** intresetRate is same for all blocks ! we just need to cal exchange rate from block i to j ;

    // so for calc exchange rate for multiple blocks ! deltaBlock*intresetRate + 1 * actionEXR;

    // for every block we need to update user data and market data ! for this we need new exchange rate !
    // exchange rate @ block 10 / user deposit exchange rate @ block 5 !
    // if new exchange rate is more than 1ether or 1 * 10 ** 18 ! so new exchange rate = new exchange rate  - start point !
    // * so negative is false
    // if new exchange rate is lower than 1ether or 1 * 10 ** 18 ! so new exchange rate = start point - new exchange rate  !
    // so negative is true;

    // and new amount will get calculated by multiply user amount to new exchange rate and !

    // *** global exchange rate and action exchange rate are useful for get new global exchange rate
    // *** user exchange rate and new global exchange rate are useful for see there is negative factor ! and calc new amount for market and user !

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
        // this is yearly interest rate for supply and borrow;
        (_SIR, _BIR) = _getSIRandBIR(_depositTotalAmount, _borrowTotalAmount);

        // calc Deposit / Borrow Interest Rate / Block
        // but we need intresetRate per block ! so we divide yearly supply and borrow interest rate to blocks per year;
        uint256 _finalSIR = _SIR.div(blocksPerYear);
        uint256 _finalBIR = _BIR.div(blocksPerYear);

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
        // there is minimum intreset rate for borrow that ise setuped by admin !
        // so minimum intreset rate + (U factor * S)
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

    // this is new EXR for multiple blocks !
    function _getNewDepositGlobalEXR(
        uint256 _DepositActionEXR,
        uint256 _userInterestModelSIR,
        uint256 _Delta
    ) internal pure returns (uint256) {
        return
            //Enext = Eprev ∗ (1 + δ ∗ r)
            _userInterestModelSIR.mul(_Delta).add(startPoint).unifiedMul(
                _DepositActionEXR
            );
    }

    // now we calc amount with  Interest Rate
    // user EXR is user deposited EXR; but we now have global EXR;
    // (global EXR / user EXR )* amount !
    function _getNewDeltaRate(
        uint256 _userAmount,
        uint256 _userEXR,
        uint256 _globalEXR
    ) internal pure returns (bool, uint256) {
        uint256 _DeltaEXR;
        uint256 _DeltaAmount;
        bool _negativeFlag;

        // if user amount for borrow or supply is more than 0 !
        if (_userAmount != 0) {
            // we calc this => (GEXR / UEXR) * amount !
            (_negativeFlag, _DeltaEXR) = _getDeltaEXR(_globalEXR, _userEXR);

            // now delta amount = user amount * exchange rate !
            _DeltaAmount = _userAmount.unifiedMul(_DeltaEXR);
        }

        return (_negativeFlag, _DeltaAmount);
    }

    function _getDeltaEXR(uint256 _globalEXR, uint256 _userEXR)
        internal
        pure
        returns (bool, uint256)
    {
        // we get new EXR by GEXR / USER EXR
        uint256 EXR = _globalEXR.unifiedDiv(_userEXR);

        //if exr > 1 !? no negative and no delta amount !
        if (EXR >= startPoint) {
            return (false, EXR.sub(startPoint));
        }
        // else ! there is negative and delta
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
