pragma solidity >=0.4.21 <0.6.0;

contract RoomAbi {
    function getTablePlayers(uint tableId) public view returns(address[] memory);
    function getTablePlayingPlayers(uint tableId) public view returns(uint number, address[] memory);
    function getPlayerInfo(address playerAddr) public view returns(address, uint, uint, uint, uint8);
    function resetNotoryInfo(uint tableId) public;
    function isTablePlayingPlayer(uint tableId, address playerAddr) public view returns(bool);
}