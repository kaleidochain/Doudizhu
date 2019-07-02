pragma solidity >=0.4.21 <0.6.0;

contract RegisterInterface{
    //注册合约
    function set(string memory _name, address _contract) public;
    //获取合约
    function get(string memory _name)public view returns (address);    
}