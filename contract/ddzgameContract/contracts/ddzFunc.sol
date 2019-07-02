pragma solidity >=0.4.21 <0.6.0;
import './ddzDao.sol';
import './LibAuthority.sol';
import './ServerAbi.sol';
import './SafeMath.sol';
import './RLP.sol';
import './TokenAbi.sol';

contract DdzFunc is ddzDao {
    using SafeMath for uint;
    using RLP for bytes;
    using RLP for RLP.RLPItem;
    using RLP for RLP.Iterator;

        // 玩家未在Room中，加入Room的Table
    function joinTable(uint64 level) public returns(bool){
        address playerAddr = msg.sender;
        require(PlayerStatus.NOTJION == Players[playerAddr].status,"用户已加入");

        //扣筹码
        TokenAbi token = TokenAbi(tokenAddress);
        uint needChips = lvlCfg[level].needChips;
        require(needChips > 0,"错误场");
        require(true == token.transferToken(playerAddr, address(this), needChips),"余额不足");

        PlayerInfo memory info = PlayerInfo(0, needChips, PlayerStatus.SITTING, 0, 0, level,0x0);
        Players[playerAddr] = info;

        joinings[level].push(playerAddr);

        emit JoinSittingQueen(playerAddr, address(this));

        if(joinings[level].length >= joining_queue_size) {
            allotTable(level);
        }
        return true;
    }
    /**
     * @dev 玩家开始
     * @param hand 局数（即在第几局弃牌）
     */
    function start(uint64 tableid, uint64 hand) public returns(bool){
        address playerAddr = msg.sender;
        PlayerInfo memory pInfo = Players[playerAddr];
        require(tableid == pInfo.tbid, "错误table id");
        require(pInfo.status == PlayerStatus.SEATED, "用户错误状态码");

        require(Tables[pInfo.tbid].currentHand == hand, "局数不匹配");
        require(Tables[pInfo.tbid].currentStatus == TalbeStatus.NOTSTARTED, "talbe 未开始");     // Table未开始游戏
		uint64 level = Tables[pInfo.tbid].level;
		uint amount = Players[playerAddr].amount;
        TokenAbi token = TokenAbi(tokenAddress);
		uint base = lvlCfg[level].base;
        if(amount < base * multiple) {
            require(true == token.transferToken(playerAddr, address(this), base*multiple - amount));
			Players[playerAddr].amount = base * multiple;
        }

        Players[playerAddr].status = PlayerStatus.READY;
        emit Start(address(this), pInfo.tbid, playerAddr, pInfo.seatNum, hand);

        for(uint i = 0; i < PARTICIPATE_NUM; i++) {
            if(PlayerStatus.READY != Players[Tables[tableid].players[i]].status) {
                return true;
            }
        }
        for(i = 0; i < PARTICIPATE_NUM; i++) {
            Players[Tables[tableid].players[i]].status = PlayerStatus.PLAYING;
        }
        Tables[tableid].currentStatus = TalbeStatus.STARTED;
        Tables[tableid].startBlock = block.number;
		emit GameStart(address(this), tableid, Tables[tableid].currentHand);
        return true;
    }
    /**
     * @dev 安排等待加入Table队列中的玩家加入Table
     */
    function allotTable(uint64 level) internal returns (bool) {
        uint i;
        uint j;

        address tmpAddr;
        uint joiningLen = joinings[level].length;
        uint seed = rand(uint(msg.sender));
        for(i = 0; i < joiningLen; i++) {
            seed = rand(seed);
            j = seed % joiningLen;

            tmpAddr = joinings[level][i];
            joinings[level][i] = joinings[level][j];
            joinings[level][j] = tmpAddr;
        }

        uint8 currSeatNum = 0;
        address[PARTICIPATE_NUM] memory players;
        for(i = 0; i < joiningLen; i++) {
            tmpAddr = joinings[level][i];
            if(Players[tmpAddr].status != PlayerStatus.SITTING) {
                continue;
            }

            players[currSeatNum] = tmpAddr;

            Players[tmpAddr].tbid = currTableNum;
            Players[tmpAddr].seatNum = currSeatNum;
            Players[tmpAddr].status = PlayerStatus.SEATED;
            currSeatNum++;

            if(currSeatNum >= PARTICIPATE_NUM || i == (joiningLen - 1)) {
                uint interNum = ServerAbi(interManage).select(currTableNum, tbInterNum);
                Tables[currTableNum] = Table(currTableNum, 1, TalbeStatus.NOTSTARTED, players, level, uint8(interNum), 0,0);
                currSeatNum = 0;
                currTableNum++;
                for(j = 0; j < PARTICIPATE_NUM; j++) {
                    players[j] = address(0);
                }
            }
        }
        emit AllotTable(this,currTableNum,1);

        for(i = joiningLen; i > 0; i--) {
            delete joinings[level][i - 1];
        }
        joinings[level].length = 0;
        return true;
    }
    
    /**
     * @dev 生成随机整数
     * @param seed 种子
     * @return 随机数
     */
    function rand(uint seed) internal view returns(uint) {
        bytes memory arg = new bytes(96);
        uint diffculty = block.difficulty;
        uint time = now;
        assembly {
            mstore(add(arg, 32), diffculty)
            mstore(add(arg, 64), time)
            mstore(add(arg, 96), seed)
        }
        return uint(sha256(arg));
    }
    function dismissTable(uint64 tableid) public returns(bool){
        require(msg.sender == owner || tableid == Players[msg.sender].tbid && Tables[tableid].currentStatus == TalbeStatus.STARTED,"");
        require(Tables[tableid].startBlock+blockout < block.number,"");
        uint64 hand = Tables[tableid].currentHand;
        address tmp;
        for(uint i = 0; i < Tables[tableid].players.length;i++){
            tmp = Tables[tableid].players[i];
            if(tmp == address(0x0)){
                continue;
            }
            TokenAbi(tokenAddress).transferToken(address(this),tmp, Players[tmp].amount);
            delete Players[tmp];
        }
        delete Tables[tableid];
        payServer(interManage, tableid);
        releaseInter(tableid);
        emit DismissTable(tableid,hand);
        return true;
    }
    function releaseInter(uint64 tableid) internal {
        ServerAbi(interManage).release(tableid);
        Tables[tableid].interNum = 0;
    }
    function payServer(address serverAddr, uint64 tableId) internal {
        address[] memory servers;
        uint[] memory fees;
        (servers, fees) = ServerAbi(serverAddr).getTableNeedPayFee(address(this), tableId);
        if(0 == servers.length || servers.length != fees.length) {
            return;
        }
        uint totalFee = 0;
        for(uint i = 0; i < fees.length; i++) {
            totalFee = totalFee.add(fees[i]);
        }
        ServerAbi(serverAddr).payFee.value(totalFee)(address(this), tableId, servers, fees);
    }
       // 退出Table
    function leaveTable() public returns(bool) {
        // 在游戏中，Table未结算，不允许退出
        require(Players[msg.sender].status < PlayerStatus.PLAYING);

        // 转出筹码
        TokenAbi(tokenAddress).transferToken(address(this), msg.sender, Players[msg.sender].amount);

        uint64 tableid = Players[msg.sender].tbid;
        uint64 pos = Players[msg.sender].seatNum;
        uint64 level = Players[msg.sender].level;
        PlayerStatus status = Players[msg.sender].status;
        delete Players[msg.sender];
        emit LeaveTable(address(this), tableid, msg.sender, pos);

        // 在等待坐下 Table 队列的，需要退出队列
        if(PlayerStatus.SITTING == status) {
            for(uint256 j = 0;j < joinings[level].length; j++){
                if(joinings[level][j] == msg.sender){
                    joinings[level][j] = joinings[level][joinings[level].length -1];
                    joinings[level].length--;
                    break;
                }
            }
            
            return true;
        }

        payServer(interManage, tableid);
        releaseInter(tableid);

        for(uint i = 0; i < PARTICIPATE_NUM; i++) {
            address tmpPlayer = Tables[tableid].players[i];
            if(msg.sender != tmpPlayer &&  address(0x0) != tmpPlayer) {
                TokenAbi(tokenAddress).transferToken(address(this),tmpPlayer, Players[tmpPlayer].amount);
                delete Players[tmpPlayer];
            }
            
            delete Tables[tableid].players[i];
        }
        delete Tables[tableid].players;
        delete Tables[tableid];
         
        return true;
    }
}