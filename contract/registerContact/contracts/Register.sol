pragma solidity >=0.4.0 <0.6.0;

contract Register {
  mapping(string => address) contracts;
  mapping(string => address) owners;
  
  function set(string memory name, address addr) public returns(bool) {
    require(owners[name] == address(0) || owners[name] == tx.origin,"owner error");
    contracts[name]= addr;
    owners[name] = tx.origin;
    return true;
  }

  function get(string memory name) public view returns(address) {
    return contracts[name];
  }
  function getOwner(string memory name) public view returns(address){
    return owners[name];
  }
  
}

//gameToken 代币
//gameContract 游戏
//luaContract lua脚本
//promoToken 活动
