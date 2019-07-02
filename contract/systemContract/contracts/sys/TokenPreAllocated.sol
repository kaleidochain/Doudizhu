pragma solidity >=0.4.21 <0.6.0;

import '../lib/math/SafeMath.sol';
import '../lib/kaleido/SysContract.sol';

contract TokenPreAllocated {
    using SafeMath for uint;

    uint constant RELEASETIMES = 12;   //一年解锁，即分12次解锁
    uint constant ONE_MONTH_SECONDS = 30 * 1 days;

    address public owner;
    uint public unlockTime;         //锁定的Token开始解锁时间
    uint public unlockAmount;       //已解锁的数量
    uint public lockAmount;         //锁定的数量

    uint public lastUnlockTime;     //最近一次解锁Token时间

    /**
     * @dev 构造函数
     * @param unlockRatio 初始流通比
     * @param lockMonths 锁定期，按月计
     */
    constructor(uint unlockRatio, uint lockMonths) public payable {
        owner = msg.sender;
        require(msg.value > 0);

        require(unlockRatio <= 100);
        require(lockMonths > 0);
        unlockAmount = msg.value.mul(unlockRatio).div(100);
        lockAmount = msg.value.sub(unlockAmount);

        unlockTime = now.add(lockMonths.add(1).mul(ONE_MONTH_SECONDS)); //lockMonths.add(1)，月末释放
    }

    /**
     * @dev 设置合约挖矿
     */
    function setMinerKey(bytes memory minerkey) public returns(bool) {
        require(msg.sender == owner);
        return SysContract.minerSetup(minerkey);
    }

    function changeOwner(address newOwner) public {
        require(msg.sender == owner);
        require(newOwner != address(0));

        owner = newOwner;
    }

    //挖矿奖励数量
    function minedAmount() internal view returns(uint) {
        return address(this).balance.sub(unlockAmount.add(lockAmount));
    }

    /**
     * @dev 挖矿奖励分配到解锁和锁定部分
     * @notice 可重复调用
     */
    function unlockMined() internal {
        uint totAmt = minedAmount();

        uint minedUnlockAmt;
        if(0 == lockAmount) {
            minedUnlockAmt = totAmt;
        } else {
            uint ratio = unlockAmount.mul(100).div(unlockAmount.add(lockAmount));
            minedUnlockAmt = totAmt.mul(ratio).div(100);
        }
        uint minedLockAmt = totAmt.sub(minedUnlockAmt);

        unlockAmount = unlockAmount.add(minedUnlockAmt);
        lockAmount = lockAmount.add(minedLockAmt);
    }

    /**
     * @dev 解锁Token
     * @notice 可重复调用
     */
    function unlock() public {
        unlockMined();

        uint currMonth = whichMonth(now);   //当前是第几个月份
        if(currMonth >= RELEASETIMES) {
            lastUnlockTime = now;
            unlockAmount = unlockAmount.add(lockAmount);
            lockAmount = 0;

            return;
        }

        uint lastUnlockMonth = whichMonth(lastUnlockTime);  //上次解锁在第几个月份
        if(lastUnlockMonth >= RELEASETIMES || currMonth <= lastUnlockMonth) {
            return;
        }
        uint leftMonths = RELEASETIMES - lastUnlockMonth;      //leftMonths > 0,不产生整数溢出
        uint currUnlockMonths = currMonth - lastUnlockMonth;   //当前要释放多少个月份的Token, currMonth > lastUnlockMonth 
        uint currUnlockAmount = lockAmount.mul(currUnlockMonths).div(leftMonths);

        lastUnlockTime = now;
        unlockAmount = unlockAmount.add(currUnlockAmount);
        lockAmount = lockAmount.sub(currUnlockAmount);
    }

    /**
     * @dev 提Token
     * @param amount 数量
     */
    function withdraw(uint amount) public {
        require(msg.sender == owner);

        unlockAmount = unlockAmount.sub(amount);
        owner.transfer(amount);
    }

    function whichMonth(uint time) internal view returns(uint) {
        if(time < unlockTime) {
            return 0;
        }

        return (time - unlockTime) / ONE_MONTH_SECONDS + 1; // 不需要调SafeMath
    }
}