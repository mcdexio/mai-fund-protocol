// const HDWalletProvider = require('@truffle/hdwallet-provider');
// const infuraKey = "fj4jll3k.....";
//
// const fs = require('fs');
// const mnemonic = fs.readFileSync(".secret").toString().trim();

module.exports = {
    networks: {
        development: {
            host: "127.0.0.1",     // Localhost (default: none)
            port: 8545,            // Standard Ethereum port (default: none)
            network_id: "*",       // Any network (default: none)
        },
        ropsten: {
            provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/YOUR-PROJECT-ID`),
                network_id: 3,       // Ropsten's id
                gas: 5500000,        // Ropsten has a lower block limit than mainnet
                confirmations: 2,    // # of confs to wait between deployments. (default: 0)
                timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
                skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
        },
        coverage: {
            host: "localhost",
            network_id: "*",
            port: 8555,
            gas: 8000000,
            gasPrice: 20000000000
        }
    },
    mocha: {
        timeout: 100000
    },
    compilers: {
        solc: {
            version: "0.6.10",    // Fetch exact version from solc-bin (default: truffle's version)
            // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
            settings: {          // See the solidity docs for advice about optimization and evmVersion
                optimizer: {
                    enabled: true,
                    runs: 200
                },
                evmVersion: "istanbul"
            }
        }
    },
    plugins: ["solidity-coverage"]
}
