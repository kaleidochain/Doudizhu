local ge = require("gameengine")
local ddz = require("doudizhu")
local st = require("ddzseat")
local json = require("json")
local eth  = require("eth")
local rlp  = require("rlp")

require("ddzabi")
require("uihandler")

local SeatStatusType = CreateEnumTable({"NOTJION", "NOTSEATED", "SITTING", "SEATED", "READY", "PLAYING", "DISCARD"},-1)
local ConsensusStateType = CreateEnumTable({"Init_check", "Po_check", "Pk_check", "Sf_check", "Bl_check", "R2_check", "R3_check", "R4_check", "Rf_check"},-1)
local GameStatusType = CreateEnumTable({"DeskState_Init", "DeskState_Grab", "DeskState_Play", "DeskState_Over"},-1)
local PlayMethondType = CreateEnumTable({"Pass", "Play"},-1)
local DealStatusType = CreateEnumTable({"None", "Self", "All"},-1)

local GrabDataCode    = 0x1000  --抢地主消息
local GrabSignDataCode  = 0x1001 --抢地主结果签名消息
local PlayDataCode = 0x1002 --过牌消息
local SettleSignDataCode  = 0x1003 --结算签名消息 

local NotaryNumber = 2

game_ddz =class()		-- 定义一个类 game_ddz 

local settled = false

function game_ddz:ctor()	-- 定义 game_texas 的构造函数
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "game_ddz ctor")
    self.seats = {}           --game_seat数组
    self.ConsensusState = -1  --线下共识状态，ConsensusStateType的值
    self.gamestate = -1       --游戏状态，GameStatusType的值
    self.gameOverFlag = false --TODO：没用到，是否要删除
    self.myseat = -1          --玩家自己的座位Id（位置）
    self.base = 0             --底分
    self.maxmultiple = 0      --最大倍数
    self.multiple = 0         --当前倍数
    self.firstqdzTurn = 0     --第一个抢地主的位置
    self.lastqdzcurnTurn = -1 --最后一个抢地主的位置
    self.landlordSeat = -1    --地主玩家位置
    self.currentqdzTurn = -1  --当前抢地主的位置
    self.currentPlayCardTurn = -1 --当前出牌的位置
    self.currentPlayCardType = {} --当前出牌座位Id的可操作值 0不出 1出牌 
    self.result = {Type = ddz.HandPatternsType.EVERYCARDTYPE, Max = 3, Size = 0, Value = 3,}  --判牌结果
    self.passNumber = 0       --不要牌的玩家数
    self.winseat = -1         --赢的玩家的位置
    self.hand = 0             --本桌牌第几轮牌局
    self.tableid = 0          --桌子Id

    self.ReadyFlag = false 
    self.ShuffleFlag = false

    --恢复数据，返回给UI
    self.RecoverData = {} 
    self.notarying = false
end

gd = game_ddz.new() 

function split(str,reps)
    local resultStrList = {}
    string.gsub(str, '[^'..reps..']+', function (w)
        table.insert(resultStrList, w)
    end)
    return resultStrList
end

--ddzroomcontract.lua调用
function game_ddz:join(seatid, balance, tableid, playeraddr, interlist, isself, connectornot)
    local ns = st.new(seatid, balance, playeraddr)
    ns.status = SeatStatusType.SEATED 
    if (self.seats == nil) then
        self.seats = {}
    end
    
    table.insert(self.seats, ns) 
    
    if (isself == true) then
        self.myseat = seatid
    end 

    local naddr = newAddress(playeraddr)
    ge.Sit(seatid, isself, tableid, naddr, interlist, connectornot) 
end



--ddzroomcontract.lua调用
function game_ddz:startGame(tbinfo, players, hand, selfaddr)

    settled = false

    for i = 1, #players do
        print(i, players[i], players[i].Pos, players[i].Amount, players[i].PlayerAddr)
        if (self:isIndesk(players[i].Pos, players[i].PlayerAddr) == false) then
            local ns = st.new(players[i].Pos, players[i].Amount, players[i].PlayerAddr)
            ns.status = players[i].Status 
            table.insert(self.seats, ns) 

            local isself = false
            if (selfaddr == pl[i].PlayerAddr) then
                isself = true
                self.myseat = pl[i].Pos 
            end 

            local naddr = newAddress(pl[i].PlayerAddr)
            local nodelist = {}
            ge.Sit(pl[i].Pos, isself, tbinfo.TableId , naddr, nodelist, false) 
        else
            self:updateState(players[i].Pos, players[i].PlayerAddr, players[i].Status)
        end
    end

    print(os.date("%Y/%m/%d %H:%M:%S ") .. "myseat:", self.myseat, "hand:", hand)

    local myseat = self:GetSeat(self.myseat)
    print(myseat, myseat.status)
    if (myseat ~= nil and myseat.status == SeatStatusType.PLAYING) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "Game Start.................")
        self.hand = hand 
        self.tableid = tbinfo.TableId
        self.base = tbinfo.BasePoint --底分
        self.maxmultiple = tbinfo.MaxMultiple
        self.gamestate = GameStatusType.DeskState_Init

        self:watchNotary()

        local seatSortFun = function(a, b)
            return a.id < b.id 
        end
        table.sort(self.seats, seatSortFun)

        --ge.ShuffleCard(54, hand) 
        self.ReadyFlag = true 

        tryDealCard()
    else
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "Game Already Start, but Yout not Start.....")
    end
end


function game_ddz:ShuffleCardBackStage(nodelist, playseats, maxplays, nexthand)
    self.nodelist = nodelist
    self.playseats = playseats
    self.maxplays = maxplays 
    self.nexthand = nexthand

    local ErrHandfn  = function(errstr)
        if errstr ~= nil then
            -- 如果后台洗牌发送错误， 通知UI洗牌错误
            rCtr:leaveTable()
        end
    end

    ge.ShuffleCardBackStage(54, playseats, maxplays, nodelist, true, nexthand, ErrHandfn)
end

function game_ddz:updateState(pos, addr, state)
    for i, v in ipairs(self.seats) do 
        if (v.id == pos and v.ad == addr) then
            v.status = state 
        end
    end
end

--重新洗牌
function game_ddz:reShuffleCard(roomaaddr, tableid, hand)
    if (hand == self.hand) then
        local err = ge.ShuffleCard(54, self.playseats,self.maxplays, hand)
        if (err ~= nil) then 
            --洗牌错误，通知UI 
            rCtr:leaveTable()
        end 
    end
end

function game_ddz:isIndesk(pos, addr)
    for i,v in ipairs(self.seats) do
       if (v.id == pos and v.ad == addr) then
           return true
       end
    end

    return false
end

function game_ddz:leave(seat, tableid)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "Leave Table....")
    -- if (selfflag == true) then
    --     self.seats = nil 

    --      --重置游戏状态
    --     --self:GameReset()
    -- else
    --     if (self.seats ~= nil) then
    --         for i,v in ipairs(self.seats) do

    --             if (v.id == seat) then
    --                 table.remove(self.seats, i) 
    --                 break
    --             end
    --         end
    --     end
       
    -- end
    
    -- ge.Leave(seat, selfflag) 
    if (self.seats ~= nil) then
        for i,v in ipairs(self.seats) do
            ge.Leave(v.id, v.id == self.myseat)
        end
        self.seats = {} 
        self:gameStateUninit() 
    end
end

function game_ddz:GetSeat(seat)
    for i,v in ipairs(self.seats) do
        print(v.id, v.ad)
        if (v.id == seat) then
            return v
        end
    end

    return nil 
end

function game_ddz:shuffleStateUninit()
    self.gamestate = -1
    self.gameOverFlag = false 
    self.multiple = 0  
    self.firstqdzTurn = 0 
    self.lastqdzcurnTurn = -1
    self.landlordSeat = -1  --地主位置  
    self.currentqdzTurn = -1   --当前抢地主的位置
    self.currentPlayCardTurn = -1 --当前出牌的位置

    for i, v in ipairs(self.seats) do
        v.grab = 0            --是否抢地主 0-不抢 1-抢 
        v.optimes = 0         --操作次数，标识最后一个抢地主是否完成
        v.privateCard = {}
        v.privateIndex = {} 
        v.publicCard = {}
        v.publicIndex = {} 
        v.grabstateSignData = "" 
        v.grabstateSignDataHash = ""
        v.grabstateSign = ""  
    end
end

function game_ddz:gameStateUninit()
    self.gamestate = -1
    self.gameOverFlag = false 
    self.multiple = 0  
    self.firstqdzTurn = 0 
    self.lastqdzcurnTurn = -1
    self.landlordSeat = -1  --地主位置  
    self.currentqdzTurn = -1   --当前抢地主的位置
    self.currentPlayCardTurn = -1 --当前出牌的位置
    self.currentPlayCardType = {} --当前出牌位置的可操作值 0不出 1出牌 
    self.result = {Type = ddz.HandPatternsType.EVERYCARDTYPE, Max = 3, Size = 0, Value = 3,}
    self.passNumber = 0  
    self.winseat = -1 
    self.hand = 0 
    self.tableid = 0 

    if (self.seats ~= nil) then
        for i,v in ipairs(self.seats) do
            v.grab = 0            --是否抢地主 0-不抢 1-抢 
            v.optimes = 0         --操作次数，标识最后一个抢地主是否完成
            v.privateCard = {}
            v.privateIndex = {} 
            v.publicCard = {}
            v.publicIndex = {}  
            v.currentRoundCard = {}  --当前轮出牌集合
            v.allRoundCard = {}      --所有轮出牌集合 
            v.playCardNum = 0        --出了多少牌 
            v.playIndex = {}         --出牌的currsor 
            v.grabstateSignData = "" 
            v.grabstateSignDataHash = ""
            v.grabstateSign = ""   
            v.settleSignData = ""  --userdata  type byteSlice
            v.settleSignDataHash = ""  --userdata  type byteSlice
            v.settleSign = ""  --userdata  type byteSlice
        end
    end
end


function game_ddz:startQdz()
    
    self.gamestate = GameStatusType.DeskState_Grab
    self.ConsensusState = ConsensusStateType.Sf_check
    self.firstqdzTurn, err = ge.FirstSeat()
    if (err ~= nil) then
        error ("Not have firstSeat"..err)
    end
    self.currentqdzTurn = self.firstqdzTurn

    local ms = gd:GetSeat(gd.myseat) 
    if (ms == nil) then
        error("myseat is nil")
    end

    local startinfo  = {} 
    startinfo.Turn = self.firstqdzTurn
    startinfo.SelfCard = {}
    startinfo.SelfCard.privateIndex = ms.privateIndex
    startinfo.SelfCard.privateCard =  ms.privateCard
    startinfo.DeskCard = {}
    startinfo.DeskCard.publicIndex = ms.publicIndex
    startinfo.DeskCard.publicCard = ms.publicCard

    ge.NotifyUI("StartInfo", startinfo)

    print(os.date("%Y/%m/%d %H:%M:%S ") .. "开始抢地主========开始位置:",self.firstqdzTurn, "====我的位置：", self.myseat)

    local fn = function()
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "Qdz Timeout .....")
        --发牌超时，提交公证
        ApplyNotary(NotaryNumber)
    end
    self.QdzTimer = timer.afterFunc(fn, 1000*35) 

end

-- UI 抢地主消息处理
function game_ddz:grabDz(op)
    if (self.myseat ~= self.currentqdzTurn) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "not you turn grab", self.myseat, self.currentqdzTurn)
        return 
    end

    local ms = self:GetSeat(self.myseat)
    if (ms == nil) then
        error("myseat is nil")
    end
    
    ms.grab = ms.grab + op
    ms.optimes = ms.optimes + 1 
    if (op == 1) then 
        --还没有人抢过地主，记住第一个抢地主的位置
        if (self.landlordSeat == -1) then
            self.lastqdzcurnTurn = self.myseat 
            self.multiple = 1
        else
            self.multiple = self.multiple * 2  
            if (self.multiple > self.maxmultiple) then 
                self.multiple = self.maxmultiple
            end
        end

        --地主位赋值
        self.landlordSeat = self.myseat
    end

    local grabInfo = {} 
    table.insert(grabInfo, self.myseat)
    table.insert(grabInfo, op)
    local jsongi = json.encode(grabInfo)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "Send grabInfo", jsongi)

    local gbData, err = rlp.Encode(grabInfo)
    if (err ~= nil) then
        error("RlpEncode err:"..err)
    end

    local ids = self:exceptIds(self.myseat)
    ge.Send(ids, 0, GrabDataCode, gbData)

    --所有人都说过话了，抢地主完成
    if (self:isOverGrab()) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "抢地主完成=========================地主：", self.landlordSeat)
        if self.QdzTimer ~= nil  then
            -- body
            self.QdzTimer:stop()
            self.QdzTimer = nil     
        end

        self:signGrabData()
    else
        if self.QdzTimer ~= nil  then
            -- body
            self.QdzTimer:reset(1000 * 35)
        else
            
            local fn = function()
                print(os.date("%Y/%m/%d %H:%M:%S ") .. "Qdz Timeout .....")
                --发牌超时，提交公证
                ApplyNotary(NotaryNumber)
            end
            self.QdzTimer = timer.afterFunc(fn, 1000*35) 
             
        end 

        local gbTninfo = self:GrabTurn(self.myseat, op)
        ge.NotifyUI("GrabTurnInfo", gbTninfo)
    end
end


