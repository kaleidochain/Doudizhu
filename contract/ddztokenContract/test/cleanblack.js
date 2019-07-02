//run:truffle exec ./test/cleanblack.js --network testnet3
//清空黑名单
var register = artifacts.require("registerInterface");
var authority = artifacts.require("AuthorityInterface");
//需要清空的白名单列表
var blacklist=[
	"0x75815ebcc39ce5321d24f7eaec378e6b15fccb56","0x1805b7ee5dd340981628b81d5d094c44a027bdc5", "0x28b8d733800ffb64a41eaa59470917a96aab51f0", "0x2063d0a0f15a03abd1a3d15601294e3dcb79518b","0xf9e3a40adf8c6bdecc34dfee57eea62a0edd9d6d", "0x0557d37d996b123fc1799b17b417a6e5d6773038", "0x197383d00ccdfb0fbdeccc14006b3fc096578bb6","0x7eff122b94897ea5b0e2a9abf47b86337fafebdc", "0xddd869c30cee2de33cbfdfe201b6dd6bdb45554d",
	"0x1714475E0260AAF9a76E63db39C7094EDd98Ff1B","0x0A964B7178e69B118F71d87D4B16A36bb8aeCD51"
]
module.exports = async function(exit) {
	try{
		register.setProvider(web3.currentProvider);
		authority.setProvider(web3.currentProvider);
		authority = await authority.at("0x1000000000000000000000000000000000000003");
		register = await register.at("0xf81a5b3abdcdc59f943011e5b093bc2820b313e0");
		var owner = web3.currentProvider.addresses[0];
		authority.getAll(owner)
		for(var i=0;i<blacklist.length;i++){
			var isblack = await authority.isBlack(owner,blacklist[i]);
			console.log(blacklist[i],isblack)
			if(isblack){
				await authority.removeBlack(blacklist[i]);
			}
		}
	} catch(e) {
		console.log(e)
	}
	exit(0);
  }

