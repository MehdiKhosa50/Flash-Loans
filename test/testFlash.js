// Importing necessary dependencies from Chai for assertions and Hardhat for deploying and interacting with smart contracts
const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { fundContract } = require("../utils/utilities");

// Importing the ABI of the ERC20 interface to interact with ERC20 tokens
const { abi } = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");

// Defining the provider for interacting with the blockchain network using Waffle
const provider = waffle.provider;

describe("FlashLoan Contract", () => {
  // Declare variables for the FlashLoan contract instance and funding-related values
  let FLASHLOAN, BORROW_AMOUNT, FUND_AMOUNT, initialFunding, txArbitrage;

  // Constant for the number of decimals used in token amounts (e.g., BUSD has 18 decimals)
  const DECIMALS = 18;

  // Addresses for the BUSD whale and token contracts involved in the arbitrage (BUSD, CAKE, CROX)
  const BUSD_WHALE = "0xf977814e90da44bfa03b6295a0616a897441acec";
  const BUSD = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";
  const CAKE = "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82";
  const CROX = "0x2c094F5A7D1146BB93850f629501eB749f6Ed491";

  // Creating a new instance of the BUSD token using its ABI to interact with it
  const busdInstance = new ethers.Contract(BUSD, abi, provider);

  beforeEach(async () => {
    // Check if the whale address has sufficient balance to fund the contract
    const whale_balance = await provider.getBalance(BUSD_WHALE);
    expect(whale_balance).not.equal("0");

    // Deploy the FlashLoan contract before running each test
    const FlashLoan = await ethers.getContractFactory("FlashLoan");
    FLASHLOAN = await FlashLoan.deploy();
    await FLASHLOAN.deployed();

    // Set the borrowing and funding amounts for the flash loan in human-readable format
    const borrowAmount = "1";
    BORROW_AMOUNT = ethers.utils.parseUnits(borrowAmount, DECIMALS);

    initialFunding = "100";
    FUND_AMOUNT = ethers.utils.parseUnits(initialFunding, DECIMALS);

    // Fund the FlashLoan contract with BUSD for testing purposes (simulating initial funding)
    await fundContract(
      busdInstance,
      BUSD_WHALE,
      FLASHLOAN.address,
      initialFunding
    );
  });

  describe("Arbitrage Execution", () => {
    it("ensures the contract is funded", async () => {
      // Check that the FlashLoan contract holds the correct BUSD balance
      const flashLoanBalance = await FLASHLOAN.getBalanceOfToken(BUSD);

      // Convert the balance to human-readable format and assert that it matches the initial funding
      const flashSwapBalance = ethers.utils.formatUnits(
        flashLoanBalance,
        DECIMALS
      );
      expect(Number(flashSwapBalance)).equal(Number(initialFunding));
    });

    it("executes the arbitrage", async () => {
      // Trigger the arbitrage function in the FlashLoan contract with the specified borrow amount
      txArbitrage = await FLASHLOAN.initateArbitrage(BUSD, BORROW_AMOUNT);

      // Assert that the arbitrage transaction was successfully executed
      assert(txArbitrage);

      // Log the contract's token balances after executing arbitrage for BUSD, CROX, and CAKE

      // Check and log the BUSD balance after the arbitrage transaction
      const contractBalanceBUSD = await FLASHLOAN.getBalanceOfToken(BUSD);
      const formattedBalBUSD = Number(
        ethers.utils.formatUnits(contractBalanceBUSD, DECIMALS)
      );
      console.log("Balance of BUSD: " + formattedBalBUSD);

      // Check and log the CROX balance after the arbitrage transaction
      const contractBalanceCROX = await FLASHLOAN.getBalanceOfToken(CROX);
      const formattedBalCROX = Number(
        ethers.utils.formatUnits(contractBalanceCROX, DECIMALS)
      );
      console.log("Balance of CROX: " + formattedBalCROX);

      // Check and log the CAKE balance after the arbitrage transaction
      const contractBalanceCAKE = await FLASHLOAN.getBalanceOfToken(CAKE);
      const formattedBalCAKE = Number(
        ethers.utils.formatUnits(contractBalanceCAKE, DECIMALS)
      );
      console.log("Balance of CAKE: " + formattedBalCAKE);
    });
  });
});