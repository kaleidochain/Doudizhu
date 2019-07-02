var HDWalletProvider = require("truffle-hdwallet-provider");
var providerproduct = new HDWalletProvider("xxxxxxx", "http://106.75.184.214:8545");
var provider214 = new HDWalletProvider("xxxxxxx", "http://192.168.0.214:8545");
var provider213 = new HDWalletProvider("xxxxxxx", "http://192.168.0.213:8545");
var provider212 = new HDWalletProvider("xxxxxxx", "http://192.168.0.212:8545");
var provider211 = new HDWalletProvider("xxxxxxx", "http://192.168.0.211:8545");
var providerlocal = new HDWalletProvider("xxxxxxx", "http://127.0.0.1:8545");
module.exports= {  
    networks: {
        development: {
        provider:providerlocal,
        gas: 20000000,
        network_id: "*", // Match any network id
        from:"0x0f69bb6f7e4a6191f825683910c6bdfe58cb2610"
        },
        product: {
            //provider:providerproduct,
            host: "192.168.0.74",
            port:38545,
            network_id: "*",       // Any network (default: none)
            gas: 4500000,
            from:"0xf919e83120b0c6699743ca363ae31dd5ba65a108",
        },
        testnet: {
            provider:provider211,
            gas: 20000000,
            network_id: "*", // Match any network id
            from:"0x0f69bb6f7e4a6191f825683910c6bdfe58cb2610"
        },testnet2: {
            provider:provider212,
            gas: 20000000,
            network_id: "*", // Match any network id
            from:"0x0f69bb6f7e4a6191f825683910c6bdfe58cb2610"
        },testnet3: {
            provider:provider213,
            gas: 20000000,
            network_id: "*", // Match any network id
            from:"0x0f69bb6f7e4a6191f825683910c6bdfe58cb2610"
        },testnet4: {
            provider:provider214,
            gas: 20000000,
            network_id: "*", // Match any network id
            from:"0x0f69bb6f7e4a6191f825683910c6bdfe58cb2610"
        }
    },
    compilers: {
        solc: {
            version: "0.5.1",    // Fetch exact version from solc-bin (default: truffle's version)
            optimizer: {
              enabled: true,
              runs: 200
            }
        }
      }

};
