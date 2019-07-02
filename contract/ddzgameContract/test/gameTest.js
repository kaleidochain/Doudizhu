//run:truffle exec ./test/gameTest.js --network testnet3
//测试合约是否部署成功
var utils = require('ethereumjs-util');
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
var wallets = {
    "0x7eff122b94897ea5b0e2a9abf47b86337fafebdc":new Buffer("0ce9f0b80483fbae111ac7df48527d443594a902b00fc797856e35eb7b12b4be","hex"), //accounts[0]
    "0x2063d0a0f15a03abd1a3d15601294e3dcb79518b":new Buffer("c66a89cba97914a11da0fe31a8dfaa13bb624efd8b7a59e03397cf3805a4931e","hex"), //accounts[1]
    "0xf9e3a40adf8c6bdecc34dfee57eea62a0edd9d6d":new Buffer("f512940f1e67b82c92d3ff7413212a89a5fd7fab62339fea69f34f55a83fa6bd","hex"), //accounts[2]
    "0x0557d37d996b123fc1799b17b417a6e5d6773038":new Buffer("f1375feeb6aef1838f7e7ef448fe3308e17884fe334e92aa71a5e1642a394768","hex"), //accounts[3]
    "0x1805b7ee5dd340981628b81d5d094c44a027bdc5":new Buffer("971dc4a4e2793bc1b094c0716d8507f9896c03b1f524e354f33aa8f9d2897347","hex"), //accounts[4]
    "0x197383d00ccdfb0fbdeccc14006b3fc096578bb6":new Buffer("f484275631f47849b769267c72d73e9fbb0fcc5445ac1052f5bc30a912b0fd8a","hex"), //accounts[5]
    "0x28b8d733800ffb64a41eaa59470917a96aab51f0":new Buffer("067a1d264d142656d5a70c052f9cf90c35d01da9893d3af2ba49274717f9c340","hex"), //accounts[6]
}
var blacklist=[
	"0x75815ebcc39ce5321d24f7eaec378e6b15fccb56","0x1805b7ee5dd340981628b81d5d094c44a027bdc5", "0x28b8d733800ffb64a41eaa59470917a96aab51f0", "0x2063d0a0f15a03abd1a3d15601294e3dcb79518b","0xf9e3a40adf8c6bdecc34dfee57eea62a0edd9d6d", "0x0557d37d996b123fc1799b17b417a6e5d6773038", "0x197383d00ccdfb0fbdeccc14006b3fc096578bb6","0x7eff122b94897ea5b0e2a9abf47b86337fafebdc", "0xddd869c30cee2de33cbfdfe201b6dd6bdb45554d"
]
var provider = new HDWalletProvider(_prikeys, host,0,_prikeys.length);
var owner = null;
var A=0,B=1,C=4,D=3,E=4,F=5,G=6;
module.exports = async function(exit) {
	try{
        var ok = await init();
        if(!ok)exit(0);
        
        var ok = await leaveTable();
        if(!ok)exit(0);
        console.log("init success");
        
        var queue = await game.getSittingQueen(1);
 
        if(queue.length > 0){console.log("等待队列已有账户");exit(0);}
        
    //joinTable
        var receipt = await game.joinTable(1,{from:accounts[A],gas:0})
        var pinfo = await game.getPlayerInfo(accounts[A]);
        if(pinfo[5] == 0){console.log("A joinTable false",receipt.tx);exit(0);}
        var receipt = await game.joinTable(1,{from:accounts[B],gas:0})
        var pinfo = await game.getPlayerInfo(accounts[B]);
        if(pinfo[5] == 0){console.log("B joinTable false",receipt.tx);exit(0);}
        var receipt = await game.joinTable(1,{from:accounts[C],gas:0})
        var pinfo = await game.getPlayerInfo(accounts[C]);
        if(pinfo[5] == 0){console.log("C joinTable false",receipt.tx);exit(0);}
        console.log("joinTable success");
    //game start
        var tableid = pinfo[1]*1;
        var tbinfo = await game.getTableInfo(tableid);
        var hand = tbinfo[1]*1;
        var receipt = await game.start(tableid,hand,{from:accounts[A],gas:0})
        var pinfo = await game.getPlayerInfo(accounts[A]);
        if(pinfo[4]*1 != 4){console.log("A start false",receipt.tx);exit(0);}
        var receipt = await game.start(tableid,hand,{from:accounts[B],gas:0})
        var pinfo = await game.getPlayerInfo(accounts[B]);
        if(pinfo[4]*1 != 4){console.log("B start false",receipt.tx);exit(0);}
        var receipt = await game.start(tableid,hand,{from:accounts[C],gas:0})
        var pinfo = await game.getPlayerInfo(accounts[C]);
        if(pinfo[4]*1 != 5){console.log("C start false",receipt.tx);exit(0);}
        console.log("game start success");
    // 牌点测试
        var receipt = await game.submitPointHash(tableid,hand,"0x1234",{from:accounts[A],gas:0});
        //console.log(receipt.tx)
        var receipt = await game.submitPointHash(tableid,hand,"0x1234",{from:accounts[B],gas:0});
        var receipt = await game.submitPointHash(tableid,hand,"0x1234",{from:accounts[C],gas:0});
        //console.log(receipt.tx)
        var players = await game.getPointPlayers("0x1234");
        console.log(players);
        if(players[0] == accounts[A]){console.log("牌点测试 success");}
    //settle
        var settledata = await gen3(A,B,C);
        var receipt = await game.playerSettle("0x"+settledata[0].toString("hex")+settledata[1].toString("hex"),{from:accounts[A],gas:0});
        var tbinfo = await game.getTableInfo(tableid);
        if(tbinfo[2]*1 == 0){
            console.log("playerSettle success");
        } else {
            console.log("playerSettle false");
            exit(0);
        }
       
    //结尾
         game.leaveTable({from:accounts[A],gas:0});
         game.leaveTable({from:accounts[B],gas:0});
         game.leaveTable({from:accounts[C],gas:0});
	} catch(e) {
		console.log(e)
	}
	exit(0);
  }

