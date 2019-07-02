pragma solidity >=0.4.21 <0.6.0;

import "../abi/RegisterInterface.sol";

contract LibRegister{
    RegisterInterface rm;

    constructor() public{
        //TODO:register合约不再是系统合约
        rm = RegisterInterface(0x002ce224cad729c63c5cdf9ce8f2e8b5b8f81ec7b4);
    }
    function registe(string memory name) internal{
        rm.set(name,address(this));
    }
    function getContract(string memory name) public view returns(address){
        return rm.get(name);
    }
}