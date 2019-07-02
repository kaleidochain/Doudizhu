pragma solidity >=0.4.21 <0.6.0;

contract Authority {
    function setAuthContractAddr(address contractAddress) public;
    function getAuthContractAddr(address contractAddress) public view returns(address);
}
// TODO: 是否需要放在这里？能引用到吗？
contract SysAuthority{
    function setPayer() public; // enableSelfPay
    function setGas(uint256 price, uint64 gaslimit) public;
    function grant(address addr)public;
    function revoke(address addr) public;
}

contract Miner {
    function set(uint64 start, uint32 lifespan, address coinbase, bytes32 vrfVerifier, bytes32 voteVerifier) public returns(bool);
    function setCoinbase(uint256 number, address coinbase) public returns(bool);
    function get(uint256 number, address miner) public view returns(uint64, uint32, address, bytes32, bytes32);
    function isMinerOfHeight(uint256 number, address addr) public view returns(bool);
}

contract Creator {
    function get(address contractAddress) public view returns(address);
}

contract Delegation {
    function delegate(address id) public payable;
    function withdraw(address id, uint amount) public;
}

library SysContract {
    address constant _creator = address(0x1000000000000000000000000000000000000001);
    address constant _miner = address(0x1000000000000000000000000000000000000002);
    address constant _auth = address(0x1000000000000000000000000000000000000003);
    address constant _delegate = address(0x1000000000000000000000000000000000000004);

    function minerSetup(bytes memory minerkey) public returns(bool) {
        return _miner.call(minerkey);
    }

    function minerChangeCoinbase(uint256 number, address addr) public returns(bool) {
        return Miner(_miner).setCoinbase(number, addr);
    }

    function minerGetCoinbase(uint256 number, address addr) public view returns(address a) {
        (a, , , , ) = Miner(_miner).get(number, addr);
        return a;
    }

    function isMinerOfHeight(uint256 number, address addr) public view returns(bool) {
        return Miner(_miner).isMinerOfHeight(number, addr);
    }

    function getCreator(address contractAddress) public view returns(address) {
        return Creator(_creator).get(contractAddress);
    }

    function getCreatorOrSelf(address addr) public view returns(address) {
        address retval = getCreator(addr);
        if (retval == address(0x0)) {
            retval = addr;
        }
        return retval;
    }

    function delegate(address target) public {
        Delegation(_delegate).delegate(target);
    }

    function delegationWithdraw(address target, uint amount) public {
        Delegation(_delegate).withdraw(target, amount);
    }

    // TODO: enable/register contract to be a authority contract
    function setAuthority(address contractAddress) public {
        Authority(_auth).setAuthContractAddr(contractAddress);
    }

    function getSeed(uint height) public view returns(uint256) {
        uint256[1] memory input;
        input[0]=height;
        uint256[1] memory output;
        assembly {
            if iszero(staticcall(not(0), 100, input, 0x20, output, 0x20)) {
                revert(0, 0)
            }
        }
        return output[0];
    }
}

