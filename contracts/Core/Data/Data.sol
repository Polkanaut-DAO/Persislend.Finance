//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract ManagerData {
    address payable Owner;

    address ManagerContractAddress;
    address liquidationManagerContractAddress;

    uint256 lastTimeRewardParamsUpdated;

    struct MarketModel {
        address _marketAddress;
        bool _marketSupport;
        bool _marketExist;
    }
    mapping(uint256 => MarketModel) MarketModelMapping;

    uint256 coreRewardPerBlock;
    uint256 coreRewardDecrement;
    uint256 coreTotalRewardAmounts;

    uint256 alphaRate;

    modifier OnlyOwner() {
        require(msg.sender == Owner, "OnlyOwner");
        _;
    }

    modifier OnlyManagerContract() {
        require(msg.sender == ManagerContractAddress, "OnlyManagerContract");
        _;
    }

    constructor() {
        Owner = payable(msg.sender);

        coreRewardPerBlock = 0x478291c1a0e982c98;
        coreRewardDecrement = 0x7ba42eb3bfc;
        coreTotalRewardAmounts = (4 * 100000000) * (10**18);

        lastTimeRewardParamsUpdated = block.number;

        alphaRate = 2 * (10**17);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////// SETTER FUNCTIONS

    function setManagerContractAddress(address _ManagerContractAddress)
        external
        OnlyOwner
        returns (bool)
    {
        ManagerContractAddress = _ManagerContractAddress;
        return true;
    }

    function setLiquidationManagerContractAddress(
        address _liquidationManagerContractAddress
    ) external OnlyOwner returns (bool) {
        liquidationManagerContractAddress = _liquidationManagerContractAddress;
        return true;
    }

    function setCoreRewardPerBlock(uint256 _coreRewardPerBlock)
        external
        OnlyManagerContract
        returns (bool)
    {
        coreRewardPerBlock = _coreRewardPerBlock;

        return true;
    }

    function setCoreRewardDecrement(uint256 _coreRewardDecrement)
        external
        OnlyManagerContract
        returns (bool)
    {
        coreRewardDecrement = _coreRewardDecrement;
        return true;
    }

    function setCoreTotalRewardAmounts(uint256 _coreTotalRewardAmounts)
        external
        OnlyManagerContract
        returns (bool)
    {
        coreTotalRewardAmounts = _coreTotalRewardAmounts;
        return true;
    }

    function setAlphaRate(uint256 _alphaRate) external returns (bool) {
        alphaRate = _alphaRate;
        return true;
    }

    function registerNewMarketInCore(uint256 _marketID, address _marketAddress)
        external
        OnlyManagerContract
        returns (bool)
    {
        MarketModel memory _MarketModel;
        _MarketModel._marketAddress = _marketAddress;
        _MarketModel._marketExist = true;
        _MarketModel._marketSupport = true;

        MarketModelMapping[_marketID] = _MarketModel;

        return true;
    }

    function updateMarketAddress(uint256 _marketID, address _marketAddress)
        external
        OnlyManagerContract
        returns (bool)
    {
        MarketModelMapping[_marketID]._marketAddress = _marketAddress;
        return true;
    }

    function updateMarketExist(uint256 _marketID, bool _exist)
        external
        OnlyManagerContract
        returns (bool)
    {
        MarketModelMapping[_marketID]._marketExist = _exist;
        return true;
    }

    function updateMarketSupport(uint256 _marketID, bool _support)
        external
        OnlyManagerContract
        returns (bool)
    {
        MarketModelMapping[_marketID]._marketSupport = _support;
        return true;
    }

    function setLastTimeRewardParamsUpdated(
        uint256 _lastTimeRewardParamsUpdated
    ) external returns (bool) {
        lastTimeRewardParamsUpdated = _lastTimeRewardParamsUpdated;
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////// GETTERS FUNCTIONS

    function getcoreRewardPerBlock() external view returns (uint256) {
        return coreRewardPerBlock;
    }

    function getcoreRewardDecrement() external view returns (uint256) {
        return coreRewardDecrement;
    }

    function getcoreTotalRewardAmounts() external view returns (uint256) {
        return coreTotalRewardAmounts;
    }

    function getMarketInfo(uint256 _marketID)
        external
        view
        returns (bool, address)
    {
        return (
            MarketModelMapping[_marketID]._marketSupport,
            MarketModelMapping[_marketID]._marketAddress
        );
    }

    function getMarketAddress(uint256 _marketID)
        external
        view
        returns (address)
    {
        return MarketModelMapping[_marketID]._marketAddress;
    }

    function getMarketExist(uint256 _marketID) external view returns (bool) {
        return MarketModelMapping[_marketID]._marketExist;
    }

    function getMarketSupport(uint256 _marketID) external view returns (bool) {
        return MarketModelMapping[_marketID]._marketSupport;
    }

    function getAlphaRate() external view returns (uint256) {
        return alphaRate;
    }

    function getLastTimeRewardParamsUpdated() external view returns (uint256) {
        return lastTimeRewardParamsUpdated;
    }
}
