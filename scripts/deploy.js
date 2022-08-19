const {
  time,
  loadFixture,
} = require('@nomicfoundation/hardhat-network-helpers');
const {
  anyValue,
} = require('@nomicfoundation/hardhat-chai-matchers/withArgs');
const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Persis', function () {
  let deployer;
  let addr1;
  let addr2;
  let addr3;
  let addr4;

  let TX;
  let blockN;
  let balance;

  let InterestModelContract;

  let ETHAggregatorV3Contract;
  let OracleProxyContract;

  let ethMarketContractor;
  let ethDataMarket;

  const borrowLimit = hre.ethers.utils.parseEther('0.75');
  const marginCallLimit = hre.ethers.utils.parseEther('0.93');
  const minimumInterestRate = 0;
  const liquiditySensitive = hre.ethers.utils.parseEther('0.05');

  beforeEach(async () => {
    [deployer, addr1, addr2, addr3, addr4] =
      await ethers.getSigners();

    /// ///////////////////////////////////////////////////////////////////////// DEPLOY ETHAggregatorV3
    const ETHAggregatorV3 = await hre.ethers.getContractFactory(
      'AggregatorV3'
    );
    ETHAggregatorV3Contract = await ETHAggregatorV3.deploy(
      '0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF'
    );
    await ETHAggregatorV3Contract.deployed();

    /// ///////////////////////////////////////////////////////////////////////// DEPLOY OracleProxy
    const OracleProxy = await hre.ethers.getContractFactory(
      'oracleProxy'
    );
    OracleProxyContract = await OracleProxy.deploy(
      ETHAggregatorV3Contract.address
    );
    await OracleProxyContract.deployed();

    /// ///////////////////////////////////////////////////////////////////////// DEPLOY InterestModel
    const InterestModel = await hre.ethers.getContractFactory(
      'InterestModel'
    );

    InterestModelContract = await InterestModel.deploy(
      hre.ethers.utils.parseEther('0.025'),
      hre.ethers.utils.parseEther('0.8'),
      hre.ethers.utils.parseEther('0.1'),
      hre.ethers.utils.parseEther('0.18'),
      hre.ethers.utils.parseEther('0.825')
    );
    await InterestModelContract.deployed();
    console.log(
      'InterestModelContract deployed to:',
      InterestModelContract.address
    );

    await InterestModelContract.setBlocksPerYear(
      hre.ethers.utils.parseEther('2102400')
    );

    /// ///////////////////////////////////////////////////////////////////////// DEPLOY ETHTokenMarket
    const ETHTokenMarket = await hre.ethers.getContractFactory(
      'ETHMarket'
    );
    ETHTokenMarketContract = await ETHTokenMarket.deploy();
    await ETHTokenMarketContract.deployed();
    console.log(
      'ETHTokenMarketContract deployed to:',
      ETHTokenMarketContract.address
    );

    /// ///////////////////////////////////////////////////////////////////////// DEPLOY ETHData
    const ETHData = await hre.ethers.getContractFactory('MarketData');
    ETHDataContract = await ETHData.deploy(
      borrowLimit,
      martinCallLimit,
      minimumInterestRate,
      liquiditySensitive
    );
    await ETHDataContract.deployed();
    console.log(
      'ETHDataContract deployed to:',
      ETHDataContract.address
    );
  });
});
