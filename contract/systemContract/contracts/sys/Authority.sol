pragma solidity >=0.4.21 <0.6.0;
contract Creator{
    //获取合约创建者
    function get(address contractAddress) public view returns(address);
}

contract Authority {
    mapping(address => uint)    maxGasPrice;    //合约自费gasPrice上限 -) 为0 继承creator
    mapping(address => uint64)  gasLimit;       //合约自费gasLimit -) 为0 继承creator
    mapping(address => uint)    model;          //合约自费模式 0-白名单模式 1-黑名单模式  -)每个合约有自己的model 不继承creator
    mapping(address => mapping(address => bool)) whiteList; //用户白名单集合 -)只有creator有
    mapping(address => mapping(address => bool)) blackList; //用户黑名单集合 -)只有creator有
    function setMaxGasPrice(address addr, uint _price) public returns(bool){
        if( getCreatorOrSelf(addr) != getCreatorOrSelf(msg.sender) ){
            return false;
        }
        maxGasPrice[addr] = _price;
        return true;
    }

    function setGasLimit(address addr, uint64 _gas) public returns(bool){
        if( getCreatorOrSelf(addr) != getCreatorOrSelf(msg.sender)){
            return false;
        }
        gasLimit[addr] = _gas;
        return true;
    }

    function setModel(address addr, uint _model) public returns(bool){
        if( getCreatorOrSelf(addr) != getCreatorOrSelf(msg.sender)){
            return false;
        }
        model[addr] = _model;
        return true;
    }

    function getMaxGasPrice(address Addr) public view returns(uint price){
        price = maxGasPrice[Addr];
        if(price > 0){
            return price;
        }
        address creator = getCreatorOrSelf(Addr);
        if(creator == Addr) {
            return price;
        }
        price = maxGasPrice[creator];
        return price;
    }

    function getGasLimit(address Addr) public view returns(uint64 gas){
        gas = gasLimit[Addr];
        if(gas > 0){
            return gas;
        }
        address creator = getCreatorOrSelf(Addr);
        if(creator == Addr) {
            return gas;
        }
        gas = gasLimit[creator];
        return gas;
    }
    
    function getModel(address Addr) public view returns(uint mod){
        mod = model[Addr];
        return mod;
    }
    function getAll(address Addr) public view returns(uint price,uint64 gas,uint mod){
        price = getMaxGasPrice(Addr);
        gas = getGasLimit(Addr);
        mod = getModel(Addr);
        return (price,gas,mod);
    }

    function isWhite(address contractAddress,address memberAddress ) public view returns(bool){
        address creator = getCreatorOrSelf(contractAddress);
        return whiteList[creator][memberAddress];
    }

    function isBlack(address contractAddress,address memberAddress ) public view returns(bool){
        address creator = getCreatorOrSelf(contractAddress);
        return blackList[creator][memberAddress];
    }

    function addBlack(address memberAddress ) public returns(bool) {
        address creator = getCreatorOrSelf(msg.sender);
        blackList[creator][memberAddress] = true;
        return true;
    }
    function addWhite(address memberAddress ) public returns(bool) {
        address creator = getCreatorOrSelf(msg.sender);
        whiteList[creator][memberAddress] = true;
        return true;
    }

    function removeBlack(address memberAddress ) public returns(bool){
        address creator = getCreatorOrSelf(msg.sender);
        delete blackList[creator][memberAddress];
        return true;
    }
    function removeWhite(address memberAddress ) public returns(bool){
        address creator = getCreatorOrSelf(msg.sender);
        delete whiteList[creator][memberAddress];
        return true;
    }

    function getCreatorOrSelf(address addr) public view returns(address){
        address creator = Creator(0x1000000000000000000000000000000000000001).get(addr);
        if (creator == address(0x0)){
            return addr;
        }
        return creator;
    }

    //合约地址是否启用了合约付费
    function enabled(address contractAddress ) public view returns(bool){
        return getMaxGasPrice(contractAddress)>0 && getGasLimit(contractAddress)>0;
    }
}