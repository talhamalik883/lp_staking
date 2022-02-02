// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { parseEther } = require("@ethersproject/units");

async function main() {
  const delay = (ms) => new Promise((res) => setTimeout(res, ms));

  const rewardTokenAddress = ""; // token ADDRESS
  const lpAddress = ""  // lp address
  const StakingContract = await ethers.getContractFactory("TokenFarmer");
  const startBlockTime = 13928846
  const rewardPerBlock = parseEther("1.1")
  // reward amount approve to staking contract
  const approveMaxTokens = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
  // amount send to staking contract for reward
  const rewardAmount = parseEther("10000")

  let stakingContract = await StakingContract.deploy(
    rewardTokenAddress,
    rewardPerBlock,
    startBlockTime,
    0
  );
  await stakingContract.deployed();

  // add pool in staking
  await stakingContract.addPool(5, lpAddress)
  
  // approve max token to staking contract
  await token.approve(stakingContract.address, approveMaxTokens)
  
  // transfer reward amount to staking contract
  await stakingContract.depositRewards(rewardAmount)

  console.log("We verify now, Please wait!");
  await delay(45000);

  await hre.run("verify:verify", {
    address: stakingContract.address,
    constructorArguments: [rewardTokenAddress, rewardPerBlock, startBlockTime, 0],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
