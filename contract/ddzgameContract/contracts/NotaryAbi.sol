pragma solidity >=0.4.21 <0.6.0;
contract NotaryAbi {
    function applyNotorys(uint tableId, address playerAddr,uint number) public returns(bool,string);
    function finishNotarize(uint256 tableid) payable public;
    function getNotaryList(address tbManage,uint256 tableid) public view returns(address[]);
    function reNotarize(uint256 tableid) public returns(bool,string);
 } 