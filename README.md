# Local setup

Clone the repo

```shell
git clone https://github.com/talhamalik883/lp_staking.git
```

Enter into the main folder.

Install dependencies

```shell
npm install
```

# Configure the deployment

Copy and rename `.env.example` to `.env`, open it and then enter your:

1. The private key of the account which will send the deployment transaction
2. BSCSCAN API key (get one [here](https://bscscan.com/myapikey))
   Adjust the contract deployment settings!
   <b>scripts/deployFarmer.js</b>

# Deployment & verification on testnet or mainnet

Enter `scripts/deployFarmerWithMock.js`
Make sure you've set the correct input according to the comments in the file.

## Testnet with mock token

```shell
 npx hardhat run scripts/deployFarmerWithMock.js --network bscTest
```

## Mainnet

```shell
npx hardhat run scripts/deployFarmer.js --network bsc
```