--其他玩家抢地主消息
function game_ddz:grabDzHand(seat, op)     
    if (seat ~= self.currentqdzTurn) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "not you turn grab", seat, self.currentqdzTurn)
        return 
    end

    local gseat = self:GetSeat(seat)
    if (gseat == nil) then
        error("gseat is nil")
    end
    
    gseat.grab = gseat.grab + op 
    gseat.optimes = gseat.optimes + 1 
    if (op == 1) then 
        --还没有人抢过地主，记住第一个抢地主的位置
        if (self.landlordSeat == -1) then
            self.lastqdzcurnTurn = seat
            self.multiple = 1
        else 
            self.multiple = self.multiple * 2 
            if (self.multiple > self.maxmultiple) then 
                self.multiple = self.maxmultiple 
            end
        end

        --地主位赋值
        self.landlordSeat = seat
    end

     --所有人都说过话了，抢地主完成
    if (self:isOverGrab()) then  
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "抢地主完成=========================地主：", self.landlordSeat)
        if self.QdzTimer ~= nil  then
            -- body
            self.QdzTimer:stop()
            self.QdzTimer = nil     
        end

        self:signGrabData() 
    else 
        if self.QdzTimer ~= nil  then
            -- body
            self.QdzTimer:reset(1000 * 35)
        else
            local fn = function()
                print(os.date("%Y/%m/%d %H:%M:%S ") .. "Qdz Timeout .....")
                --发牌超时，提交公证
                ApplyNotary(NotaryNumber)
            end
            self.QdzTimer = timer.afterFunc(fn, 1000*35) 
             
        end 

        local gbTninfo = self:GrabTurn(seat, op)
        ge.NotifyUI("GrabTurnInfo", gbTninfo)
    end
end

function game_ddz:signGrabData()
    local grabData = {} 
    table.insert(grabData, self.firstqdzTurn)
    table.insert(grabData, self.landlordSeat) 
    table.insert(grabData, self.multiple)
    table.insert(grabData, self.hand)
    for i,v in ipairs(self.seats) do
        if (v.status == SeatStatusType.PLAYING) then
            local itemData = {}
            table.insert(itemData, v.id) 
            table.insert(itemData, v.grab)
            table.insert(itemData, v.optimes) 

            table.insert(grabData, itemData)
        end
    end 

    local bsdstr = json.encode(grabData)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "Send GrabState_Info:", bsdstr)

    local signData, err = rlp.Encode(grabData) 
    if (err ~= nil) then
        error("RlpEncode err:"..err)
    end 
    local signDataHash = signData:Hash()
    local sign = ge.Sign(signDataHash)

    local myseat = self:GetSeat(self.myseat)
    local ids = self:exceptIds(self.myseat)

    myseat.grabstateSignData = signData:toHexString()
    myseat.grabstateSignDataHash = signDataHash:toHexString()
    myseat.grabstateSign = sign:toHexString()
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "GrabSignData ===========+++++:", myseat.grabstateSignData, myseat.grabstateSignDataHash, myseat.grabstateSign)

    local GrabSignData = {}
    table.insert(GrabSignData, signDataHash:toHexString())
    table.insert(GrabSignData, sign:toHexString())
    table.insert(GrabSignData, ge:DeskID())
    table.insert(GrabSignData, myseat.id) 

    local ssdstr = json.encode(GrabSignData) 
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "GrabSignData Msg:", ssdstr)

    local gsdata, err = rlp.Encode(GrabSignData)
    if (err ~= nil) then
        err("RlpEncode err:"..err)
    end

    print(os.date("%Y/%m/%d %H:%M:%S ") .. "send GrabSignDataCode ===", #ids)

    ge.Send(ids, 0, GrabSignDataCode, gsdata)
    
    self:tryGrabCommitTimeOut(signDataHash:toHexString())
end

function game_ddz:VerificationGrabSign(rdata)
    local myseat = self:GetSeat(self.myseat)
    local sdseat = self:GetSeat(rdata.ID)

    print(os.date("%Y/%m/%d %H:%M:%S ") .. "Verification Grab Sign Start")
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "vgss ====", myseat or nil, sdseat or nil)

    if (myseat ~= nil and sdseat ~= nil) then
        if (myseat.grabstateSignDataHash ~= "" and myseat.grabstateSignDataHash ~= rdata.GbHash)  then
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "GrabState Hash is not equal...", myseat.grabstateSignDataHash, rdata.GbHash)
            return 
        end 

        -- local gbdh = byteSlice.new()
        -- gbdh:appendHexString(rdata.GbHash)
        -- local gbds = byteSlice.new() 
        -- gbds:appendHexString(rdata.Sign)
        -- sdseat.grabstateSignDataHash = rdata.GbHash
        -- sdseat.grabstateSign = rdata.Sign

        sdseat.grabstateSignDataHash = rdata.GbHash
        sdseat.grabstateSign = rdata.Sign
        local allsign = true 

        for i,v in ipairs(self.seats) do
            if (v.status == SeatStatusType.PLAYING and v.grabstateSign == "") then
                print(os.date("%Y/%m/%d %H:%M:%S ") .. "flag break=====", v.id, nil or v.grabstateSign)
                allsign = false
                break
            end
        end

        print(os.date("%Y/%m/%d %H:%M:%S ") .. "allsign flag ========", allsign)

        if (allsign == true) then
            --如果设置了定时器，先停止定时器。
            if (self.grabSignTimer ~= nil) then
                self.grabSignTimer:stop()
                self.grabSignTimer = nil     
            end

            --ge.UpdateConsensus() 
            print("ge.GetMsgListLen() = ", ge.GetMsgListLen())
            ge.UpdateConsensusEx(math.min(ge.GetMsgListLen(), 64))
            
            self.ConsensusState = ConsensusStateType.Bl_check 
            
            --saveGameState(gd) 

            if (self.landlordSeat == -1) then
                --  重新洗牌
                self:ShuffleCardReset()
                self.ReadyFlag = true
            else 
                --解密三张公共暗牌，开始出牌
                
                local seat = self:GetSeat(self.myseat)
                if (seat == nil) then
                    error("no seat")
                end

                ge.CheckCard(self.maxplays + 1, seat.publicIndex)
            end 

            --error(" 123")
            return
        end
    end
end

function game_ddz:tryGrabCommitTimeOut(datahash)
    for i,v in ipairs(self.seats) do
        print("v.id, self.myseat = ", v.id, self.myseat, v.status, v.grabstateSignDataHash)
        if ( v.id ~= self.myseat  and  v.status == SeatStatusType.PLAYING  and v.grabstateSignDataHash~= "") then
             if (datahash ~= v.grabstateSignDataHash) then
                --提交公证 待完善 
                self:ApplyNotary(NotaryNumber)

                return
            end
        end  
    end

    if self.myseat == 1 then
        --self:ApplyNotary(NotaryNumber)
    end

    local allsign = true 

    for i,v in ipairs(self.seats) do
        if (v.status == SeatStatusType.PLAYING and v.grabstateSignDataHash == "") then
            allsign = false
            break
        end
    end

    if (allsign == true) then
        
        print("ge.GetMsgListLen() = ", ge.GetMsgListLen(), math.min(ge.GetMsgListLen(), 64))
        ge.UpdateConsensusEx(math.min(ge.GetMsgListLen(), 64))
        --ge.UpdateConsensus() 
        self.ConsensusState = ConsensusStateType.Bl_check
           
        if (self.landlordSeat == -1) then
            --  重新洗牌
            self:ShuffleCardReset() 

            self.ReadyFlag = true 
        else 
            --解密三张公共暗牌，开始出牌
            local seat = self:GetSeat(self.myseat)
            if (seat == nil) then
                error("no seat")
            end

            ge.CheckCard(self.maxplays + 1, seat.publicIndex)

        end

        return
    end

    --else 设定超时
    local fn = function()
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "GrabSign TimeOut")
        --提交公证，待完善
        self:ApplyNotary(NotaryNumber)
    end 
    --加定时器
    self.grabSignTimer = timer.afterFunc(fn, 30 *1000)
end

function game_ddz:ShuffleCardReset()
    
    self:shuffleStateUninit() 
    ge.ResetShuffleState()  

    -- local sigAndData = byteSlice:new() 
    -- local sigdata = byteSlice:new()
    
    -- for i,v in ipairs(self.seats) do
    --     if (v.status == SeatStatusType.PLAYING  and v.grabstateSign ~= nil) then
    --                  
    --         sigAndData:appendString(v.grabstateSign:toString())
    --         if (v.id == self.myseat) then
    --                     
    --             sigdata:appendString(v.grabstateSignData:toString())
    --         end 
    --         --resetsign 
    --         v.grabstateSignData = nil 
    --         v.grabstateSignDataHash = nil
    --         v.grabstateSign = nil  
    --     end    
    -- end
    
    -- sigAndData:appendString(sigdata:toString())  
    -- local hstr = sigAndData:toHexString()
    -- print(hstr) 
    local reshuffleinfo = {} 
    reshuffleinfo.hand = self.hand 
    ge.NotifyUI("ReshuffleInfo", reshuffleinfo)

    print(os.date("%Y/%m/%d %H:%M:%S ") .. "room reshuffle =======================")
   
    rCtr.tc.Transact("reshaff", self.hand) 

end

function game_ddz:GameReset(nexthand)
    self:gameStateUninit() 
    ge.GameReset() 
    self.nexthand = nexthand 
    local ErrHandfn  = function(errstr)
        if errstr ~= nil then
            -- 如果后台洗牌发送错误， 通知UI洗牌错误
            rCtr:leaveTable()
        end
    end

    ge.ShuffleCardBackStage(54, self.playseats,self.maxplays, self.nodelist, false, nexthand, ErrHandfn)
end



