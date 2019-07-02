local eth = require("eth")
local json = require("json")
local ge = require("gameengine")

require ("init")
require ("ddzabi")
-- local gt = require("game")

ddzroom_contract = class()

function ddzroom_contract:ctor()
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "ddzroom_contract ctor")
    self.curTable = 0   --当前TableID
    self.selfaddr = ge.SelfAddr()  --当前玩家账号地址 
    self.level = 0
    --print("room_contract ctor() ", self.selfaddr, err)
    self.tc = eth.contract(DDZRoomManagerABI, DDZRoomManagerAddr)
    self.btcContract = eth.contract(BitcoinTokenABI, btAddr)
    self.promotContract = eth.contract(PromotABI,promotAddr)
    --通知游戏UI事件而使用的订阅ID
    self.AllotTableSubId = "0"
    self.ReadySubId = "0"
    self.StartGameSubId = "0"
    self.SettleSubId = "0"
    self.LeaveSubId = "0"
    --与合约交互用的订阅数据
    self.JoinRoomSub  = nil
    self.AllotTableSub = nil 
    self.JoinSittingQueenSub = nil
    self.LeaveSub = nil
    self.StartSub = nil
    self.ReShaffSub = nil
    self.StartGameSub = nil
    self.SettleSub = nil 
    self.giveMeTokeSub = nil 
end

rCtr = ddzroom_contract:new()

function newAddress(str)--要求40个字节，所以不能带0x
    if string.sub(str, 1, 2) == "0x" then
        str = string.sub(str, 3, string.len(str))
    end
    return address.new(str) --调用luatype里的address
end

function ddzroom_contract:Unsubscribe() 
    self.curTable = 0 
    self.level = 0

    print(os.date("%Y/%m/%d %H:%M:%S ") .. "Unsubscribe() ")
    if (self.JoinRoomSub ~= nil) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "Unsubscribe joint")
        local err = self.tc.CancelWatchLog(self.JoinRoomSub)
        if (err ~= nil) then
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "Unsubscribe joint err")
        end
        self.JoinRoomSub = nil 

    end

    if (self.AllotTableSub ~= nil) then
        self.tc.CancelWatchLog(self.AllotTableSub)
        self.AllotTableSub = nil 
    end
    if (self.JoinSittingQueenSub ~= nil) then
        self.tc.CancelWatchLog(self.JoinSittingQueenSub)
        self.JoinSittingQueenSub = nil 
    end
    if (self.StartSub ~= nil) then
        self.tc.CancelWatchLog(self.StartSub)
        self.StartSub = nil 
    end
    if (self.ReShaffSub ~= nil) then
        self.tc.CancelWatchLog(self.ReShaffSub)
        self.ReShaffSub = nil 
    end
    if (self.StartGameSub ~= nil) then
        self.tc.CancelWatchLog(self.StartGameSub)
        self.StartGameSub = nil 
    end
    if (self.SettleSub ~= nil) then
        self.tc.CancelWatchLog(self.SettleSub) 
        self.SettleSub = nil 
    end

    if (self.LeaveSub ~= nil) then
        self.tc.CancelWatchLog(self.LeaveSub)
        self.LeaveSub = nil 
    end

    if (self.LeaveRoomSub ~= nil) then
        self.tc.CancelWatchLog(self.LeaveRoomSub) 
        self.LeaveRoomSub = nil 
    end
end

--获取房间Inter列表
function RoomInter()
    
    local inters = {}
  
        local interaddrs = rCtr.tc.Call("getTableInters", rCtr.curTable)
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "interaddrs = ", #interaddrs)
       
        for i = 1, #interaddrs do
            print(interaddrs[i], type(interaddrs[i]), tostring(interaddrs[i]))
            local addr,nd,x1,x2,x3 = rCtr.tc.Call("getInterInfo", tostring(interaddrs[i]))
            
            table.insert(inters, nd)
        end
    -- end
    return inters
end

--LeaveRoom合约事件回调函数
function LeaveRoom(roomAddr, playerAddr)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "LeaveRoom()", "player = " .. playerAddr .. ", myself = " .. rCtr.selfaddr .. ", roomaddr = " .. roomAddr)
    if (playerAddr == rCtr.selfaddr) then
        rCtr:Unsubscribe()
    end
end

--JoinSittingQueen合约事件回调函数
function JoinSittingQueen(playerAddr, roomAddr)
    print("JoinSittingQueen() ", playerAddr, roomAddr)
    if (playerAddr == rCtr.selfaddr) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "SittingDown OK !!!!")
    else
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "Others JoinSittingQueen !!!")
    end
end

