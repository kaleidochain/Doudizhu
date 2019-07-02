-- local ge = require("gameengine")

local json = require("json")
--local eth  = require("eth")
local rlp  = require("rlp")
--local game = require("game")--结算用到game

--require("genseat")
--require("abi")

--print("notary.lua")

local AckMsg = 0x02


-- ///公证相关
-- const (
-- 	Init_check = iota
-- 	Po_check
-- 	Pk_check
-- 	Sf_check
-- 	Bl_check
-- 	R2_check
-- 	R3_check
-- 	R4_check
-- 	Rf_check
-- )

local Init_check = 0
local 	Po_check = 1
local 	Pk_check = 2
local 	Sf_check = 3
local 	Bl_check = 4
local 	R2_check = 5
local 	R3_check = 6
local 	R4_check = 7
local 	Rf_check = 8

NoCommit = -50
WitnessError  = -25
Timeout       = -20
DataError     = -10
VerifyFail    = -19
Cheat         = -18 --做弊，如下注额不对
StateTooSmall = -30
NoError       = -1 --没有错误，最先提交的罚1

    
Reason_Verify = 1
--Reason_SendFail --只送出了，没有收到一个ack
--Reason_LackAck --只收到部分ack,相当于部分人没收到，正常的话应该是最先提交的人没收到
Reason_SendFail = 2 --ack没收齐
Reason_Invalid = 3
Reason_Lack = 4   --少发消息
Reason_OpLack = 5 --对方少发消息
Reason_Cheat = 6
Reason_Tamper = 7 --对发过的消息做手脚,篡改
Reason_Hide = 8 --藏匿收到的消息
--Reason_Data

local function printtable(tbdsr)
    print("printtable enter")
    for i,v in pairs(tbdsr) do
        
        print(i,v)
        if type(v) == "table" then
            print("member table ", i)
            for ii,vv in pairs(v) do
                print(ii,vv)
                if type(vv) =="table" then
                    print("member table xx ", ii)
                    for iii,vvv in pairs(vv) do
                        print(iii,vvv)
                    end
                    print("member table xx end")
                end
            end
        print("member table end")
        end
    end
    print("printtable exit")
end

--[[
type BetData struct {
	Bet     uint64
	BetSeat SeatID
	DeskID  []byte
	ID      SeatID
}

//CheckOutKeyData 弃牌玩家发出的密钥
type CheckOutKeyData struct {
	Cursor []uint
	K      []*PublicKey
	E      []*big.Int
	Z      []*big.Int
}

type MsgAck struct {
	Deskid   DeskID
	DestSeat SeatID
	SrcSeat  SeatID

	MsgCode MsgCodeType //消息类型  code = 自定义的消息类型
	SeqNum  uint32
}

]]
local ackstruct = {0, 0, 0, 0, 0}--定义结构，为解码

function FindMsg(code, srcSeat, msglist)
	for i = 1, #msglist do
		if msglist[i].MsgCode == code and msglist[i].SrcSeat == srcSeat then
			return i, msglist[i]
        end
    end
	return -1, nil
end

