pragma solidity >=0.4.21 <0.6.0;

contract registerInterface{
    //注册合约
    function set(string _name, address _contract) public;
    //获取合约
    function get(string _name)public view returns (address);
    
}
contract AuthorityInterface {
    function setMaxGasPrice(address addr, uint _price) public returns(bool);
    function setGasLimit(address addr, uint64 _gas) public returns(bool);
    function setModel(address addr, uint _model) public returns(bool);
    function getAll(address Addr) public view returns(uint price,uint64 gas,uint mod);
    function addBlack(address memberAddress ) public returns(bool);
    function addWhite(address memberAddress ) public returns(bool);
    function removeBlack(address memberAddress ) public returns(bool);
    function removeWhite(address memberAddress ) public returns(bool);
    function isBlack(address contractAddress,address memberAddress ) public view returns(bool);
    function isWhite(address contractAddress,address memberAddress ) public view returns(bool);
}


contract LibAuthority {

    AuthorityInterface auth;

    constructor() public{
	    auth = AuthorityInterface(0x1000000000000000000000000000000000000003);
    }

    function setMaxGasPrice(uint _price) internal{
        auth.setMaxGasPrice(this,_price);
    }

    function setGasLimit(uint64 _gas) internal{
        auth.setGasLimit(this,_gas);
    }
    //0-白名单模式(默认),1-黑名单模式
    function setModel(uint _model) internal{
        auth.setModel(this,_model);
    }

    //设置合约白名单用户
    function addWhite(address addr) internal{
        auth.addWhite(addr);
    }
    function addBlack(address addr) internal{
        auth.addBlack(addr);
    }
    //移除用户地址白名单
    function removeWhite(address addr) internal{
        auth.removeWhite(addr);
    }
    function getAll()public view returns(uint,uint64,uint){
        return auth.getAll(this);
    }
    function isWhite(address addr)public view returns(bool){
        return auth.isWhite(this,addr);
    }
    function isBlack(address addr)public view returns(bool){
        return auth.isBlack(this,addr);
    }
}