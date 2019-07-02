var Server = artifacts.require("./Server.sol");
var register = artifacts.require("./RegisterInterface");
var interName = "InterManager";
var notaryName = "NotaryManager";
module.exports = function(deployer, network, accounts) { 
    var inter,notary;
    register.setProvider(deployer.provider);
    register = register.at("0xf81a5b3abdcdc59f943011e5b093bc2820b313e0");
    deployer.then(function() {
        return deployer.deploy(Server,1);
    }).then(function(instance) {
        inter = instance;
        return deployer.deploy(Server,2);
    }).then(async function(instance) {
        notary = instance;
        await register.set(notaryName, notary.address);
        await register.set(interName , inter.address);
        console.log(notaryName+notary.address)
    });
};

