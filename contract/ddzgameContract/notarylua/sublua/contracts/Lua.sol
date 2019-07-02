pragma solidity ^0.4.20;

import './LibContract.sol';

contract Lua is LibContract{
    mapping(bytes32 => bytes)  files; //filename => txhash
    string[]  filenames;
    address public owner;
    string public name;
    string public version;
    constructor(string _name,string _version) public {
        owner = msg.sender;
        name = _name;
        version = _version;
        _setContract(_name,this); //注册合约到模块
    }
    modifier onlyOwner {
        assert(msg.sender == owner);
        _;
    }
    
    function setfile(string _name,bytes _txhash) public onlyOwner returns(bool){
        if(_txhash.length != 32) return false;
        bytes32 _key = sha256(bytes(_name));
        if(files[_key].length == 0){
            files[_key]=_txhash;
            filenames.push(_name);
            return true;
        }
        bytes memory buff =  new bytes(files[_key].length+_txhash.length);
        

        uint len =  files[_key].length;
        for(uint i=0; i<len; i++){
            buff[i]=files[_key][i];
        }
        for(i=0; i<_txhash.length; i++){
            buff[len+i]=_txhash[i];
        }
        files[_key]=buff;
        return true;
    }
    function txhashs(string _name) public view returns(bytes){
        bytes32 _key = sha256(bytes(_name));
        return files[_key];
    }
    function length()public view returns(uint){
        return (filenames.length);
    }
    
    function filebyindex(uint index)public view returns(string){
        if(index>=filenames.length) return "";
        return filenames[index];
    }
}
