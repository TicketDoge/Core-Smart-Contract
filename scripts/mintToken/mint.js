const { ethers } = require("ethers");
const { contractAddress, contractABI } = require("./helper");

// Connect to the Ethereum network via an Infura provider (or another provider)
const provider = new ethers.providers.JsonRpcProvider(
  "https://arb-sepolia.g.alchemy.com/v2/G1z2srUKvlgPC0PAdQG5bfJ_fXkBE2n4"
);

// Create a wallet instance using your private key and connect it to the provider
const privateKey =
  "28a207254be80cd56b8ef477444113b5d2c53329d0328e10cda6676764fb1b12"; // NEVER expose your real private key in production code! 0x6Ac97c57138BD707680A10A798bAf24aCe62Ae9D
const wallet = new ethers.Wallet(privateKey, provider);

// Create a contract instance connected with the wallet
const contract = new ethers.Contract(contractAddress, contractABI, wallet);

async function sendTransaction(amount, user) {
  try {
    amount = ethers.utils.parseEther(amount.toString());

    const tx = await contract.buy(user, amount);

    console.log("Transaction sent, hash:", tx.hash);

    // Optionally wait for the transaction to be mined
    const receipt = await tx.wait();
    console.log("Transaction mined:", receipt);
  } catch (error) {
    console.error("Error sending transaction:", error);
  }
}
sendTransaction(1000, "0x81878429C68350DdB41Aaaf05cF2f03bf37e72D5");