function game_ddz:TryStartPlayCard()
    local ms = self:GetSeat(self.myseat)
    if (ms == nil) then
        error("myseat == nil")
    end

    local playCardflag = true 
    for i,v in ipairs(self.seats) do
        if (v.status == SeatStatusType.PLAYING and #v.publicCard ~= #v.publicIndex) then
            playCardflag = false
        end
    end

    if (playCardflag == true and self.landlordSeat ~= -1) then
        for i,v in ipairs(self.seats) do
            if (#v.privateCard == 0) then
                for i=1,#v.privateIndex do
                    table.insert(v.privateCard, -1)
                end
            end 

            if (v.id == self.landlordSeat) then
                for ii,vv in ipairs(ms.publicCard) do 
                    --是地主 把公共牌插到最后
                    table.insert(v.privateIndex, ms.publicIndex[ii])
                    table.insert(v.privateCard, vv)
                         
                end
            end
        end

        for i,v in ipairs(self.seats) do
            print("牌点列表初始化完成====", #v.privateIndex, #v.privateCard)
        end

        self.currentPlayCardTurn = self.landlordSeat --当前出牌位置
        self.currentPlayCardType = {}
        table.insert(self.currentPlayCardType, PlayMethondType.Play)

        local startPlayCardInfo = {} 
        startPlayCardInfo.LandlordSeat = self.landlordSeat 
        startPlayCardInfo.FinalMultiple = self.multiple
        startPlayCardInfo.DeskCard = {} 
        startPlayCardInfo.DeskCard.publicIndex = ms.publicIndex
        startPlayCardInfo.DeskCard.publicCard = ms.publicCard 

        self.gamestate = GameStatusType.DeskState_Play
        ge.NotifyUI("StartPlayCardInfo", startPlayCardInfo) 

        print(os.date("%Y/%m/%d %H:%M:%S ") .. "开始出牌========地主位置:",self.landlordSeat, "====我的位置：", self.myseat)
        self:printCard()

        local playCardInfo = {} 
        playCardInfo.CurrentPlay = {} 
        -- playCardInfo.CurrentPlay.Seat = seat
        -- playCardInfo.CurrentPlay.Index = index
        -- playCardInfo.CurrentPlay.Card = card
    
        playCardInfo.Result = {} 
        playCardInfo.Result = self.result

        playCardInfo.CurrentMultiple = self.multiple
        playCardInfo.NextTurn = self.landlordSeat
        
        if (self.landlordSeat == self.myseat) then
            playCardInfo.IsMyTurn = true 
        else
            playCardInfo.IsMyTurn = false 
        end 
    
        local pcistr = json.encode(playCardInfo)
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "Play==========", pcistr)
    
        ge.NotifyUI("PlayCardInfo", playCardInfo) 
        
        local fn = function()
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "Play Card Timeout .....")
            --发牌超时，提交公证
            ApplyNotary(NotaryNumber)
        end
        self.playCardTimer = timer.afterFunc(fn, 1000*35) 

    end
end

function game_ddz:playCard(index, card)

    local presultinfo = {state = 0, info = ""}

    if (self.currentPlayCardTurn ~= self.myseat) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "not playCardTurn ", self.currentPlayCardTurn, self.myseat)
        presultinfo.state = 1
        presultinfo.info = "not playCardTurn,  curnt: "..tostring(self.currentPlayCardTurn) 

        return presultinfo
    end

    local op = PlayMethondType.Pass

    if (#index ~=0 and #card ~=0) then
        op = PlayMethondType.Play
    end

    if (self:isAllownOP(op) == false) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "not Allown op")

        presultinfo.state = 1
        presultinfo.info = "not Allown op "
        return presultinfo
    end

    local gseat = self:GetSeat(self.myseat)
    if (gseat == nil) then
        error("gseat is nil")
    end

    if (op == PlayMethondType.Pass) then 

        if (self.playCardTimer ~= nil ) then
            -- body
            self.playCardTimer:reset(1000*35) 
        else 
            local fn = function()
                print(os.date("%Y/%m/%d %H:%M:%S ") .. "Play Card Timeout .....")
                --发牌超时，提交公证
                ApplyNotary(NotaryNumber)
            end
            self.playCardTimer = timer.afterFunc(fn, 1000*35)     
        end
        --不出  
        --保存出的牌
        self:keepRoundItemCard(gseat, index, card)

        self.passNumber = self.passNumber + 1
        
        self:sendPlayInfo(op, index, card) 

        if (self.passNumber == 2) then
            -- 重新一轮
            self.result = {Type = ddz.HandPatternsType.EVERYCARDTYPE, Max = 3, Size = 0, Value = 3}
            self:keepRoundCard()

            self.currentPlayCardType = {}
            table.insert(self.currentPlayCardType, PlayMethondType.Play)
        else 
            self.currentPlayCardType = {}
            table.insert(self.currentPlayCardType, PlayMethondType.Play)
            table.insert(self.currentPlayCardType, PlayMethondType.Pass)
        end

        local playCardInfo =  self:playTurn(self.myseat, index, card, false) 
        ge.NotifyUI("PlayCardInfo", playCardInfo)

        self:printCard() 

    else
        --出牌
        if (self:isCardofPlay(self.myseat, index) == false) then
            
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "card is not of seat:", index, self.myseat)
          
            presultinfo.state = 1
            presultinfo.info = "card is not of seat:" .. tostring(self.myseat)

            return presultinfo
        end
       
        local result = ddz:judgePokerType(card) 
        
        if (self:isCanPlay(result) == false) then
            -- boy
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "POKERS_NOT_MATCHING ", self.myseat, result.Type)
            presultinfo.state = 1
            presultinfo.info = "POKERS_NOT_MATCHING type:" .. tostring(result.Type)
            return presultinfo
        end

        
        self.result = result
        if (result.Type ==ddz.HandPatternsType.ROCKET  or result.Type ==ddz.HandPatternsType.BOMB) then
            -- 炸弹和火箭倍数乘2
            self.multiple = self.multiple * 2 
            if (self.multiple > self.maxmultiple)then 
                self.multiple = self.maxmultiple 
            end
        end
        self.passNumber = 0 
         --保存出的牌
        self:keepRoundItemCard(gseat, index, card)

        self:sendPlayInfo(op, index, card) 

        if (self:isAllInPublicCard(card) == false) then
            -- 不全都是公共牌才发送密钥
            ge.CheckCard(self.myseat, index)
        end  
       
        gseat.playCardNum = gseat.playCardNum + #index
        for i,v in ipairs(index) do
            table.insert(gseat.playIndex, v)
        end
       
        if (gseat.playCardNum == #gseat.privateCard) then
           -- 牌出完，游戏结束 
           if (self.playCardTimer ~= nil ) then
                -- body
                self.playCardTimer:stop() 
           end

           self:keepRoundCard() 
           print(os.date("%Y/%m/%d %H:%M:%S ") .. "==========游戏结束==============胜利玩家:", self.myseat) 
           self.winseat = self.myseat 

           local playCardInfo = self:playTurn(self.myseat, index, card, true)
           ge.NotifyUI("PlayCardInfo", playCardInfo)

           self:printCard() 
           self.gamestate = GameStatusType.DeskState_Over

           self:showSurplusCard(self.winseat)
        else
            if (self.playCardTimer ~= nil ) then
                -- body
                self.playCardTimer:reset(1000*35) 
            else 
                local fn = function()
                    print(os.date("%Y/%m/%d %H:%M:%S ") .. "Play Card Timeout .....")
                    --发牌超时，提交公证
                    ApplyNotary(NotaryNumber)
                end
                self.playCardTimer = timer.afterFunc(fn, 1000*35)     
            end


            self.currentPlayCardType = {}
            table.insert(self.currentPlayCardType, PlayMethondType.Play)
            table.insert(self.currentPlayCardType, PlayMethondType.Pass)
            local playCardInfo = self:playTurn(self.myseat, index, card, false)
            ge.NotifyUI("PlayCardInfo", playCardInfo)

            self:printCard() 
        end
    end

    presultinfo.info = index 
    return presultinfo
end

function game_ddz:playCardHand(seat, index, card)
    if (self.currentPlayCardTurn ~= seat) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "not playCardTurn ", self.currentPlayCardTurn, seat)
        return    
    end
    
    local op = PlayMethondType.Pass

    if (#index ~=0 and #card ~=0) then
        op = PlayMethondType.Play
    end

    if (self:isAllownOP(op) == false) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "not Allown op")
        return
    end

    local gseat = self:GetSeat(seat)
    if (gseat == nil) then
        error("gseat is nil")
    end

    if (op == PlayMethondType.Pass) then
        --不出  
        --保存出的牌
        if (self.playCardTimer ~= nil ) then
            -- body
            self.playCardTimer:reset(1000*35) 
        else 
            local fn = function()
                print(os.date("%Y/%m/%d %H:%M:%S ") .. "Play Card Timeout .....")
                --发牌超时，提交公证
                ApplyNotary(NotaryNumber)
            end
            self.playCardTimer = timer.afterFunc(fn, 1000*35)     
        end

        self:keepRoundItemCard(gseat, index, card)

        self.passNumber = self.passNumber + 1 
        
        if (self.passNumber == 2) then
            -- 重新一轮
            self.result = {Type = ddz.HandPatternsType.EVERYCARDTYPE, Max = 3, Size = 0, Value = 3}
            self:keepRoundCard()  
            self.currentPlayCardType = {}
            table.insert(self.currentPlayCardType, PlayMethondType.Play)
        else 
            self.currentPlayCardType = {}
            table.insert(self.currentPlayCardType, PlayMethondType.Play)
            table.insert(self.currentPlayCardType, PlayMethondType.Pass)
        end

        local playCardInfo = self:playTurn(seat, index, card, false)
        ge.NotifyUI("PlayCardInfo", playCardInfo)

        self:printCard() 
    else
        --出牌
        --不要相信发过来的牌点，等解密出来，再处理
        if (self:isCardofPlay(seat, index) == false) then
            
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "car is not of seat:", index, seat)
            return
        end

        if (self:isAllInPublicCard(card) == false) then
            -- 不全是公共牌才发送密钥
            ge.CheckCard(seat, index)
        else 
            --直接处理出牌逻辑，不用再次解锁
            self:realPlayCardHand(seat, index, card)
        end
    end
end

function game_ddz:realPlayCardHand(seat, index, card)
    local gseat = self:GetSeat(seat)
    if (gseat == nil) then
        error("gseat is nil")
    end

    local result = ddz:judgePokerType(card) 
    if (self:isCanPlay(result) == false) then
        -- boy
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "POKERS_NOT_MATCHING ", seat, result.Type)
        return 
    end

    self.result = result
    if (result.Type ==ddz.HandPatternsType.ROCKET  or result.Type ==ddz.HandPatternsType.BOMB) then
        -- 炸弹和火箭倍数乘2
        self.multiple = self.multiple * 2 
        if (self.multiple > self.maxmultiple)then 
            self.multiple = self.maxmultiple 
        end
    end
    self.passNumber = 0 

    --保存出的牌
    self:keepRoundItemCard(gseat, index, card)

    gseat.playCardNum = gseat.playCardNum + #index
    for i,v in ipairs(index) do
        table.insert(gseat.playIndex, v)
    end

    print(os.date("%Y/%m/%d %H:%M:%S ") .. "realPlayCardHand===", #index)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "gseat.playCardNum======", gseat.playCardNum)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "#gseat.privateCard", #gseat.privateCard)

    if (gseat.playCardNum == #gseat.privateCard) then
        -- 牌出完，游戏结束  
        if (playCardTimer ~= nil ) then
            -- body
            self.playCardTimer:stop() 
        end

        self:keepRoundCard() 
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "==========游戏结束==============胜利玩家:", seat) 
        self.winseat = seat 

        local playCardInfo = self:playTurn(seat, index, card, true)
        ge.NotifyUI("PlayCardInfo", playCardInfo) 

        self:printCard()
        self.gamestate = GameStatusType.DeskState_Over

        self:showSurplusCard(self.winseat)
    else 
        if (self.playCardTimer ~= nil ) then
            -- body
            self.playCardTimer:reset(1000*35) 
        else 
            local fn = function()
                print(os.date("%Y/%m/%d %H:%M:%S ") .. "Play Card Timeout .....")
                --发牌超时，提交公证
                ApplyNotary(NotaryNumber)
            end
            self.playCardTimer = timer.afterFunc(fn, 1000*35)     
        end

        self.currentPlayCardType = {}
        table.insert(self.currentPlayCardType, PlayMethondType.Play)
        table.insert(self.currentPlayCardType, PlayMethondType.Pass)

        local playCardInfo = self:playTurn(seat, index, card, false)
        ge.NotifyUI("PlayCardInfo", playCardInfo)

        self:printCard() 
    end
end

function game_ddz:playTurn(seat, index, card, isover)  
    local nseat, err = ge.NextSeat(seat)
    if (err ~= nil) then
        error ("Seat == nil "..err)
    end

    ---游戏结束，没有下一个可出牌的位置
    if (isover == true) then
        nseat = -1 
    end

    local playCardInfo = {} 
    playCardInfo.CurrentPlay = {} 
    playCardInfo.CurrentPlay.Seat = seat
    playCardInfo.CurrentPlay.Index = index
    playCardInfo.CurrentPlay.Card = card

    playCardInfo.Result = {} 
    playCardInfo.Result = self.result
    playCardInfo.CurrentMultiple = self.multiple
    playCardInfo.NextTurn = nseat 
    
    self.currentPlayCardTurn = nseat 

    if (nseat == self.myseat) then
        playCardInfo.IsMyTurn = true 
    else
        playCardInfo.IsMyTurn = false 
    end 

    local pcistr = json.encode(playCardInfo)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "Play==========", pcistr) 

    return playCardInfo
    --ge.NotifyUI("PlayCardInfo", playCardInfo)
end

function game_ddz:isCanPlay(result)  
    local selfreusltstr = json.encode(self.result)
    local resultstr = json.encode(result)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "self reuslt:", selfreusltstr)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "result:", resultstr) 

    if (self.result ~= nil) then
        if (self.result.Type ~= ddz.HandPatternsType.EVERYCARDTYPE) then
            if (result.Type ~= self.result.Type) then
                --略过火箭和炸弹
                if (result.Type ~= ddz.HandPatternsType.ROCKET) then
                    if (result.Type ~= ddz.HandPatternsType.BOMB) then
                        return false 
                    end
                end
            end
           
            --当牌型一致的时候
            if (result.Type == self.result.Type) then
                if (result.Type == ddz.HandPatternsType.SINGLESTRAIGHT or
                result.Type == ddz.HandPatternsType.DOUBLESTRAIGHT or
                result.Type == ddz.HandPatternsType.THREESTRAIGHT or 
                result.Type == ddz.HandPatternsType.THREESTRAIGHTTAKESINGLE or
                result.Type == ddz.HandPatternsType.THREESTRAIGHTTAKEDOUBLE) then
                    if ((result.Size ~= self.result.Size) or (result.Max <= self.result.Max)) then
                        return false 
                    end
                else 
                    -- 其他的类型判断值是否不大
                    if (result.Value <= self.result.Value) then
                        return false 
                    end
                end
            end
        end
    end

    if (result.Type < 15) then
        return true 
    else
        return false
    end
end

function game_ddz:Settle(seat)
    -- body

    if settled then
    --    return
    end
    settled = true
    
    local GameSettleData = {}
    table.insert(GameSettleData, DDZRoomManagerAddr)
    table.insert(GameSettleData, self.tableid)
    table.insert(GameSettleData, self.hand) 

    local list = {} 
    if (seat == self.landlordSeat) then
        -- 地主赢
        local gdb = {} 
        table.insert(gdb, seat)
        table.insert(gdb, 1)
        table.insert(gdb, 2 * self.multiple * self.base)
        table.insert(list, gdb)

        local  ids = self:exceptIds(seat)
        for i,v in ipairs(ids) do
            local gdb = {} 
            table.insert(gdb, v)
            table.insert(gdb, 0)
            table.insert(gdb, self.multiple * self.base)
            table.insert(list, gdb)
        end
    else 
        --农民赢
        local gdb = {} 
        table.insert(gdb, seat)
        table.insert(gdb, 1)
        table.insert(gdb, self.multiple * self.base) 
        table.insert(list, gdb)

        local ids = self:exceptIds(seat) 

        for i,v in ipairs(ids) do
            if (v == self.landlordSeat) then
                local gdb = {} 
                table.insert(gdb, v)
                table.insert(gdb, 0)
                table.insert(gdb, 2 * self.multiple * self.base)
                table.insert(list, gdb)
            else 
                local gdb = {} 
                table.insert(gdb, v)
                table.insert(gdb, 1)
                table.insert(gdb, self.multiple * self.base) 
                table.insert(list, gdb)
            end
        end
    end 

    table.insert(GameSettleData, list)
    self.settlelist = list 

    local gsdstr = json.encode(GameSettleData)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "settleData$$$$$$$$$$", gsdstr)

    local signData, err = rlp.Encode(GameSettleData) 
    if (err ~= nil) then
        err("RlpEncode err:"..err)
    end

    local myseat = self:GetSeat(self.myseat)
    if (myseat == nil) then
        error("seat == nil ")
    end
    local ids = self:exceptIds(self.myseat)

    signDataHash = signData:Hash()
    sign = ge.Sign(signDataHash)

    myseat.settleSignData = signData:toHexString() --userdata  type byteSlice
    myseat.settleSignDataHash = signDataHash:toHexString() --userdata  type byteSlice
    myseat.settleSign = sign:toHexString()  --userdata  type byteSlice

    local SettleSignData = {}
    table.insert(SettleSignData, signDataHash:toHexString())
    table.insert(SettleSignData, sign:toHexString())
    table.insert(SettleSignData, ge:DeskID())
    table.insert(SettleSignData, myseat.id)

    local ssdstr = json.encode(SettleSignData) 
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "SettleSignData Msg:", ssdstr)

    local ssdddata, err = rlp.Encode(SettleSignData)
    if (err ~= nil) then
        err("RlpEncode err:"..err)
    end

    ge.Send(ids, 0, SettleSignDataCode, ssdddata)
    self:TrySettleCommitTimeOut(signDataHash:toHexString())
