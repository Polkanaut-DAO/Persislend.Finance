const hre = require('hardhat');

async function Deploy() {
  const borrowLimit = hre.ethers.utils.parseEther('0.7');
  const marginCallLimit = hre.ethers.utils.parseEther('0.9');
  // const minimumInterestRate = 0;
  // const liquiditySensitive = hre.ethers.utils.parseEther('0.05');

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY DAI
  const DAI = await hre.ethers.getContractFactory('DAI');
  const exampleDAITokenContract = await DAI.deploy();
  await exampleDAITokenContract.deployed();

  console.log(
    'exampleDAITokenContract deployed to:',
    exampleDAITokenContract.address
  );

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY ETHAggregatorV3
  const ETHAggregatorV3 = await hre.ethers.getContractFactory(
    'AggregatorV3'
  );
  const ETHAggregatorV3Contract = await ETHAggregatorV3.deploy(
    '0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e'
  );
  await ETHAggregatorV3Contract.deployed();

  console.log(
    'ETHAggregatorV3Contract deployed to:',
    ETHAggregatorV3Contract.address
  );

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY LINKAggregatorV3
  const LINKAggregatorV3 = await hre.ethers.getContractFactory(
    'AggregatorV3'
  );
  const LINKAggregatorV3Contract = await LINKAggregatorV3.deploy(
    '0x48731cF7e84dc94C5f84577882c14Be11a5B7456'
  );
  await LINKAggregatorV3Contract.deployed();

  console.log(
    'LINKAggregatorV3Contract deployed to:',
    LINKAggregatorV3Contract.address
  );

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY OracleProxy
  const OracleProxy = await hre.ethers.getContractFactory(
    'oracleProxy'
  );
  const OracleProxyContract = await OracleProxy.deploy(
    ETHAggregatorV3Contract.address,
    LINKAggregatorV3Contract.address
  );
  await OracleProxyContract.deployed();

  console.log(
    'OracleProxyContract deployed to:',
    OracleProxyContract.address
  );

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY InterestModel
  const InterestModel = await hre.ethers.getContractFactory(
    'InterestModel'
  );

  const InterestModelContract = await InterestModel.deploy(
    hre.ethers.utils.parseEther('0.025'),
    hre.ethers.utils.parseEther('0.8'),
    hre.ethers.utils.parseEther('0.1'),
    hre.ethers.utils.parseEther('0.18'),
    hre.ethers.utils.parseEther('0.825')
  );
  await InterestModelContract.deployed();

  TX = await InterestModelContract.setBlocksPerYear(2102400);
  await TX.wait(1);

  console.log(
    'InterestModelContract deployed to:',
    InterestModelContract.address
  );

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY ETHTokenMarket
  const ETHTokenMarket = await hre.ethers.getContractFactory(
    'ETHMarket'
  );
  const ETHTokenMarketContract = await ETHTokenMarket.deploy();
  await ETHTokenMarketContract.deployed();

  console.log(
    'ETHTokenMarketContract deployed to:',
    ETHTokenMarketContract.address
  );

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY ETHData
  const ETHData = await hre.ethers.getContractFactory('MarketData');
  const ETHDataContract = await ETHData.deploy(
    borrowLimit,
    marginCallLimit
  );
  await ETHDataContract.deployed();

  console.log(
    'ETHDataContract deployed to:',
    ETHDataContract.address
  );

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY DAITokenMarket
  const DAITokenMarket = await hre.ethers.getContractFactory(
    'TokenMarket'
  );
  const DAITokenMarketContract = await DAITokenMarket.deploy(
    exampleDAITokenContract.address
  );
  await DAITokenMarketContract.deployed();

  console.log(
    'DAITokenMarketContract deployed to:',
    DAITokenMarketContract.address
  );

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY DAIData
  const DAIData = await hre.ethers.getContractFactory('MarketData');
  const DAIDataContract = await DAIData.deploy(
    borrowLimit,
    marginCallLimit
  );
  await DAIDataContract.deployed();

  console.log(
    'DAIDataContract deployed to:',
    DAIDataContract.address
  );

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY linkTokenMarket
  const LINKTokenMarket = await hre.ethers.getContractFactory(
    'TokenMarket'
  );
  const LINKTokenMarketContract = await LINKTokenMarket.deploy(
    exampleDAITokenContract.address
  );
  await LINKTokenMarketContract.deployed();

  console.log(
    'LINKTokenMarketContract deployed to:',
    LINKTokenMarketContract.address
  );

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY linkData
  const LINKData = await hre.ethers.getContractFactory('MarketData');
  const LINKDataContract = await LINKData.deploy(
    borrowLimit,
    marginCallLimit
  );
  await LINKDataContract.deployed();

  console.log(
    'LINKDataContract deployed to:',
    LINKDataContract.address
  );

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY CORE MANAGER
  const Manager = await hre.ethers.getContractFactory('Manager');

  const ManagerContract = await Manager.deploy();
  await ManagerContract.deployed();

  console.log(
    'ManagerContract deployed to:',
    ManagerContract.address
  );

  /// ///////////////////////////////////////////////////////////////////////// DEPLOY CORE MANAGER DATA
  const ManagerDataStorage = await hre.ethers.getContractFactory(
    'ManagerData'
  );

  const ManagerDataStorageContract =
    await ManagerDataStorage.deploy();
  await ManagerDataStorageContract.deployed();

  console.log(
    'ManagerDataStorageContract deployed to:',
    ManagerDataStorageContract.address
  );

  ////////// *** setup *** //////////
  /// ETH MARKET //////////////////////////////////////////////////////////////////////
  TX = await ETHTokenMarketContract.setManagerContract(
    ManagerContract.address
  );
  await TX.wait(1);

  TX = await ETHTokenMarketContract.setDataStorageContract(
    ETHDataContract.address
  );
  await TX.wait(1);

  TX = await ETHTokenMarketContract.setInterestModelContract(
    InterestModelContract.address
  );
  await TX.wait(1);

  TX = await ETHTokenMarketContract.setMarketName('ETH');
  await TX.wait(1);

  TX = await ETHTokenMarketContract.setMarketID(0);
  await TX.wait(1);

  /// DAI MARKET //////////////////////////////////////////////////////////////////////
  TX = await DAITokenMarketContract.setManagerContract(
    ManagerContract.address
  );
  await TX.wait(1);

  TX = await DAITokenMarketContract.setDataStorageContract(
    DAIDataContract.address
  );
  await TX.wait(1);

  TX = await DAITokenMarketContract.setInterestModelContract(
    InterestModelContract.address
  );
  await TX.wait(1);

  TX = await DAITokenMarketContract.setMarketName('DAI');
  await TX.wait(1);

  TX = await DAITokenMarketContract.setMarketID(1);
  await TX.wait(1);

  /// LINK MARKET //////////////////////////////////////////////////////////////////////
  TX = await LINKTokenMarketContract.setManagerContract(
    ManagerContract.address
  );
  await TX.wait(1);

  TX = await LINKTokenMarketContract.setDataStorageContract(
    LINKDataContract.address
  );
  await TX.wait(1);

  TX = await LINKTokenMarketContract.setInterestModelContract(
    InterestModelContract.address
  );
  await TX.wait(1);

  TX = await LINKTokenMarketContract.setMarketName('LINK');
  await TX.wait(1);

  TX = await LINKTokenMarketContract.setMarketID(2);
  await TX.wait(1);

  /// ETH DATA //////////////////////////////////////////////////////////////////////
  TX = await ETHDataContract.setMarketContract(
    ETHTokenMarketContract.address
  );
  await TX.wait(1);

  TX = await ETHDataContract.setInterestModelContract(
    InterestModelContract.address
  );
  await TX.wait(1);

  /// DAI DATA //////////////////////////////////////////////////////////////////////
  TX = await DAIDataContract.setMarketContract(
    DAITokenMarketContract.address
  );
  await TX.wait(1);

  TX = await DAIDataContract.setInterestModelContract(
    InterestModelContract.address
  );
  await TX.wait(1);

  /// LINK DATA //////////////////////////////////////////////////////////////////////
  TX = await LINKDataContract.setMarketContract(
    LINKTokenMarketContract.address
  );
  await TX.wait(1);

  TX = await LINKDataContract.setInterestModelContract(
    InterestModelContract.address
  );
  await TX.wait(1);

  /// MANAGER //////////////////////////////////////////////////////////////////////
  TX = await ManagerDataStorageContract.setManagerContractAddress(
    ManagerContract.address
  );
  await TX.wait(1);

  TX = await ManagerContract.setOracleContract(
    OracleProxyContract.address
  );
  await TX.wait(1);

  TX = await ManagerContract.setManagerDataStorageContract(
    ManagerDataStorageContract.address
  );
  await TX.wait(1);

  TX = await ManagerContract.registerNewHandler(
    0,
    ETHTokenMarketContract.address
  );
  await TX.wait(1);

  TX = await ManagerContract.registerNewHandler(
    1,
    DAITokenMarketContract.address
  );
  await TX.wait(1);

  TX = await ManagerContract.registerNewHandler(
    2,
    LINKTokenMarketContract.address
  );
  await TX.wait(1);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
Deploy().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