async function gen3(A,B,C){
    var ainfo = await game.getPlayerInfo(accounts[A]);
    var binfo = await game.getPlayerInfo(accounts[B]);
    var cinfo = await game.getPlayerInfo(accounts[C]);
    
    var tableid = ainfo[1]*1;
    var tbinfo = await game.getTableInfo(tableid);
    var hand = tbinfo[1]*1;

    // var tableid =croom.getPlayerInfo(accounts[A])[1].toString()*1
    // var hand =croom.getTableInfo(tableid)[1].toString()*1
    var data=[game.address,tableid,hand,[ [0,1,3],[1,0,2],[2,0,1] ]];
    var rlpdata = utils.rlp.encode(data);
    var hash = utils.keccak(rlpdata);

 
    var signA = utils.ecsign(hash,wallets[accounts[A]]);
    var signB = utils.ecsign(hash,wallets[accounts[B]]);
    var signC = utils.ecsign(hash,wallets[accounts[C]]);

    var signAbuf = Buffer.concat([signA["r"],signA["s"],utils.toBuffer(signA["v"])]);
    var signBbuf = Buffer.concat([signB["r"],signB["s"],utils.toBuffer(signB["v"])]);
    var signCbuf = Buffer.concat([signC["r"],signC["s"],utils.toBuffer(signC["v"])]);
   
    var signs = Buffer.concat([signAbuf,signBbuf,signCbuf]);
    var ret=[];
    ret[0]=signs;
    ret[1]=rlpdata;
    return ret;
    //var msg  = Buffer.concat([signs,rlpdata]);

}
async function gendiscard(B){
    var binfo = await game.getPlayerInfo(accounts[B]);
    var tableid = binfo[1]*1;
    var tbinfo = await game.getTableInfo(tableid);
    var hand = tbinfo[1]*1;

    // var tableid =await game.getPlayerInfo(accounts[B])[1].toString()*1
    // var hand =await game.getTableInfo(tableid)[1].toString()*1
    tableid = tableid.toString(16);
    hand = hand.toString(16);
    while(tableid.length<16){
        tableid ="0"+tableid;
    }
    while(hand.length<8){
        hand ="0"+hand;
    }
    data = game.address.substring(2)+tableid+hand
    //console.log(data)
    data = new Buffer(data,"hex")

    var hash = utils.keccak(data);
    //console.log(hash.toString("hex"))
    //console.log(accounts[B])
    var signB = utils.ecsign(hash,wallets[accounts[B]]);
    //console.log(signB )
    var signBbuf = Buffer.concat([signB["r"],signB["s"],utils.toBuffer(signB["v"])]);
    return "0x"+signBbuf.toString("hex");
}
async function gen1(A){
    var ainfo = await game.getPlayerInfo(accounts[A]);
    var tableid = ainfo[1]*1;
    var tbinfo = await game.getTableInfo(tableid);
    var hand = tbinfo[1]*1;
    
    var data = [game.address,tableid,hand,[ [0,1,2],[1,0,2]]];
    var rlpdata = utils.rlp.encode(data);

    var hash = utils.keccak(rlpdata);

    var signA = utils.ecsign(hash,wallets[accounts[A]]);
    var signB = utils.ecsign(hash,wallets[accounts[B]]);
    
    var signAbuf = Buffer.concat([signA["r"],signA["s"],utils.toBuffer(signA["v"])]);
    //var signBbuf = Buffer.concat([signB["r"],signB["s"],utils.toBuffer(signB["v"])]);
    //var signCbuf = Buffer.concat([signC["r"],signC["s"],utils.toBuffer(signC["v"])]);
   
    var signs = signAbuf;
    var ret=[];
    ret[0]=signs;
    ret[1]=rlpdata;
    return "0x"+ret[0].toString("hex")+ret[1].toString("hex");
}
async function gen2(A,B){
    var ainfo = await game.getPlayerInfo(accounts[A]);
    var binfo = await game.getPlayerInfo(accounts[B])
    var tableid = ainfo[1]*1;
    var tbinfo = await game.getTableInfo(tableid);
    var hand = tbinfo[1]*1;
    var aseat = ainfo[2]*1; //a桌子位置
    var bseat = binfo[2]*1; //b桌子位置

    var data=[game.address,tableid,hand,[[aseat,1,2],[bseat,0,2]]];
    var rlpdata=utils.rlp.encode(data);
    var hash = utils.keccak(rlpdata);

    var signA = utils.ecsign(hash,wallets[accounts[A]]);
    var signB = utils.ecsign(hash,wallets[accounts[B]]);
    
    var signAbuf = Buffer.concat([signA["r"],signA["s"],utils.toBuffer(signA["v"])]);
    var signBbuf = Buffer.concat([signB["r"],signB["s"],utils.toBuffer(signB["v"])]);
    
    var signs = Buffer.concat([signAbuf,signBbuf]);
    var ret=[];
    ret[0]=signs;
    ret[1]=rlpdata;
    return ret;
}
async function leaveTable(){
    for(var i=0;i<accounts.length;i++){
        var pinfo = await game.getPlayerInfo(accounts[i]);
        if(pinfo[5]!=0) {
            await game.leaveTable({from:accounts[i]});
        }
        pinfo = await game.getPlayerInfo(accounts[i]);
        if(pinfo[5]!=0) {
            console.log("账户",accounts[i],"离桌失败");
            return false;
        }
    }
    return true;
}
async function init(){
    register.setProvider(provider);
    authority.setProvider(provider);
    portal.setProvider(provider);
    game.setProvider(provider);
    token.setProvider(provider);

    register = await register.at("0xf81a5b3abdcdc59f943011e5b093bc2820b313e0");
    authority = await authority.at("0x1000000000000000000000000000000000000003");

    var portalAddress = await register.get("ddzPortal");
    if(emptyaddress(portalAddress)){
        console.log("ddzPotal empty");
        return false;
    }
    portal = await portal.at(portalAddress);

    var gameAddress = await portal.gameContract();
    if(emptyaddress(gameAddress)){
        console.log("gameAddress empty");
        return false;
    }  
    game = await game.at(gameAddress);

    var tokenAddress = await portal.gameToken();
    if(emptyaddress(tokenAddress)){
        console.log("tokenAddress empty");
        return false;
    }
    token = await token.at(tokenAddress);

    var promotAddress = await portal.promoToken();
    if(emptyaddress(promotAddress)){
        console.log("promotAddress empty");
        return false;
    }
    owner = await game.owner();
    //var owner =  web3.currentProvider.addresses[0];

    //console.log("owner",owner)
    //清除黑名单
    for(var i=0;i<blacklist.length;i++){
        var isblack = await authority.isBlack(owner,blacklist[i]);
        //console.log(blacklist[i],isblack)
        if(isblack){
            await authority.removeBlack(blacklist[i],{from:owner});
        }
    }
   
    //初始化代币
    for(var i=0;i<accounts.length;i++){
        var balance = await token.balanceOf(accounts[i]);
        
        if (balance < 100) {
            //console.log(accounts[i],balance*1);
            await token.transfer(accounts[i],100000,{from:owner});
        }
    }
    return true;
}

function emptyaddress(address){
    if(address == "" || address== "0x" || address=="0x0000000000000000000000000000000000000000"){
        return true;
    }
    return false;
}
