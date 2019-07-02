pragma solidity >=0.4.21 <0.6.0;

import '../lib/math/SafeMath.sol';

/// User can receive delegated tokens, and safely delegate tokens to others by
/// this contract. For miners, delegating tokens to others would not decrease
/// your stake.
contract Delegation {
    using SafeMath for uint;

    mapping (address => uint) totalReceived; // addr => the total amount of received tokens
    mapping (address => uint) totalDelegated; // addr => the total amount of delegated tokens
    mapping (address => mapping(address => uint)) details; // from addr => (to addr => amount)

    // Delegate is an event that `value` tokens has been delegated to `receiver` by `funder`
    event Delegate(address funder, address receiver, uint value);
    // Withdraw is an event that `value` tokens has been withdrawed from `receiver` by `funder`
    event Withdraw(address funder, address receiver, uint value);

    /// `msg.sender` delegate `msg.value` tokens to address `to`. These tokens
    /// still belong to `msg.sender`.
    function delegate(address to) public payable {
        require(msg.value > 0);
        require(to != address(0));

        uint a = details[msg.sender][to].add(msg.value);
        uint b = totalDelegated[msg.sender].add(msg.value);
        uint c = totalReceived[to].add(msg.value);

        details[msg.sender][to] = a;
        totalDelegated[msg.sender] = b;
        totalReceived[to] = c;
        emit Delegate(msg.sender, to, msg.value);
    }

    /// `msg.sender` withdraws `amount` of tokens from address `addr`.
    function withdraw(address addr, uint amount) public {
        uint a = details[msg.sender][addr].sub(amount);
        uint b = totalDelegated[msg.sender].sub(amount);
        uint c = totalReceived[addr].sub(amount);

        details[msg.sender][addr] = a;
        totalDelegated[msg.sender] = b;
        totalReceived[addr] = c;

        msg.sender.transfer(amount);
        emit Withdraw(msg.sender, addr, amount);
    }

    /// @return total received tokens delegated to `addr`
    function totalReceivedToken(address addr) public view returns(uint) {
        return totalReceived[addr];
    }

    /// @return total delegated tokens by `addr`
    function totalDelegatedToken(address addr) public view returns(uint) {
        return totalDelegated[addr];
    }

    /// @return amount of tokens delegated by `from` to `to`
    function getAmount(address from, address to) public view returns(uint) {
        return details[from][to];
    }
}
