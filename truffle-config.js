module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545, // Change this to match your Ganache configuration
      network_id: "*",
    },
  },
  compilers: {
    solc: {
      version: "0.8.4", // Match the Solidity version used in your contract
    },
  },
};
