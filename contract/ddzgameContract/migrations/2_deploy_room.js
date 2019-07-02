//var TableMgr = artifacts.require("./TableManager.sol");

const Croom = artifacts.require("./DdzGame");
const gameFunc = artifacts.require("./DdzFunc");
var register= artifacts.require("./registerInterface");
var gameToken=artifacts.require("./TokenAbi");
var portal = artifacts.require("./Portal");
var contractName = "ddzgameContract";
module.exports = function(deployer, network, accounts) {
    var dezgame,dezfunc;
    register.setProvider(deployer.provider);
   
    gameToken.setProvider(deployer.provider);
    portal.setProvider(deployer.provider);
    

    deployer.then(function() {
        return deployer.deploy(Croom,contractName,16,1,1,3,{value:1e19});
    }).then(async function(instance) {
        dezgame = instance;
        return deployer.deploy(gameFunc);
    }).then(async function(instance) {
        dezfunc = instance;
        //项目初始化
        register = await register.at("0xf81a5b3abdcdc59f943011e5b093bc2820b313e0");
        //console.log(register)
        var notaryAddress = await register.get("NotaryManager");
        var interAddress  = await register.get("InterManager");
        var portalAddres  = await register.get("ddzPortal");
        portal = await portal.at(portalAddres);


        var gameTokenAddress = await portal.gameToken();
        gameToken = await gameToken.at(gameTokenAddress);
        var owner = await gameToken.owner()
        if(owner != await dezgame.owner()){
            console.log("管理账户错误:"+owner);
            return;
        }
        await portal.setgameContract(dezgame.address);
        //以下异步并发执行
        await dezgame.setFuncAddr(dezfunc.address);
        await gameToken.setRoomMgr(dezgame.address,{gas:1000000});
        await dezgame.setTokenAddr(gameToken.address);
        await dezgame.setInterAddr(interAddress);
        await dezgame.setNotaryAddr(notaryAddress);
    });
};

