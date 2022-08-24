const {
  time,
  loadFixture,
} = require('@nomicfoundation/hardhat-network-helpers');
const {
  anyValue,
} = require('@nomicfoundation/hardhat-chai-matchers/withArgs');
const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Persis Lend Finance', function () {
  const amount = hre.ethers.utils.parseEther('10');
  const amountToDAI = hre.ethers.utils.parseEther('10');

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

  let DAITokenMarketContract;
  let DAIDataContract;

  let ManagerContract;
  let ManagerDataStorageContract;

  let exampleDAITokenContract;

  const borrowLimit = hre.ethers.utils.parseEther('0.7');
  const marginCallLimit = hre.ethers.utils.parseEther('0.9');
  // const minimumInterestRate = 0;
  // const liquiditySensitive = hre.ethers.utils.parseEther('0.05');

  beforeEach(async () => {
    [deployer, addr1, addr2, addr3, addr4] =
      await ethers.getSigners();

    /// ///////////////////////////////////////////////////////////////////////// DEPLOY DAI
    const DAI = await hre.ethers.getContractFactory('DAI');
    exampleDAITokenContract = await DAI.deploy();
    await exampleDAITokenContract.deployed();

    // approve to deposit;
    TX = await exampleDAITokenContract.approve(
      addr1.address,
      amountToDAI
    );
    await TX.wait(1);

    // deposit
    TX = await exampleDAITokenContract.transfer(
      addr1.address,
      amountToDAI
    );
    await TX.wait(1);

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
      ETHAggregatorV3Contract.address,
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

    await InterestModelContract.setBlocksPerYear(2102400);

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
      marginCallLimit
    );
    await ETHDataContract.deployed();

    /// ///////////////////////////////////////////////////////////////////////// DEPLOY DAITokenMarket
    const DAITokenMarket = await hre.ethers.getContractFactory(
      'TokenMarket'
    );
    DAITokenMarketContract = await DAITokenMarket.deploy(
      exampleDAITokenContract.address
    );
    await DAITokenMarketContract.deployed();

    /// ///////////////////////////////////////////////////////////////////////// DEPLOY DAIData
    const DAIData = await hre.ethers.getContractFactory('MarketData');
    DAIDataContract = await DAIData.deploy(
      borrowLimit,
      marginCallLimit
    );
    await DAIDataContract.deployed();

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

    /// DAI MARKET //////////////////////////////////////////////////////////////////////
    await DAITokenMarketContract.setManagerContract(
      ManagerContract.address
    );
    await DAITokenMarketContract.setDataStorageContract(
      DAIDataContract.address
    );
    await DAITokenMarketContract.setInterestModelContract(
      InterestModelContract.address
    );
    // await ETHTokenMarketContract.setRewardManagerContract(
    //   ETHRewardManagerContract.address
    // );
    await DAITokenMarketContract.setMarketName('DAI');
    await DAITokenMarketContract.setMarketID(1);

    /// ETH DATA //////////////////////////////////////////////////////////////////////
    await ETHDataContract.setMarketContract(
      ETHTokenMarketContract.address
    );
    await ETHDataContract.setInterestModelContract(
      InterestModelContract.address
    );

    /// DAI DATA //////////////////////////////////////////////////////////////////////
    await DAIDataContract.setMarketContract(
      DAITokenMarketContract.address
    );
    await DAIDataContract.setInterestModelContract(
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
    await ManagerContract.registerNewHandler(
      1,
      DAITokenMarketContract.address
    );
  });

  // annual

  describe('Test ETH Market', async function () {
    beforeEach(async function () {
      //user 1 make deposit / 10 ether in ether market
      TX = await ETHTokenMarketContract.connect(addr1).deposit(
        amount,
        {
          value: amount,
        }
      );
      await TX.wait(1);
    });
    it('User make deposit in market , and we check all updated details about user and market ;)', async function () {
      // check user deposit in eth market; should be equal to amount;
      answer = await ETHTokenMarketContract.getUserDepositAmount(
        addr1.address
      );
      expect(answer).equal(amount);

      // check eth market total deposit; should be equal to amount;
      answer =
        await ETHTokenMarketContract.getMarketDepositTotalAmount();
      expect(answer).equal(amount);

      // now check how much user can withdraw from market after deposit ; should be equal to amount;
      answer =
        await ETHTokenMarketContract.getUserMaxAmountToWithdraw(
          addr1.address
        );
      expect(answer).equal(amount);

      // now check how much user can borrow from market; it should be 70% of amount;
      answer = await ETHTokenMarketContract.getUserMaxAmountToBorrow(
        addr1.address
      );
      expect(answer).equal(hre.ethers.utils.parseEther('7'));

      // get how much user can borrow from manager contract !
      answer = await ManagerContract.getHowMuchUserCanBorrow(
        addr1.address,
        0
      );
      expect(answer).equal(hre.ethers.utils.parseEther('7'));

      // get how much user can borrow from manager contract ! in $ value :) here we check borrowable $ value;
      answer =
        await ManagerContract.getUserUpdatedParamsFromAllMarkets(
          addr1.address
        );
      expect(answer[0]).equal(7);

      // get updated user details after making intreset update for user and market ! in $ value ! here we check deposit $ value
      answer = await ManagerContract.getUpdatedInterestAmountsForUser(
        addr1.address,
        0
      );
      expect(answer[0]).equal(10);

      // here we check how much user is free to borrow from given market !
      answer = await ManagerContract.getUserFreeToWithdraw(
        addr1.address,
        0
      );
      expect(answer).equal(amount);
    });
  });

  describe('Test DAI Market', async function () {
    beforeEach(async function () {
      // approve to deposit;
      TX = await exampleDAITokenContract
        .connect(addr1)
        .approve(DAITokenMarketContract.address, amountToDAI);
      await TX.wait(1);

      // deposit
      TX = await DAITokenMarketContract.connect(addr1).deposit(
        amountToDAI
      );
      await TX.wait(1);
    });
    it('User make deposit in market', async function () {
      // check user deposit in eth market; should be equal to amount;
      answer = await DAITokenMarketContract.connect(
        addr1
      ).getUserDepositAmount(addr1.address);
      expect(answer).equal(amountToDAI);

      // check eth market total deposit; should be equal to amount;
      answer =
        await DAITokenMarketContract.getMarketDepositTotalAmount();
      expect(answer).equal(amountToDAI);

      // now check how much user can withdraw from market after deposit ; should be equal to amount;
      answer =
        await DAITokenMarketContract.getUserMaxAmountToWithdraw(
          addr1.address
        );
      expect(answer).equal(amountToDAI);

      // now check how much user can borrow from market; it should be 70% of amount;
      answer = await DAITokenMarketContract.getUserMaxAmountToBorrow(
        addr1.address
      );
      expect(answer).equal(hre.ethers.utils.parseEther('7'));

      // get how much user can borrow from manager contract !
      answer = await ManagerContract.getHowMuchUserCanBorrow(
        addr1.address,
        1
      );
      expect(answer).equal(hre.ethers.utils.parseEther('7'));

      // get how much user can borrow from manager contract ! in $ value :) here we check borrowable $ value;
      answer =
        await ManagerContract.getUserUpdatedParamsFromAllMarkets(
          addr1.address
        );
      expect(answer[0]).equal(7);

      // get updated user details after making intreset update for user and market ! in $ value ! here we check deposit $ value
      answer = await ManagerContract.getUpdatedInterestAmountsForUser(
        addr1.address,
        1
      );
      expect(answer[0]).equal(10);

      // here we check how much user is free to borrow from given market !
      answer = await ManagerContract.getUserFreeToWithdraw(
        addr1.address,
        1
      );
      expect(answer).equal(amountToDAI);
    });
  });

  describe('Test, User 1 Deposit DAI ,User 2 Deposit ETH, User 2 Borrow DAI !', async function () {
    beforeEach(async function () {
      /// *** user 1 make deposit in DAI market;
      // approve to deposit;
      TX = await exampleDAITokenContract
        .connect(addr1)
        .approve(DAITokenMarketContract.address, amountToDAI);
      await TX.wait(1);

      // deposit
      TX = await DAITokenMarketContract.connect(addr1).deposit(
        amountToDAI
      );
      await TX.wait(1);

      /// *** user 2 make deposit in ETH market;
      TX = await ETHTokenMarketContract.connect(addr2).deposit(
        amount,
        {
          value: amount,
        }
      );
      await TX.wait(1);
    });
    it('User 1 deposit / User 2 borrow ! check balances after this actions !', async function () {
      // user 2 want borrow from market; let see how much he can borrow from dai market !
      answer = await DAITokenMarketContract.getUserMaxAmountToBorrow(
        addr2.address
      );
      expect(answer).equal(hre.ethers.utils.parseEther('7'));

      // now user 2 make borrow from DAI market ! 7 DAI token / 70 % of deposit;
      TX = await DAITokenMarketContract.connect(addr2).borrow(answer);
      await TX.wait(1);

      // now DAI balance of user 2 should be 7 from zero !
      expect(
        await exampleDAITokenContract.balanceOf(addr2.address)
      ).equal(hre.ethers.utils.parseEther('7'));

      // now DAI market balance should be 7 DAI !
      answer =
        await DAITokenMarketContract.getMarketBorrowTotalAmount();
      expect(answer).equal(hre.ethers.utils.parseEther('7'));

      // now borrow balance of user 2 should be 7 !
      answer = await DAITokenMarketContract.getUserBorrowAmount(
        addr2.address
      );
      expect(answer).equal(hre.ethers.utils.parseEther('7'));

      // now DAI balance of user 1 should be 10 / no change for user 1
      answer = await DAITokenMarketContract.getUserDepositAmount(
        addr1.address
      );
      expect(answer).equal(amountToDAI);

      // now borrow balance of user 1 should be 0 !
      answer = await DAITokenMarketContract.getUserBorrowAmount(
        addr1.address
      );
      expect(answer).equal(hre.ethers.utils.parseEther('0'));

      // now check withdrawable ETH balance of user 2 after borrow ! it should be 0 ! because ot active borrow !
      answer =
        await ETHTokenMarketContract.getUserMaxAmountToWithdraw(
          addr2.address
        );
      expect(answer).equal(hre.ethers.utils.parseEther('0'));

      // let see how much he can borrow from dai market ! after first borrow ! it should be 0 because of all of user liq is for first borrow;
      answer = await DAITokenMarketContract.getUserMaxAmountToBorrow(
        addr2.address
      );
      expect(answer).equal(hre.ethers.utils.parseEther('0'));

      /// *** user 2 make deposit in ETH market again;
      TX = await ETHTokenMarketContract.connect(addr2).deposit(
        amount,
        {
          value: amount,
        }
      );
      await TX.wait(1);

      // now check withdrawable ETH balance of user 2 after borrow ! it should be new deposit ! because ot active borrow !
      answer =
        await ETHTokenMarketContract.getUserMaxAmountToWithdraw(
          addr2.address
        );
      expect(answer).equal(amount);

      // // let see how much he can borrow from dai market ! after first borrow ! expect to be 3 / we have 10 liq but in dai market there is free 3 DAI !
      // answer = await DAITokenMarketContract.getUserMaxAmountToBorrow(
      //   addr2.address
      // );
      // expect(answer).equal(hre.ethers.utils.parseEther('3'));

      // // now let check withdrawable DAI for user 1! it should be 3 because 7 token borrowed from addr2
      // answer =
      //   await DAITokenMarketContract.getUserMaxAmountToWithdraw(
      //     addr1.address
      //   );
      // expect(answer).equal(hre.ethers.utils.parseEther('3'));

      // // now user 2 will borrow more dai tokens !
      // answer = await DAITokenMarketContract.getUserMaxAmountToBorrow(
      //   addr2.address
      // );
      // expect(answer).equal(hre.ethers.utils.parseEther('3'));

      // TX = await DAITokenMarketContract.connect(addr2).borrow(answer);
      // await TX.wait(1);

      // // user 2 borrowed more dai , now total borrow of user 2 is 10
      // // now borrow balance of user 2 should be 10 !
      // answer = await DAITokenMarketContract.getUserBorrowAmount(
      //   addr2.address
      // );
      // expect(answer).equal(hre.ethers.utils.parseEther('10'));

      // // now borrow balance of market dai should be 10 !
      // answer =
      //   await DAITokenMarketContract.getMarketBorrowTotalAmount();
      // expect(answer).equal(hre.ethers.utils.parseEther('10'));

      // // now withdraw balance of user 1 should be 0 !;
      // answer =
      //   await DAITokenMarketContract.getUserMaxAmountToWithdraw(
      //     addr1.address
      //   );
      // expect(answer).equal(hre.ethers.utils.parseEther('0'));

      // // now withdrawable balance of user 2 / user 2 got 3 dai borrow ! it is 30 % of free liq from user 2 ; but wee need guaranteed liq from user 2 and it is more 40 % of borrowed;
      // answer =
      //   await ETHTokenMarketContract.getUserMaxAmountToWithdraw(
      //     addr2.address
      //   );
      // // 2 more tokens are for margin call !
      // expect(answer).equal(hre.ethers.utils.parseEther('5'));
    });
  });

  describe('Test, Annual Interest Rate', async function () {
    beforeEach(async function () {
      /// *** user 1 make deposit in DAI market;
      // approve to deposit;
      TX = await exampleDAITokenContract.approve(
        DAITokenMarketContract.address,
        hre.ethers.utils.parseEther('1000')
      );
      await TX.wait(1);

      // deposit
      TX = await DAITokenMarketContract.deposit(
        hre.ethers.utils.parseEther('1000')
      );
      await TX.wait(1);

      /// *** user 2 make deposit in ETH market;
      TX = await ETHTokenMarketContract.connect(addr2).deposit(
        hre.ethers.utils.parseEther('5'),
        {
          value: hre.ethers.utils.parseEther('5'),
        }
      );
      await TX.wait(1);
    });
    it('Annual Interest Rate !', async function () {
      // now deployer borrow some ETH from ETH market;
      TX = await ETHTokenMarketContract.borrow(
        hre.ethers.utils.parseEther('3')
      );
      await TX.wait(1);

      // get SIRBIR;
      answer =
        await ETHTokenMarketContract.getUpdatedMarketSIRAndBIR();
      console.log(ethers.utils.formatUnits(answer[0].toString(), 16));
      console.log(ethers.utils.formatUnits(answer[1].toString(), 16));
    });
  });
});
