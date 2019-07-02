pragma solidity >=0.4.0 <0.6.0;

/// @author The Kaleido Team
/// @title An account who registers into Miner will becomes a miner.
contract Miner {
    /// Info holds minerkey information
    struct Info {
        uint64 start;           // from where mining starts, until the end of the interval
        uint32 lifespan;        // lifespan of each sub key in height
        address coinbase;       // who gains rewards
        bytes32 vrfVerifier;
        bytes32 voteVerifier;
    }

    /// STEP_SIZE is size of each interval, must < 2^32
    uint256 constant STEP_SIZE = 1000000;

    /// MAX_WRITE_AHEAD is max block number that miner could register, preventing
    /// too many future miner's data
    uint256 constant MAX_WRITE_AHEAD = 1 * STEP_SIZE;

    uint256 constant LOOK_BACK_K = 100;

    /// minerMap saves all miners by interval SN.
    ///
    /// SN => Miner => Info
    mapping(uint256 => mapping(address => Info)) minerMap;

    /// newMiners saves miners by start number from which miner starts mining. So we
    /// can know all miners starting mining from each height.
    ///
    /// start => Miners
    mapping(uint256 => address[]) newMiners;

    /// emit when a new miner is added
    event Added(uint256 start, address miner);

    /// emit when a miner info is updated
    event Updated(uint256 start, address miner);

    /// set saves miner info with the interval. The miner will starts mining
    /// from height `start`, and the coinbase will gains the rewards. When
    /// updating, new start must be less than or equals to origin start.
    ///
    /// @return true if success, false if fail.
    function set(uint64 start, uint32 lifespan, address coinbase, bytes32 vrfVerifier, bytes32 voteVerifier) public returns(bool) {
        // require start <= block.number + MAX_WRITE_AHEAD
        if (start > block.number + MAX_WRITE_AHEAD) {
            return false;       // start is too big than H+MAX
        }
        // require start >= block.number + LOOK_BACK_K
        if (start < block.number + LOOK_BACK_K) {
            return false;       // start is too small than H+K
        }

        uint256 sn = start / STEP_SIZE;
        uint256 end = (1 + sn) * STEP_SIZE;
        if (block.number >= end) { // expired
            return false;
        }

        uint64 origin = minerMap[sn][msg.sender].start;

        bool isUpdate = (origin != 0);
        // update require start equals to origin
        if (isUpdate && origin != start) {
            return false;
        }

        minerMap[sn][msg.sender] = Info(start, lifespan, coinbase, vrfVerifier, voteVerifier);

        if (isUpdate) {
            emit Updated(start, msg.sender);
        } else {
            newMiners[start].push(msg.sender);
            emit Added(start, msg.sender);
        }

        return true;
    }

    /// setCoinbase updates the miner's coinbase in interval of `number`, fail
    /// if the interval has expired or not exists.
    ///
    /// @param number - any number of the interval to be modified
    ///
    /// @return true if success, false otherwise.
    function setCoinbase(uint256 number, address coinbase) public returns(bool) {
        uint256 sn = number / STEP_SIZE;
        uint256 end = (1 + sn) * STEP_SIZE;

        if (block.number >= end) { // this interval already expired
            return false;
        }

        Info storage info = minerMap[sn][msg.sender];
        if (info.start == 0) { // not registered
            return false;
        }

        info.coinbase = coinbase;

        emit Updated(info.start, msg.sender);

        return true;
    }

    /// get returns the miner info registed for block `number`
    ///
    /// @param number - any number of the interval to be modified
    ///
    /// @return miner info
    function get(uint256 number, address miner) public view returns(uint64, uint32, address, bytes32, bytes32) {
        Info storage info = minerMap[number/STEP_SIZE][miner];
        if (info.start == 0) { // not registered
            return (0, 0, address(0), 0, 0);
        }
        return (info.start, info.lifespan, info.coinbase, info.vrfVerifier, info.voteVerifier);
    }

    // isMinerOfHeight returns true if addr is a miner of the block number
    function isMinerOfHeight(uint256 number, address addr) public view returns(bool) {
        uint256 start = minerMap[number/STEP_SIZE][addr].start;
        return start != 0 && number >= start; // number<end is always true
    }

    function getNewAddedMinersCount(uint256 number) public view returns(uint) {
        return newMiners[number].length;
    }

    function getNewAddedMiner(uint256 number, uint32 index) public view returns(address miner) {
        return newMiners[number][index];
    }
}
