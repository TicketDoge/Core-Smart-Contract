const { ethers } = require("ethers");
const { contractAddress, contractABI } = require("./helper");
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

async function getImageUri(ref) {
  try {
    const id = await contract.referralToTokenId(ref);
    const token = await contract.idToListedToken(id);
    const tokenUri = token.tokenURI;
    const response = await axios.get(tokenUri);
    const metadata = response.data;
    const imageUrl = metadata.image;
    console.log(imageUrl);
  } catch (error) {
    console.error("Error Getting Image URL:", error);
  }
}
getImageUri("GIE-7879");
