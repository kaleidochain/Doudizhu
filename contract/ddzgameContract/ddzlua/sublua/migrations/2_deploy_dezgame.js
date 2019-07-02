//var TableMgr = artifacts.require("./TableManager.sol");
var zlib = require('zlib');
var fs = require('fs');
var path = require('path');//解析需要遍历的文件夹

var register= artifacts.require("./registerInterface");

var portal = artifacts.require("./Portal")

var name = "luadoudizhu"; 
var version = "0.1.1";
var bootfile = "game.lua";
var filePath = path.resolve('../../');
module.exports = function(deployer, network, accounts) {

    register.setProvider(deployer.provider);
    register = register.at("0xf81a5b3abdcdc59f943011e5b093bc2820b313e0");

    deployer.then(async function(instance){
        //项目初始化
       
        var portalAddress = await register.get("ddzPortal");
        portal = portal.at(portalAddress);
        console.log("portalAddress"+portalAddress)
        await portal.setLua("gameLua",name,version,bootfile);
       
        var readDir = fs.readdirSync(filePath);
        for(var i=0;i<readDir.length;i++){
            filename = readDir[i];
    
            var filedir = path.join(filePath, filename);
            //根据文件路径获取文件信息，返回一个fs.Stats对象
            stats = await fs.statSync(filedir)
            if(stats.isDirectory()){
                continue;
            }
            var content = fs.readFileSync(filedir, 'utf-8');

            buff = zlib.deflateSync(content);
    
            if (buff.length > 25000) {
                console.log("file ",filename,"too large")
                exit(1)
            }
           
            portal.sendTransaction({data:"0x"+buff.toString("hex")}).then(function(filename){
                return function(receipt){
                    console.log(filename,receipt.tx);
                    portal.setfile("gameLua",filename,receipt.tx)
                }
            }(filename))

        }

        var len = await portal.length("gameLua")
        while(len.toString()*1 != readDir.length-1){
            //console.log(len.toString()*1,readDir.length)
            len = await portal.length("gameLua")
        }
    });
};

