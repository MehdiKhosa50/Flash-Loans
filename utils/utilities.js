const { network, ethers } = require("hardhat");

/**
 * Transfers a specified amount of ERC20 tokens from the sender's account to the recipient's account.
 * The function impersonates the sender as a whale account and uses it to sign the transaction.
 * 
 * @param {Object} contract - The ERC20 token contract instance.
 * @param {string} sender - The address of the account to impersonate (whale).
 * @param {string} recipient - The address of the recipient who will receive the tokens.
 * @param {string} amount - The amount of tokens to transfer (in Ether units).
 */
const fundToken = async (contract, sender, recipient, amount) => {
    // Convert the specified amount to its token decimal equivalent (18 decimals).
    const FUND_AMOUNT = ethers.utils.parseUnits(amount, 18);

    // Impersonate the whale account (sender) to fund the recipient.
    const whale = await ethers.getSigner(sender);

    // Connect the impersonated whale account to the contract.
    const contractSigner = contract.connect(whale);

    // Transfer the token amount from the whale to the recipient.
    await contractSigner.transfer(recipient, FUND_AMOUNT);
};

/**
 * Impersonates an account and funds the recipient with a specified amount of tokens.
 * This is used for testing by simulating the transfer of tokens from accounts with large balances (whales).
 * 
 * @param {Object} contract - The ERC20 token contract instance.
 * @param {string} sender - The address of the whale account to impersonate.
 * @param {string} recipient - The address of the recipient who will receive the tokens.
 * @param {string} amount - The amount of tokens to transfer (in Ether units).
 */
const fundContract = async (contract, sender, recipient, amount) => {
    // Start impersonating the sender (whale) account on the Hardhat network.
    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [sender],
    });

    // Call the fundToken function to transfer tokens to the recipient.
    await fundToken(contract, sender, recipient, amount);

    // Stop impersonating the sender account.
    await network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [sender],
    });
};

module.exports = {
    fundContract: fundContract,
};