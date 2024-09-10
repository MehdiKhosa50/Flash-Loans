// Import the Hardhat Runtime Environment (HRE), which provides utilities for deploying and interacting with smart contracts.
// This is useful when running the script standalone via `node <script>` or through `npx hardhat run <script>`.
const hre = require("hardhat");

async function main() {
  // Get the current timestamp in seconds and set an unlock time 60 seconds in the future.
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = currentTimestampInSeconds + 60;

  // Specify the amount of ETH (0.001 ETH) to lock in the contract, converting it to the appropriate units.
  const lockedAmount = hre.ethers.parseEther("0.001");

  // Deploy the "Lock" contract, passing in the unlock time and sending the locked ETH to it during deployment.
  const lock = await hre.ethers.deployContract("Lock", [unlockTime], {
    value: lockedAmount,
  });

  // Wait for the contract to be fully deployed on-chain before proceeding.
  await lock.waitForDeployment();

  // Log the contract details, including the amount of locked ETH and the contract address.
  console.log(
    `Lock with ${ethers.formatEther(
      lockedAmount
    )} ETH and unlock timestamp ${unlockTime} deployed to ${lock.target}`
  );
}

// Execute the main function and catch any errors that may occur during the deployment process.
// The script exits with a non-zero code if an error is encountered, indicating failure.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});