--AllotTable合约事件回调函数
function AllotTable(roomaddr, tableId, nextHand)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "AllotTable()", "roomaddr = " .. roomaddr .. ", tableid = " .. tableId, "nextHand ="..nextHand)
    
    local addr, tableid, seatNum, amount, status, level = rCtr.tc.Call("getPlayerInfo", rCtr.selfaddr)
    print("addr, tableid, seatNum, amount, status, level = ", addr, tableid, seatNum, amount:String(), status, level)
    if tableid ~= 0 and rCtr.curTable==0 then
        local Players = rCtr.tc.Call("getTablePlayers", tableid)

        local flag = false 
        for i = 1, #Players do
            print("rCtr.selfaddr, Players[i] = ", type(rCtr.selfaddr), type(Players[i]))
            print("rCtr.selfaddr, Players[i] = ", rCtr.selfaddr, Players[i], rCtr.selfaddr == Players[i])
            if (rCtr.selfaddr == Players[i]) then
                print("flag = true ")
                flag = true 
                break 
            end
        end

        if (flag == true) then
            local interlist = {}
            local returnplayers = {}
            local playSeats = {}
            for i = 1, #Players do
                local addr, tableid, seatNum, amount, status, level = rCtr.tc.Call("getPlayerInfo", Players[i])
                table.insert( playSeats, seatNum)
                if (Players[i] == rCtr.selfaddr) then
                    rCtr.curTable = tableid
                    interlist = RoomInter()
                   
                    gd:join(seatNum, amount, tableid, addr, interlist, true, false)
                else
                    gd:join(seatNum, amount, tableid, addr, interlist, false, false)
                end

                local ti = {
                    ["Pos"] = seatNum,
                    ["PlayerAddr"] = addr,
                    ["Amount"] = amount:String(),
                    ["Status"] = status, 
                    ["Level"] = level,
                }
                table.insert(returnplayers, ti)
            end

            local resultinfo = {
                ["TableID"] = rCtr.curTable,
                ["Players"] = returnplayers,
            }

            rCtr:watchLeave()
            rCtr:watchReady()
            rCtr:watchStartGame()
            rCtr:watchSettle()

            ge.NotifySub(rCtr.AllotTableSubId, resultinfo) 
            --斗地主最多三个人
            gd:ShuffleCardBackStage(interlist, playSeats, 3, nextHand)
            rCtr:watchReshuffleStart() 
        end
    end
end


function roomleaveHandler(roomaddr, tableid, addr, pos) 
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "roomleaveHandler() ", tableid, addr, pos)
    if tableid == rCtr.curTable  then 
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "roomleaveHandler() ", tableid, addr, pos)
        local t = {}
        t["Tableid"] = tableid
        t["Addr"] = addr
        t["Pos"] = pos
        gd:leave(pos, tableid)
        ge.NotifySub(rCtr.LeaveSubId, t) 

        --取消监听 
        rCtr:Unsubscribe() 
    end
end

--UI订阅Leave（玩家离开桌子）事件，当合约事件LeaveTable触发时该事件被触发
function ddzroom_contract:watchLeave()
    if self.LeaveSub  == nil then
        local t = {}
        table.insert(t, self.curTable)
        self.LeaveSub = self.tc.WatchLog("LeaveTable", roomleaveHandler, t)
    end
    
end

function roomreadyHandler(roomAddr, tbNum, playerAddr, pos, hand)
    if tbNum == rCtr.curTable then 
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "roomreadyHandler()", "table = " .. tbNum .. ", player = " .. playerAddr .. ", pos = " .. pos .. ", hand = " .. hand) 
        --gd:start(pos) ready事件可能在游戏开始事件后到达

        local t = {}
        t["Tableid"] = rCtr.curTable
        t["Addr"] = playerAddr
        t["Pos"] = pos
        ge.NotifySub(rCtr.ReadySubId, t)--只需要通知即可
    end 
end

--UI订阅Ready（玩家准备就绪）事件，当合约事件Start触发时该事件被触发
function ddzroom_contract:watchReady()
    if self.StartSub == nil then
        local t = {}
        table.insert(t, self.curTable)
        self.StartSub = self.tc.WatchLog("Start", roomreadyHandler, t)
    end
    
end 

function roomstartgameHandler(roomaddr, tableid, hand)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "roomstartgameHandler()", "curTable = " .. rCtr.curTable .. ", tableid = " .. tableid .. ", hand = " .. hand)
    if tableid == rCtr.curTable then
        local players = rCtr:playersinfo()
        local tbInfo, currentHand = rCtr:tableinfo() 
        --gt:startGame(players, hand)
        gd:startGame(tbInfo, players, hand, rCtr.selfaddr)

        local t = {}
        t["Tableid"] = tableid
        t["Hand"] = hand
        ge.NotifySub(rCtr.StartGameSubId, t)
    end 
end

