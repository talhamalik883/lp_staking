const { ethers, network } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");
const { parseEther, formatEther } = require("@ethersproject/units");

use(solidity);

describe("Staking Contract", function () {
  const tokenName = 'TOKENNAME'
  const tokenSymbol = 'SYMBOL'

  it("Snapshot EVM", async function () {
    snapshotId = await ethers.provider.send("evm_snapshot");
  });

  it("Defining Generals", async function () {
    // General
    provider = ethers.provider;
    accounts = await hre.ethers.getSigners();
  });

  it("Deploying Mock token", async function () {
    const RewardToken = await ethers.getContractFactory("ERC20Mock");
    rewardToken = await RewardToken.deploy(tokenName, tokenSymbol, parseEther("100"));
  });

  it("Deploying pretend LP token", async function () {
    const LPToken = await ethers.getContractFactory("ERC20Mock");
    lpToken = await LPToken.deploy("Lp-Token", "Lp", parseEther("100"));
  });

  it("Deploying Farm", async function () {
    const StakingContract = await ethers.getContractFactory("TokenFarmer");
    let currentBlock = await ethers.provider.getBlockNumber();
    stakingContract = await StakingContract.deploy(
      rewardToken.address,
      parseEther("1"),
      currentBlock,
      currentBlock + 25
    );
    await stakingContract.deployed();
  });

  it("Create a Pool", async function () {
    await stakingContract.addPool(10, rewardToken.address);
  });

  it("Create a Pool LP", async function () {
    await stakingContract.addPool(10, lpToken.address);
  });

  it("Edit a Pool No update", async function () {
    await stakingContract.editPool(0, 10);
  });

  it("Edit a Pool update all", async function () {
    await stakingContract.editPool(0, 10);
  });

  it("Deposit In a Reward token Pool", async function () {
    await rewardToken.approve(stakingContract.address, parseEther("10"));
    await stakingContract.deposit(0, parseEther("10"));

    const depositValue = await stakingContract.userInfo(0, accounts[0].address);
    expect(depositValue[0]).to.equal(parseEther("10"));
  });

  it("Withdraw Deposit Tokens", async function () {
    await stakingContract.withdraw(0, parseEther("10"));
  });

  it("Add Rewards for distribution", async function () {
    await rewardToken.approve(stakingContract.address, parseEther("10"));
    await stakingContract.depositRewards(parseEther("10"));
  });
  it("Deposit In a Reward token Pool", async function () {
    await rewardToken.approve(stakingContract.address, parseEther("10"));
    await stakingContract.deposit(0, parseEther("10"));

    const depositValue = await stakingContract.userInfo(0, accounts[0].address);
    expect(depositValue[0]).to.equal(parseEther("10"));
  });

  it("Withdraw Rewards for distribution", async function () {
    await stakingContract.withdrawRewards(parseEther("1"));
  });

  it("Withdraw Deposit Tokens", async function () {
    console.log(
      "Before harvest: ",
      formatEther(await rewardToken.balanceOf(accounts[0].address))
    );
    for (let i = 0; i < 20; i++) {
      await network.provider.send("evm_mine");
    }
    await stakingContract.withdraw(0, parseEther("0"));
    console.log(
      "After harvest: ",
      formatEther(await rewardToken.balanceOf(accounts[0].address))
    );
  });

  it("Deposit In a LP token Pool", async function () {
    await lpToken.approve(stakingContract.address, parseEther("10"));
    await stakingContract.deposit(1, parseEther("10"));

    const depositValue = await stakingContract.userInfo(1, accounts[0].address);
    expect(depositValue[0]).to.equal(parseEther("10"));
  });

  it("Harvest LP Token pool", async function () {
    console.log(
      "Before harvest: ",
      formatEther(await rewardToken.balanceOf(accounts[0].address))
    );
    for (let i = 0; i < 20; i++) {
      await network.provider.send("evm_mine");
    }
    await stakingContract.withdraw(1, parseEther("0"));
    console.log(
      "After harvest: ",
      formatEther(await rewardToken.balanceOf(accounts[0].address))
    );
  });

  it("Add Rewards for distribution", async function () {
    await rewardToken.approve(stakingContract.address, parseEther("20"));
    await stakingContract.depositRewards(parseEther("20"));
  });

  it("withdraw LP Token pool and grab rewards", async function () {
    console.log(
      "Before harvest: ",
      formatEther(await rewardToken.balanceOf(accounts[0].address))
    );
    for (let i = 0; i < 5; i++) {
      await network.provider.send("evm_mine");
    }
    await stakingContract.withdraw(1, parseEther("10"));
    console.log(
      "After harvest: ",
      formatEther(await rewardToken.balanceOf(accounts[0].address))
    );
  });

  it("Revert EVM state", async function () {
    await ethers.provider.send("evm_revert", [snapshotId]);
  });
});
