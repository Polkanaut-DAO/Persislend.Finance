// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "./OracleInterface.sol";

contract oracleProxy {
    address payable owner;

    mapping(uint256 => Oracle) oracle;

    struct Oracle {
        OracleInterface feed;
        uint256 feedUnderlyingPoint;
        bool needPriceConvert;
        uint256 priceConvertID;
    }

    uint256 constant unifiedPoint = 10**18;
    uint256 constant defaultUnderlyingPoint = 8;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address ethOracle) {
        owner = payable(msg.sender);
        _setOracleFeed(0, ethOracle, 8, false, 0);
    }

    function _setOracleFeed(
        uint256 tokenID,
        address feedAddr,
        uint256 decimals,
        bool needPriceConvert,
        uint256 priceConvertID
    ) internal returns (bool) {
        Oracle memory _oracle;
        _oracle.feed = OracleInterface(feedAddr);

        _oracle.feedUnderlyingPoint = (10**decimals);

        _oracle.needPriceConvert = needPriceConvert;

        _oracle.priceConvertID = priceConvertID;

        oracle[tokenID] = _oracle;
        return true;
    }

    function getTokenPrice(uint256 tokenID) external view returns (uint256) {
        // Oracle memory _oracle = oracle[tokenID];
        // // _oracle.feed.latestAnswer();
        // uint256 underlyingPrice = uint256(_oracle.feed.getLatestPrice());

        // uint256 unifiedPrice = _convertPriceToUnified(
        //     underlyingPrice,
        //     _oracle.feedUnderlyingPoint
        // );

        // if (_oracle.needPriceConvert) {
        //     _oracle = oracle[_oracle.priceConvertID];
        //     uint256 convertFeedUnderlyingPrice = uint256(
        //         _oracle.feed.getLatestPrice()
        //     );
        //     uint256 convertPrice = _convertPriceToUnified(
        //         convertFeedUnderlyingPrice,
        //         oracle[2].feedUnderlyingPoint
        //     );
        //     unifiedPrice = unifiedMul(unifiedPrice, convertPrice);
        // }

        // require(unifiedPrice != 0);
        return 1;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function _convertPriceToUnified(uint256 price, uint256 feedUnderlyingPoint)
        internal
        pure
        returns (uint256)
    {
        return div(mul(price, unifiedPoint), feedUnderlyingPoint);
    }

    /* **************** safeMath **************** */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return _mul(a, b);
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return _div(a, b, "div by zero");
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

    function unifiedMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return _div(_mul(a, b), unifiedPoint, "unified mul by zero");
    }
}
