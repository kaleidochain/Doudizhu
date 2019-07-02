pragma solidity ^0.4.24;

contract registerInterface{
    //注册合约
    function set(string _name ,address _contract)public ;
    //获取合约
    function get(string _name)public view returns (address);

}
contract gameContract{
    function owner() public view returns(address);
    function setluaAddress(address addr) public returns(bool);
    function luaAddress() public returns(address);
}