--UI订阅StartGame（开始游戏）事件，当合约事件GameStart触发时该事件被触发
function ddzroom_contract:watchStartGame()
    if self.StartGameSub == nil  then
        local t = {}
        table.insert(t, self.curTable)
        self.StartGameSub = self.tc.WatchLog("GameStart", roomstartgameHandler, t)
    end
    
end

function roomsettleHandler(hand, playernum, tableid, nextHand)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "roomsettleHandler() ", "curTable = " .. rCtr.curTable .. ", hand = " .. hand .. ", playerNum = " .. playernum .. ", tableid = " .. tableid, ", gd.notarying = ", gd.notarying) 
    print("nextHand = ", nextHand)
    gd.nexthand = nextHand
    if tableid == rCtr.curTable and not gd.notarying and gd.gamestate ~= -1 then
        --是不是要组成table
        gd:GameReset(nextHand) 

        local t = {}
        t["Hand"] = hand
        t["PlayerNum"] = playernum
        t["Tableid"] = tableid
        ge.NotifySub(rCtr.SettleSubId, t)
    end
end

--UI订阅Settle（结算）事件，当合约事件Settle触发时该事件被触发
function ddzroom_contract:watchSettle()
    if self.SettleSub == nil  then
        local t = {}
        table.insert(t, self.curTable)
        self.SettleSub = self.tc.WatchLog("Settle", roomsettleHandler, t)
    end
    
end

--都不叫地主重新洗牌事件
function reShuffleHandler(tableid, hand)
    if tableid == rCtr.curTable then
        gd:reShuffleCard(roomaddr, tableid, hand)
    end
end

function ddzroom_contract:watchReshuffleStart()
    if self.ReShaffSub == nil then
        self.ReShaffSub = self.tc.WatchLog("ReShaff", reShuffleHandler)
    end
    
end

function ddzroom_contract:tableinfo(params)
    local playerNum, base, needChips, multiple = rCtr.tc.Call("getRoomInfo", self.level) 
    local tbNum, currentHand, currentStatus, level = rCtr.tc.Call("getTableInfo", rCtr.curTable)
   
    local tableInfo = {
        ["TableId"] = rCtr.curTable,
        ["Creator"] = rCtr.selfaddr,
        ["PlayerNum"] = playerNum,
        ["BasePoint"] = base,
        ["NeedChips"] = needChips,
        ["CurrentStatus"]= currentStatus,
        ["MaxMultiple"] = multiple,
    }
    return tableInfo, currentHand
end

function ddzroom_contract:selfPlayingStatus()
    local addr, tableid, seatNum, amount, status, level = rCtr.tc.Call("getPlayerInfo", self.selfaddr)
    print(addr, tableid, seatNum, amount:String(), status,level)
    return addr, tableid, seatNum, status,level
end

--以下四个函数由UI调用
function ddzroom_contract:FastJoin(params)

    local t = json.decode(params) 
    if self.JoinSittingQueenSub == nil  then
        self.JoinSittingQueenSub = self.tc.WatchLog("JoinSittingQueen", JoinSittingQueen)
    end
    
    if self.AllotTableSub == nil  then
        self.AllotTableSub = self.tc.WatchLog("AllotTable", AllotTable)
    end
   

    self.level = t.Level
    local tx = self.tc.Transact("joinTable", t.Level)
    print("tx = ", tx)

    
   if self.LeaveRoomSub == nil  then
        self.LeaveRoomSub = self.tc.WatchLog("LeaveRoom", LeaveRoom)
   end
   

    --self.LeaveSub =  self.tc.WatchLog("LeaveTable", roomleaveHandler)
end 

function ddzroom_contract:leaveTable(params)
    self.tc.Transact("leaveTable")--不需要参数
end

function ddzroom_contract:Getplayersinfo(params)
    --local tid = tonumber(params)
    --local nilAddress [common.AddressLength]byte
    local players = {}

    --printtable(players)
    local Players = rCtr.tc.Call("getTablePlayers", rCtr.curTable)
    for i = 1, #Players do
        local addr, tableid, seatNum, amount, status,level = rCtr.tc.Call("getPlayerInfo", Players[i])
        print(addr, tableid, seatNum, amount:Stirng(), status,level)
        local info = {
            ["Pos"] = seatNum,
            ["PlayerAddr"] = addr,
            ["Amount"] = amount:String(),
            ["Status"] = status,
            ["Level"] = level,
        }
        table.insert(players, info)
    end
    return players
end


function ddzroom_contract:playersinfo(params)
    --local tid = tonumber(params)
    --local nilAddress [common.AddressLength]byte
    local players = {}

    --printtable(players)
    local Players = rCtr.tc.Call("getTablePlayers", rCtr.curTable)
    for i = 1, #Players do
        local addr, tableid, seatNum, amount, status,level = rCtr.tc.Call("getPlayerInfo", Players[i])
        print(addr, tableid, seatNum, amount:String(), status,level)
        local info = {
            ["Pos"] = seatNum,
            ["PlayerAddr"] = addr,
            ["Amount"] = amount,
            ["Status"] = status,
            ["Level"] = level,
        }
        table.insert(players, info)
    end
    return players
