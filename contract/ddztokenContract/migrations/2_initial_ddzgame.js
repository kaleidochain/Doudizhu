var Gametoken = artifacts.require("Gametoken");
var promoToken = artifacts.require("PromoToken")
var PortalToken = artifacts.require("Portal");
var register = artifacts.require("registerInterface");
module.exports = function(deployer){
  var token,portal,promot;
  register.setProvider(deployer.provider);
  
  deployer.then(function(){
    return deployer.deploy(PortalToken);
  }).then(function(ret){
    portal = ret;
    return deployer.deploy(Gametoken,"ddzgameToken",{value:1e19});
  }).then(function(ret){
    token = ret;
    return deployer.deploy(promoToken,"ddzpromoToken",token.address,{value:1e19});
  }).then(async function(ret){
    promot = ret;
    register = await register.at("0xf81a5b3abdcdc59f943011e5b093bc2820b313e0");

    await token.setTransactor(promot.address);
    await portal.setgameToken(token.address);
    await portal.setpromoToken(promot.address);
    await register.set("ddzPortal",portal.address);
  })
}
