pragma solidity >=0.4.21 <0.6.0;

contract TokenAbi {
    function balanceOf(address _owner) public view returns (uint balance);
    function transferForTM(uint256 tableid,address from, address to, uint value) public returns(string);
    function transferToken(address from, address to, uint value) public returns(bool);
    function transfer(address to, uint256 value) public returns(bool);
    function setRoomMgr(address roomAddress) public returns(bool);
    function authorityAddress() public  view returns(address);
    function owner() public view returns(address);
}