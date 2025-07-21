require('dotenv').config(); // Add this to the top
const HDWalletProvider = require('@truffle/hdwallet-provider');
const { ALCHEMY_SEPOLIA_URL, DEPLOYER_PRIVATE_KEY } = process.env;

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 7545,            // Standard Ganache UI port
      //port: 8545,            // Standard Ganache CLI port (if you are using Ganache CLI)
      network_id: "*",       // Any network (default: none)
    },
     sepolia: {
      provider: () => {
        // This new setup prevents the provider from timing out
        const provider = new HDWalletProvider(DEPLOYER_PRIVATE_KEY, ALCHEMY_SEPOLIA_URL);
        provider.engine.on('error', (err) => {
          console.error('HDWalletProvider Error:', err);
        });
        return provider;
      },
      network_id: 11155111,
      gas: 5500000,        // Set a reasonable gas limit
      gasPrice: 20000000000, // 20 Gwei (a standard price)
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      networkCheckTimeout: 10000,
    }
  },

  compilers: {
    solc: {
      version: "0.8.0",    // Fetch exact version from solc-bin (default: truffle's version)
    }
  },
};