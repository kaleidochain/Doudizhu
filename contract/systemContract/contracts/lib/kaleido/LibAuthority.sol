pragma solidity >=0.4.21 <0.6.0;

import "./LibRegister.sol";
import "../abi/AuthorityInterface.sol";

contract LibAuthority is LibRegister{
    RegisterInterface rm;
    AuthorityInterface auth;

    constructor() public{
        //TODO:register合约不再是系统合约
        rm = RegisterInterface(0x002cE224CaD729c63C5cDF9CE8F2E8B5B8f81eC7B4);
	    auth = AuthorityInterface(0x001000000000000000000000000000000000000003);
    }
    function registe(string memory name) internal{
        rm.set(name,address(this));
    }
   
    function setMaxGasPrice(uint _price) internal{
        auth.setMaxGasPrice(address(this),_price);
    }

    function setGasLimit(uint64 _gas) internal{
        auth.setGasLimit(address(this),_gas);
    }
    //0-白名单模式(默认),1-黑名单模式
    function setModel(uint _model) internal{
        auth.setModel(address(this),_model);
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
        return auth.getAll(address(this));
    }
    function isWhite(address addr)public view returns(bool){
        return auth.isWhite(address(this),addr);
    }
    function isBlack(address addr)public view returns(bool){
        return auth.isBlack(address(this),addr);
    }
}