// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { parseEther } = require("@ethersproject/units");

  async function main() {
  const delay = (ms) => new Promise((res) => setTimeout(res, ms));

  // ERC20 contract info
  const rewardPerBlock = parseEther("1.1")
  const tokenName = 'TOKENNAME'
  const tokenSymbol = 'SYMBOL'
  let tokenSupply = 100000
  tokenSupply = parseEther(tokenSupply.toString())

  // reward amount approve to staking contract
  const approveMaxTokens = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
  // amount send to staking contract for reward
  const rewardAmount = parseEther("10000")

  let token = await hre.ethers.getContractFactory('ERC20Mock');

  token = await token.deploy(tokenName, tokenSymbol, tokenSupply);

  await token.deployed();

  console.log('Token deployed at:', token.address);
  
  
  let StakingContract = await ethers.getContractFactory("TokenFarmer");

  stakingContract = await StakingContract.deploy(
    token.address,
    rewardPerBlock,
    0,
    0
  );

  await stakingContract.deployed();
  // approve max token to staking contract
  await token.approve(stakingContract.address, approveMaxTokens)
  // transfer reward amount to staking contract
  await stakingContract.depositRewards(rewardAmount)

  console.log('stakingContract ', stakingContract.address)

  console.log("We verify now, Please wait!");
  await delay(45000);

   // verifying token contract
   await hre.run("verify:verify", {
    address: token.address,
    contract: "contracts/mocks/ERC20Mock.sol:ERC20Mock",
    constructorArguments: [tokenName, tokenSymbol, tokenSupply],
  });

  // verifying lp staking contract
  await hre.run("verify:verify", {
    address: stakingContract.address,
    contract: "contracts/TokenFarmer.sol:TokenFarmer",
    constructorArguments: [token.address, rewardPerBlock, 0, 0],
  });
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