end

function ddzroom_contract:ready(params)
   
    local tbNum, currentHand, currentStatus,level = self.tc.Call("getTableInfo", self.curTable)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "ddzroom_contract:ready() hand = " .. currentHand .. ", tableid = " .. self.curTable .. ", status = " .. currentStatus)
    self.tc.Transact("start", self.curTable, currentHand)--不需要参数
end

function giveMeTokenHandler(saddr, value)
    -- body
    if (saddr == rCtr.selfaddr) then
        -- 充值成功
        print(os.date("%Y/%m/%d %H:%M:%S ") .."giveMeTokeHandler", saddr, value:String())
    end

end

function ddzroom_contract:giveMeToken()
    -- body
    if self.giveMeTokeSub == nil  then
        -- body
        self.promotContract.WatchLog("GiveMeToken", giveMeTokenHandler)
    end

    self.promotContract.Transact("giveMeToken")--不需要参数
end

function  ddzroom_contract:balanceOf()
    local balance = self.btcContract.Call("balanceOf",self.selfaddr)

    local balanceInfo = {
        ["Addr"] = self.selfaddr,
        ["Balance"] = balance:String(),
    } 

    return balanceInfo
end 

function  ddzroom_contract:exchangeKal(params)
    local t = json.decode(params) 
    print(os.date("%Y/%m/%d %H:%M:%S ") .."exchangeKal", t.Value)
    local v = bigInt:new() 
    local sv , result = v:SetString(t.Value, 0)
    if result == true then 
        self.btcContract.Transact("exchangeKal", sv)
    end
end

function  ddzroom_contract:exchangeGoldcoin(params)
    local t = json.decode(params) 
    print(os.date("%Y/%m/%d %H:%M:%S ") .."exchangeGoldcoin", t.Value)
    local v = bigInt:new()
    local sv , result = v:SetString(t.Value, 0)
    print("SetString reuslt:", result)
    if result == true then 
        local txop = {
            ["to"] = btAddr,  
            ["value"] = sv ,
        }
              
        local txhash, err =  eth.SendTransaction(txop)
        if err ~= nil  then
            print("SendTransaction err :", err) 
            return 
        end 
            
        print("Transaction Hash:", txhash)
    end
        
end


function  ddzroom_contract:KalTransaction(params)
    local t = json.decode(params) 
    print(os.date("%Y/%m/%d %H:%M:%S ") .."KalTransaction", t.Address, t.Value)
    local v = bigInt:new()
    local sv , result = v:SetString(t.Value, 0)
    if result == true then 
        local txop = {
            ["to"] = t.Address,  
            ["value"] = sv ,
        }     
        local txhash, err =  eth.SendTransaction(txop)
        if err ~= nil  then
            print("SendTransaction err :", err) 
            return 
        end 
            
        print("Transaction Hash:", txhash)
    end
end



function  ddzroom_contract:KalBalance(params)
   
    local balance , err = eth.BalanceAt(self.selfaddr)
    if err ~= nil then
        print("BalanceAt err :", err)
    end 

    local balanceInfo = {
        ["Addr"] = self.selfaddr,
        ["Balance"] = balance:String(),
        ["Errstr"] = err,
    } 
    return balanceInfo
end


function  ddzroom_contract:verify(params)
    local t = json.decode(params) 
    print(os.date("%Y/%m/%d %H:%M:%S ") .."verify", t.Tableid, t.Hand)
    local result = ge.Verify(t.Tableid, t.Hand)
    if string.sub(result, 1, 1) == "{" then
        return json.decode(result)
    end
    return result
end

function SubmitPointHandler( tableid, hand, addr, errstr)
    if tableid == rCtr.curTable and addr == rCtr.selfaddr then 
        if errstr ~= "" then  
            print("SubmitPoint err :", errstr)
            return 
        end 

        print("SubmitPoint ok :", tableid, hand, addr)
    end 
end

function  ddzroom_contract:submitPointHash(hand, pointHash)

    if self.SubmitPointSub == nil  then
        local index = {} 
        table.insert( index, self.curTable)
        self.SubmitPointSub = self.tc.WatchLog("SubmitPoint", SubmitPointHandler, index)
    end

    local bph = byteSlice.new() 
    bph:appendString(pointHash)
    self.tc.Transact("submitPointHash", self.curTable, hand, bph)
end

function ddzroom_contract:dismissTableFlag(tableid)
   local reuslt = self.tc.Call("dismissTable", tableid)

   print("dismissTableFlag", reuslt)

   return reuslt 
end

function ddzroom_contract:dismissTable(tableid )
    self.tc.Transact("dismissTable", tableid)
end