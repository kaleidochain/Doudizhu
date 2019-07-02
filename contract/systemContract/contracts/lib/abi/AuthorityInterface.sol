pragma solidity >=0.4.21 <0.6.0;

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