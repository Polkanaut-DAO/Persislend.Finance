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
  const amount = hre.ethers.utils.parseEther('10');

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

  let ETHTokenMarketContract;
  let ETHDataContract;

  let ManagerContract;
  let ManagerDataStorageContract;

  const borrowLimit = hre.ethers.utils.parseEther('0.7');
  const marginCallLimit = hre.ethers.utils.parseEther('0.9');
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

    await InterestModelContract.setBlocksPerYear(
      hre.ethers.utils.parseEther('2102400')
    );

    /// ///////////////////////////////////////////////////////////////////////// DEPLOY ETHTokenMarket
    const ETHTokenMarket = await hre.ethers.getContractFactory(
      'ETHMarket'
    );
    ETHTokenMarketContract = await ETHTokenMarket.deploy();
    await ETHTokenMarketContract.deployed();

    /// ///////////////////////////////////////////////////////////////////////// DEPLOY ETHData
    const ETHData = await hre.ethers.getContractFactory('MarketData');
    ETHDataContract = await ETHData.deploy(
      borrowLimit,
      marginCallLimit,
      minimumInterestRate,
      liquiditySensitive
    );
    await ETHDataContract.deployed();

    /// ///////////////////////////////////////////////////////////////////////// DEPLOY CORE MANAGER
    const Manager = await hre.ethers.getContractFactory('Manager');

    ManagerContract = await Manager.deploy();
    await ManagerContract.deployed();

    /// ///////////////////////////////////////////////////////////////////////// DEPLOY CORE MANAGER DATA
    const ManagerDataStorage = await hre.ethers.getContractFactory(
      'ManagerData'
    );

    ManagerDataStorageContract = await ManagerDataStorage.deploy();
    await ManagerDataStorageContract.deployed();

    ////////// *** setup *** //////////
    /// ETH MARKET //////////////////////////////////////////////////////////////////////
    await ETHTokenMarketContract.setManagerContract(
      ManagerContract.address
    );
    await ETHTokenMarketContract.setDataStorageContract(
      ETHDataContract.address
    );
    await ETHTokenMarketContract.setInterestModelContract(
      InterestModelContract.address
    );
    // await ETHTokenMarketContract.setRewardManagerContract(
    //   ETHRewardManagerContract.address
    // );
    await ETHTokenMarketContract.setMarketName('ETH');
    await ETHTokenMarketContract.setMarketID(0);

    /// ETH DATA //////////////////////////////////////////////////////////////////////
    await ETHDataContract.setMarketContract(
      ETHTokenMarketContract.address
    );
    await ETHDataContract.setInterestModelContract(
      InterestModelContract.address
    );

    /// MANAGER //////////////////////////////////////////////////////////////////////
    await ManagerDataStorageContract.setManagerContractAddress(
      ManagerContract.address
    );

    await ManagerContract.setOracleContract(
      OracleProxyContract.address
    );
    await ManagerContract.setManagerDataStorageContract(
      ManagerDataStorageContract.address
    );
    await ManagerContract.registerNewHandler(
      0,
      ETHTokenMarketContract.address
    );
  });

  describe('', async function () {
    it('DEPOSIT DAI', async function () {
      //user 1 make deposit / 10 ether in ether market
      TX = await ETHTokenMarketContract.connect(addr1).deposit(
        amount,
        {
          value: amount,
        }
      );
      await TX.wait(1);

      // check user deposit in eth market
      answer = await ETHTokenMarketContract.getUserDepositAmount(
        addr1.address
      );
      expect(answer).equal(amount);

      // check eth market total deposit
      answer =
        await ETHTokenMarketContract.getMarketDepositTotalAmount();
      expect(answer).equal(amount);

      // ** //
      // user1 make withdraw
      answer =
        await ETHTokenMarketContract.getUserMaxAmountToWithdraw(
          addr1.address
        );
      expect(answer).equal(amount);

      TX = await ETHTokenMarketContract.connect(addr1).withdraw(
        amount
      );
      await TX.wait(1);

      // check user deposit in eth market after withdraw
      answer = await ETHTokenMarketContract.getUserDepositAmount(
        addr1.address
      );
      expect(answer).equal(0);

      // check eth market total deposit after withdraw
      answer =
        await ETHTokenMarketContract.getUserMaxAmountToWithdraw(
          addr1.address
        );
      console.log(answer.toString());
    });
  });
});
