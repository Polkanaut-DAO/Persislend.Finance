//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../Data/Data.sol";
import "../../Utils/Oracle/oracleProxy.sol";
import "../../Markets/Interface/MarketInterface.sol";
import "../../Utils/Utils/SafeMath.sol";

import "../../Utils/Tokens/standardIERC20.sol";

contract Manager {
    using SafeMath for uint256;

    address public Owner;

    ManagerData ManagerDataStorageContract;
    oracleProxy OracleContract;

    struct UserModelAssets {
        uint256 depositAssetSum;
        uint256 borrowAssetSum;
        uint256 marginCallLimitSum;
        uint256 depositAssetBorrowLimitSum;
        uint256 depositAsset;
        uint256 borrowAsset;
        uint256 price;
        uint256 callerPrice;
        uint256 depositAmount;
        uint256 borrowAmount;
        uint256 borrowLimit;
        uint256 marginCallLimit;
        uint256 callerBorrowLimit;
        uint256 userBorrowableAsset;
        uint256 withdrawableAsset;
    }

    mapping(address => UserModelAssets) _UserModelAssetsMapping;

    uint256 public marketsLength;

    modifier OnlyOwner() {
        require(msg.sender == Owner, "OnlyOwner");
        _;
    }

    constructor() {
        Owner = msg.sender;
    }

    function setOracleContract(address _OracleContract)
        external
        OnlyOwner
        returns (bool)
    {
        OracleContract = oracleProxy(_OracleContract);
        return true;
    }

    function setManagerDataStorageContract(address _ManagerDataStorageContract)
        external
        OnlyOwner
        returns (bool)
    {
        ManagerDataStorageContract = ManagerData(_ManagerDataStorageContract);
        return true;
    }

    function registerNewHandler(uint256 _marketID, address _marketAddress)
        external
        OnlyOwner
        returns (bool)
    {
        ManagerDataStorageContract.registerNewMarketInCore(
            _marketID,
            _marketAddress
        );
        marketsLength = marketsLength + 1;
        return true;
    }

    function applyInterestHandlers(
        address payable _userAddress,
        uint256 _marketID
    )
        external
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        // create memory model from user model
        UserModelAssets memory _UserModelAssets;

        // create 2 var support and address for market
        bool _Support;
        address _Address;

        // make loop over all markets
        for (uint256 ID; ID < marketsLength; ID++) {
            // check support and address from manager data storage
            (_Support, _Address) = ManagerDataStorageContract.getMarketInfo(ID);

            // if market with this id is supporting
            if (_Support) {
                // create market instance
                MarketInterface _HandlerContract = MarketInterface(_Address);

                // _HandlerContract.updateRewardManagerData(_userAddress);

                // get user deposit and borrow from market
                (
                    _UserModelAssets.depositAmount,
                    _UserModelAssets.borrowAmount
                ) = _HandlerContract.updateUserMarketInterest(_userAddress);

                // get market details , what is margin call limit and borrow limit;
                _UserModelAssets.borrowLimit = _HandlerContract
                    .getMarketBorrowLimit();
                _UserModelAssets.marginCallLimit = _HandlerContract
                    .getMarketMarginCallLimit();

                // if current id for loop is math ID;
                if (ID == _marketID) {
                    // get price of asset;
                    _UserModelAssets.price = OracleContract.getTokenPrice(ID);
                    // set caller price for now
                    _UserModelAssets.callerPrice = _UserModelAssets.price;
                    // set borrow limit for now
                    _UserModelAssets.callerBorrowLimit = _UserModelAssets
                        .borrowLimit;
                }

                // if user has deposit
                if (
                    _UserModelAssets.depositAmount > 0 ||
                    _UserModelAssets.borrowAmount > 0
                ) {
                    // get price for other markets
                    if (ID != _marketID) {
                        _UserModelAssets.price = OracleContract.getTokenPrice(
                            ID
                        );
                    }

                    // if user deposit is more than 0;
                    if (_UserModelAssets.depositAmount > 0) {
                        // we mul deposit to asset price !
                        _UserModelAssets.depositAsset = _UserModelAssets
                            .depositAmount
                            .unifiedMul(_UserModelAssets.price);

                        // now calc asset borrow limit SUM ! how much user can borrow for all markets ! in $
                        _UserModelAssets
                            .depositAssetBorrowLimitSum = _UserModelAssets
                            .depositAssetBorrowLimitSum
                            .add(
                                _UserModelAssets.depositAsset.unifiedMul(
                                    _UserModelAssets.borrowLimit
                                )
                            );

                        // now get margin call limit SUM for user in all markets in $
                        _UserModelAssets.marginCallLimitSum = _UserModelAssets
                            .marginCallLimitSum
                            .add(
                                _UserModelAssets.depositAsset.unifiedMul(
                                    _UserModelAssets.marginCallLimit
                                )
                            );

                        // and this is deposit of user in all markets in $
                        _UserModelAssets.depositAssetSum = _UserModelAssets
                            .depositAssetSum
                            .add(_UserModelAssets.depositAsset);
                    }

                    // now if user borrow is more than 0 , we calc borrow sum in $ for user in all markets
                    // borrow amount * price
                    if (_UserModelAssets.borrowAmount > 0) {
                        _UserModelAssets.borrowAsset = _UserModelAssets
                            .borrowAmount
                            .unifiedMul(_UserModelAssets.price);
                        // borrow sum
                        _UserModelAssets.borrowAssetSum = _UserModelAssets
                            .borrowAssetSum
                            .add(_UserModelAssets.borrowAsset);
                    }
                }
            }
        }

        if (
            // if user can borrow ! and has liq to borrow more assets
            _UserModelAssets.depositAssetBorrowLimitSum >
            _UserModelAssets.borrowAssetSum
        ) {
            // we calc borrowable by sub already borrowd (borrowAssetSum) from depositAssetBorrowLimitSum
            _UserModelAssets.userBorrowableAsset = _UserModelAssets
                .depositAssetBorrowLimitSum
                .sub(_UserModelAssets.borrowAssetSum);

            // now after get user deposit $ user borrowable $ user borrowed $/ how much user can withdraw from platform?
            _UserModelAssets.withdrawableAsset = _UserModelAssets
                .depositAssetBorrowLimitSum
                .sub(_UserModelAssets.borrowAssetSum)
                .unifiedDiv(_UserModelAssets.callerBorrowLimit);
        }

        return (
            _UserModelAssets.userBorrowableAsset.unifiedDiv(
                _UserModelAssets.callerPrice
            ),
            _UserModelAssets.withdrawableAsset.unifiedDiv(
                _UserModelAssets.callerPrice
            ),
            _UserModelAssets.marginCallLimitSum,
            _UserModelAssets.depositAssetSum,
            _UserModelAssets.borrowAssetSum,
            _UserModelAssets.callerPrice
        );
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////// Av.. Liquidity

    function getHowMuchUserCanBorrow(
        address payable _userAddress,
        uint256 _marketID
    ) external view returns (uint256) {
        // get user total deposit amount and user total borrow ! from all markets ! $ value ***
        uint256 _userTotalDepositAssets;
        uint256 _userTotalBorrowAssets;

        (
            _userTotalDepositAssets,
            _userTotalBorrowAssets
        ) = getUserUpdatedParamsFromAllMarkets(_userAddress);

        // if $ value of deposit / user / is 0 , user can't borrow anythig ! so we return 0;
        if (_userTotalDepositAssets == 0) {
            return 0;
        }

        // now if $ value user deposit is more that $ value borrow user; we should make sub ! x - y = z ! z is free liq
        // now we make div on z (free liq) and $ price of this market ! for example z / 1$ dai or z / 1000$ eth;
        if (_userTotalDepositAssets > _userTotalBorrowAssets) {
            return
                _userTotalDepositAssets.sub(_userTotalBorrowAssets).unifiedDiv(
                    _getUpdatedMarketTokenPrice(_marketID)
                );
        } else {
            return 0;
        }
    }

    // this function is useful to get see how much user can borrow ! and how much is borrowed ! is $ value
    function getUserUpdatedParamsFromAllMarkets(address payable _userAddress)
        public
        view
        returns (uint256, uint256)
    {
        // make var for total deposit and borrow ! this is $ value
        uint256 _userTotalDepositAssets;
        uint256 _userTotalBorrowAssets;

        // make loop over all markets;
        for (uint256 ID; ID < marketsLength; ID++) {
            // if id of market is supporting!
            if (ManagerDataStorageContract.getMarketSupport(ID)) {
                // get user deposit  and user borrow ; this is $ value
                uint256 _userDepositAsset;
                uint256 _userBorrowAsset;

                (
                    _userDepositAsset,
                    _userBorrowAsset
                ) = getUpdatedInterestAmountsForUser(_userAddress, ID);

                // what is borrow limit for this market ! this is 7- % of user deposit liq;
                uint256 _marketBorrowLimit = _getMarketBorrowLimit(ID);
                // now we make mul between user deposit and market borrow limit ! for example 10$ * 70 % !
                uint256 _userDepositWithLimit = _userDepositAsset.unifiedMul(
                    _marketBorrowLimit
                );

                // we have var total deposit $ / this is $ value of deposit user in all markets; we will add _userDepositWithLimit to this var;
                // we don't need $ value of all deposit liq / we need $ value of deposit $ * borrow lim !
                _userTotalDepositAssets = _userTotalDepositAssets.add(
                    _userDepositWithLimit
                );

                // this is borrow $ value of user across all markets;
                _userTotalBorrowAssets = _userTotalBorrowAssets.add(
                    _userBorrowAsset
                );
            } else {
                continue;
            }
        }

        // at the end we will return total $ value of deposit and borrow;
        return (_userTotalDepositAssets, _userTotalBorrowAssets);
    }

    function getUpdatedInterestAmountsForUser(
        address payable _userAddress,
        uint256 _marketID
    ) public view returns (uint256, uint256) {
        // here in this function we get deposit $ and borrow $ of user !
        // get market price from chain link ;
        uint256 _marketTokenPrice = _getUpdatedMarketTokenPrice(_marketID);

        // create contract instance of market !
        MarketInterface _MarketInterface = MarketInterface(
            ManagerDataStorageContract.getMarketAddress(_marketID)
        );

        // get deposit amount and borrow amount;
        uint256 _userDepositAmount;
        uint256 _userBorrowAmount;

        (_userDepositAmount, _userBorrowAmount) = _MarketInterface
            .getUpdatedInterestAmountsForUser(_userAddress);

        // deposit $ = deposit amount * market price;
        uint256 _userDepositAssets = _userDepositAmount.unifiedMul(
            _marketTokenPrice
        );
        // borrow $ = borrow amount * market price;
        uint256 _userBorrowAssets = _userBorrowAmount.unifiedMul(
            _marketTokenPrice
        );

        // now return $ value of deposit and borrow of user from match market ;
        return (_userDepositAssets, _userBorrowAssets);
    }

    function getUserLimitsFromAllMarkets(address payable _userAddress)
        public
        view
        returns (uint256, uint256)
    {
        uint256 _userBorrowLimitFromAllMarkets;
        uint256 _userMarginCallLimitLevel;
        for (uint256 ID; ID < marketsLength; ID++) {
            if (ManagerDataStorageContract.getMarketSupport(ID)) {
                uint256 _userDepositForMarket;
                uint256 _userBorrowForMarket;
                (
                    _userDepositForMarket,
                    _userBorrowForMarket
                ) = getUpdatedInterestAmountsForUser(_userAddress, ID);
                uint256 _borrowLimit = _getMarketBorrowLimit(ID);
                uint256 _marginCallLimit = _getMarketMarginCallLevel(ID);
                uint256 _userBorrowLimitAsset = _userDepositForMarket
                    .unifiedMul(_borrowLimit);
                uint256 userMarginCallLimitAsset = _userDepositForMarket
                    .unifiedMul(_marginCallLimit);
                _userBorrowLimitFromAllMarkets = _userBorrowLimitFromAllMarkets
                    .add(_userBorrowLimitAsset);
                _userMarginCallLimitLevel = _userMarginCallLimitLevel.add(
                    userMarginCallLimitAsset
                );
            } else {
                continue;
            }
        }

        return (_userBorrowLimitFromAllMarkets, _userMarginCallLimitLevel);
    }

    // here we give match market id; manager will make loop on all markets and get user free liq of user in $;
    function getUserFreeToWithdraw(
        address payable _userAddress,
        uint256 _marketID
    ) external view returns (uint256) {
        // this is total $ that user borrowed from market;
        uint256 _totalUserBorrowAssets;

        uint256 _userDepositAssetsAfterBorrowLimit;
        // user deposit $ value
        uint256 _userDepositAssets;
        // user borrow $ value;
        uint256 _userBorrowAssets;

        // we have to loop over all markets;
        for (uint256 ID; ID < marketsLength; ID++) {
            // if market with this id is supporting !
            if (ManagerDataStorageContract.getMarketSupport(ID)) {
                // we get $ value of deposit and borrow after make update in intreset param;
                (
                    _userDepositAssets,
                    _userBorrowAssets
                ) = getUpdatedInterestAmountsForUser(_userAddress, ID);

                // we update total borrow $ value;
                _totalUserBorrowAssets = _totalUserBorrowAssets.add(
                    _userBorrowAssets
                );

                // now we multiply user deposit $ value to match market borrow lim! and add them to variable;
                _userDepositAssetsAfterBorrowLimit = _userDepositAssetsAfterBorrowLimit
                    .add(
                        _userDepositAssets.unifiedMul(_getMarketBorrowLimit(ID))
                    );
            }
        }

        if (_userDepositAssetsAfterBorrowLimit > _totalUserBorrowAssets) {
            return
                _userDepositAssetsAfterBorrowLimit
                    .sub(_totalUserBorrowAssets)
                    .unifiedDiv(_getMarketBorrowLimit(_marketID))
                    .unifiedDiv(_getUpdatedMarketTokenPrice(_marketID));
        }
        return 0;
    }

    // ////////////////////////////////////////////////////////////////////////////////////////////////////////// MANAGER TOOLS

    function getUpdatedMarketTokenPrice(uint256 _marketID)
        external
        view
        returns (uint256)
    {
        return _getUpdatedMarketTokenPrice(_marketID);
    }

    function _getUpdatedMarketTokenPrice(uint256 _marketID)
        internal
        view
        returns (uint256)
    {
        return (OracleContract.getTokenPrice(_marketID));
    }

    function getMarketMarginCallLevel(uint256 _marketID)
        external
        view
        returns (uint256)
    {
        return _getMarketMarginCallLevel(_marketID);
    }

    function _getMarketMarginCallLevel(uint256 _marketID)
        internal
        view
        returns (uint256)
    {
        MarketInterface _MarketInterface = MarketInterface(
            ManagerDataStorageContract.getMarketAddress(_marketID)
        );

        return _MarketInterface.getMarketMarginCallLimit();
    }

    function getMarketBorrowLimit(uint256 _marketID)
        external
        view
        returns (uint256)
    {
        return _getMarketBorrowLimit(_marketID);
    }

    function _getMarketBorrowLimit(uint256 _marketID)
        internal
        view
        returns (uint256)
    {
        MarketInterface _MarketInterface = MarketInterface(
            ManagerDataStorageContract.getMarketAddress(_marketID)
        );

        return _MarketInterface.getMarketBorrowLimit();
    }
}