function FindAckMsg(seqNum, srcSeat, msglist, startIndex)
    print("FindAckMsg() ", #msglist, msglist, seqNum)
	for i = startIndex, #msglist do
		if msglist[i].MsgCode == AckMsg and msglist[i].SrcSeat == srcSeat then
			--return i, &msglist[i]
			--ackMsg = {}
			--msgdata = MsgData{msglist[i].Data}
            --err = msgdata.Decode(ackMsg)
            local ack = rlp.Decode(msglist[i].Data, ackstruct)
            print("ack = ", ack[1], ack[2], ack[3], ack[4], ack[5])
            --if ack.SeqNum == seqNum then
            if ack[5] == seqNum then
			--if err == nil and ackMsg.SeqNum == seqNum then
				return i, msglist[i]
			end
		end
    end
	return -1, nil
end

function StepSingleOp(singleresult, msglists, memcount, cur, curTurn, msgCode, fnOpMsg, skipmsg)    
    --print("StepSingleOp() ", msglists, memcount, startIndex, cur, curTurn)
    --local singleresult = {}
    --singleresult.MakeUp = {}--make(map[int]*MsgWrap)
    
    local startIndex = singleresult.End
    -------------------------------------------------

    local curList = msglists[cur]
    
    --可能是上一状态的消息，先过滤掉
    for startIndex = startIndex, #curList do
        if curList[startIndex].MsgCode ~= skipmsg then
            break
        end
    end

    singleresult.End = startIndex
    print("StepSingleOp() seat, startIndex ", cur, startIndex, #curList, msgCode)
    local SeqNum = 0
    if startIndex < #curList then
        print("curList[startIndex].MsgCode = ", curList[startIndex].MsgCode)
    end
    --根据消息标记

    if startIndex >= (#curList+1) or curList[startIndex].MsgCode ~= msgCode then
        print("msgcode not equal cur, curTurn = ", startIndex == (#curList+1), cur, curTurn)
        if cur ~= curTurn then --没有收到下注消息，去发送方列表查找
            bFound, msg = FindMsg(msgCode, curTurn, msglists[curTurn])
            print("StepSingleOp() bFound, msg = ", bFound, msg)
            if bFound and msg ~= nil then
                if fnOpMsg(msg, singleresult) then

                    --这里也要查找发送方是否已经收到确认，如果有，则确认方藏匿消息了
                    local startx = startIndex-memcount
                    if startx < 1 then
                        startx = 1
                    end
                    local findpos, msgack = FindAckMsg(msg.SeqNum, cur, msglists[curTurn], startx)
                    print("Check Hide self ", findpos, msgack, msg.SeqNum, cur, curTurn, startx)
                    if msgack ~= nil then
                        print("Reason_Hide cur, curTurn, seqNum = ", cur, curTurn, msg.SeqNum)
                        singleresult.Reason = Reason_Hide
                        singleresult.Succ = false
                    else

                        singleresult.Data = msg.Data

                        singleresult.Succ = #singleresult.MakeUp == 0--原来有补齐的，两次后不往下走了
    
                        singleresult.MakeUp[singleresult.End] = msg
                        --rv.publicKeyflag = true
                        
                    end

                else
                    print("singleresult.Reason = Reason_Invalid")
                    singleresult.Reason = Reason_Invalid
                    singleresult.Succ = false
                end
            else
                print("singleresult.Reason = Reason_OpLack")
                singleresult.Reason = Reason_OpLack
            end
        else
            
            singleresult.Reason = Reason_Lack
            singleresult.Succ = false
        end
    else --成功
        --检查数据合法性即可
        if fnOpMsg(curList[startIndex], singleresult) then
            --保存到result.Data中
            singleresult.Data = curList[startIndex].Data

            SeqNum = curList[startIndex].SeqNum

            singleresult.Succ = true
        else
            singleresult.Reason = Reason_Invalid
            singleresult.Succ = false
        end
        --print("msgcode right cur, curTurn = ", cur, curTurn, singleresult.Succ)
        if cur ~= curTurn then
            singleresult.End = singleresult.End + 1
            if singleresult.Succ and curList[singleresult.End].MsgCode == AckMsg then --自己给下注方的ack
                local ack = rlp.Decode(curList[singleresult.End].Data, ackstruct)
                if ack[5] == curList[singleresult.End-1].SeqNum then
                    singleresult.End = singleresult.End + 1
                end
            else
                --要查找发送方是否已经收到确认，如果有，则确认方藏匿消息了
                --srcSeat要为cur，但列表是msglists[curTurn]
                local findpos, msg = FindAckMsg(curList[singleresult.End-1].SeqNum, cur, msglists[curTurn], startIndex)
                print("Check Hide ", findpos, msg)
                if msg ~= nil then
                    print("Reason_Hide cur, curTurn, seqNum = ", cur, curTurn, curList[singleresult.End-1].SeqNum)
                    singleresult.Reason = Reason_Hide
                end
            end
        elseif singleresult.Succ then
            --找memcount个ack，少的去别人列表找
            local count = 3*(memcount-1)+1--(memcount-1) * 2
            local ackflags = {} --从1开始，不会赋值0下标的值
            for i = 1, memcount do
                if i-1 ~= curList[startIndex].SrcSeat then
                    ackflags[i] = false
                end
            end
            local e = count+startIndex
            if e > #curList then
                e = #curList
            end
            --print("StepSingleOp() e = ", e)
            local nextpos = singleresult.End
            local bOtherMsg = false
            for i = startIndex+1, e do
                --print("i = ", i, ", curList[i].MsgCode = ", curList[i].MsgCode)
                if curList[i].MsgCode == AckMsg then
                    --检查合法性

                    local ack = rlp.Decode(curList[i].Data, ackstruct)
                    --printtable(ack)
                    --print("ack ", ack.SeqNum, ack[5], curList[startIndex].SeqNum)
                    --print("ack ", ack[1], ack[2], ack[3], ack[4], ack[5], curList[startIndex].SeqNum)
                    if ack[5] == curList[startIndex].SeqNum then
                    --if err == nil and pb.SeqNum == curList[startIndex].SeqNum then
                        --print("curList[i].SrcSeat = ", curList[i].SrcSeat)
                        ackflags[curList[i].SrcSeat+1] = true
                    end
                elseif not bOtherMsg then
                    --print("set nextpos = ", i)
                    nextpos = i --中间夹了其它消息，下次从这里开始，不然下一步缺少消息
                    bOtherMsg = true
                end
            end

            --printtable(ackflags)
            --如果ack缺失，去别的列表查找
            for i = 1, #ackflags do
                --print(ackflags[i], SeqNum)
                if ackflags[i] ~= nil and not ackflags[i] and SeqNum ~= 0 then
                    --print("call FindAckMsg i = ", i)--作msglists下标时要减1
                    local findpos, msg = FindAckMsg(SeqNum, i-1, msglists[i-1], startIndex)
                    print("FindAckMsg() return findpos, msg = ", findpos, msg)
                    if msg ~= nil then
                        singleresult.MakeUp[findpos] = msg
                        singleresult.Reason = Reason_SendFail
                        ackflags[i] = true
                    end
                end
            end

            local succ = true
            local ackcount = 0
            
            for i = 1, #ackflags do
                print("ackflags[i] = ", ackflags[i])
                if  ackflags[i] ~= nil then
                    if not ackflags[i] then
                        succ = false
                    else
                        ackcount = ackcount + 1
                    end
                end
            end
            print("#ackflags, ackcount = ", #ackflags, ackcount)
            if ackcount < #msglists-1 then
                singleresult.Reason = Reason_SendFail
                succ = false
            end

            singleresult.Succ = succ
            if succ then
                singleresult.End = singleresult.End + memcount
            end
            if bOtherMsg then
                singleresult.End = nextpos
            end
        else
            --print("cur ~= curTurn and singleresult.Succ false ")
            singleresult.Reason = Reason_Lack
        end
    end

    if singleresult.State == nil then
        singleresult.State = 0
    end
        --print("StepSingleOp() singleresult.Succ = ", singleresult.Succ)
    if singleresult.Succ then
        singleresult.State = singleresult.State + 1
    end
    return singleresult
end

function RecoverSingleOpRound(From, seatids, msglists, result, curTurn, conformToRules, mapMsgOp, skipmsg) 
    --print("RecoverSingleOpRound() ", From, seatids, msglists, result, curTurn)
    local memCount = #seatids
    --count := len(msglists)
    

    for i = 1, memCount do
        repeat
            --result[i].End是上次走的终点，要作为新的起点
            if result[i] == nil then
                result[i] = {}
                result[i].End = 1
                result[i].MakeUp = {}
            end
            --print("ready to gobet ", i, curTurn, result[i])
            --print(result[i].End)
            --print(msglists[curTurn])
            print("result[i].End > #msglists[seatids[i]] = ", i, result[i].End,  #msglists[seatids[i]])
            if result[i].End > #msglists[seatids[i]]+1 and #result[i].MakeUp==0 then
                --continue
                print("break")
                result[i].MakeUp = {}
                break
            end
            --func GoBet(msglists map[SeatID][]MsgWrap, memcount int, startIndex int, cur SeatID, curTurn SeatID) (result *BetResult) {
            
            for code, fn in pairs(mapMsgOp) do--循环是因为可能有多种消息
                StepSingleOp(result[i], msglists, #seatids, seatids[i], curTurn, code, fn, skipmsg)
                if result[i].Succ then--只要有一种消息走成功即可
                    break
                end
            end

            -- result[i] = StepSingleOp(msglists, #seatids, result[i].End, seatids[i], curTurn, fnOpMsg)
            -- --print((*result)[i])
            --lua中table的长度以最大的为准，只赋值一个t[9]，长度即为9了
            --print("RecoverSingleOpRound() result[i] = ", i, result[i], result[i].Succ, #(result[i].MakeUp), result[i].Reason)
            -- printtable(result[i])
            result[i].Seat = seatids[i]
        until true
    end
    
    --判断状态差
    bContinue = true
    for i = 1, #result do --需再对比playinfo
        if not result[i].Succ then--or #result[i].MakeUp > 0 then
            bContinue = false
        end
    end
    
    if bContinue then --状态差为0，看是否是通过补齐的，只有状态差为0且都不需要补齐才继续往前走
        --一起继续往前走
        --CheckState++

        --还要比较数据是否一致
        --bet := result[0].Bet
        local data = result[1].Data
        --print("data: ", data)
        bEqual = true
        --比较bet数据，现只比较原始数据，原始数据一致即合法，不可能不合法还能一起把游戏走下去的
        for i = 1, #result do
            --if result[i].Bet != bet {
            --print("data: ", i, result[i].Data)
            iCmp = bytesCompare(result[i].Data, data)
            if iCmp ~= 0 then --数据不一致时，以接收者为准，因为有了签名只有发送者才能伪造
                if result[i].Seat == curTurn then
                    result[i].Reason = Reason_Tamper
                    result[i].Succ = false
                else
                    result[1].Reason = Reason_Tamper
                    result[1].Succ = false
                end
                bEqual = false
                break
            end
        end
        if not bEqual then
            print(" data not equal return false")
            return false
        end

        if not conformToRules(result, seatids, curTurn) then
            return false
        end

        --[[ 有可能一个操作需要多个消息，如出牌，不仅要出牌消息，还要有解牌消息
        bEnd = true --如果都没有下注的消息，就不往下走了
        for i = 1, #seatids do
            --print("end ", curTurn, result[i].End, #msglists[curTurn], msglists[curTurn][result[i].End].MsgCode)
            if result[i].End < #msglists[curTurn] then
                for msg,fn in pairs(mapMsgOp) do
                    if msglists[curTurn][result[i].End].MsgCode == msg then
                        bEnd = false
                        break
                    end
                end

                --(msglists[curTurn][result[i].End].MsgCode == BetDataCode or
                --msglists[curTurn][result[i].End].MsgCode == CheckOutDataCode) then
                    --print("set bEnd = false")
                --bEnd = false

                break
            end
        end
        --print("bEnd = ", bEnd)
        if bEnd then
            print(" c return ")
            return false
        end
        ]]

        --要做一些处理，如操作者往下移等
        --curTurn = curTurn + 1

    else
        --print(" d return ")
        return false
    end
    --print(" e return ")
    return true
end

function RecoverConsensus(msglist, startindex, id, oids, msgcode, msgstruct)
    local nps = {["id"]=id}
    nps.nrs = {}
    nps.MakeUp = {}
    for i = 1, #oids do
        --print("oids[i] = ", oids[i])
        nps.nrs[oids[i]] = {["id"]=oids[i]}
    end

    --print("startindex, #msglist = ", startindex, #msglist)
    for i = startindex, #msglist do
        --print("msglist[i].MsgCode = ", msglist[i].MsgCode)
        if msglist[i].MsgCode == msgcode then
            local md = rlp.DoubleDecode(msglist[i].Data, msgstruct)
            --print("BetSignDataCode ", msglist[i].SrcSeat, id)
            if msglist[i].SrcSeat == id then
                nps.seqnum = msglist[i].SeqNum-- 用于寻找补齐消息的
                nps.pb = msglist[i].Data
            else
                print("msglist[i].SrcSeat = ", msglist[i].SrcSeat)
                nps.nrs[msglist[i].SrcSeat].pb = msglist[i].Data
            end
        elseif msglist[i].MsgCode == AckMsg then
            --print("AckMsg msglist[i].SrcSeat, id = ", msglist[i].SrcSeat, id)
            if msglist[i].SrcSeat ~= id then
                local md = rlp.Decode(msglist[i].Data, ackstruct)
                --if md.MsgCode == BetSignDataCode then
                --print("md = ", md[1],md[2],md[3],md[4],md[5])
                if md[4] == msgcode then
                    print("ack msglist[i].SrcSeat = ", msglist[i].SrcSeat)
                    nps.nrs[msglist[i].SrcSeat].publicKeyRspflag = true
                end
            end
        end
    end
    return nps
end

--lua没有go的slice，所以要传一下startindexes
function CompareConsensus(judge, msglists, startindexes, memCount, seatids, msgcode, msgstruct)
    local resultCon = {}
    for i = 1, memCount do
        --var otherids []gutils.SeatID = make([]gutils.SeatID, 0)
        local otherids = {}
        for j = 1, #seatids do
            if seatids[j] ~= seatids[i] then
                table.insert(otherids, seatids[j])
                --otherids = append(otherids, v)
            end
        end
        resultCon[i] = RecoverConsensus(msglists[seatids[i]], startindexes[i], seatids[i], otherids, msgcode, msgstruct)
        print("RecoverConsensus resultCon[i] = ", seatids[i], #msglists[seatids[i]], resultCon[i])
        --printtable(resultCon[i])
        resultCon[i].Seat = seatids[i]
    end
    --补齐
    local nRet = 0
    for i = 1, #resultCon do
        print("resultCon[", i, "].pb = ", resultCon[i].pb)--#resultCon[i].nrs)不需要打印长度了，不准的，而且有可能下标为0的不准在长度中
        if resultCon[i].pb == nil then
            judge.Result[resultCon[i].id] = Reason_Lack
            judge.GameOver = true
            print("resultCon[", i, "].pb == nil")
            nRet = 1
        end

        for j, v in pairs(resultCon[i].nrs) do
            print("vi.pb, publicKeyRspflag = ", i, resultCon[i].nrs[j].pb, resultCon[i].nrs[j].publicKeyRspflag)
            if resultCon[i].nrs[j].pb == nil then
                local bFound, msg = FindMsg(msgcode, v.id, msglists[resultCon[i].nrs[j].id])
                if msg ~= nil then
                    print("CompareConsensus() bFound, msg = ", bFound, msg.SeqNum)
                    --local md = rlp.DoubleDecode(msg.Data, msgstruct)
                    table.insert(resultCon[i].MakeUp, msg)
                else
                    judge.Result[resultCon[i].id] = Reason_Lack
                end
                print("resultCon[", i, "].nrs[", j, "].pb == nil")
                nRet = 2
            end
            --[[ack不补齐了，ack不影响流程
            if not resultCon[i].nrs[j].publicKeyRspflag then
                local bFound, msg = FindAckMsg(resultCon[i].seqnum, resultCon[i].nrs[j].id, msglists[resultCon[i].nrs[j].id], 1)
                print("AckMsg bFound, msg = ", resultCon[i].seqnum, bFound, msg)
                if msg ~= nil then
                    local md = rlp.Decode(msg.Data, ackstruct)
                    table.insert(resultCon[i].msglist, md)
                else
                    judge.Result[resultCon[i].id] = Reason_Lack
                end
                print("not resultCon[", i, "].nrs[", j, "].publicKeyRspflag")
                nRet = 4
            end
            ]]
        end
    end

    print("CompareConsensus() nRet = ", nRet)
    if nRet == 0 then
        local bConsensusEqual = true
        local settleResult = resultCon[1].pb --lua talbe类型的，不是userdata
        for i = 2, #resultCon do
            local ncomp = bytesCompare(resultCon[i].pb, settleResult)
            print("ncomp = ", ncomp)
            if ncomp ~= 0 then
                bConsensusEqual = false
                break
            end
        end

        print("bConsensusEqual = ", bConsensusEqual)
        if bConsensusEqual then
            judge.Result[From] = NoError
            judge.GameOver = false
            return nRet,resultCon
        end
        --需要外面再判断哪个是对的，如结算哪个是对的
        return bConsensusEqual,resultCon
    else
        --return nRet,resultCon
        return false, resultCon
    end
end
