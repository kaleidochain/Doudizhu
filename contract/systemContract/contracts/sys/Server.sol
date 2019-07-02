pragma solidity >=0.4.21 <0.6.0;

import '../lib/math/SafeMath.sol';

contract Server {
    using SafeMath for uint;

    uint constant MAX_SERVER_NUMBER = 1024 * 1024 * 8;  //1M
    uint constant MARGIN_THRESHOLD  = 100;              //抵押数量门槛

    event Register(address indexed addr, string nodeid, uint amount);
    event ModifyNodeId(address indexed addr, string nodeid);
    event UnRegister(address indexed addr, string nodeid, uint amount);
    event ApplyForServer(address indexed roomAddr, uint indexed tableId, uint number);
    event ReApplyForServer(address indexed roomAddr, uint indexed tableId, uint number);

    /**
     * @dev 服务计费模式
     */
    enum ChargeMode {
        NOTSET,         //未设置
        SERVICETIME,    //1 按服务时间
        SERVICECOUNT    //2 按服务次数
    }

    struct ServerData {
        address addr;
        string  nodeid;
        uint    pawnAmount;     //抵押金额
        uint    price;          //服务的价格
        uint    recieveFee;     //收到的服务费
    }

    struct ServiceRecord {
        uint    tableid;        //游戏tableid
        uint    startHeigth;    //开始服务高度
        uint    payedAmount;    //已付费金额
    }

    address public owner;
    uint    public chargMode;   //收费模式
    ServerData[] servers;
    mapping(address=>uint) serverIdx;

    mapping(address => mapping(address => ServiceRecord[]))  serviceRecords;        //(server地址 => (room地址 => 服务记录列表))
    mapping(address => mapping(address => mapping(uint => uint)))  tableRecordIdx;  //(server地址 => (room地址 => (tableid => serviceRecords中的索引)))
    mapping(address => mapping(uint => address[]))  tableUseServers;     //房间的table使用的server列表(room地址 => (tableId => server地址列表))

    constructor(uint chargMode_) public {
        require(uint(ChargeMode.SERVICETIME) == chargMode_ || uint(ChargeMode.SERVICECOUNT) == chargMode_);
        chargMode = chargMode_;
        owner = msg.sender;
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

    function serverExist(address addr) internal view returns(bool) {
        return serverIdx[addr] > 0;
    }
    function serverDataIdx(address addr) internal view returns(uint) {
        return serverIdx[addr] - 1;
    }

    function pushServer(ServerData memory data) internal returns(bool) {
        if(serverExist(data.addr)){
            return false;
        }

        servers.push(data);
        serverIdx[data.addr] = servers.length;
        return true;
    }

    function popOutServer(address addr) internal returns(bool) {
        if(!serverExist(addr)){
            return false;
        }

        uint idx = serverDataIdx(addr);
        delete servers[idx].nodeid;
        delete servers[idx];
        if(idx != (servers.length - 1)) {
            servers[idx] = servers[servers.length - 1];
            servers[idx].nodeid = servers[servers.length - 1].nodeid;
            serverIdx[servers[idx].addr] = idx + 1;
        }
        servers.length--;

        delete serverIdx[addr];

        return true;
    }

    function numberOfServers() public view returns(uint) {
        return servers.length;
    }

    /**
     * @dev 注册server
     * @param nodeid server的node id
     */
    function register(string memory nodeid, uint price) public payable returns (bool) {
        uint amount = msg.value;
        require(amount >= MARGIN_THRESHOLD);
        require(!serverExist(msg.sender));

        emit Register(msg.sender, nodeid, amount);

        return pushServer(ServerData(msg.sender, nodeid, amount, price, 0));
    }

    /**
     * @dev 增加抵押
     */
    function addPawnAmount() public payable returns (bool) {
        uint amount = msg.value;
        require(amount > 0);
        require(serverExist(msg.sender));
        servers[serverDataIdx(msg.sender)].pawnAmount = servers[serverDataIdx(msg.sender)].pawnAmount.add(amount);
    }

    /**
     * @dev Server注销
     * @return 是否成功
     */
    function unRegister() public returns (bool) {
        require(serverExist(msg.sender));

        uint pawnAmount = servers[serverDataIdx(msg.sender)].pawnAmount;
        uint fee = servers[serverDataIdx(msg.sender)].recieveFee;
        popOutServer(msg.sender);
        msg.sender.transfer(pawnAmount.add(fee));

        return true;
    }
    
    /**
     * @dev 修改server的nodeid
     * @param nodeid server的node id
     */
    function modifyNodeid(string memory nodeid) public {
        require(serverExist(msg.sender));
        servers[serverDataIdx(msg.sender)].nodeid = nodeid;

        emit ModifyNodeId(msg.sender, nodeid);
    }

    /**
     * @dev 调整服务价格
     * @param price 服务的价格
     */
    function adjustPrice(uint price) public {
        require(serverExist(msg.sender));
        servers[serverDataIdx(msg.sender)].price = price;
    }

    /**
     * @dev 获取Server信息
     */
    function getServerInfo(address addr) public view returns(address, string memory, uint, uint, uint) {
        if(!serverExist(addr)) {
            return (address(0x0),"",0,0,0);
        }

        ServerData storage obj = servers[serverDataIdx(addr)];
        return (obj.addr, obj.nodeid, obj.pawnAmount, obj.price, obj.recieveFee);
    }

    function delServeRecord(address roomAddr, uint tableId) public {
        doDelServeRecord(msg.sender, roomAddr, tableId);
    }

    function addServeRecord(address serverAddr, address roomAddr, uint tableId) internal {
        if(serviceRecExist(serverAddr, roomAddr, tableId)) {
            return;
        }

        serviceRecords[serverAddr][roomAddr].push(ServiceRecord(tableId, block.number, 0));
        tableRecordIdx[serverAddr][roomAddr][tableId] = serviceRecords[serverAddr][roomAddr].length;

        return;
    }

    function doDelServeRecord(address serverAddr, address roomAddr, uint tableId) internal {
        if(!serviceRecExist(serverAddr, roomAddr, tableId)) {
            return;
        }

        uint idx = serviceRecIdx(serverAddr, roomAddr, tableId);
        
        uint recordLen = serviceRecords[serverAddr][roomAddr].length;
        if(idx < (recordLen - 1))
        {
            ServiceRecord storage rec = serviceRecords[serverAddr][roomAddr][recordLen - 1];
            serviceRecords[serverAddr][roomAddr][idx] = rec;
            tableRecordIdx[serverAddr][roomAddr][rec.tableid] = idx + 1;
            delete serviceRecords[serverAddr][roomAddr][recordLen - 1];
        } else {
            delete serviceRecords[serverAddr][roomAddr][idx];
        }
        serviceRecords[serverAddr][roomAddr].length--;

        delete tableRecordIdx[serverAddr][roomAddr][tableId];
    }

    function getNeedPayFee(address roomAddr, uint tableId, address serverAddr) public view returns(uint) {
        if(!serverExist(serverAddr)) {
            return 0;
        }
        ServerData storage objSvr = servers[serverDataIdx(serverAddr)];
        if(!serviceRecExist(serverAddr, roomAddr, tableId)) {
            return 0;
        }
        uint idx = serviceRecIdx(serverAddr, roomAddr, tableId);
        ServiceRecord storage objRec = serviceRecords[serverAddr][roomAddr][idx];

        if(chargMode == uint(ChargeMode.SERVICETIME)) {
            uint totalHeigth = block.number.sub(objRec.startHeigth);
            return objSvr.price.mul(totalHeigth).sub(objRec.payedAmount);
        } else {
            return objSvr.price;
        }
    }

    /**
     * @dev 取指定room的table记录需要付的服务费
     * @param roomAddr 房间地址
     * @param tableId 桌子id
     * @return (地址列表, 费用列表)
     */
    function getTableNeedPayFee(address roomAddr, uint tableId) public view returns(address[] memory, uint[] memory) {
        uint len = tableUseServers[roomAddr][tableId].length;
        address[] memory svrs = new address[](len);
        uint[] memory fees = new uint[](len);
        for(uint i = 0; i < len; i++) {
            address serverAddr = tableUseServers[roomAddr][tableId][i];
            svrs[i] = serverAddr;
            fees[i] = getNeedPayFee(roomAddr, tableId, serverAddr);
        }

        return (svrs, fees);
    }

    /**
     * @dev 取server服务指定room的table记录
     * @param serverAddr server地址
     * @param roomAddr 房间地址
     * @param tableId 桌子id
     * @return (tableId, 开始服务的区块高度, 已支付的费用)
     */
    function getServeTableRec(address serverAddr, address roomAddr, uint tableId) public view returns(uint, uint, uint) {
        if(serviceRecExist(serverAddr, roomAddr, tableId)) {
            uint idx = serviceRecIdx(serverAddr, roomAddr, tableId);
            ServiceRecord storage obj = serviceRecords[serverAddr][roomAddr][idx];
            return (obj.tableid, obj.startHeigth, obj.payedAmount);
        }

        return (0,0,0);
    }

    /**
     * @dev 取server服务指定room的记录
     * @param serverAddr server地址
     * @param roomAddr 房间地址
     * @return (tableId, 开始服务的区块高度, 已支付的费用)的列表
     */
    function getServeRoomRec(address serverAddr, address roomAddr) public view returns(uint[] memory, uint[] memory, uint[] memory) {
        ServiceRecord[] storage records = serviceRecords[serverAddr][roomAddr];
        uint len = records.length;
        uint[] memory tableids = new uint[](len);
        uint[] memory startHeigths = new uint[](len);
        uint[] memory payedAmts = new uint[](len);
        for(uint i = 0; i < len; i++) {
            tableids[i] = records[i].tableid;
            startHeigths[i] = records[i].startHeigth;
            payedAmts[i] = records[i].payedAmount;
        }

        return (tableids, startHeigths, payedAmts);
    }

    function addServerRecieveFee(address serverAddr, uint amount) internal {
        if(!serverExist(serverAddr)) {
            return;
        }
        uint idx = serverDataIdx(serverAddr);
        servers[idx].recieveFee = servers[idx].recieveFee.add(amount);
    }

    function serviceRecExist(address serverAddr, address roomAddr, uint tableId) internal view returns(bool) {
        return tableRecordIdx[serverAddr][roomAddr][tableId] > 0;
    }

    function serviceRecIdx(address serverAddr, address roomAddr, uint tableId) internal view returns(uint) {
        return tableRecordIdx[serverAddr][roomAddr][tableId] - 1;
    }

    function addPay(address serverAddr, address roomAddr, uint tableId, uint amount) internal {
        if(serviceRecExist(serverAddr, roomAddr, tableId)) {
            uint idx = serviceRecIdx(serverAddr, roomAddr, tableId);
            serviceRecords[serverAddr][roomAddr][idx].payedAmount = serviceRecords[serverAddr][roomAddr][idx].payedAmount.add(amount);
            addServerRecieveFee(serverAddr, amount);
        }
    }

    function payOne(address roomAddr, uint tableId, address serverAddr) public payable returns(bool) {
        require(msg.value > 0);
        addPay(serverAddr, roomAddr, tableId, msg.value);
        return true;
    }

    function payFee(address roomAddr, uint tableId, address[] memory serverAddrs, uint[] memory fees) public payable returns(bool) {
        require(serverAddrs.length == fees.length);

        uint i;
        uint totalFee = 0;
        for(i = 0; i < fees.length; i++) {
            addPay(serverAddrs[i], roomAddr, tableId, fees[i]);
            totalFee = totalFee.add(fees[i]);
        }

        require(totalFee <= msg.value);
        return true;
    }

    /**
     * @dev 取房间table选择的server
     * @param roomAddr 房间地址
     * @param tableId 桌子id
     * @return 选择的server
     */
    function getSelected(address roomAddr, uint tableId) public view returns(address[] memory) {
        return tableUseServers[roomAddr][tableId];
    }

    function clearSelected(address roomAddr, uint tableId) internal {
        delete tableUseServers[roomAddr][tableId];
        tableUseServers[roomAddr][tableId].length = 0;
    }

    function contain(address[] memory arrAddrs, address addr) internal pure returns(bool) {
        for(uint i = 0; i < arrAddrs.length; i++) {
            if(addr == arrAddrs[i]) {
                return true;
            }
        }
        return false;
    }

    function doSelect(address[] memory exclude, uint tableId, uint number) internal returns(uint) {
        uint needNumber = number;
        uint index;
        uint guard;
        bool finish;
        uint seed = tableId;
        uint serverNumber = numberOfServers();
        while(needNumber > 0) {
            seed = rand(seed);
            index = seed % serverNumber;
            guard = index;
            finish = false;
            while(contain(tableUseServers[msg.sender][tableId], servers[index].addr)
            || contain(exclude, servers[index].addr)) {
                index = (index + 1) % serverNumber;
                if(index == guard) {
                    finish = true;
                    break;
                }
            }
            if(finish) {
                break;
            }

            needNumber--;
            tableUseServers[msg.sender][tableId].push(servers[index].addr);
            addServeRecord(servers[index].addr, msg.sender, tableId);
        }

        return (number - needNumber);
    }

    /**
     * @dev 选Server
     * @param tableId 桌子id
     * @param number 要选择的个数
     * @return 实际选择的个数
     */
    function select(uint tableId, uint number) public returns(uint) {
        clearSelected(msg.sender, tableId);
        address[] memory exclude = new address[](0);
        uint selectedNumber = doSelect(exclude, tableId, number);
        emit ApplyForServer(msg.sender, tableId, selectedNumber);
        return selectedNumber;
    }

    /**
     * @dev 重新选Server
     * @param number 要选择的个数
     * @return 实际选择的个数
     */
    function reSelect(uint tableId, uint number) public returns(uint) {
        address[] memory exclude = tableUseServers[msg.sender][tableId];
        clearSelected(msg.sender, tableId);
        uint selectedNumber = doSelect(exclude, tableId, number);
        emit ReApplyForServer(msg.sender, tableId, selectedNumber);
        return selectedNumber;
    }

    /**
     * @notice index > 0
     */
    function isBitSet(bytes memory bitset, uint index) internal pure returns(bool) {
        require(index > 0);
        uint posi = (index - 1) / 8;
        uint posj = (index - 1) % 8 + 1;

        return uint8(bitset[posi] & bytes1(uint8(1 << (8 - posj)))) > 0;
    }

    function setBit(bytes memory bitset, uint index) internal pure {
        require(index > 0);
        uint posi = (index - 1) / 8;
        uint posj = (index - 1) % 8 + 1;
        bitset[posi] = (bitset[posi] | bytes1(uint8(1 << (8 - posj))));
    }

    /**
     * @dev 重新选Server
     * @notice 时间复杂度O(n)
     * @param tableId 桌子id
     * @param number 要选择的个数
     * @return 实际选择的个数
     */
    function reSelect2(uint tableId, uint number) public returns(uint) {
        if(0 == number) {
            return 0;
        }

        uint serverNumber = numberOfServers();
        serverNumber = (MAX_SERVER_NUMBER <= serverNumber) ? MAX_SERVER_NUMBER : serverNumber;
        if(serverNumber <= tableUseServers[msg.sender][tableId].length) {
            clearSelected(msg.sender, tableId);
            return 0;
        }

        bytes memory bitset = new bytes(serverNumber / 8 + 1);
        uint i;
        uint execluedNumber = 0;
        for(i = 0; i < tableUseServers[msg.sender][tableId].length; i++) {
            if(serverExist(tableUseServers[msg.sender][tableId][i])) {  // 服务器可能已调了unRegister
                setBit(bitset, serverDataIdx(tableUseServers[msg.sender][tableId][i]) + 1);
                execluedNumber++;
            }
        }
        
        uint notSelectedNum = serverNumber - execluedNumber;
        clearSelected(msg.sender, tableId);

        uint needNumber = number;
        uint seed = tableId;
        for(i = 1; i <= serverNumber; i++) {
            if(isBitSet(bitset, i)) {
                continue;
            }

            seed = rand(seed);
            if(seed % notSelectedNum < needNumber) {
                needNumber--;
                tableUseServers[msg.sender][tableId].push(servers[i - 1].addr);
                addServeRecord(servers[i - 1].addr, msg.sender, tableId);
                if(0 == needNumber) {
                    break;
                }
            }
            notSelectedNum--;
            if(0 == notSelectedNum) {
                break;
            }
        }

        emit ReApplyForServer(msg.sender, tableId, number - needNumber);
        return (number - needNumber);
    }

    function stopService(address serverAddr, address roomAddr, uint tableId) internal {
        if(!serviceRecExist(serverAddr, roomAddr, tableId)) {
            return;
        }
        if(!serverExist(serverAddr)) {
            return;
        }

        uint price = servers[serverDataIdx(serverAddr)].price;
        uint mustPayFee;
        uint idx = 0;
        if(uint(ChargeMode.SERVICETIME) == chargMode) {
            idx = serviceRecIdx(serverAddr, roomAddr, tableId);
            uint startHeigth = serviceRecords[serverAddr][roomAddr][idx].startHeigth;
            uint totalFee = price.mul(block.number.sub(startHeigth));
            mustPayFee = totalFee.mul(4).div(5);
        } else {
            mustPayFee = price;
        }

        if(serviceRecords[serverAddr][roomAddr][idx].payedAmount >= mustPayFee) {
            doDelServeRecord(serverAddr, roomAddr, tableId);
        }
    }

    /**
     * @dev 释放table的server
     * @param tableId table的id
     */
    function release(uint tableId) public {
        for(uint i = 0; i < tableUseServers[msg.sender][tableId].length; i++) {
            stopService(tableUseServers[msg.sender][tableId][i], msg.sender, tableId);
        }

        delete tableUseServers[msg.sender][tableId];
        tableUseServers[msg.sender][tableId].length = 0;
    }
}