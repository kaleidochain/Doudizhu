pragma solidity ^0.4.24;

contract register{
    //注册合约
    function set(string _name ,address _contract)public ;
    //获取合约
    function get(string _name)public view returns (address);

}
contract SysAuthority{
    //合约设置自己付费
    function setPayer() public;

    //设置合约gasPrice,gasLimit;
    function setGas(uint256 price, uint64 gaslimit) public;

    //设置合约白名单用户
    function grant(address addr)public;

    //移除用户地址白名单
    function revoke(address addr) public;


}

contract AuthIndex{
    //设置合约的权限控制合约地址
    function setAuthContractAddr(address add) public;
    //获取合约的权限控制合约地址
    function getAuthContractAddr(address add) public view returns(address); 
}


contract LibContract {
    register rm;
    SysAuthority auth;
    AuthIndex aindex;
    function LibContract(){
        rm = register(0x1000000000000000000000000000000000000003);
	    aindex = AuthIndex(0x1000000000000000000000000000000000000001);
    }

    function _setauthority(address addr)public{
        auth = SysAuthority(addr);
        aindex.setAuthContractAddr(addr);
    }

    function _setContract(string name ,address addr){
        rm.set(name,addr);
    }
    function _getContract(string name) returns(address){
        rm.get(name);
    }

    //合约设置自己付费
    function _setPayer() public{
        auth.setPayer();
    }
       
    //设置合约gasPrice,gasLimit;
    function _setGas(uint256 price, uint64 gaslimit) public{
        auth.setGas(price,gaslimit);
    }


    //设置合约白名单用户
    function _grant(address addr)public{
        auth.grant(addr);
    }

    //移除用户地址白名单
    function _revoke(address addr) public{
        auth.revoke(addr);
    }

}