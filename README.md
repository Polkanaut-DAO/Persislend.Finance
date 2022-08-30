Persis Lend, Defi project, Lending and Borrowing platform.

---

in this platform, I used solidity language to create smart contracts and reactjs for creating front-end and ethers to manage WEB3 and make connections between front-end and blockchain.

The important part of this project is to use the updated price of ERC20 assets in the platform, thanks to ChainLink contracts, we get the most updated price of tokens and use them to manage the 4 main actions of the platform and liquidation process.

User's can deposit ERC20 assets that are supported in Persis Lend and borrow up to 70 % of the value of deposited assets in other markets. 
for example, a user can deposit 100$ DAI and borrow up to 70$ ETH.

calculation of interest rates in Persis Lend will happen in the interest model contract and is based on the total amounts of deposits and borrows in the market. If the deposits in the market increase, the interest rates decrease, making borrowing more frugal. If the borrows increase, the interest rates increase, making depositing more frugal.

there is a minimum interest rate for borrowing from Persis Lend and the value is set in the deployment process. In front of the platform, the user will see the supply and borrow rates per block. In short, we calculate the yearly interest rate in the interest model by the total deposit amount and total borrow amount, and then by dividing them by the total blocks per year, to get the rate per block.

every market is contained 2 contracts, a contract for logic functions and a contract for storing data and details about market balance and user balance. with this pattern, anytime we can create a new contract for logic functions without losing data.

for the Liquidation process, we have a liquidation contract. in this contract,by get last price of erc20 assets from ChainLink contracts ,we calculate liquidationLimitAssetSum $ based on margin call limit factor and userBorrowAssetSum $ and if liquidationLimitAssetSum is lower than or equal to userBorrowAssetSum, user is ready for Margin call  !

in the core of all these markets, there is a Manager contract, the duty of this contract is to update market and user balance details and run interest rate calculations after or before any action. Manager contract is connected to all markets and at any time we can get updated withdrawable or borrowable amounts for users and use them in withdraw or borrow action.
