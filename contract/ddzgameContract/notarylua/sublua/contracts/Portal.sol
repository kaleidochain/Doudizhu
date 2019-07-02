pragma solidity >=0.4.21 <0.6.0;

contract Portal {
    address public gameContract; //游戏合约
    address public promoToken;  //活动合约
    address public gameToken;   //代币合约
    address public owner;
    constructor()public{
      owner = msg.sender;
    }
    function()external{}
    modifier onlyOwner {
        assert(msg.sender == owner);
        _;
    }

    function setgameContract(address addr) public onlyOwner returns(bool){
      gameContract = addr;
      return true;
    }

    function setpromoToken(address addr) public onlyOwner returns(bool){
      promoToken = addr;
      return true;
    }

    function setgameToken(address addr) public onlyOwner returns(bool){
      gameToken = addr;
      return true;
    }

//保存游戏相关lua脚本
    struct lua {
      string name;
      string version;
      string bootfile;
      uint update;  //部署高度
      string[] filenames;   //filename列表;
      mapping(bytes32 => string) files; // hash(filename)=>txhash
    }
    mapping(string => lua) Luas; //所有lua脚本项目

    function setLua(string memory _type,string memory _name,string memory _version,string memory _bootfile) public onlyOwner returns(bool){
        Luas[_type].name = _name;
        Luas[_type].version = _version;
        Luas[_type].update = block.number;
        Luas[_type].bootfile = _bootfile;
        delete Luas[_type].filenames;
        return true;
    }

    function name(string memory _type)public view returns(string memory){
      return Luas[_type].name;
    }
    
    function version(string memory _type)public view returns(string memory){
      return Luas[_type].version;
    }
    function bootfile(string memory _type)public view returns(string memory){
      return Luas[_type].bootfile;
    }
    function vhash(string memory _type)public view returns(address){
      return address(Luas[_type].update);
    }
    function setfile(string memory _type, string memory _filename, string memory _txhash) public onlyOwner returns(bool){
        bytes32 _key = sha256(bytes(_filename));
        Luas[_type].files[_key] = _txhash;
        Luas[_type].filenames.push(_filename);
        return true;
    }

    function txhashs(string memory _type,string memory _filename) public view returns(string memory){
        bytes32 key = sha256(bytes(_filename));
        return Luas[_type].files[key];
    }

    function length(string memory _type)public view returns(uint){
        return (Luas[_type].filenames.length);
    }

    function filebyindex(string memory _type,uint _index)public view returns(string memory){
        if(_index >= Luas[_type].filenames.length) return "";
        return Luas[_type].filenames[_index];
    }
}

