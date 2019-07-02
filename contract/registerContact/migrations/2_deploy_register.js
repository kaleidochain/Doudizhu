const Register = artifacts.require("Register");
module.exports = function(deployer){
deployer.then(function(){
return deployer.deploy(Register); 
});
}
