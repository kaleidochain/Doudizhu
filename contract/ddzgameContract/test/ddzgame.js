//run:truffle exec ./test/ddzgame.js --network testnet3
var HDWalletProvider = require("truffle-hdwallet-provider");
var register = artifacts.require("registerInterface");
var authority = artifacts.require("AuthorityInterface");
var game = artifacts.require("ddzGame");
var portal = artifacts.require("Portal");
var token = artifacts.require("TokenAbi");
var network = ""
for(var i=0;i<process.argv.length-1;i++){
    if(process.argv[i]=="--network"){
        network = process.argv[i+1];
        break;
    }
}


if(network== "product"){
    host="http://106.75.184.214:8545";
} else if(network == "testnet"){
    host = "http://192.168.0.211:8545";
} else if(network == "testnet2"){
    host = "http://192.168.0.212:8545";
} else if(network == "testnet3"){
    host = "http://192.168.0.213:8545";
}else {
    host = "http://127.0.0.1:8545";
}


var _prikeys=[
    "0ce9f0b80483fbae111ac7df48527d443594a902b00fc797856e35eb7b12b4be", //"0x7eff122b94897ea5b0e2a9abf47b86337fafebdc"
    "c66a89cba97914a11da0fe31a8dfaa13bb624efd8b7a59e03397cf3805a4931e", //"0x2063d0a0f15a03abd1a3d15601294e3dcb79518b":
    "f512940f1e67b82c92d3ff7413212a89a5fd7fab62339fea69f34f55a83fa6bd", //"0xf9e3a40adf8c6bdecc34dfee57eea62a0edd9d6d":
    "f1375feeb6aef1838f7e7ef448fe3308e17884fe334e92aa71a5e1642a394768", //"0x0557d37d996b123fc1799b17b417a6e5d6773038":
    "971dc4a4e2793bc1b094c0716d8507f9896c03b1f524e354f33aa8f9d2897347", //"0x1805b7ee5dd340981628b81d5d094c44a027bdc5":
    "f484275631f47849b769267c72d73e9fbb0fcc5445ac1052f5bc30a912b0fd8a", //"0x197383d00ccdfb0fbdeccc14006b3fc096578bb6":
    "067a1d264d142656d5a70c052f9cf90c35d01da9893d3af2ba49274717f9c340", //"0x28b8d733800ffb64a41eaa59470917a96aab51f0":
    "xxxxxxx", //"0x0f69bb6f7e4a6191f825683910c6bdfe58cb2610":
    "xxxxxxx", //"0xcd3bca4d0397293de34dd812fafc9e46af86db1c" 
    "2f1cb8fed83cc906ffb0b5ff18bcfa2d377a818cb2e2bb72853ff7cc9e3606ea", //"0xa25f406dd5a4bff511c2dc226ea5cf3b0a4434a8"
]
var accounts=[
    "0x1805b7ee5dd340981628b81d5d094c44a027bdc5",
    "0x28b8d733800ffb64a41eaa59470917a96aab51f0",
    "0x2063d0a0f15a03abd1a3d15601294e3dcb79518b",
    "0xf9e3a40adf8c6bdecc34dfee57eea62a0edd9d6d",
    "0x0557d37d996b123fc1799b17b417a6e5d6773038",
    "0x197383d00ccdfb0fbdeccc14006b3fc096578bb6",
    "0x7eff122b94897ea5b0e2a9abf47b86337fafebdc"
]

var blacklist=[
	"0x75815ebcc39ce5321d24f7eaec378e6b15fccb56","0x1805b7ee5dd340981628b81d5d094c44a027bdc5", "0x28b8d733800ffb64a41eaa59470917a96aab51f0", "0x2063d0a0f15a03abd1a3d15601294e3dcb79518b","0xf9e3a40adf8c6bdecc34dfee57eea62a0edd9d6d", "0x0557d37d996b123fc1799b17b417a6e5d6773038", "0x197383d00ccdfb0fbdeccc14006b3fc096578bb6","0x7eff122b94897ea5b0e2a9abf47b86337fafebdc", "0xddd869c30cee2de33cbfdfe201b6dd6bdb45554d"
]
var provider = new HDWalletProvider(_prikeys, host,0,_prikeys.length);

module.exports = async function(exit) {
	try{
        register.setProvider(provider);
        authority.setProvider(provider);
        portal.setProvider(provider);
        game.setProvider(provider);
        token.setProvider(provider);

        register = register.at("0xf81a5b3abdcdc59f943011e5b093bc2820b313e0");
        authority = authority.at("0x1000000000000000000000000000000000000003");

        var portalAddress = await register.get("ddzPortal");
        portal = portal.at(portalAddress);

        var gameAddress = await portal.gameContract();
        game = game.at(gameAddress);

        var tokenAddress = await portal.gameToken();
        token = token.at(tokenAddress);

        var owner = await game.owner();
        //var owner =  web3.currentProvider.addresses[0];

        //console.log("owner",owner)
        //清除黑名单
		for(var i=0;i<blacklist.length;i++){
			var isblack = await authority.isBlack(owner,blacklist[i]);
			console.log(blacklist[i],isblack)
			if(isblack){
				 await authority.removeBlack(blacklist[i],{from:owner});
			}
        }
        //初始化代币
        for(var i=0;i<accounts.length;i++){
            var balance = await token.balanceOf(accounts[i]);
            console.log(accounts[i],balance*1);
            if (balance < 10000) {
                await token.transfer(accounts[i],100000,{from:owner});
            }
        }
        //TODO:

	} catch(e) {
		console.log(e)
	}
	exit(0);
  }

