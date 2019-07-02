pragma solidity >=0.4.0 <0.6.0;

/// Creator stores by whom a contract is created.
///
/// Creator is set before constructor of a contract, so you can use it safely in constructor.
contract Creator {
    mapping(address => address) _creator;  // contract address => creator

    /// @return the creator address of a contract, the zero address 0x0 if contract is not a valid contract address
    function get(address contractAddr) public view returns(address) {
      return _creator[contractAddr];
    }
}
