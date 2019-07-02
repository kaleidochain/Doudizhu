pragma solidity >=0.4.21 <0.6.0;
import "./lib/kaleido/SysContract.sol";
import "./lib/math/SafeMath.sol";

/**
 * DelegatePool is a simple implementation for delegate pool. It supports
 * gather tokens to register as a miner. And all tokens belong to their
 * original owner. The rewards would be delivered offline.
 */
contract DelegatePool {
    using SafeMath for uint256;

    mapping(address=>uint256) private _balances;

    // register self into minerdb
    function registerMiner(bytes memory minerkey) public {
        require(msg.sender == SysContract.getCreator(address(this)));
        SysContract.minerSetup(minerkey);
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return A uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Delegate token to this contract.
     */
    function delegate() public payable returns (bool) {
        require(msg.value > 0);
        _balances[msg.sender] = _balances[msg.sender].add(msg.value);
        return true;
    }

    /**
     * @dev Transfer token to a specified address.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function transfer(address to, uint256 value) public {
        require(to != address(0), "transfer to the zero address");

        _balances[msg.sender] = _balances[msg.sender].sub(value);
        to.transfer(value);
    }
}