end 

function game_ddz:TrySettleCommitTimeOut(datahash)
    for i,v in ipairs(self.seats) do
        if (v.id ~= self.myseat  and  v.status == SeatStatusType.PLAYING  and v.settleSignDataHash~= "") then
            if (datahash ~= v.settleSignDataHash) then
                --提交公证 待完善 
                self:ApplyNotary(NotaryNumber)

                return
            end
        end  
    end

    local allsign = true 

    for i,v in ipairs(self.seats) do
        if (v.status == SeatStatusType.PLAYING   and v.settleSign == "") then
            allsign = false
            break
        end
    end

    if (allsign == true) then
        --结算，提交到合约 待完善
        --ge.UpdateConsensus() 
        --self.ConsensusState = ConsensusStateType.Rf_check
        
        local sigAndData = byteSlice:new() 
        local sigdata = byteSlice:new()

        for i,v in ipairs(self.seats) do
            if (v.status == SeatStatusType.PLAYING and v.settleSign ~= "") then
                sigAndData:appendHexString(v.settleSign)
                if (v.id == self.myseat) then
                    sigdata:appendHexString(v.settleSignData)
                end
            end    
        end

        sigAndData:appendString(sigdata:toString())
    
        rCtr.tc.Transact("playerSettle", sigAndData, false)

        local hstr = sigAndData:toHexString()
        print(hstr)

        self:GameOverToUI() 
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "Settle Result Commit // Game Over.....*************\n")
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "table id", self.tableid)
        return
    end

    --else 设定超时
    local fn = function()
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "SettleSign TimeOut")
        --提交公证，待完善
        self:ApplyNotary(NotaryNumber)
    end 
    --加定时器
    self.settleSignTimer = timer.afterFunc(fn, 30 *1000)
end 

function game_ddz:VerificationSettleSign(rdata)
    
    local myseat = self:GetSeat(self.myseat)
    local sdseat = self:GetSeat(rdata.ID)

    print(os.date("%Y/%m/%d %H:%M:%S ") .. "Verification Settle Sign Start")

    if (myseat ~= nil and sdseat ~= nil) then
        if (myseat.settleSignDataHash ~= "" and myseat.settleSignDataHash ~= rdata.SeHash)  then
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "SettleState Hash is not equal...", myseat.settleSignDataHash, rdata.SeHash)
            return 
        end 

        -- local ssdh = byteSlice.new()
        -- ssdh:appendHexString(rdata.SeHash)
        -- local ssds = byteSlice.new() 
        -- ssds:appendHexString(rdata.Sign)
        -- sdseat.settleSignDataHash = ssdh
        -- sdseat.settleSign = ssds

        sdseat.settleSignDataHash = rdata.SeHash
        sdseat.settleSign = rdata.Sign

        local allsign = true 

        for i,v in ipairs(self.seats) do
            if (v.status == SeatStatusType.PLAYING  and v.settleSign == "") then
                allsign = false
                break
            end
        end

        if (allsign == true) then
            --如果设置了定时器，先停止定时器。
            if (self.settleSignTimer ~= nil) then
                self.settleSignTimer:stop()
                self.settleSignTimer = nil     
            end

            --结算，提交到合约 待完善 
            --ge.UpdateConsensus() 
            --self.ConsensusState = ConsensusStateType.Rf_check 
            local sigAndData = byteSlice:new() 
            local sigdata = byteSlice:new()
    
            for i,v in ipairs(self.seats) do
                if (v.status == SeatStatusType.PLAYING and v.settleSign ~= "") then
                    sigAndData:appendHexString(v.settleSign)
                    if (v.id == self.myseat) then
                        sigdata:appendHexString(v.settleSignData)
                    end
                end    
            end
    
            sigAndData:appendString(sigdata:toString())  
            local hstr = sigAndData:toHexString()
            print(os.date("%Y/%m/%d %H:%M:%S ") ..hstr) 
      
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "room settle =======================")
            --self.roomManagercontrac.Transact("playerSettle", sigAndData)
            rCtr.tc.Transact("playerSettle", sigAndData)

            self:GameOverToUI() 
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "Settle Result Commit // Game Over.....*************\n")
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "table addr", self.tableid)
            return
        end
    end
end

function game_ddz:cursor2Card(seat, cursor)
    local x = 0 

    for i,v in ipairs(seat.privateIndex) do
        if (v == cursor) then
            x = i 
            break 
        end
    end

    if (x ~= 0) then
        local card = seat.privateCard[x] 
        return card
    end

    return -1 
end

function game_ddz:trySettle()
    local settleflag = true 

    for i,v in ipairs(self.remain) do

        local st = self:GetSeat(v.seat) 
        for ii,vv in ipairs(v.index) do
            local c = self:cursor2Card(st, vv) 
            if (c == -1) then
                --等于-1说明还没有解锁
                settleflag = false 
                break 
            end

        end
        
        if (settleflag == false) then
            break 
        end
    end

    print(os.date("%Y/%m/%d %H:%M:%S ") .. "settleflag =========", settleflag)
    if (settleflag == true) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "win seat=============", self.winseat)
        self:Settle(self.winseat) 

    end
end

function game_ddz:GameOverToUI()
    local gameOverInfo = {}
    gameOverInfo.Win = self.winseat
    gameOverInfo.Base = self.base
    gameOverInfo.Multiple = self.multiple
    gameOverInfo.SettleList = self.settlelist
    gameOverInfo.RemainCard = {}

    local remainCard = {}
    if self.remain ~= nil then
        for i,v in ipairs(self.remain) do

            local item = {Seat = v.seat, Index = v.index, Card = {}}
            local st = self:GetSeat(v.seat) 
        
            for ii,vv in ipairs(v.index) do
                print(os.date("%Y/%m/%d %H:%M:%S "), ii,vv)
                local c = self:cursor2Card(st, vv)
                if (c == -1) then
                    --等于-1说明还没有解锁
                    error("car is unlock")
                end
                table.insert(item.Card, c)

            end

            table.insert(remainCard, item)
        end
    end

    gameOverInfo.RemainCard = remainCard 

    self:updateBalance() 

    ge.NotifyUI("GameOverInfo", gameOverInfo)
end

function game_ddz:updateBalance()
    for i, v in ipairs(self.settlelist) do
        for ii, vv in ipairs(self.seats) do
            if (v[1] == vv.id) then
                if (v[2] == 0) then
                    vv.balance = vv.balance - v[3]
                else
                    vv.balance = vv.balance + v[3]
                end 
            end
        end
    end
end

function game_ddz:keepRoundItemCard(gseat, index, card)
    --lua rlp解码数组要确定长度 ，index, card 长度不确定 这里转换成字符串 
    local rounditem = {}
    local indexstr = ""
    for i,v in ipairs(index) do
        if (i ~= #index) then
            indexstr = indexstr .. tostring(v) .. ","
        else
            indexstr = indexstr .. tostring(v)
        end
    end
    table.insert(rounditem, indexstr)

    local cardstr = ""
    for i,v in ipairs(card) do
        if (i ~= #card) then
            cardstr = cardstr .. tostring(v) .. ","
        else
            cardstr = cardstr .. tostring(v)
        end
    end
    table.insert(rounditem, cardstr)
    table.insert(gseat.currentRoundCard, rounditem)
end


function game_ddz:keepRoundCard()
    for i,v in ipairs(self.seats) do
        table.insert(v.allRoundCard, v.currentRoundCard) 
        v.currentRoundCard = {} 
    end
end

--给其他玩家发密钥
function game_ddz:showDownCard(seats, index)
    if (#index == 0) then
        error("index length is 0")
    end

    for i,v in ipairs(seats) do
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "showdown:", v)
        ge.CheckCard(v, index)
    end
end


function game_ddz:sendPlayInfo(op, index, card)
    local playinfo = {} 

    table.insert(playinfo, self.myseat)
    table.insert(playinfo, op)

    --lua rlp解码数组要确定长度 ，index, card 长度不确定 这里转换成字符串
    local indexstr = ""
    for i,v in ipairs(index) do
        if (i ~= #index) then
            indexstr = indexstr ..tostring(v)..","
        else
            indexstr = indexstr..tostring(v)
        end
    end
    table.insert(playinfo, indexstr)

    local cardstr = ""
    for i,v in ipairs(card) do
        if (i ~= #card) then
            cardstr = cardstr..tostring(v)..","
        else
            cardstr = cardstr..tostring(v)
        end
    end
    table.insert(playinfo, cardstr)

    local jsongi = json.encode(playinfo)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "Send playInfo", jsongi)

    local psData, err = rlp.Encode(playinfo)
    if (err ~= nil) then
        error("RlpEncode err:"..err)
    end

    local ids = self:exceptIds(self.myseat)
    ge.Send(ids, 0, PlayDataCode, psData)
end

--是否是该玩家的牌
function game_ddz:isCardofPlay(seat, index)
    local gseat = self:GetSeat(seat)
    if (gseat == nil) then
        error("gseat is nil")
    end

    local seatstr = json.encode(seat)
    local privateIndexstr = json.encode(gseat.privateIndex)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "seat:", seatstr)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "privateIndex:", privateIndexstr)

    for i,v in ipairs(index) do
        local flag = false 
        for ii,vv in ipairs(gseat.privateIndex) do
            if (v == vv) then
                flag = true 
                break 
            end
        end
        if (flag ==false) then
            return false 
        end
    end
    
    return true 

end

function game_ddz:isAllownOP(op)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "op", op)
    for i=1, #self.currentPlayCardType do
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "cpct====:",self.currentPlayCardType[i])
    end

    for i,v in ipairs(self.currentPlayCardType) do
        if (op == v) then
            return true 
        end
    end

    return false  
end


function game_ddz:isOverGrab()
     
    for i,v in ipairs(self.seats) do
        if (v.status == SeatStatusType.PLAYING  and v.optimes == 0) then
            return false
        end
    end
    
    if (self.lastqdzcurnTurn ~= -1) then --有抢过地主
        local gseat = self:GetSeat(self.lastqdzcurnTurn)
        if (gseat == nil) then
            error("gseat is nil")
        end
        --第一个叫地主的位置，还有抢地主的机会
        if (self.landlordSeat ~= self.lastqdzcurnTurn and gseat.optimes ~= 2) then
            return false
        end
    end
    
    return true
end
  
function game_ddz:GrabTurn(seat, op)
    local nseat, err = ge.NextSeat(seat)
    if (err ~= nil) then
        error("Seat == nil "..err)
    end

    local nseatValue = self:GetSeat(nseat)
    if (nseatValue == nil) then
        error("gseat is nil")
    end

    while(true)do
        if (nseatValue.optimes == 0 or (nseatValue.optimes == 1 and nseatValue.grab ~= 0)) then
            break 
        else
            nseat, err = ge.NextSeat(nseat)
            nseatValue = self:GetSeat(nseat)
            if (nseatValue == nil) then
                error("gseat is nil")
            end
        end
    end

    self.currentqdzTurn = nseat  --当前抢地主的位置

    local gbTninfo = {}
    gbTninfo.Grab = {}
    gbTninfo.Grab.ID = seat
    gbTninfo.Grab.OP = op
    gbTninfo.CurnSeat = nseat
    gbTninfo.Multiple = self.multiple
    --没人抢过
    if (self.landlordSeat == -1) then
        gbTninfo.CurnOPName = 0 --叫地主
    else
        gbTninfo.CurnOPName = 1 --抢地主
    end

    if (nseat == self.myseat) then
        gbTninfo.IsMyTurn = true
    else
        gbTninfo.IsMyTurn = false
    end
    --ge.NotifyUI("GrabTurnInfo", gbTninfo)

    return gbTninfo 
end

function game_ddz:exceptIds(seat)
    local ids = {}
    if (type(seat) == "number") then
        for i, v in ipairs(self.seats) do
            if (v.status == SeatStatusType.PLAYING and v.id ~= seat) then
                table.insert(ids, v.id)
            end
        end
        return ids
    elseif(type(seat) == "table")  then
        local fn = function(value)
            
            for i,v in ipairs(seat) do
                if (value == v) then
                    return false 
                end
            end

            return true
        end

        for i,v in ipairs(self.seats) do
            if (v.status == SeatStatusType.PLAYING and fn(v) == true) then
                table.insert(ids, v)
            end
        end

        return ids
    end
end

function game_ddz:isLastSeat(seat)
    local seatSortFun = function(a, b)
        return a.id < b.id
    end
    table.sort(self.seats, seatSortFun)

    local lastseat = -1 
    for i, v in ipairs(self.seats) do
        if (v.status == SeatStatusType.PLAYING) then
            lastseat = v.id
        end
    end

    return seat == lastseat
end

