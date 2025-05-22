const { ethers } = require("ethers");
const {
  contractAddress,
  contractABI,
  tokenAddress,
  tokenAbi,
} = require("./helper");
const axios = require("axios");

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

async function sendTransaction(
  amount,
  user,
  hasReferral,
  referralCode,
  modelProduct,
  colorProduct,
  wheelsProduct,
  ProductPrice,
  totalPriceProduct,
  prompt
) {
  try {
    const apiToken =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYWRtaW4iLCJpZCI6IjY3MGZhNDQ5M2M2NmNhZjlkNzc0NmVkOCIsImlhdCI6MTcyOTA3ODM0NX0.SsgIdeSe_11Cdrqo14u-QgaESkjAzzb1i9JFT5Rpp_4";
    const headers = {
      Authorization: `Bearer ${apiToken}`,
    };

    const jsonIpfs = await axios.post(
      `https://api.muskfans.com/api/v1/create-nft`,
      {
        modelProduct,
        colorProduct,
        wheelsProduct,
        ProductPrice,
        totalPriceProduct,
        prompt,
      },
      { headers }
    );

    const tokenUri = jsonIpfs.data.data;

    const tx = await contract.createNft(
      amount,
      user,
      hasReferral,
      referralCode,
      tokenUri
    );

    console.log("Transaction sent, hash:", tx.hash);

    // Optionally wait for the transaction to be mined
    const receipt = await tx.wait();
    console.log("Transaction mined:", receipt);
  } catch (error) {
    console.error("Error sending transaction:", error);
  }
}
