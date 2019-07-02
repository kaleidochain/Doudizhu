pragma solidity >=0.4.21 <0.6.0;

contract gameTokenInterface{
    function transfer(address _to, uint _value)public returns(bool);
    function balanceOf(address _owner)public view returns (uint);
    function setToken(address addr) public returns(bool);
    function owner()public view returns(address);
    function setTransactor(address addr) public returns(bool);
}
import "./LibAuthority.sol";
contract Promotoken is LibAuthority{

    //erc223
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    event GiveMeToken(address indexed _user,uint _value);
    
    string public name ;

    uint256 public totalSupply;
    address public owner;
    uint give = 1e16;
    address public tokenAddress;            //游戏用的token地址
    address public authorityAddress;    //权限合约地址
    //game end
    
    constructor(string memory _name,address  gameTokenAddress)public payable{
        owner = msg.sender;
        name = _name;
        //注册活动合约
        //registe(_name);
        //获取代币合约
        tokenAddress = gameTokenAddress;
        //开启合约代扣费
        setMaxGasPrice(1e11);
        setGasLimit(1e6);
        setModel(1); //黑名单模式
    }
    //kaleido转为活动金币
    function () external payable {}

    //新用户申请活动金币
    function giveMeToken() public returns(bool){
        require(!isBlack(msg.sender),"用户已领取");
        require(address(this).balance >= give,"活动已结束");
        //tokenAddress.send(give);
        require(tokenAddress.call.value(give)(""),"transfer error");
        uint _value = gameTokenInterface(tokenAddress).balanceOf(address(this));
        gameTokenInterface(tokenAddress).transfer(msg.sender,_value);
        addBlack(msg.sender);//申请一次后加入黑名单
        emit GiveMeToken(msg.sender,give);
        return true;
    }
    //开启关闭活动
    function enable(uint enabled) public payable returns(bool){
        if(enabled == 0){
            setMaxGasPrice(0);
            setGasLimit(1);
            msg.sender.transfer(address(this).balance);
        } else {
            setMaxGasPrice(1e11);
            setGasLimit(1e6);
        }
        return true;
    }
}