function game_ddz:IsDealOver() 
    for i, v in ipairs(self.seats) do
        print(os.date("%Y/%m/%d %H:%M:%S "), self.myseat, "deal print=====:",v.id, #v.privateIndex, #v.privateCard, #v.publicIndex, #v.publicCard)
        if (v.id == self.myseat) then
            if (v.status == SeatStatusType.PLAYING and (#v.privateCard ~= 17 or #v.publicIndex ~=3)) then
                print(os.date("%Y/%m/%d %H:%M:%S "), self.myseat, "deal print=====return:",v.id, #v.privateIndex, #v.privateCard, #v.publicIndex, #v.publicCard)
                return false
            end
        else
            if (v.status == SeatStatusType.PLAYING and (#v.privateIndex ~= 17 or #v.publicIndex ~=3)) then 
                print(os.date("%Y/%m/%d %H:%M:%S ") , self.myseat, "deal print=====return:",v.id, #v.privateIndex, #v.privateCard, #v.publicIndex, #v.publicCard)
                return false 
            end
        end
    end

    return true 
end

--检查出的牌是否全是公共牌，公共牌已经全部解锁，不用再次解锁
function game_ddz:isAllInPublicCard(cards)
    local ms = self:GetSeat(self.myseat)
    if (ms == nil) then
        error("myseat == nil")
    end

    for i, v in pairs(cards) do
        local  flag = false 
        for ii, vv in ipairs(ms.publicCard) do
            if (v == vv) then
                flag = true
            end
        end

        if (flag == false) then
            return false
        end
    end 
    return true 
end

function game_ddz:showSurplusCard(winseat)
    local remain = {} 
    for i, v in ipairs(self.seats) do
        if (v.status == SeatStatusType.PLAYING and v.id ~= winseat) then
            local item = {seat = v.id, index = {}}
            for ii, vv in ipairs(v.privateIndex) do
                local flag = false
                for jj, pv in ipairs(v.playIndex) do
                    if (vv == pv) then
                        flag = true 
                        break 
                    end
                end 

                if (flag == false) then
                    
                    table.insert(item.index, vv)
                end
            end
            table.insert(remain, item)
        end   
    end 

    for i,v in ipairs(remain) do
        ge.CheckCard(v.seat, v.index)
    end

    --保存剩余的牌标 
    self.remain = remain 

    --可能剩余的牌这边已经都解密，可以尝试结算了
    self:trySettle()
end

function game_ddz:printCard()
    local ms = self:GetSeat(self.myseat)
    if (ms == nil) then
        error("myseat == nil")
    end

    local indexstr = ""
    for i, v in ipairs(ms.privateIndex) do
        if (i ~= #ms.privateIndex) then
            indexstr = indexstr .. tostring(v) .. ","
        else
            indexstr = indexstr .. tostring(v)
        end
    end
   
    local cardstr = ""
    for i, v in ipairs(ms.privateCard) do
        if (i ~= #ms.privateCard) then
            cardstr = cardstr .. tostring(v) .. ","
        else
            cardstr = cardstr .. tostring(v)
        end
    end

    print(os.date("%Y/%m/%d %H:%M:%S ") .. "==============牌面=====================")
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "index:" .. indexstr)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "card:" .. cardstr)
end

function game_ddz:recoverSeats(selfaddr, tableid)
    rCtr.curTable = tableid 

    local players = rCtr:playersinfo()
    local tbInfo, currentHand = rCtr:tableinfo() 
    local playSeats = {}
    for i, v in ipairs(players) do
        print(i, v)
        local ns = st.new(v.Pos, v.Amount, v.PlayerAddr)
        ns.status = v.Status

        table.insert(self.seats, ns)

        if (v.PlayerAddr == selfaddr) then
            self.myseat = v.Pos
        end

        local naddr = newAddress(v.PlayerAddr)
        --isself为true会连接到inter,这里都为fasle,先不连接inter
        ge.Sit(v.Pos, false, tableid, naddr, {}, false)

        --Sit在go中状态为play
        ge.UpdateState(v.Pos) 
        table.insert( playSeats, v.Pos)
    end

    self.hand = currentHand
    self.tableid = tbInfo.TableId 
    self.base = tbInfo.BasePoint --底分
    self.maxmultiple = tbInfo.MaxMultiple
    self.gamestate = GameStatusType.DeskState_Init
    self.playseats = playseats
    self.maxplays = 3 

    local seatSortFun = function(a, b)
        return a.id < b.id
    end
    table.sort(self.seats, seatSortFun) 

    local recoverTableInfo = {
        ["TableID"] = tableid,
        ["Players"] = players,
    }

    self.RecoverData.TableInfo = recoverTableInfo 

end

function game_ddz:recoverDealCard(reData)
    local dealData = reData:dealOP() 

    for i, v in ipairs(dealData) do
        print(i, "src seat:", v.SeatTo, "len currsors:", #v.Currsors, "Open:", v.Open)
        for j, sv in ipairs(gd.seats) do 
            if (sv.id == v.SeatTo) then
                for ii, vi in ipairs(v.Currsors) do
                    table.insert(sv.privateIndex, vi)
                end

                --自己要恢复明牌
                if (v.SeatTo == self.myseat) then
                    print("|-----index --> card")
                    local cards = {}
                    local decIndex, decCard = reData:decCards()
                    for ci, currv in ipairs(v.Currsors) do
                        -- print(ci, currv)
                        for decIi, decIv in ipairs(decIndex) do
                            if (currv == decIv) then
                                print("card:", currv, decCard[decIi])
                                table.insert(cards, decCard[decIi])
                            end
                        end
                    end 
                    print("card len:", #cards)
                    if #v.Currsors == #cards then
                        for ic,vc in ipairs(cards) do
                            table.insert(sv.privateCard, vc)
                        end
                    end
                end
            elseif (v.SeatTo == self.maxplays + 1) then
                for ii,vi in ipairs(v.Currsors) do
                    table.insert(sv.publicIndex, vi)
                end
            end 
        end
    end

    local dealoverflag = gd:IsDealOver()

    local ms = gd:GetSeat(gd.myseat) 
    if (ms == nil) then
        error("myseat is nil")
    end

    local dealinfo  = {} 
    dealinfo.Turn = self.firstqdzTurn
    dealinfo.SelfCard = {}
    dealinfo.SelfCard.privateIndex = ms.privateIndex
    dealinfo.SelfCard.privateCard =  ms.privateCard
    dealinfo.DeskCard = {}
    -- dealinfo.DeskCard.publicIndex = ms.publicIndex
    -- dealinfo.DeskCard.publicCard = ms.publicCard 
    --不能如上赋值，因为如果后面也引用到了同一变量，会导致不能编码成json， 
    local pindex = {} 
    local pcard = {} 

    for i,v in ipairs(ms.publicIndex) do
        table.insert( pindex, v)
    end

    for i,v in ipairs(ms.publicCard) do
        table.insert( pcard, v )
    end
    dealinfo.DeskCard.publicIndex = pindex
    dealinfo.DeskCard.publicCard = pcard
    self.RecoverData.DealInfo = dealinfo 
    
    --长度为3 说明发牌过程已经完成
    if #dealData == 4 and dealoverflag == true then 
        self.RecoverData.DealFlag = true  --各阶段是否完成的标志
        return true  --继续恢复下面的流程
    else
        --还没有发完的牌？
        print("deal card unfinished")
        return false --不用恢复下面的流程
    end
end

function game_ddz:recoverGrabDz(reData)
    self.gamestate = GameStatusType.DeskState_Grab
    self.firstqdzTurn, err = ge.FirstSeat()
    if (err ~= nil) then
        error ("Not have firstSeat"..err)
    end
    self.currentqdzTurn = self.firstqdzTurn

    print("re grabdz =====")

    local seat , op = -1, -1 
    local logicData = reData:logicData() 
    for i,v in ipairs(logicData) do
        print(i, "src seat:", v.SrcSeat, "Msg Code:", v.Code, "Data:", v.Data)
        if (v.Code == GrabDataCode) then
            local grabInfo = {} 
            table.insert(grabInfo, 0)
            table.insert(grabInfo, 0)
            local  grabInfo, err = rlp.Decode(v.Data, grabInfo)
            if (err ~= nil) then
                error("RlpDecode err:"..err)
            end 
            print("抢地主消息=====", "seat:", grabInfo[1], "op:", grabInfo[2])
            seat, op = grabInfo[1], grabInfo[2]
           

            local gseat = self:GetSeat(seat)
            if (gseat == nil) then
                error("gseat is nil")
            end

            gseat.grab = gseat.grab + op 
            gseat.optimes = gseat.optimes + 1 
            if (op == 1) then 
                --还没有人抢过地主，记住第一个抢地主的位置
                if (self.landlordSeat == -1) then
                    self.lastqdzcurnTurn = seat
                    self.multiple = 1
                else 
                    self.multiple = self.multiple * 2 
                    if (self.multiple > self.maxmultiple)then 
                        self.multiple = self.maxmultiple 
                    end
                end

                --地主位赋值
                self.landlordSeat = seat
            end
        end
    end 

    local grabinfo  = {} 
    grabinfo.LastqdzSeat = seat 
    grabinfo.LastqdzOP = op
    grabinfo.LandlordSeat = self.landlordSeat
    grabinfo.Multiple = self.multiple
    self.RecoverData.GrabInfo = grabinfo 

    if (self:isOverGrab()) then  
        --抢地主过程完成，继续向下恢复
        self.RecoverData.GrabFlag = true 
        return true 
    else 
        --self:GrabTurn(seat, op)
        return false 
    end
end

function game_ddz:recoverGrabSign(reData)
    print("re grabdz sign =====")
    local logicData = reData:logicData() 
    for i, v in ipairs(logicData) do
        print(i, "src seat:", v.SrcSeat, "Msg Code:", v.Code, "Data:", v.Data)
        if (v.Code == GrabSignDataCode) then
            local GrabSignData = {}
            table.insert(GrabSignData, "")
            table.insert(GrabSignData, "") 
            table.insert(GrabSignData, "") 
            table.insert(GrabSignData, 0)
            local GrabSignData, err = rlp.Decode(v.Data, GrabSignData)
            if (err ~= nil) then
                error("RlpDecode err:"..err)
            end 
    
            local signdata = json.encode(GrabSignData)
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "receive GrabSignData:", signdata) 
            local rdata = {
                GbHash = GrabSignData[1],
                Sign = GrabSignData[2],  
                Desk = GrabSignData[3], 
                ID = GrabSignData[4],
            } 
            local sdseat = self:GetSeat(rdata.ID)  

            sdseat.grabstateSignDataHash = rdata.GbHash
            sdseat.grabstateSign = rdata.Sign 
        end
    end 

    local allsign = true 

    for i,v in ipairs(self.seats) do
        if (v.status == SeatStatusType.PLAYING and v.grabstateSign == "") then
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "flag break=====", v.id, nil or v.grabstateSign)
            allsign = false
            break
        end
    end

    local grabresultinfo  = {} 
    grabresultinfo.LandlordSeat = self.landlordSeat
    grabresultinfo.FinalMultiple = self.multiple

    if (allsign == true) then
        -- 抢地主签名完成
        ge.UpdateConsensus() 
        self.ConsensusState = ConsensusStateType.Bl_check 
        
        --恢复公共牌
        local myseat = gd:GetSeat(gd.myseat)
        local cards = {} 
        local decIndex, decCard = reData:decCards() 
        for ci, currv in ipairs(myseat.publicIndex) do
            -- print(ci, currv)
            for decIi,decIv in ipairs(decIndex) do
                if (currv == decIv) then
                    print("card:", currv, decCard[decIi])
                    table.insert(cards, decCard[decIi])
                end
            end
        end 
        print("public card len:", #cards)
        if #myseat.publicIndex == #cards then
            for ic, vc in ipairs(cards) do
                --table.insert(sv.privateCard, vc)
                for i, v in ipairs(gd.seats) do 
                    if (v.status == SeatStatusType.PLAYING) then
                        table.insert(v.publicCard, vc)
                    end
                end
            end
        end

        self.RecoverData.GrabSignFlag = true   
        grabresultinfo.DeskCard = {} 
        local pindex = {} 
        local pcard = {} 
        for i,v in ipairs(myseat.publicIndex ) do
            table.insert( pindex, v)
        end

        for i,v in ipairs(myseat.publicCard) do
            table.insert( pcard, v )
        end

        grabresultinfo.DeskCard.publicIndex = pindex 
        grabresultinfo.DeskCard.publicCard = pcard 
        self.RecoverData.GrabResultInfo = grabresultinfo 
  
        return true 
    else
        self.RecoverData.GrabResultInfo = grabresultinfo 
        return false 
    end
end 

function game_ddz:recoverPlayCard(reData)
    local ms = self:GetSeat(self.myseat)
    if (ms == nil) then
        error("myseat == nil")
    end

    local playCardflag = true 

    for i, v in ipairs(self.seats) do
        if (v.status == SeatStatusType.PLAYING and #v.publicCard ~= #v.publicIndex) then
            playCardflag = false
        end
    end

    if (playCardflag == true and self.landlordSeat ~= -1) then
        for i, v in ipairs(self.seats) do
            if (#v.privateCard == 0) then
                for i = 1, #v.privateIndex do
                    table.insert(v.privateCard, -1)
                end
            end 

            if (v.id == self.landlordSeat) then
                for ii, vv in ipairs(ms.publicCard) do 
                    --是地主 把公共牌插到最后
                    table.insert(v.privateIndex, ms.publicIndex[ii])
                    table.insert(v.privateCard, vv)
                         
                end
            end
        end

        for i,v in ipairs(self.seats) do
            print("牌点列表初始化完成====",v.id,  #v.privateIndex, #v.privateCard)
        end

        self.currentPlayCardTurn = self.landlordSeat --当前出牌位置
        self.currentPlayCardType = {}
        table.insert(self.currentPlayCardType, PlayMethondType.Play) 

        self.gamestate = GameStatusType.DeskState_Play
    end 

    local lseat = -1
    local lindex = {} 
    local lcard = {} 
    local lresult = false 

    local logicData = reData:logicData() 
    for i, v in ipairs(logicData) do
        print(i, "src seat:", v.SrcSeat, "Msg Code:", v.Code, "Data:", v.Data)
        if (v.Code == PlayDataCode) then
            local playData = {} 
            table.insert(playData, 0)
            table.insert(playData, 0)
            table.insert(playData, "")
            table.insert(playData, "")
            local playData, err = rlp.Decode(v.Data, playData)
            if (err ~= nil) then
                error("RlpDecode err:"..err)
            end
            local pdstr = json.encode(playData)
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "receive playData:", pdstr)

            local indexstr = split(playData[3], ",")
            local index = {}
            for i, v in ipairs(indexstr) do
                table.insert(index, tonumber(v))
            end

            local cardstr = split(playData[4], ",")
            local card = {}
            for i, v in ipairs(cardstr) do
                table.insert(card, tonumber(v))
            end

            local seat = playData[1]

            print("play card msg:", seat, #index, #card)

            if (self.currentPlayCardTurn == seat) then
                local op = PlayMethondType.Pass
                if (#index ~=0 and #card ~=0) then
                    op = PlayMethondType.Play
                end

                if (self:isAllownOP(op) == true) then
                    local gseat = self:GetSeat(seat)
                    if (gseat == nil) then
                        error("gseat is nil")
                    end

                    if (op == PlayMethondType.Pass) then
                        --不出  
                        --保存出的牌
                        self:keepRoundItemCard(gseat, index, card)

                        self.passNumber = self.passNumber + 1 

                        if (self.passNumber == 2) then
                            -- 重新一轮
                            self.result = {Type = ddz.HandPatternsType.EVERYCARDTYPE, Max = 3, Size = 0, Value = 3}
                            self:keepRoundCard()  
                            self.currentPlayCardType = {}
                            table.insert(self.currentPlayCardType, PlayMethondType.Play)
                        else 
                            self.currentPlayCardType = {}
                            table.insert(self.currentPlayCardType, PlayMethondType.Play)
                            table.insert(self.currentPlayCardType, PlayMethondType.Pass)
                        end

                        --self:playTurn(seat, index, card, false)
                        --self:printCard() 
                    else
                        --出牌
                        --不要相信发过来的牌点，等解密出来，再处理
                        if (self:isCardofPlay(seat, index) == true) then
                            print(os.date("%Y/%m/%d %H:%M:%S ") .. "car is of seat:", index, seat)
                            if (self:isAllInPublicCard(card) == false) then
                                -- 不全是公共牌才发送密钥
                                print("re Check")
                                --ge.CheckCard(seat, index)

                                local cds = {} 
                                local decIndex, decCard = reData:decCards() 

                                for ci, currv in ipairs(index)  do 
                                    for decIi, decIv in ipairs(decIndex)  do 
                                        if (currv == decIv) then
                                            print("cds :", currv, decCard[decIi])
                                            table.insert( cds, decCard[decIi])
                                        end
                                    end
                                end 

                                print("play card len:", #cds)
                                if (#index == cds) and seat ~= self.myseat then
                                    -- body
                                    local gseat = gd:GetSeat(seat)
                                    if  (gseat == nil) then
                                        error("gseat is nil")
                                    end

                                    if (#gseat.privateCard == 0) then
                                        for i=1,#gseat.privateIndex do
                                            table.insert( gseat.privateCard, -1)
                                        end
                                    end

                                    for i,v in ipairs(index) do
                                        for ii,vv in ipairs(gseat.privateIndex) do
                                            if (v == vv) then
                                                gseat.privateCard[ii] = cds[i]
                                            end
                                        end
                                    end 

                                    card = cds 
                                end
                            
                            else 
                                --直接处理出牌逻辑，不用再次解锁 
                                print("re real Play")
                                --self:realPlayCardHand(seat, index, card)
                            end

                            local gseat = self:GetSeat(seat)
                            if  (gseat == nil) then
                                error("gseat is nil")
                            end

                            local result = ddz:judgePokerType(card) 

                            if (self:isCanPlay(result) == true) then
                                 -- boy
                                print(os.date("%Y/%m/%d %H:%M:%S ") .. "POKERS_MATCHING ", seat, result.Type)
                                self.result = result
                                if (result.Type ==ddz.HandPatternsType.ROCKET  or result.Type ==ddz.HandPatternsType.BOMB ) then
                                    -- 炸弹和火箭倍数乘2
                                    self.multiple = self.multiple * 2 
                                    if (self.multiple > self.maxmultiple )then 
                                        self.multiple = self.maxmultiple 
                                    end
                                end
                                self.passNumber = 0 

                                --保存出的牌
                                self:keepRoundItemCard(gseat, index, card)

                                gseat.playCardNum = gseat.playCardNum + #index
                                for i,v in ipairs(index) do
                                    table.insert( gseat.playIndex, v)
                                end

                                print(os.date("%Y/%m/%d %H:%M:%S ") .. "realPlayCardHand===", #index)
                                print(os.date("%Y/%m/%d %H:%M:%S ") .. "gseat.playCardNum======", gseat.playCardNum)
                                print(os.date("%Y/%m/%d %H:%M:%S ") .. "#gseat.privateCard", #gseat.privateCard)

                                if (gseat.playCardNum == #gseat.privateCard) then
                                    -- 牌出完，游戏结束 
                                    self:keepRoundCard() 
                                    print(os.date("%Y/%m/%d %H:%M:%S ") .. "==========游戏结束==============胜利玩家:", seat) 
                                    self.winseat = seat 

                                   -- self:playTurn(seat, index, card, true) 
                                    --self:printCard()
                                    self.gamestate = GameStatusType.DeskState_Over
                                    lseat = seat
                                    lindex = index
                                    lcard = card
                                    lresult = true  
                                    --self:showSurplusCard(self.winseat)

                                    local remain = {} 
                                    for i,v in ipairs(self.seats) do
                                        if (v.status == SeatStatusType.PLAYING and v.id ~= self.winseat) then
                                            -- body
                                            local item = {seat = v.id, index = {}}
                                            for ii,vv in ipairs(v.privateIndex) do
                                                local flag = false
                                                for jj,pv in ipairs(v.playIndex) do
                                                    if (vv == pv) then
                                                        flag = true 
                                                        break 
                                                    end
                                                end 

                                                if (flag == false) then
                                                    -- body
                                                    table.insert( item.index , vv)
                                                end
                                            end
                                            table.insert( remain, item)
                                        end   
                                    end 

                                     --保存剩余的牌标 
                                    self.remain = remain 

                                    local decIndex, decCard = reData:decCards() 
                                    for i,v in ipairs(remain) do
                                        --ge.CheckCard(v.seat, v.index) 

                                        local cds = {} 
                                        for ci, currv in ipairs(v.index)  do 
                                            for decIi, decIv in ipairs(decIndex)  do 
                                                if (currv == decIv) then
                                                    print("cds :", currv, decCard[decIi])
                                                    table.insert( cds, decCard[decIi])
                                                end
                                            end
                                        end 
                                        
                                        print("show card len:", #cds)
                                        if (#v.index == cds) and seat ~= self.myseat then
                                            -- body
                                            local gseat = gd:GetSeat(seat)
                                            if  (gseat == nil) then
                                                error("gseat is nil")
                                            end

                                            for i,v in ipairs(index) do
                                                for ii,vv in ipairs(gseat.privateIndex) do
                                                    if (v == vv) then
                                                        gseat.privateCard[ii] = cds[i]
                                                    end
                                                end
                                            end
                                        end
                                    end
                                else
                                    self.currentPlayCardType = {}
                                    table.insert( self.currentPlayCardType, PlayMethondType.Play)
                                    table.insert( self.currentPlayCardType, PlayMethondType.Pass)
                                    lseat = seat
                                    lindex = index
                                    lcard = card
                                    lresult = false
                                    --self:playTurn(seat, index, card, false)
                                    --self:printCard() 
                                end
                            end
                        end
                    end
                end
            end
        end
    end 

    local playinfo  = {} 
    playinfo.LastPlaySeat = lseat 
    playinfo.LastPlayIndex = lindex
    playinfo.LastPlayCard = lcard
    local selfremainIndex = {} 
    local selfremainCard = {} 
    for i,v in ipairs(ms.privateIndex) do
        local flag = true
        for ii,vv in ipairs(ms.playIndex) do
            if (v == vv) then
                flag = false 
            end
        end

        if (flag == true) then
            table.insert( selfremainIndex, v)
            table.insert( selfremainCard, ms.privateCard[i])
        end
    end
    playinfo.SelfRemainIndex = selfremainIndex 
    playinfo.SelfRemainCard = selfremainCard 

    local OtherremainIndex = {} 
    for i,v in ipairs(self.seats) do
        if (v.id ~= self.myseat) then
            local ORrItem = {} 
            ORrItem.Id = v.id
            ORrItem.RemainIndex = {} 
            for j,jv in ipairs(v.privateIndex) do
                local flag = true
                for jj,jvv in ipairs(v.playIndex) do
                    if (jv == jvv) then
                        flag = false 
                    end
                end
        
                if (flag == true) then
                    table.insert(ORrItem.RemainIndex, jv)
                end
            end  
            table.insert( OtherremainIndex, ORrItem)
        end
    end 
    playinfo.OtherremainIndex = OtherremainIndex

    playinfo.RemainCard = {} 

    if (self.gamestate == GameStatusType.DeskState_Over ) then
        -- 游戏结束
        print("game over") 

        local settleflag = true 
        for i,v in ipairs(self.remain) do

            local st = self:GetSeat(v.seat) 
            for ii,vv in ipairs(v.index) do
                local c = self:cursor2Card(st, vv) 
                if (c == -1) then
                    --等于-1说明还没有解锁
                    settleflag = false 
                    break 
                end

            end
            
            if (settleflag == false) then
                break
            end
        end

        print(os.date("%Y/%m/%d %H:%M:%S ") .. "settleflag =========", settleflag) 

        if (settleflag == true) then
            -- 游戏结束，并且所有剩余的牌已经摊开 
            self.RecoverData.PlayCardFlag = true  

            local remainCard = {}
            for i,v in ipairs(self.remain) do
        
                local item = {Seat = v.seat, Index = v.index, Card = {}}
                local st = self:GetSeat(v.seat) 
               
                for ii,vv in ipairs(v.index) do
                    print(os.date("%Y/%m/%d %H:%M:%S "), ii,vv)
                    local c = self:cursor2Card(st, vv)
                    if (c == -1) then
                        --等于-1说明还没有解锁
                        error("car is unlock")
                    end
                    table.insert(item.Card, c)
        
                end
        
                table.insert(remainCard, item)
            end 
            playinfo.RemainCard = remainCard 
            self.RecoverData.PlayInfo = playinfo 
            
            return true 

        else
            --游戏结束， 但是剩余牌没有全部摊开
            self.RecoverData.PlayInfo = playinfo 
            return false
        end
    else
        --游戏没结束，牌没有打完
        print("game not over") 
        self.RecoverData.PlayInfo = playinfo 
        return false 
    end
end



function game_ddz:recoverSettle(reData)
    -- body
     print("re settle sign =====")

     local logicData = reData:logicData() 
     for i,v in ipairs(logicData) do
         print(i, "src seat:", v.SrcSeat, "Msg Code:", v.Code, "Data:", v.Data)
         if (v.Code == SettleSignDataCode) then
            -- body
            local SettleSignData = {}
            table.insert( SettleSignData, "" )
            table.insert( SettleSignData, "" ) 
            table.insert( SettleSignData, "" ) 
            table.insert( SettleSignData, 0 )
            local SettleSignData, err = rlp.Decode(data, SettleSignData)
            if (err ~= nil) then
                error("RlpDecode err:"..err)
            end 

            local signdata = json.encode(SettleSignData)
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "receive SettleSignData:", signdata) 
            local sig2table = {
                SeHash = SettleSignData[1],
                Sign = SettleSignData[2],  
                Desk = SettleSignData[3], 
                ID = SettleSignData[4],
            } 

            if (sig2table.ID == self.myseat) then
                -- body
                local  seat = self.winseat

                local GameSettleData = {}
                table.insert( GameSettleData, DDZRoomManagerAddr)
                table.insert( GameSettleData, self.tableid )
                table.insert( GameSettleData, self.hand ) 

                local  list = {} 
                if (seat == self.landlordSeat) then
                    -- 地主赢
                    local gdb = {} 
                    table.insert( gdb, seat)
                    table.insert( gdb,  1 )
                    table.insert( gdb,  2 * self.multiple * self.base)
                    table.insert( list, gdb)

                    local  ids = self:exceptIds(seat) 

                    for i,v in ipairs(ids) do
                        local gdb = {} 
                        table.insert( gdb, v)
                        table.insert( gdb,  0 )
                        table.insert( gdb,  self.multiple * self.base)
                        table.insert( list, gdb)
                    end
                else 
                    --农民赢
                    local gdb = {} 
                    table.insert( gdb, seat)
                    table.insert( gdb,  1 )
                    table.insert( gdb,   self.multiple * self.base) 
                    table.insert( list, gdb)

                    local  ids = self:exceptIds(seat) 

                    for i,v in ipairs(ids) do

                        if  (v == self.landlordSeat) then
                            -- body
                            local gdb = {} 
                            table.insert( gdb, v)
                            table.insert( gdb,  0 )
                            table.insert( gdb,  2 * self.multiple * self.base)
                            table.insert( list, gdb)
                        else 
                            local gdb = {} 
                            table.insert( gdb, v)
                            table.insert( gdb,  1 )
                            table.insert( gdb,   self.multiple * self.base) 
                            table.insert( list, gdb)
                        end
                        
                    end
                end 
                table.insert( GameSettleData , list)
                self.settlelist = list 

                local gsdstr = json.encode(GameSettleData)
                print(os.date("%Y/%m/%d %H:%M:%S ") .. "settleData$$$$$$$$$$", gsdstr)

                local signData, err = rlp.Encode(GameSettleData) 
                if (err ~= nil) then
                    -- body
                    err("RlpEncode err:"..err)
                end

                local myseat = self:GetSeat(self.myseat)
                if (myseat == nil) then
                    -- body
                    error("seat == nil ")
                end  

                signDataHash = signData:Hash()
                sign = ge.Sign(signDataHash)
                
                if (signDataHash:toHexString() == sig2table.SeHash and sign:toHexString() == sig2table.Sign) then
                    -- body
                else
                    error("recover error")
                end

                myseat.settleSignData = signData:toHexString() 
                myseat.settleSignDataHash = rdata.SeHash
                myseat.settleSign = rdata.Sign 

            else

                local sdseat = self:GetSeat(sig2table.ID) 
                sdseat.settleSignDataHash = rdata.SeHash
                sdseat.settleSign = rdata.Sign
            end
            
         end
     end 
 
    

     local allsign = true 

     for i,v in ipairs(self.seats) do
         if (v.status == SeatStatusType.PLAYING  and v.settleSign == "") then
             allsign = false
             break
         end
     end

     local gameOverInfo = {}
     gameOverInfo.Win = self.winseat
     gameOverInfo.Base = self.base
     gameOverInfo.Multiple = self.multiple
     gameOverInfo.SettleList = self.settlelist
     self.RecoverData.GameOverInfo = gameOverInfo 

    if (allsign == true) then
      
         --结算，提交到合约 待完善 
         ge.UpdateConsensus() 
         self.ConsensusState = ConsensusStateType.Rf_check 
         local sigAndData = byteSlice:new() 
         local sigdata = byteSlice:new()
 
         for i,v in ipairs(self.seats) do
             if (v.status == SeatStatusType.PLAYING  and v.settleSign ~= "") then
                 -- body 
                 sigAndData:appendHexString(v.settleSign)
                 if (v.id == self.myseat) then
                     -- body
                     sigdata:appendHexString(v.settleSignData)
                 end
             end    
         end
 
         sigAndData:appendString(sigdata:toString())  
         local hstr = sigAndData:toHexString()
         print(os.date("%Y/%m/%d %H:%M:%S ") ..hstr) 
   
         print(os.date("%Y/%m/%d %H:%M:%S ") .. "room settle =======================")
         --self.roomManagercontrac.Transact("playerSettle", sigAndData)
         rCtr.tc.Transact("playerSettle", sigAndData)

         --self:GameOverToUI() 
         print(os.date("%Y/%m/%d %H:%M:%S ") .. "Settle Result Commit // Game Over.....*************\n")
         print(os.date("%Y/%m/%d %H:%M:%S ") .. "table addr", self.tableid) 

         self.RecoverData.SettleFlag = true 
         return true 
    else 
        --结算签名没有收齐，
        return false 
    end
 
end



function game_ddz:recoverOrNot()
    local selfaddr, tbid, seat, status = rCtr:selfPlayingStatus()
    if (status == SeatStatusType.NOTJION) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "now Status: NOTJION") 
        --1 还没有调用openDoor 
        --2 调用了openDoor，但是还没有上链 
        --还没有table 
       -- rCtr:leaveTable()  
        self.RecoverData.SeatStatus = status 
        return 
    elseif (status == SeatStatusType.NOTSEATED) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "now Status: NOTSEATED")
        --1 没有调用sitDown
        --2 调用了sitDonw,但是还没上链
        --还没有table 
        rCtr:leaveTable()  
        self.RecoverData.SeatStatus = status 
        return 
    elseif (status == SeatStatusType.SITTING) then 
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "now Status: SITTING")
        --1 调用sitDown成功，并上链
        --2 集齐三个玩家，但是还没有上链
        --还没有table
        rCtr:leaveTable() 
        self.RecoverData.SeatStatus = status 
        return 
    elseif (status == SeatStatusType.SEATED) then 
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "now Status: SEATED")
        --1 三个玩家集齐，并上链
        --2 已经准备，调用了start,但是还没有上链
        --已经有table 
        rCtr:leaveTable()
        self.RecoverData.SeatStatus = status  
        return 
    elseif (status == SeatStatusType.READY) then 
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "now Status: READY")
        --1 已经准备，调用了start,并上链
        --2 三个玩家都准备，调用了start，但是还没有上链 
        --已经有table 
        rCtr:leaveTable()
        self.RecoverData.SeatStatus = status  
        return 
    elseif (status == SeatStatusType.PLAYING) then
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "now Status: PLAYING")
        --1 三个玩家都准备，调用了start,并上链
        --2 链下状态，待确定
        --已经有table   

        local disflag = rCtr:dismissTableFlag(tbid)  

        if disflag == true then 
            rCtr:dismissTable(tbid)
            return 
        end 


        self.RecoverData.SeatStatus = status 
        self:recoverSeats(selfaddr, tbid)
        local reData, err = ge.Recover(seat,54) 
        if (err ~= nil) then
            error("go Recover: "..err)
        end

        print(reData)

        local consensustate = reData:consensuState() 
        print("Consensustate:", consensustate) 

        self.RecoverData.ConsensusState = consensustate 
        self.RecoverData.DealFlag = false  --各阶段是否完成的标志
        self.RecoverData.GrabFlag = false 
        self.RecoverData.GrabSignFlag = false 
        self.RecoverData.PlayCardFlag = false 
        self.RecoverData.SettleFlag = false 

        if (consensustate >= 3) then
            local rDealresult = self:recoverDealCard(reData) 
            if (rDealresult == true) then
                local rGrabresult = self:recoverGrabDz(reData)
                if (rGrabresult == true) then
                    local rgrabSignresult = self:recoverGrabSign(reData)
                    if (rgrabSignresult == true) then
                        local rplayCardResult = self:recoverPlayCard(reData) 
                        if (rplayCardResult == true) then
                            self:recoverSettle(reData)
                        end
                    end
                end
            end
        else 
            error("can't recover....")
        end
        
        local RDstr = json.encode(self.RecoverData)
        print(RDstr)
    end
end


function game_ddz:Recover()
    local RecoverReturnData = {} 
    RecoverReturnData.Stage = ""
    if (gd.RecoverData.SeatStatus ~= nil and gd.RecoverData.SeatStatus == SeatStatusType.PLAYING) then
        -- 需要恢复
        interlist = RoomInter() 
        print(interlist)
        local ms = self:GetSeat(self.myseat)
        if (ms == nil) then
            error("myseat == nil")
        end 
        self.nodelist = interlist 

        local naddr = newAddress(ms.ad)
        ge.ReConnectInter(ms.id, self.tableid, naddr, interlist) 


        if gd.RecoverData.ConsensusState ~= nil and  gd.RecoverData.ConsensusState >= 3 then
            -- 在lua层出错 可以恢复。 

            if (gd.RecoverData.DealFlag ~= nil and gd.RecoverData.DealFlag == false) then
                -- 恢复发牌 
                RecoverReturnData.Stage = "Deal"
            else 
                if (gd.RecoverData.GrabFlag ~= nil and gd.RecoverData.GrabFlag == false) then
                    -- 恢复抢地主
                    RecoverReturnData.Stage = "Grab"
                    if (gd.RecoverData.GrabInfo.LastqdzSeat == -1) then
                        local gbTninfo = {}
                        gbTninfo.Grab = {}
                        gbTninfo.Grab.ID = gd.RecoverData.GrabInfo.LastqdzSeat
                        gbTninfo.Grab.OP = gd.RecoverData.GrabInfo.LastqdzOP
                        gbTninfo.CurnSeat = self.firstqdzTurn
                        gbTninfo.Multiple = self.multiple
                        --没人抢过
                        if (self.landlordSeat == -1) then
                            gbTninfo.CurnOPName = 0 --叫地主
                        else
                            gbTninfo.CurnOPName = 1 --抢地主
                        end

                        if (self.firstqdzTurn == self.myseat) then
                            gbTninfo.IsMyTurn = true
                        else
                            gbTninfo.IsMyTurn = false
                        end
                        RecoverReturnData.GrabTurnInfo = gbTninfo 
                    else 
                        local gbTninfo = gd:GrabTurn(gd.RecoverData.GrabInfo.LastqdzSeat, gd.RecoverData.GrabInfo.LastqdzOP) 
                        RecoverReturnData.GrabTurnInfo = gbTninfo 
                    end

                    
                else 
                    if (gd.RecoverData.GrabSignFlag ~= nil and gd.RecoverData.GrabSignFlag == false) then
                        -- 恢复抢地主签名
                        RecoverReturnData.Stage = "GrabSign"
                    else 
                        if (gd.RecoverData.PlayCardFlag ~= nil and gd.RecoverData.PlayCardFlag == false) then
                            -- 恢复出牌 
                            RecoverReturnData.Stage = "PlayCard"  
                            if (gd.RecoverData.PlayInfo.LastPlaySeat == -1) then
                                local playCardInfo = {} 
                                playCardInfo.CurrentPlay = {} 
                                playCardInfo.CurrentPlay.Seat = gd.RecoverData.PlayInfo.LastPlaySeat
                                playCardInfo.CurrentPlay.Index = gd.RecoverData.PlayInfo.LastPlayIndex
                                playCardInfo.CurrentPlay.Card = gd.RecoverData.PlayInfo.LastPlayCard

                                playCardInfo.Result = {} 
                                playCardInfo.Result = self.result
                                playCardInfo.CurrentMultiple = self.multiple
                                playCardInfo.NextTurn = self.landlordSeat 
                                
                                self.currentPlayCardTurn = self.landlordSeat 

                                if (self.landlordSeat == self.myseat) then
                                    playCardInfo.IsMyTurn = true 
                                else
                                    playCardInfo.IsMyTurn = false 
                                end 
                                RecoverReturnData.PlayCardInfo = playCardInfo 
                            else 
                                local playCardInfo = gd:playTurn(gd.RecoverData.PlayInfo.LastPlaySeat, gd.RecoverData.PlayInfo.LastPlayIndex, gd.RecoverData.PlayInfo.LastPlayCard, false)
                                RecoverReturnData.PlayCardInfo = playCardInfo 
                            end
                           
                        else 
                            if (gd.RecoverData.SettleFlag ~= nil and gd.RecoverData.SettleFlag == false) then
                                -- 恢复结算
                                RecoverReturnData.Stage = "Settle"

                            end
                        end
                    end
                end
            end 

        end

    end

    return RecoverReturnData
end

gd:recoverOrNot()

function EventHandler(method, params)
    print(method, params) 

    if (method == "Grab") then
        local t = json.decode(params)
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "UI Grab:", t.ID, t.OP)
        gd:grabDz(t.OP)
    elseif (method == "Play") then
        local t = json.decode(params)
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "UI CheckOut:", t.ID, t.OP, t.Index, t.Card) 
        local result = gd:playCard(t.Index, t.Card)
        rstr = json.encode(result)
        return rstr 
    elseif (method == "RecoverOrNot") then 

        local RDstr = json.encode(gd.RecoverData)

        --gd.RecoverData = {} 
        print("RecoverData:=========\n", RDstr)
        return RDstr 
    elseif (method == "Recover") then 
        
        local recoverReturnData = gd:Recover() 
        local RDstr = json.encode(recoverReturnData)
        return RDstr 

    end

    return "jsonxxx"
end

function HandleMsg(srcSeat, code, data)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "==========HandleMsg===========", srcSeat, code)
    --抢地主消息
    if (code == GrabDataCode) then
        local grabInfo = {} 
        table.insert(grabInfo, 0)
        table.insert(grabInfo, 0)
        local grabInfo, err = rlp.Decode(data, grabInfo)
        if (err ~= nil) then
            error("RlpDecode err:"..err)
        end

        gd:grabDzHand(grabInfo[1], grabInfo[2])
    elseif (code == GrabSignDataCode) then
        -- 抢地主签名消息 
        local GrabSignData = {}
        table.insert(GrabSignData, "")
        table.insert(GrabSignData, "") 
        table.insert(GrabSignData, "") 
        table.insert(GrabSignData, 0)
        local GrabSignData, err = rlp.Decode(data, GrabSignData)
        if (err ~= nil) then
            error("RlpDecode err:"..err)
        end 

        local signdata = json.encode(GrabSignData)
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "receive GrabSignData:", signdata) 
        local sig2table = {
            GbHash = GrabSignData[1],
            Sign = GrabSignData[2],  
            Desk = GrabSignData[3], 
            ID = GrabSignData[4],
        } 
        
        gd:VerificationGrabSign(sig2table)
    elseif (code == PlayDataCode) then
        local playData = {} 
        table.insert(playData, 0)
        table.insert(playData, 0)
        table.insert(playData, "")
        table.insert(playData, "")
        local playData, err = rlp.Decode(data, playData)
        if (err ~= nil) then
            error("RlpDecode err:"..err)
        end
        local pdstr = json.encode(playData)
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "receive playData:", pdstr)

        local indexstr  = split(playData[3], ",")
        local index = {}
        for i, v in ipairs(indexstr) do
            table.insert(index, tonumber(v))
        end

        local cardstr = split(playData[4], ",")
        local card = {}
        for i, v in ipairs(cardstr) do
            table.insert(card, tonumber(v))
        end

        gd:playCardHand(playData[1], index, card)
    elseif (code == SettleSignDataCode) then 
        local SettleSignData = {}
        table.insert(SettleSignData, "")
        table.insert(SettleSignData, "") 
        table.insert(SettleSignData, "") 
        table.insert(SettleSignData, 0)
        local SettleSignData, err = rlp.Decode(data, SettleSignData)
        if (err ~= nil) then
            error("RlpDecode err:"..err)
        end

        local signdata = json.encode(SettleSignData)
        --print(os.date("%Y/%m/%d %H:%M:%S ") .. "receive SettleSignData:", signdata) 
        local sig2table = {
            SeHash = SettleSignData[1],
            Sign = SettleSignData[2],
            Desk = SettleSignData[3],
            ID = SettleSignData[4],
        } 
        
        gd:VerificationSettleSign(sig2table)
    end
end

function ShuffleCardResult(err) 
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "ShuffleCardResult")

    gd.ShuffleFlag = true
    tryDealCard()

    -- local seatnum = #gd.seats

    -- print(os.date("%Y/%m/%d %H:%M:%S ") .. "Deal Private Card")
    -- for i,v in ipairs(gd.seats) do
    --     if (v.status == SeatStatusType.PLAYING) then 
    --         print(v.id, DealStatusType.Self)
    --         local err = ge.DealCard(v.id, 17, DealStatusType.Self) 
    --         if (err ~= nil) then
    --             print(os.date("%Y/%m/%d %H:%M:%S ") .. "DealCard err:", err)
    --             error("DealCard err"..err)
    --         end
    --     end
    -- end

    -- print(os.date("%Y/%m/%d %H:%M:%S ") .. "Deal Public Card")
    -- local err = ge.DealCard(seatnum + 1, 3, DealStatusType.None)
    -- if (err ~= nil) then
    --     print(os.date("%Y/%m/%d %H:%M:%S ") .. "DealCard err:", err)
    --     error("DealCard err"..err)
    -- end

    -- local fn = function()
    --     print(os.date("%Y/%m/%d %H:%M:%S ") .. "DealCard Timeout .....")
    --     --发牌超时，提交公证
    -- end
    -- gd.dealCardTimer = timer.afterFunc(fn, 1000*30)
end

function tryDealCard()
    if gd.ShuffleFlag == true and gd.ReadyFlag == true then 

        local ph = ge.DeskID() 
        rCtr:submitPointHash(gd.hand, ph) 

        print(os.date("%Y/%m/%d %H:%M:%S ") .. "Deal Private Card")
        for i, v in ipairs(gd.seats) do
            if (v.status == SeatStatusType.PLAYING) then 
                print("index :", i)
                print("v type:", type(v))
                print("id type:", type(v.id))
                print("self type:", type(DealStatusType.Self))
                print(v.id, DealStatusType.Self)
                local err = ge.DealCard(v.id, 17, DealStatusType.Self) 
                if (err ~= nil) then
                    print(os.date("%Y/%m/%d %H:%M:%S ") .. "DealCard err:", err)
                    error("DealCard err" .. err)
                end
            end
        end

        print(os.date("%Y/%m/%d %H:%M:%S ") .. "Deal Public Card")
        local err = ge.DealCard(gd.maxplays + 1, 3, DealStatusType.None)
        if (err ~= nil) then
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "DealCard err:", err)
            error("DealCard err" .. err)    
        end

        local fn = function()
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "DealCard Timeout .....")
            --发牌超时，提交公证
            ApplyNotary(NotaryNumber)
        end
        gd.dealCardTimer = timer.afterFunc(fn, 1000*30) 

        gd.ShuffleFlag = false 
        gd.ReadyFlag = false 
        
    end
end

function DealCardResult(seat, index, card)
    --print(os.date("%Y/%m/%d %H:%M:%S "), "DealCardResult")
    print(os.date("%Y/%m/%d %H:%M:%S "), gd.myseat,  " =====DealCard seat: ", seat, "index:", index, "card:", card)
    for i, v in ipairs(gd.seats) do
        if (v.id == seat) then
            for ii, vi in ipairs(index) do
                table.insert(v.privateIndex, vi)
            end
            
            for ic, vc in ipairs(card) do
                table.insert(v.privateCard, vc)
            end
        elseif (seat == gd.maxplays + 1) then
            for ii, vi in ipairs(index) do
                table.insert(v.publicIndex, vi)
            end

            for ic, vc in ipairs(card) do
                table.insert(v.publicCard, vc)
            end
        end
    end 

    local dealoverflag = gd:IsDealOver()

    print(os.date("%Y/%m/%d %H:%M:%S ") .. "dealoverflag", dealoverflag) 
    local ms = gd:GetSeat(gd.myseat)
    if (ms == nil) then
        error("myseat is nil")
    end

    --自己 明牌发完，并且公牌 暗牌发完
    if (dealoverflag == true and ms.status == SeatStatusType.PLAYING and gd.dealCardTimer ~= nil) then 
        gd.dealCardTimer:stop() 
        gd.dealCardTimer = nil 
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "stop dealCardTimer .....  Deal Card Done++++++++++++++")
       
        gd:startQdz() 
    end
end

function CheckCardResult(seat, index, card)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "CheckCardResult") 
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "========CheckCard seat:", seat, "index:", index, "card:", card) 

    if (gd.gamestate == GameStatusType.DeskState_Grab) then
        local myseat = gd:GetSeat(gd.myseat)
        if (#index ~= #card or #index ~= #myseat.publicIndex) then
            error ("checkCard error")
        end

        for ii, cur in ipairs(myseat.publicIndex) do
            if (cur ~= index[ii]) then
                error("checkCard error")
            end

            for i, v in ipairs(gd.seats) do 
                if (v.status == SeatStatusType.PLAYING) then
                    table.insert(v.publicCard, card[ii])
                end
            end
        end

        --尝试出牌
        gd:TryStartPlayCard()
    elseif(gd.gamestate == GameStatusType.DeskState_Play) then
        local indexstr = json.encode(index)
        local cardstr = json.encode(card)
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "出牌位置================", seat, "index:", indexstr, "card:", cardstr)
        if (#index ~= #card) then
            error("checkCard error")
        end
        --出牌
        local gseat = gd:GetSeat(seat)
        if (gseat == nil) then
            error("gseat is nil")
        end
        
        if (#gseat.privateCard == 0) then
            for i=1, #gseat.privateIndex do
                table.insert(gseat.privateCard, -1)
            end
        end

        for i, v in ipairs(index) do
            for ii, vv in ipairs(gseat.privateIndex) do
                if (v == vv) then
                    gseat.privateCard[ii] = card[i]
                end
            end
        end

        gd:realPlayCardHand(seat, index, card)
    elseif (gd.gamestate == GameStatusType.DeskState_Over) then 
        local indexstr = json.encode(index)
        local cardstr = json.encode(card)
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "摊牌位置================", seat, "index:", indexstr, "card:", cardstr)
        if (#index ~= #card) then
            error("checkCard error")
        end
        --出牌
        local gseat = gd:GetSeat(seat)
        if (gseat == nil) then
            error("gseat is nil")
        end

        for i, v in ipairs(index) do
            for ii, vv in ipairs(gseat.privateIndex) do
                if (v == vv) then
                    gseat.privateCard[ii] = card[i]
                end
            end
        end
        gd:trySettle()
    else        
        print(os.date("%Y/%m/%d %H:%M:%S ") .. "Unknow gameState", gd.gamestate)
    end
end


function game_ddz:ApplyNotary(num)
    print("ApplyNotary() ", num)
    --调用合约
    rCtr.tc.Transact("applyNotarize", num)
end


function game_ddz:SendNotaireContext(nodestr)
    
    local ws = nil 

    print("SendNotaireContext() ", self.ConsensusState, ConsensusStateType.Sf_check, self.hand)
    if (self.ConsensusState == ConsensusStateType.Sf_check) then
        -- body
        ge.SendNotaireContext(nodestr, self.hand)
        return
    elseif (self.ConsensusState == ConsensusStateType.Bl_check) then
        -- body
        print("Bl_check SendNotaireContext")
        for i,v in ipairs(self.seats) do
            print("v = ", v.status, v.grab, v.grabstateSignData, v.grabstateSignDataHash, v.grabstateSign)
            if (v.status == SeatStatusType.PLAYING and v.grabstateSignDataHash ~= nil and v.grabstateSign ~= nil) then
                -- body 
                print("ws = ", ws)
                if (ws == nil) then
                    ws = witness.new(self.ConsensusState)
                    print("new ws = ", ws)
                end

                if  (v.id == self.myseat) then
                    local gssdh  = byteSlice.new() 
                    gssdh:appendHexString(v.grabstateSignDataHash)--要转成[]byte类型
                    ws:SetSignData(gssdh)
                end

                local item = notaireSign.new() 
                item:SetID(v.id) 
                local gss  = byteSlice.new() --要转成[]byte类型
                gss:appendHexString(v.grabstateSign)
                item:SetSign(gss) 
                ws:AddSign(item)

                
            end    
        end
    elseif (self.ConsensusState == ConsensusStateType.R2_check) then
        -- body 
        print("R2_check SendNotaireContext")
        for i,v in ipairs(self.seats) do
            if (v.status == SeatStatusType.PLAYING and v.settleSignDataHash ~= nil and v.settleSign ~= nil) then
                -- body 
                if (ws == nil) then
                    ws = witness.new(self.ConsensusState)
                end

                if  (v.id == self.myseat) then
                    ws:SetSignData(v.settleSignDataHash)
                end

                local item = notaireSign.new() 
                item:SetID(v.id) 
                item:SetSign(v.flopSign) 
                ws:AddSign(item)

            end    
        end
    else
        print("invalid ConsensusState")
        return
    end

    
    print("self.ConsensusState, self.ConsensusState == R4_check = ", self.ConsensusState, ConsensusStateType.R4_check, self.ConsensusState == ConsensusStateType.R4_check)
    if (self.ConsensusState == ConsensusStateType.Bl_check or self.ConsensusState == ConsensusStateType.R2_check or 
        self.ConsensusState == ConsensusStateType.R3_check or self.ConsensusState == ConsensusStateType.R4_check) then
        
        -- ws.Data, _ = s.BuildDeskCommonData(s.ConsensusState - 1) 
        local  foldIds = {} 
        local  curseat = -1
        local  publicCard = {}

        curseat = self.landlordSeat  --从地主开始出牌

        local tbinfo = {}
        table.insert(tbinfo, self.base)--底分
        table.insert(tbinfo, self.maxmultiple)
        local tbinfoRlp , err = rlp.Encode(tbinfo) 
        if (err ~= nil) then
            -- body
            --err("RlpEncode err:"..err)
            print("RlpEncode err:"..err)
        end

        print("lua DeskCommonDataInit", tbinfoRlp)
        local pointmap = ge.GetPointMap()
        local points = ge.GetPoints()
        deskcData = deskCommonData.new(tbinfoRlp, curseat, publicCard, pointmap, points)
        ge.DeskCommonDataInit(deskcData, foldIds)
        local dcdbyte = deskcData:RlpEncode() 
        print("ws, dcdbyte = ", ws, dcdbyte)
        ws:SetData(dcdbyte)
        
    end

    --init 
    ge.WitnessInit(ws)

    local nc = notaireContext.new(ws, self.myseat, self.tableid, self.hand) 

    --init 
    ge.NotaireContextInit(nc)

    print("lua Send NotaireContext ....... ")
    ge.SubmitNotaryEx(nc, nodestr)
    print("lua Send NotaireContext Over .......")
end

--[[
    type NotaryApplyNotory struct {
	Table  common.Address
	Player common.Address
	Number *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}
]]
function applynotaryHandler(tableaddr, tableid, number)
    print("applynotaryHandler() ", tableaddr, tableid, number)

    local notarylist = rCtr.tc.Call("getNotaryList", tableaddr, tableid)
	print("applynotaryHandler() ", #notarylist)
	for i = 1, #notarylist do
        local address, nodestr, pawnAmount, locktime =  rCtr.tc.Call("getNotaryInfo", notarylist[i])
        print(address, nodestr, pawnAmount, locktime)
        gd:SendNotaireContext(nodestr)
    end

    gd.notarying = true
    ge.NotifyUI("BeginNotary", "")
end
--[[
    type TableManagerFinishNotary struct {
	Tableid *big.Int
	Hand    *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}
]]
function finishnotaryHandler(tableid, hand, data)
    print("finishnotaryHandler() ", tableid, hand, ", data = ", data)
    
    ge.NotifyUI("FinishNotary", "")

    local memCount = 3
    local GameSettleData = {}
    table.insert( GameSettleData, "")
    table.insert( GameSettleData, 0 )
    table.insert( GameSettleData, 0 ) 

    local  list = {} 
    
    for i = 1, memCount do
        local gdb = {0, 0, 0} 
        table.insert(list, gdb)
    end
    table.insert( GameSettleData , list)

    local gsdata, err = rlp.Decode(data, GameSettleData)
    print("finishnotaryHandler() err = ", err)
    if err == nil then

        print("gsdata = ", gsdata[1], gsdata[2], gsdata[3])
        print("gsdata[4][1] = ", gsdata[4][1][1], gsdata[4][1][2], gsdata[4][1][3])
        print("gsdata[4][2] = ", gsdata[4][2][1], gsdata[4][2][2], gsdata[4][2][3])
        print("gsdata[4][3] = ", gsdata[4][3][1], gsdata[4][3][2], gsdata[4][3][3])

        gd.settlelist = gsdata[4]
        for i = 1, memCount do
            if gsdata[4][i][2] == 0 then
                gd.winseat = gsdata[4][i][1]
                break
            end
        end
        gd:GameOverToUI()
    end

    gd.notarying = false
    
    if err==nil and gd.gamestate ~= -1 then
        local timerid = nil
        local fn = function()
            print(os.date("%Y/%m/%d %H:%M:%S ") .. "Qdz Timeout .....")
            if timerid ~= nil then
                timerid:stop()
            end
            --发牌超时，提交公证
            roomsettleHandler(hand, memCount, tableid, gd.nexthand)
        end
        timerid = timer.afterFunc(fn, 10) 
        --roomsettleHandler(hand, memCount, tableid)
    end

end

function game_ddz:watchNotary()
    print("game_ddz:watchNotary() ")
    rCtr.tc.WatchLog("ApplyNotory", applynotaryHandler)
    --self.tableManagercontract.WatchLog("FinishNotary", finishnotaryHandler)
    rCtr.tc.WatchLog("FinishNotary", finishnotaryHandler)
end

function ApplyNotary(num)
    gd:ApplyNotary(num) 
    --调用合约
end

ge.setCallback(ShuffleCardResult, DealCardResult, CheckCardResult, HandleMsg, ApplyNotary)
