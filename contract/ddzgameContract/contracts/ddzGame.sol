pragma solidity >=0.4.21 <0.6.0;
import './ddzDao.sol';
import './LibAuthority.sol';
import './ServerAbi.sol';
import './SafeMath.sol';
import './RLP.sol';
import './TokenAbi.sol';

contract DdzGame is ddzDao,LibAuthority {
    using SafeMath for uint;
    using RLP for bytes;
    using RLP for RLP.RLPItem;
    using RLP for RLP.Iterator;

    constructor(string memory _name, uint64 multiple_, uint8 tbInterNum_, uint8 tbNotaryNum_, uint64 joiningQueueSize) payable public {
        owner = msg.sender;
		multiple = multiple_;
        tbInterNum = tbInterNum_;
        tbNotaryNum = tbNotaryNum_;
        //joining_queue_size = joiningQueueSize;
        if(0 == joiningQueueSize % PARTICIPATE_NUM)
        {
            joining_queue_size = joiningQueueSize;
        } else {
            joining_queue_size = (joiningQueueSize / PARTICIPATE_NUM + 1) * PARTICIPATE_NUM;
        }

        lvlCfg[1] = LevelConfig(200, 0);
        lvlCfg[2] = LevelConfig(1000, 10);
        lvlCfg[3] = LevelConfig(5000, 50);
        lvlCfg[4] = LevelConfig(20000, 200);
        currTableNum = 1;
        setMaxGasPrice(1e11);
        setGasLimit(1e7);
        addWhite(msg.sender);
    }

    // 检查必须是合约的所有者
    modifier onlyOwner {
        assert(msg.sender == owner);
        _;
    }

    //设置分配桌子
    function setQueueSize(uint64 joiningQueueSize) public onlyOwner returns(bool){
        if(0 == joiningQueueSize % PARTICIPATE_NUM)
        {
            joining_queue_size = joiningQueueSize;
        } else {
            joining_queue_size = (joiningQueueSize / PARTICIPATE_NUM + 1) * PARTICIPATE_NUM;
        }
        return true;
    }
    function setluaAddress(address addr) public onlyOwner returns(bool){
        luaAddress = addr;
        return true;
    }
     //设置公证脚本
    function setnotaryluaAddress(address addr) public onlyOwner returns(bool){
        notaryluaAddress = addr;
        return true;
    }
    function setTokenAddr(address addr)  public onlyOwner {
        tokenAddress = addr;
    }
    function setInterAddr(address addr) public onlyOwner{
        interManage = addr;
    }
    function setNotaryAddr(address addr) public onlyOwner{
        notaryManage = addr;
    }
    function setFuncAddr(address addr) public onlyOwner{
        funcAddress = addr;
    }

    /**
     * @dev 增加筹码
     */
    function addChips(uint value) public returns(bool) {
        if(Players[msg.sender].status == PlayerStatus.NOTJION) {
            return false;
        }
        TokenAbi token = TokenAbi(tokenAddress);
        if(!token.transferToken(msg.sender, address(this), value)) {
            return false;
        }
        Players[msg.sender].amount = Players[msg.sender].amount.add(value);
        return true;
    }
    function withdrawChips(uint value)public returns(bool){
        if(Players[msg.sender].amount <= value ||
        Players[msg.sender].amount-value < lvlCfg[Players[msg.sender].level].needChips){
            emit WithdrawChips(Players[msg.sender].tbid,msg.sender,"insufficient amount");
            return false;
        }
        if(!TokenAbi(tokenAddress).transferToken(address(this), msg.sender, value)) {
            emit WithdrawChips(Players[msg.sender].tbid,msg.sender,"token insufficient balance");
            return false;
        }
        Players[msg.sender].amount = Players[msg.sender].amount-value;
        WithdrawChips(Players[msg.sender].tbid,msg.sender,"");
        return true;
    }
    /**
     * @dev 获取房间信息
     */
    function getRoomInfo(uint64 level) public view returns(uint8,uint64,uint,uint64) {
        return (PARTICIPATE_NUM, lvlCfg[level].base, lvlCfg[level].needChips, multiple);
    }

    /**
     * @dev 获取等待入座队列
     */
    function getSittingQueen(uint64 level) public view returns (address[] memory) {
        return joinings[level];
    }

    /**
     * @dev 获取Table的所有玩家
     * @param tableid Table的ID
     */
    function getTableInfo(uint64 tableid) public view returns(uint64,uint64,uint8,uint64,uint,uint64,uint8,uint8) {
        Table memory tb = Tables[tableid];
        
        return (tb.tbid, tb.currentHand, uint8(tb.currentStatus),lvlCfg[tb.level].base, lvlCfg[tb.level].needChips,tb.level,tb.interNum, tb.nortaryNum);

    }
    
    /**
     * @dev 获取Table的所有玩家
     * @param tableid Table的ID
     */
    function getTablePlayers(uint64 tableid) public view returns(address[] memory players) {
        players = new address[](Tables[tableid].players.length);
        for(uint i= 0; i < Tables[tableid].players.length; i++){
            players[i] = Tables[tableid].players[i];
        }
        return;
    }

    /**
     * @dev 获取Table的所有正在玩游戏玩家
     * @param tableid Table的ID
     */
    function getTablePlayingPlayers(uint64 tableid) public view returns(uint64 number, address[] players) {
        players = new address[](Tables[tableid].players.length);
        if(TalbeStatus.STARTED == Tables[tableid].currentStatus) {
            
            for(uint i=0;i<Tables[tableid].players.length;i++){
                players[i] = Tables[tableid].players[i];
            }
            return (PARTICIPATE_NUM, players);
        }
    }

    /**
     * @dev 获取玩家信息
     */
    function getPlayerInfo(address playerAddr) public view returns(address, uint64, uint64, uint, uint8, uint64) {
        PlayerInfo memory pInfo = Players[playerAddr];
        return (playerAddr, pInfo.tbid, pInfo.seatNum, pInfo.amount, uint8(pInfo.status), pInfo.level);
    }

    // 玩家未在Room中，加入Room的Table
    function joinTable(uint64 level) public returns(bool){
        return funcAddress.delegatecall(msg.data);
    }
    function start(uint64 tableid, uint64 hand) public returns(bool){
        return funcAddress.delegatecall(msg.data);
    }
    // 退出Table
    function leaveTable() public returns(bool) {
        bytes4 funcid = bytes4(keccak256("leaveTable()"));
        return funcAddress.delegatecall(funcid);
    }



    /**
     * @dev 验证签名
     * @param sigs      签名信息
     * @param message       签名消息
     * @param tableid   Table的ID
     */
    function verifySigs(bytes memory sigs, bytes32 message, uint64 tableid) internal view returns(bool) {
        address[PARTICIPATE_NUM] memory players = Tables[tableid].players;

        uint i;
        uint j;

        uint[] memory mark = new uint[](players.length);
        for(i = 0; i < players.length; i++) {
            mark[i] = 0;
        }

        uint playingNum = 0;
        for(i = 0; i < players.length; i++) {
            if(address(0) == players[i]) {
                continue;
            }

            if (PlayerStatus.PLAYING == Players[players[i]].status) {
                playingNum++;
                mark[i] = 1;
            }
        }

        uint sigLen = 65 * playingNum;
        if (sigs.length != sigLen){
            return false;
        }

        uint8 v;
        bytes32 r;
        bytes32 s;
        for (i = 0; i < playingNum; i++) {
            assembly {
                r := mload(add(sigs, add(32, mul(i, 65))))
                s := mload(add(sigs, add(64, mul(i, 65))))
                v := mload(add(sigs, add(65, mul(i, 65))))
            }

            if (v < 27) {
                v += 27;
            }

            address addr = ecrecover(message, v, r, s);
            // emit SettlePlayer(addr, currentHand);
            for (j = 0; j < players.length; j++) {
                if (players[j] == addr) {
                    mark[j] = 0;
                    break;
                }
            }
        }

        for(i = 0; i < mark.length; i++) {
            if(1 == mark[i]) {
                return false;
            }
        }
        return true;
    }

    function resetNotray(uint64 tableid) internal returns(bool) {
        delete Notarys[tableid];
        return true;
    }

    //重置table的状态
    function reset(uint64 tableid) internal returns(bool){
        address[PARTICIPATE_NUM] memory players = Tables[tableid].players;
        uint i;
        for(i = 0; i < players.length; i++) {
            Players[players[i]].status = PlayerStatus.SEATED;
        }

        Tables[tableid].currentStatus = TalbeStatus.NOTSTARTED;
        resetNotray(tableid);
        return true;
    }
    function reshaff(uint64 hand) public returns(bool ret){
        Players[msg.sender].reshaff = hand;
        uint64 tableid = Players[msg.sender].tbid;
        
        for(uint i=0;i<Tables[tableid].players.length; i++){
            if(Players[  Tables[tableid].players[i] ].reshaff != hand){
                return true;
            }
        }
        for(i=0;i<Tables[tableid].players.length; i++){
            Players[ Tables[tableid].players[i] ].reshaff = 0; 
        }
        emit ReShaff(tableid,hand);
        return true;
    }
    /**
     * @dev 结算
     * @param sigs  签名信息
     * @param data  分配方案
     */
    function settle(Data_Src src, bytes sigs, bytes data) internal returns(bool) {
        RLP.RLPItem memory bal = data.toRLPItem();
        
        require(bal.isList(),"rlp data error");
        RLP.RLPItem[] memory settledata = bal.toList();
        require(settledata.length == 4,"rlp data length error");
        // address gameContract= rlpToAddress(settledata[0]);
        
        uint64 tableid = uint64(settledata[1].toUint());
        // uint currentHand    = settledata[2].toUint();
        require(address(this) == rlpToAddress(settledata[0]),"game contract address error");
        require(Tables[tableid].currentHand == settledata[2].toUint(),"table hand error");

        if(Data_Src.PLAYER == src) {
            // 玩家提交需要验证签名
            bytes32 message = keccak256(data);
		    require(verifySigs(sigs, message, tableid),"play sign error");
        }
        
        if(Data_Src.NORTARY == src) {
            // uint tableid = 20181001;
            // Inter(interManage).reApplyForInters(tableid);
        }

        require(settledata[3].isList(),"rlp data input error");


        RLP.RLPItem[] memory itemDatas = settledata[3].toList();

        address[PARTICIPATE_NUM] memory players = Tables[tableid].players;

        // 下面需要改为事务
        uint i;
        uint add;
        uint sub;
        for(i = 0; i < itemDatas.length; i++) {
            require(itemDatas[i].isList(),"item data error");
            RLP.RLPItem[] memory item = itemDatas[i].toList();
            require(item.length == 3,"item length error");

            address playerAddr = players[item[0].toUint()]; // 如果item[0].toUint() > PARTICIPATE_NUM ?
            
            if(1 == item[1].toUint()) {
                Players[playerAddr].amount = Players[playerAddr].amount.add(item[2].toUint());
                add = add.add(item[2].toUint());
            } else {
                Players[playerAddr].amount = Players[playerAddr].amount.sub(item[2].toUint());
                sub = sub.add(item[2].toUint());
            }
        }
        require(add == sub,"add != sub");
        emit Settle(Tables[tableid].currentHand,PARTICIPATE_NUM,tableid,Tables[tableid].currentHand+1);

        payServer(interManage, tableid);    //给inter付费
        reset(tableid);
        Tables[tableid].currentHand++;
        return true;
    }

    /**
     * @dev 结算

     * @param data  分配方案
     */
    function playerSettle(bytes memory data) public returns(bool){
        uint i;
        uint playingNum = 0;
        address[PARTICIPATE_NUM] memory players =  Tables[Players[msg.sender].tbid].players;
        for(i = 0; i < players.length; i++) {
            if (PlayerStatus.PLAYING == Players[players[i]].status) {
                playingNum++;             
            }
        }
        uint sigLen = 65 * playingNum;
        require(data.length > sigLen,"data length error");
    
        bytes memory balData = new bytes(data.length - sigLen);
        bytes memory sigs = new bytes( sigLen);
        for(i = sigLen; i < data.length; i++) {
            balData[i - sigLen] = data[i];
        }
        for(i = 0; i < sigLen; i++) {
            sigs[i] = data[i];
        }
        return settle(Data_Src.PLAYER, sigs, balData);
    }

    /**
     * @dev 公证者提交公证
     * @param data 分配方案
     */
    function submitNotary(bytes data) public returns(bool){
        emit SubmmitSettleData(msg.sender, uint64(data.length), data);
        bytes32 dhash = keccak256(data);
        address nrAddr = msg.sender;

        RLP.RLPItem memory bal = data.toRLPItem();
        require(bal.isList(),"rlp data err");
        RLP.RLPItem[] memory settledata = bal.toList();

        require(settledata.length == 4,"rlp data length error");

        require(address(this) == rlpToAddress(settledata[0]),"address error");
  
        uint64 tableid = uint64(settledata[1].toUint());
        require(uint64(settledata[2].toUint()) == Tables[tableid].currentHand,"currnet Hand error"); 

        address[] memory notarys = ServerAbi(notaryManage).getSelected(address(this), tableid);
        require (notarys.length > 0,"notarys error");

        uint i;
        bool flg = false;
        for(i = 0; i < notarys.length; i++) {
            // 判断提交者是否在公证者列表中
            if(nrAddr == notarys[i]) {
                flg = true;
                break;
            }
        }

        require(flg,"notary error");

        for(i = 0; i < Notarys[tableid].length; i++) {
            if(Notarys[tableid][i].nrAddr == nrAddr) {
                // 已提交，最新的覆盖旧的
                delete Notarys[tableid][i].allocate;
                Notarys[tableid][i].allocate = dhash;
                return true;
            }
        }

        Notarys[tableid].push(NotaryInfo(nrAddr, dhash));
        if(notarys.length == Notarys[tableid].length) {
            doNotarize(tableid,data);
        }
        return true;
    }

    function doNotarize(uint64 tableid,bytes data) internal returns(bool) {
        address[] memory notarys = ServerAbi(notaryManage).getSelected(address(this), tableid);
 	    require(notarys.length > 0,"notary not exist");

        uint lenNrInfo = Notarys[tableid].length;
        require(lenNrInfo>0,"notary not fond");

        uint i;
        bytes32  firstNrInfo = Notarys[tableid][0].allocate;
        for(i = 1; i < lenNrInfo; i++) {
            if(Notarys[tableid][i].allocate != firstNrInfo) {
                // 执行公证再进行比较，是因为允许公证者重复提交公证信息，新的覆盖旧的
                resetNotray(tableid);
                uint notaryNum = ServerAbi(interManage).select(tableid, tbNotaryNum);
                Tables[tableid].nortaryNum = uint8(notaryNum);
                return true;
            }
        }

        settle(Data_Src.NORTARY, new bytes(0), data);
        emit FinishNotary(tableid,Tables[tableid].currentHand);
        finishNotarize(tableid);
    }

    function rlpToAddress(RLP.RLPItem item) internal returns(address addr){

        if (item.toBytes().length==21) {
            addr = item.toAddress();
            return addr;
        } 
        
        string memory strAddr = item.toAscii();
        bytes memory bAddr = bytes(strAddr);

        uint iAdd = 0;
        uint tmp = 0;
        for(uint i = bAddr.length-40; i < bAddr.length; i++) {
            tmp = 0;
            if (bAddr[i] >= byte('0') && bAddr[i] <= byte('9')) {
                tmp = uint(bAddr[i]) - uint(byte('0'));
            }

            if (bAddr[i] >= byte('a') && bAddr[i] <= byte('f')) {
                tmp = 10 + uint(bAddr[i]) - uint(byte('a'));
            }

            if (bAddr[i] >= byte('A') && bAddr[i] <= byte('F')) {
                tmp = 10 + uint(bAddr[i]) - uint(byte('A'));
            }

            iAdd = iAdd << 4 | tmp;
        }

        return address(iAdd);
    }
    //申请公证
    function applyNotarize() public returns(bool) {
        uint64 tableid = Players[msg.sender].tbid;
        require(tableid > 0,"table not exist");
        require(PlayerStatus.PLAYING == Players[msg.sender].status,"table not playing");   // 在游戏进行中的玩家才允许申请公证
        address[] memory notarylist = ServerAbi(notaryManage).getSelected(address(this),tableid);
        if(notarylist.length > 0){
            return false;
        }
        resetNotray(tableid);

        uint notaryNum = ServerAbi(notaryManage).select(tableid, tbNotaryNum);
        Tables[tableid].nortaryNum = uint8(notaryNum);
        emit SelectNotary(tableid,notaryNum);
        return true;
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

    function releaseInter(uint64 tableid) internal {
        ServerAbi(interManage).release(tableid);
        Tables[tableid].interNum = 0;
    }
 
    /**
     * @dev 公证这完成table公证
     */
    function finishNotarize(uint64 tableid) internal returns(bool) {
        if(Tables[tableid].nortaryNum > 0) {
            Tables[tableid].nortaryNum = 0;
            payServer(notaryManage, tableid);
            
        }
        ServerAbi(notaryManage).release(tableid);
        resetNotray(tableid);
        return true;
    }
    function getTableInters(uint64 tableid)public view returns(address[]){
        return ServerAbi(interManage).getSelected(this,tableid);
    }
    function getTableNotarys(uint64 tableid)public view returns(address[]){
        return ServerAbi(notaryManage).getSelected(this,tableid);
    }
    //
    function getInterInfo(address interAddress)public view returns(address, string, uint, uint, uint){
        return ServerAbi(interManage).getServerInfo(interAddress);
    }
    function getNotaryInfo(address notaryAddress)public view returns(address, string, uint, uint, uint){
        return ServerAbi(notaryManage).getServerInfo(notaryAddress);
    }

    //上传校验牌点hash
    //桌子上玩家都传了相同hash才生效
    function submitPointHash(uint64 tableid,uint64 hand,bytes memory pointHash) public returns(bool){
        if(Players[msg.sender].tbid != tableid){
            emit SubmitPoint(tableid,hand,msg.sender,"error tableid");
            return false;
        }
        if(Tables[tableid].currentHand != hand){
            emit SubmitPoint(tableid,hand,msg.sender,"error hand");
            return false;
        }

        if (Players[msg.sender].status < PlayerStatus.PLAYING){
            emit SubmitPoint(tableid,hand,msg.sender,"error player status");
            return false;
        }

        bytes32 phash = sha256(pointHash);
        Players[msg.sender].pointHash = phash;
        emit SubmitPoint(tableid,hand,msg.sender,"");
        address[] memory playingPlayer = new address[](PARTICIPATE_NUM);
        address tmp;
        uint64 index = 0;
        for(uint i = 0; i < Tables[tableid].players.length;i++){
            tmp = Tables[tableid].players[i];
            if(tmp == address(0x0) || Players[tmp].status < PlayerStatus.PLAYING){
                continue;
            }
            if(Players[tmp].pointHash != phash){
                return true;
            }
            playingPlayer[index] = tmp;
            index++;
        }
        PointHashs[phash] = playingPlayer;
        emit SubmitPoint(index,index,msg.sender,"");
        return true;
    }
    
    //根据牌点hash获取玩家
    function getPointPlayers(bytes memory pointHash)public view returns(address[] memory players){
       return PointHashs[sha256(pointHash)];
    }
    //获取桌子游戏开始的区块高度

    function getTableStartBlock(uint64 tableid)public view returns(uint64){
        return uint64(Tables[tableid].startBlock);
    }
    //超时解散桌子
    function dismissTable(uint64 tableid) public returns(bool){
        return funcAddress.delegatecall(msg.data);
    }
}
