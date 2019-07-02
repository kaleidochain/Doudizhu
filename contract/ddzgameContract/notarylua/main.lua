
local json = require("json")
local eth  = require("eth")
local rlp  = require("rlp")

local ddz = require("doudizhu")

--require("genseat")
require("abi")
require("notary")

require("game_ddz")

local notarypm = require("notarypm")

function NotaryMain(CheckState, From, seatids, msglists, desk, notarycontext)
    if CheckState == ConsensusStateType.Sf_check then
        return NotaryGrabByMsgList(CheckState, From, seatids, msglists, desk, notarycontext)
    else
        return NotaryPlayByMsgList(CheckState, From, seatids, msglists, desk, notarycontext)
	end
end

-- local grabInfo = {} 
-- table.insert( grabInfo, self.myseat)
-- table.insert( grabInfo, op ) 
-- local gbData , err = rlp.Encode(grabInfo)
local stGrabData = {""}

local stGrabSignData = {"", "", "", 0}
local stSettleSignData = {"", "", "", 0}

local g_curGrab = 0 --当前叫地主分数
local g_lordseat = -1

local FinalshuffleSignDataCode = 0x26

local KeyCardDataCode = 0x27

local function checkGrabMsg(msg, singleresult)
    --print("msg.MsgCode = ", msg.MsgCode)
    if msg.MsgCode == GrabDataCode then
        local stGrabInfo = {0, 0}
        local grabInfo = rlp.DoubleDecode(msg.Data, stGrabInfo)
        --print("grabInfo = ", grabInfo[1], grabInfo[2])
        singleresult.Grab = grabInfo[2]
        return true
    end
    return false
end

local function GrabConformToRules(result, seatids, curTurn)
    print("GrabConformToRules() ", result, curTurn)
    print("", result[curTurn+1])
    print("GrabConformToRules() ", curGrab, result[curTurn+1].Grab)
    --[[不需要比前面的大
    if curGrab < result[curTurn+1].Grab then
        curGrab = result[curTurn+1].Grab
        return true
    else
        --return false
    end
    ]]
    if g_curGrab < result[curTurn+1].Grab then
        g_curGrab = result[curTurn+1].Grab
        g_lordseat = curTurn
    end
    return true
end

local g_playinfos = {}
local g_playresult = {Type = ddz.HandPatternsType.EVERYCARDTYPE, Max = 3, Size = 0, Value = 3}
local g_passcount = 0
local g_playCardCount = {}
--还要记录很多当前牌局的信息，相当于game_ddz的数据成员

local fnCheckPlayCardMsg = function(msg, singleresult) --bool {
    
    --md := MsgData{Data: msg.Data}
    if msg.MsgCode == PlayDataCode then
        --singleresult.Data = msg.Data

        local st = {0, 0, "", ""} --seat, op, indexstr, cardstr
        local playinfo = rlp.DoubleDecode(msg.Data, st)

        singleresult.playinfo = playinfo

        --print("fnCheckPlayCardMsg() playinfo[1], playinfo[2] = ", playinfo[1], playinfo[2], playinfo[3], playinfo[4])
        --playinfo[1]为座位号,playinfo[2]为o——为0时表示不出,1表示出牌
        --if playinfo[1] ~= 0 and playinfo[2] ~= 0 then
            table.insert(g_playinfos, playinfo)
            return true
        --else

        --end
    else
        print("fnCheckPlayCardMsg() msg.MsgCode = ", msg.MsgCode)
    end

    print("fnCheckPlayCardMsg() return false")
    return false
    --return true --temp
end --fnPlayCardMsg

--[[
local function fnCheckKeyData(msg, singleresult)
    --不需要处理，只标识发牌消息是合法的
    return true
end
]]
local split = function(s, p)

    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt

end

local g_multiple = 1
local g_maxmultiple = 16

local function PlayConformToRules(result, seatids, curTurn)

    --print("PlayConformToRules() ", result[1].playinfo[1],result[1].playinfo[2],result[1].playinfo[3],result[1].playinfo[4])

    local cardsstr = result[1].playinfo[4]
    --print("", cards, ddz, ddz.judgePokerType)
    if result[1].playinfo[2]==0 then --不出
        g_passcount = g_passcount + 1
        if g_passcount == 2 then
            g_playresult = {Type = ddz.HandPatternsType.EVERYCARDTYPE, Max = 3, Size = 0, Value = 3}
        end
        return result,true
    end

    g_passcount = 0

    local lcard = split(cardsstr, "," )
    local  cards = {}
    for i,v in ipairs(lcard) do
        table.insert( cards, tonumber(v) )
    end

    local playresult = ddz:judgePokerType(cards) 
    --print("", playresult.Type, playresult.Value)

    local canplay = isCanPlay(playresult, g_playresult)
    if canplay then
        if g_playCardCount[result[1].playinfo[1]]==nil then
            g_playCardCount[result[1].playinfo[1]] = 0
        end
        g_playCardCount[result[1].playinfo[1]] = g_playCardCount[result[1].playinfo[1]] + #cards
        if (playresult.Type ==ddz.HandPatternsType.ROCKET  or playresult.Type ==ddz.HandPatternsType.BOMB) then
            -- 炸弹和火箭倍数乘2
            g_multiple = g_multiple * 2 
            if g_multiple > g_maxmultiple then 
                g_multiple = g_maxmultiple
            end
        end
    else
        print("PlayConformToRules() canplay = ", canplay)
    end

    g_playresult = playresult
    return result,canplay

end

local firstTurn = 0
function isOverGrab(optimes)

    for i,v in ipairs(optimes) do
        if v==0 then
            return false
        end
    end
    if g_lordseat~=0 and optimes[firstTurn]~=2 then
        return false
    end
    return true
end

function NotaryGrabByMsgList(CheckState, From, seatids, msglists, desk, notarycontext, bBlind)

    local bBlind = CheckState == ConsensusStateType.Sf_check
    print("lua NotaryGrabByMsgList() ", CheckState, From, #seatids, #msglists, desk, notarycontext.Wt, bBlind)
    local judge = {}
    judge.Result = {}
    local count = #msglists
    local memCount = #seatids
    for i = 1, memCount do
        --print("a ", seatids[i], msglists[seatids[i]] )
        if msglists[seatids[i]] == nil then
            print("b ", i)
            judge.Result[seatids[i]] = NoCommit
        end
    end

    if #judge.Result>0 then
        print("judge.Result ", judge.Result)
        judge.GameOver = true
        --[[
        for _, v := range seatids {
			if _, ok := msglists[v]; !ok {
				judge.Result[v] = NoCommit
			}
		}]]
        return judge
    end

    --result := make([]*BetResult, count)
    local result = {} --RecoverBetRound会初始化

	local allSucc = true
	--bHasSucc := false --其中有一个成功
	local bMakeUp = false --是否有通过补齐的

    local curTurn = desk.CurTurn --总是0,斗地主的不是玩家传的，都是从0开始抢地方
    
    local mapMsgOp = {}
    mapMsgOp[GrabDataCode] = checkGrabMsg

    local startIndexs = {}
    for i = 1, #seatids do
        startIndexs[i] = 0
    end
    local bAllEqual, cards, judge, newIndexes = CompareRecoverDealcards(seatids, msglists, startIndexs, 1, desk, notarycontext.Wt, false, FinalshuffleSignDataCode)
    print("bAllEqual, cards, judge = ", bAllEqual, cards, judge, newIndexes[1], newIndexes[2], newIndexes[3])
    if not bAllEqual then
        commitJudge(judge, notarycontext)
        return judge
    --fmt.Println("!bAllEqual ", judge)
        --return
    end
        

    --searchRange = 3*(memCount-1) + 1
    --searchRange = searchRange + 1--lua的下标比其它的多1
    
    --local searchRange = 9

    for i = 1, memCount do
        result[i] = {}
        result[i].End = newIndexes[i]+1+8--+1因为lua从1开始
        result[i].MakeUp = {}
    end

    --抢地主
    local optimes = {0, 0, 0}
    firstTurn = curTurn --要为全局的,isOverGrab用到
    local bTimerout = true

    while true do
        
        bSucc = RecoverSingleOpRound(From, seatids, msglists, result, curTurn, GrabConformToRules, mapMsgOp)
        print("bSucc = ", bSucc)
        if not bSucc then
            
            for i = 1, memCount do
                print("result[i].State = ", result[i].State)
            end

            for i = 1, memCount do
                print("result[i].Reason = ", result[i].Reason, result[i].State)
                if result[i].Reason ~= nil or #result[i].MakeUp then
                    print("i, reason = ", i, seatids[i], result[i].Reason, #result[i].MakeUp)
                    if result[i].Reason == Reason_Invalid then
                        judge.Result[seatids[i]] = Cheat--与出牌消息签名有误一致，都判为作弊
                    end
                    bTimerout = false
                    break
                end
            end
            if bTimerout then
                judge.Result[curTurn] = Timeout
            end
            break
        end
        
        
        optimes[curTurn+1] = optimes[curTurn+1]+1
        print("optimes[curTurn] = ", optimes[curTurn])
        if isOverGrab(optimes) then
            bTimerout = false --成功，要把bTimerout置为false，因为bTimerout默认为true
            break
        end
        
        curTurn = (curTurn + 1) % 3

        local bEnd = true
        for i = 1, #seatids do
            --[[
            result[i].End = result[i].End + memCount-1
            if curTurn==i-1 then --自己发的消息，多一个消息
                result[i].End = result[i].End + 1
            end
            ]]
            --print("next result[", i, "].End = ", othermsgs[i], result[i].End)
            print("next result[", i, "].End = ", result[i].End, #msglists[seatids[i]])
            if result[i].End < #msglists[seatids[i]] then --只要有一个还有消息，就继续，看能否补齐
                bEnd = false
            end
        end
        if bEnd then
            
            --如果是单轮补齐的，回退curTurn
            local prev = curTurn - 1
            if prev < 0 then
                prev = 2
            end
            print("prev = ", prev)
            for i = 1, memCount do
                --print("result[i].Reason = ", result[i].Reason, result[i].State)
                if result[i].Seat == prev and result[i].Reason == Reason_SendFail and #result[i].MakeUp then
                    print("prev, i, reason = ", i, prev, #result[i].MakeUp)
                    curTurn = prev
                    bTimerout = false
                    break
                end
            end
    
            break
        end

    end

    --判断是否适合消息补齐，要且只要发送的状态为Reason_SendFail
    print("bTimerout, curTurn = ", bTimerout, curTurn, result, #result)
    local curIndex = 1
    for i = 1, #result do
        if result[i].Seat == curTurn then
            curIndex = i
            break
        end
    end
    
    print("curTurn, curIndex = ", curTurn, curIndex)

    --print("result[curIndex] = ", result[curIndex])
    --print("result[curIndex].Reason = ", result[curIndex].Reason)
    bMakeUp = result[curIndex].Reason==Reason_SendFail
    for i = 1, #result do
        if result[i].Reason == Reason_Hide then
            bMakeUp = false
            --清空补齐的消息
            for i = 1, #result do
                result[i].MakeUp = {}
            end
            break
        end
    end
    print("bMakeUp, curIndex = ", bMakeUp, curIndex)
    if not bMakeUp then
        --发送并没有发送失败，则发送者已经收到确认，如果还发现需要补齐，是假补齐，作弊的
        for i = 1, #result do --
            print("i, result[i].Succ = ", i, result[i].Succ, #result[i].MakeUp, result[i].Reason)
            
            if #result[i].MakeUp>0 then
                result[i].Succ = false
                result[i].Reason = Reason_Hide
            end
        end
    else
        --再检查是否有作弊假补齐的，那就是发送已经收到ack，但确认方藏匿，放在StepSingleOp更好做
        
        --不提交公证结果，补发消息给游戏
        local makeupcount = 0
        for i = 1, #result do --
            if #result[i].MakeUp > 0 then
                --notarypm.Send(notarycontext.TableCtr, result[i].Seat, result[i].MakeUp[#result[i].MakeUp])
                --再考虑补齐多个消息的……
                print("seat, makeupcount = ", result[i].Seat, makeupcount)
                for j = 1, #result[i].MakeUp do
                    if result[i].MakeUp[j] ~= nil then
                        makeupcount = makeupcount + 1
                        notarypm.Send(notarycontext.TableCtr, result[i].Seat, result[i].MakeUp[j])
                    end
                end
            end
        end

        return makeupcount--不走公证结果了，公证结果相当于结算后结束游戏
    end

    if bTimerout and not isOverGrab(optimes) then
        print("set judge.Result[curTurn+1] = Timeout 3")
        judge.Result[curTurn+1] = Timeout
    end
    
    if bSucc and isOverGrab(optimes) then
        local startIndexs = {}
        for i = 1, #seatids do
            startIndexs[i] = result[i].End - 1 -- 减掉1,go从0开始，lua从1开始
        end
        --抢地主共识
        local bSucc,resultCon = CompareConsensus(judge, msglists, startIndexs, memCount, seatids, GrabSignDataCode, stGrabSignData)
        if not bSucc then
            print("CompareConsensus return fail")
            local makeupcount = 0
            for i = 1, #resultCon do --
                if #resultCon[i].MakeUp > 0 then
                    --notarypm.Send(notarycontext.TableCtr, result[i].Seat, result[i].MakeUp[#result[i].MakeUp])
                    --再考虑补齐多个消息的……
                    print("seat, makeupcount = ", resultCon[i].Seat, makeupcount)
                    for j = 1, #resultCon[i].MakeUp do
                        if resultCon[i].MakeUp[j] ~= nil then
                            makeupcount = makeupcount + 1
                            notarypm.Send(notarycontext.TableCtr, resultCon[i].Seat, resultCon[i].MakeUp[j])
                        end
                    end
                end
            end
            print("grabconsensus not bSucc makeupcount = ", makeupcount)
            if makeupcount > 0 then
                return makeupcount--不走公证结果了，公证结果相当于结算后结束游戏
            end
            --return judge
        end
    else
        for i = 1, #result do
            print("i, result[i].Succ, result[i].Reason = ", i, result[i].Succ, result[i].Reason, result[i].Seat, result[i].End)
            --print("", msglists[result[i].Seat], msglists[result[i].Seat][result[i].End-1])
            if not result[i].Succ then
                if result[i].Reason == Reason_Verify then
                    --找到发送者
					--msg := msglists[v.Seat][v.End-1]
					judge.Result[msg.SrcSeat] = VerifyFail
                elseif result[i].Reason == Reason_SendFail then
                    --补齐

                    judge.GameOver = false
                elseif result[i].Reason == Reason_Invalid then
                    --local msg = msglists[v.Seat][v.End-1]
                    local msg = msglists[result[i].Seat][result[i].End-1]
                    print("msg = ", msg, msg.SrcSeat)
                    judge.Result[msg.SrcSeat] = Cheat
                elseif result[i].Reason == Reason_Tamper then
                    judge.Result[result[i].Seat+1] = Cheat
                elseif result[i].Reason == Reason_Hide then
                    judge.Result[result[i].Seat+1] = Cheat
                elseif result[i].Reason == Reason_Lack then
                    judge.Result[curTurn+1] = Timeout
                elseif result[i].Reason == Reason_OpLack then
                    judge.Result[curTurn+1] = Timeout
                end
            end
        end
    end

    return commitJudge(judge, notarycontext)
end

function IsNeedDecrypt(indexstr, card, curTurn, lordseat)
    local lindex = split(indexstr, "," )
    for i,v in ipairs(lindex) do
        if tonumber(v) < 17+math.abs(curTurn-lordseat)*17 then
            return true
        end
    end
    return false
end

function NotaryPlayByMsgList(CheckState, From, seatids, msglists, desk, notarycontext)
    local bBlind = false
    print("lua NotaryPlayByMsgList() ", CheckState, From, #seatids, #msglists, desk, notarycontext.Wt, bBlind)

    local judge = {}
    judge.Result = {}
    local count = #msglists
    memCount = #seatids
    for i = 1, memCount do
        --print("a ", seatids[i], msglists[seatids[i]] )
        if msglists[seatids[i]] == nil then
            print("b ", i)
            judge.Result[seatids[i]] = NoCommit
        end
    end

    if #judge.Result>0 then
        print("judge.Result ", judge.Result)
        judge.GameOver = true
        --[[
        for _, v := range seatids {
			if _, ok := msglists[v]; !ok {
				judge.Result[v] = NoCommit
			}
        }]]
        commitJudge(judge, notarycontext)
        return judge
    end

    --result := make([]*BetResult, count)
    local result = {} --RecoverBetRound会初始化

	local allSucc = true
	--bHasSucc := false --其中有一个成功
    local bMakeUp = false --是否有通过补齐的
    local bSucc = true

    print("desk.BetData2 = ", desk.BetData2)
    local tbst = {0, 0}
    local tbinfo = rlp.Decode(desk.BetData2, tbst)
    print("", tbinfo[1], tbinfo[2], tbinfo[3])--base maxmultiple
    --g_multiple = tbinfo[2]--还要算抢地主的倍数
    --g_maxmultiple = tbinfo[3]
    g_multiple = 1
    g_maxmultiple = tbinfo[2]

    local lordseat = desk.CurTurn
    local curTurn = desk.CurTurn --从共识中获取，地主位
    local settleKeyCount = 2

    print("curTurn, #seatids, #msglists = ", curTurn, #seatids, #msglists)
    
    if allSucc then
        --searchRange := 3*(memCount-1) + 1
        --发三张明牌
        local startIndexs = {}
        for i = 1, #seatids do
            startIndexs[i] = 0
        end
        bAllEqual, cards, judge, startIndexs = CompareRecoverDealcards(seatids, msglists, startIndexs, 1, desk, notarycontext.Wt, true, GrabSignDataCode)
        print("bAllEqual, cards, judge = ", bAllEqual, cards, judge, startIndexs)
        if not bAllEqual then
        --fmt.Println("!bAllEqual ", judge)
            --return
        end
        
        
        for i = 1, #seatids do
            result[i] = {}
            result[i].State = 0
            --print("startIndexs[", i, "] = ", startIndexs[i])
            result[i].End = 8 + startIndexs[i] -- 去掉前面发3张明牌的消息
            result[i].MakeUp = {}
        end

        --fmt.Println("dealcards ", judge)
        --判断消息是否一致，有可能自己的消息和发给别人的不一样，但合理且签名正确
        --比如本来自己发给别人的是下注20，结果提交上来的是下注10，或者放在走完列表后判断？

        local mapMsgPlay = {}
        mapMsgPlay[PlayDataCode] = fnCheckPlayCardMsg
        --mapMsgPlay[KeyCardDataCode] = fnCheckKeyData --不能这么标识，影响其它地方了
        
        local bAllEqual, cards

        --各轮出牌
        while true do
            bSucc = RecoverSingleOpRound(From, seatids, msglists, result, curTurn, PlayConformToRules, mapMsgPlay, GrabSignDataCode)
            --print("RecoverSingleOpRound() return bSucc = ", bSucc)
            if not bSucc then
                print("RecoverSingleOpRound() return bSucc = ", bSucc)
                break
            end

            local othermsgs = {0, 0, 0}

            local bDecrypt = false

            --取一个就可以，上面成功的话，应该是相等的
            --print("playinfo ", result[1].playinfo, result[1].playinfo[3], result[1].playinfo[4])
            if result[1].playinfo ~= nil and result[1].playinfo[2] == 1 then
                local cardsCount = 17
                if curTurn == lordseat then
                    cardsCount = 20
                end
                print("lordseat, curTurn, cardsCount = ", lordseat, curTurn, cardsCount, g_playCardCount[result[1].playinfo[1]])
                if g_playCardCount[result[1].playinfo[1]]==cardsCount then--出完牌了，走结算
                    break
                end
                
                bDecrypt = IsNeedDecrypt(result[1].playinfo[3], v, curTurn, lordseat)
                if bDecrypt then
                    --出牌，如果不是选择不出的话，要有解牌消息
                    local startIndexs = {}
                    for i = 1, #seatids do
                        startIndexs[i] = result[i].End - 1 -- 减掉1,go从0开始，lua从1开始
                    end
                    
                    bAllEqual, cards, judge, othermsgs = CompareRecoverDealcards(seatids, msglists, startIndexs, 1, desk, notarycontext.Wt, true, PlayDataCode)
                    --print("bAllEqual, cards, judge = ", bAllEqual, cards, judge, othermsgs)
                    --对比cards和result[1].playinfo[4]

                    if not bAllEqual then
                    --fmt.Println("!bAllEqual ", judge)
                        --return
                        break
                    end
                end
            end

            local bEnd = false
            for i = 1, #seatids do
                result[i].End = result[i].End + othermsgs[i]
                if bDecrypt then
                    result[i].End = result[i].End + 7
                end
                --print("next result[", i, "].End = ", othermsgs[i], result[i].End)
                if result[i].End > #msglists[seatids[i]] then
                    bEnd = true
                end
            end
            if bEnd then
                break
            end
            
            curTurn = curTurn + 1
            if curTurn > 2 then
                curTurn = 0
            end

        end

        for i = 1, #result do
            if not result[i].Succ then
                allSucc = false
            else
                --bHasSucc = true
            end
            if #result[i].MakeUp > 0 then
                bMakeUp = true
            end
        end
        print("print lua judge = ", judge, allSucc)

        if result[1].playinfo~=nil then
            if IsNeedDecrypt(result[1].playinfo[3], v, curTurn, lordseat) then
                settleKeyCount = 3
            end
        end
    end

    print("result[1].End, #msglists[1] = ", curTurn, result[1].End, result[curTurn+1].End, #msglists[curTurn])
    --print("result[1].End, #msglists[1] = ", curTurn, result[1].End, msglists[curTurn])

    local curIndex = 1
    for i = 1, #result do
        if result[i].Seat == curTurn then
            curIndex = i
            break
        end
    end

    local bMakeUp = result[curIndex].Reason==Reason_SendFail
    for i = 1, #result do
        if result[i].Reason == Reason_Hide then
            bMakeUp = false
            --清空补齐的消息
            for i = 1, #result do
                result[i].MakeUp = {}
            end
            break
        end
    end
    print("bMakeUp, curIndex = ", bMakeUp, curIndex)
    if not bMakeUp then
        --发送并没有发送失败，则发送者已经收到确认，如果还发现需要补齐，是假补齐，作弊的
        for i = 1, #result do --
            print("i, result[i].Succ = ", i, result[i].Succ, #result[i].MakeUp, result[i].Reason)
            
            if #result[i].MakeUp>0 then
                result[i].Succ = false
                result[i].Reason = Reason_Hide
            end
        end
    else
        --再检查是否有作弊假补齐的，那就是发送已经收到ack，但确认方藏匿，放在StepSingleOp更好做
        
        --不提交公证结果，补发消息给游戏
        local makeupcount = 0
        for i = 1, #result do --
            if #result[i].MakeUp > 0 then
                --notarypm.Send(notarycontext.TableCtr, result[i].Seat, result[i].MakeUp[#result[i].MakeUp])
                --再考虑补齐多个消息的……
                print("seat, makeupcount = ", result[i].Seat, makeupcount)
                for j = 1, #result[i].MakeUp do
                    if result[i].MakeUp[j] ~= nil then
                        makeupcount = makeupcount + 1
                        notarypm.Send(notarycontext.TableCtr, result[i].Seat, result[i].MakeUp[j])
                    end
                end
            end
        end

        return makeupcount--不走公证结果了，公证结果相当于结算后结束游戏
    end

    if result[curIndex].End > #msglists[curTurn] then
        result[curIndex].Reason = Reason_Lack
        result[curIndex].Succ = false
        allSucc = false
    end

    if allSucc then
        
        local seatSortFun = function(a, b)
            return a.State  < b.State 
        end
        table.sort( result, seatSortFun ) 

        --判断状态差，如果大于1，是不合法的，比
        print("result[#result].State, result[1].State = ", result[#result].State, result[1].State)
        if result[#result].State - result[1].State > 1 then
            print("state diff > 1", result[#result].State - result[1].State)
            for i = 2, #result do
				if result[i].State-result[1].State > 1 then
					judge.Result[result[i].Seat] = StateTooSmall
                end
            end
            judge.GameOver = true
            return judge
        end

        --判断是否超时
        local curSeat = msglists[0][#msglists[0]].SrcSeat
        local diff = result[count].State-result[1].State
		if CheckState >= ConsensusStateType.Sf_check and diff == 0 then
			
            local Oper = curSeat + 1
            if Oper > memCount then
                Oper = 1
            end
            print("Oper = ", Oper)
            judge.Result[Oper] = Timeout
            judge.GameOver = true

			--return
        end

        --前操作者缺ack及后面的消息，
        if CheckState >= ConsensusStateType.Sf_check and result[count].State-result[1].State == 1 then
            print("diff 1 ", CheckState)
			--再尝试补齐,状态大的要为发送者，且只有他一个
			if count > 2 and result[count-1].State == result[1].State then
                --var msg *gutils.MsgWrap
                local msg = nil
                for i = 1, #msglists[result[count].Seat] do
                    local v = msglists[result[count].Seat][i]
					if v.SrcSeat == result[count].Seat and
						v.MsgCode ~= AckMsg then
						msg = v
                    end
                end
				for i = 1, count-1 do
					result[i].MakeUp[result[i].End] = msg
                end

                --
                for i = 1, #result do --
                    if #result[i].MakeUp > 0 then
                        notarypm.Send(notarycontext.TableCtr, result[i].Seat, result[i].MakeUp[#result[i].MakeUp])
                        
                    end
                end
            end

			judge.GameOver = false

			return 1
        end

		if bMakeUp then --通过补齐的，可能是因为丢包
			judge.GameOver = false
            --不奖不罚
            print("bMakeUp")
            
            for i = 1, #result do --
                if #result[i].MakeUp > 0 then
                    notarypm.Send(notarycontext.TableCtr, result[i].Seat, result[i].MakeUp[#result[i].MakeUp])
                end
            end

            
			return
        end

        local cardsCount = 17
        if curTurn == lordseat then
            cardsCount = 20
        end
        if g_playCardCount[result[1].playinfo[1]]==cardsCount then--出完牌了，走结算
            local startIndexs = {}
            for i = 1, #seatids do
                startIndexs[i] = result[i].End - 1 -- 减掉1,go从0开始，lua从1开始
            end
            local bSucc,resultCon = CompareConsensus(judge, msglists, startIndexs, memCount, seatids, SettleSignDataCode, stGrabSignData)
            if not bSucc then
                print("CompareConsensus return fail")
                local makeupcount = 0
                for i = 1, #resultCon do --
                    if #resultCon[i].MakeUp > 0 then
                        --notarypm.Send(notarycontext.TableCtr, result[i].Seat, result[i].MakeUp[#result[i].MakeUp])
                        --再考虑补齐多个消息的……
                        print("seat, makeupcount = ", resultCon[i].Seat, makeupcount)
                        for j = 1, #resultCon[i].MakeUp do
                            if resultCon[i].MakeUp[j] ~= nil then
                                makeupcount = makeupcount + 1
                                notarypm.Send(notarycontext.TableCtr, resultCon[i].Seat, resultCon[i].MakeUp[j])
                            end
                        end
                    end
                end
                print("settle consensus not bSucc makeupcount = ", makeupcount)
                if makeupcount > 0 then
                    return makeupcount--不走公证结果了，公证结果相当于结算后结束游戏
                end
                --return judge
            end
            local bAllEqual, cards, judgeTemp = CompareRecoverDealcards(seatids, msglists, startIndexs, settleKeyCount, desk, notarycontext.Wt, true, 0)
            print("CompareSettlecards() bAllEqual, cards, judge = ", bAllEqual, cards, judge, othermsgs)
            if not bAllEqual then
            --fmt.Println("!bAllEqual ", judge)
                --return
                --break
            end
            judge = judgeTemp

            if not bSucc then
                --公证者要判断是谁赢了
                print("winner : ", curTurn)
                local settleResult = Settle(curTurn, lordseat, notarycontext.TableCtr, notarycontext.Hand, tbinfo[1], g_multiple)
                local signDataHash = settleResult:Hash()
                print("settleResult = ", settleResult, signDataHash:toHexString(), settleResult:toHexString())
                for i = 1, #resultCon do
                    local md = rlp.DoubleDecode(resultCon[i].pb, stSettleSignData)
                    print("md = ", md[1], md[2], md[3])
                    --local gss  = byteSlice.new() --要转成[]byte类型
                    --gss:appendHexString(md[1])
                    --local ncomp = bytesCompare(gss, settleResult)
                    local ncomp = md[1]==signDataHash:toHexString()
                    print("ncomp = ", ncomp)
                    if not ncomp  then
                        judge.Result[i] = Cheat
                    end
                end
                --return judge

            else
                
            end
        else
            --
        end

    else
        --for _, v := range result {
        for i = 1, #result do
            print("i, result[i].Succ, result[i].Reason = ", i, result[i].Succ, result[i].Reason, result[i].Seat, result[i].End)
            --print("", msglists[result[i].Seat], msglists[result[i].Seat][result[i].End-1])
            if not result[i].Succ then
                if result[i].Reason == Reason_Verify then
                    --找到发送者
					--msg := msglists[v.Seat][v.End-1]
					judge.Result[msg.SrcSeat] = VerifyFail
                elseif result[i].Reason == Reason_SendFail then
                    --补齐

                    judge.GameOver = false
                elseif result[i].Reason == Reason_Invalid then
                    --local msg = msglists[v.Seat][v.End-1]
                    local msg = msglists[result[i].Seat][result[i].End-1]
                    print("msg = ", msg, msg.SrcSeat)
                    judge.Result[msg.SrcSeat] = Cheat
                elseif result[i].Reason == Reason_Tamper then
                    judge.Result[result[i].Seat+1] = Cheat
                elseif result[i].Reason == Reason_Hide then
                    judge.Result[result[i].Seat+1] = Cheat
                elseif result[i].Reason == Reason_Lack then
                    judge.Result[curTurn+1] = Timeout
                elseif result[i].Reason == Reason_OpLack then
                    judge.Result[curTurn+1] = Timeout
                end
            end
        end
    end

    return commitJudge(judge, notarycontext)
end

function commitJudge(judge, notarycontext)

    local tablemgrcontract = eth.contract(DDZRoomManagerABI, DDZRoomManagerAddr)
    local tablectr = notarycontext.TableCtr
    local hand = notarycontext.Hand

    --执行审判结果，如果是补齐类的，通知各端恢复游戏
    if judge.GameOver ~= nil and not judge.GameOver then
        --for _, v := range result then
        --[[
        for i = 1, #judge.Result do
        
            if #judge.Result[i].MakeUp > 0 then
                

            end
            
        end
        ]]
        print("tablectr = ", tablectr)
        tablemgrcontract.Transact("finishNotarize", tablectr)

        return
    end

    local memCount = 3

    
    local GameSettleData = {}
    table.insert( GameSettleData, DDZRoomManagerAddr)
    table.insert( GameSettleData, tablectr )
    table.insert( GameSettleData, hand ) 

    local  list = {} 

    local judgecount = 0
    local judgeValue = 0
    for i = 1, memCount do
        if judge.Result[i] ~= nil then
            judgecount = judgecount + 1
            judgeValue = judgeValue + judge.Result[i]
            print("judge : ", i-1, judge.Result[i])
        end
    end

    print("judgecount = ", judgecount, ", judgeValue = ", judgeValue)
    if judgecount == 0 then
        return
    end

    if judgecount < memCount then
        local other = -judgeValue/(memCount - judgecount)
        for i = 1, memCount do
            if judge.Result[i] == nil then
                judge.Result[i] = other
            end
        end
    end
    --print("judge.Result[curTurn+1] = ", curTurn, judge.Result[curTurn+1])
    --local other = -judge.Result[curTurn+1]/2
    
    for i = 1, memCount do
        local flag = 1
        if judge.Result[i]<0 then
            flag = 0
            judge.Result[i] = -judge.Result[i]
        end

        print("flag, judge.Result[i-1] = ", flag, judge.Result[i])
        local gdb = {} 
        table.insert( gdb, i-1)--seat
        table.insert( gdb,  flag )--flag
        table.insert( gdb,  judge.Result[i])

        table.insert( list, gdb)
    end

    table.insert( GameSettleData , list)

    local signData, err = rlp.Encode(GameSettleData) 
    if (err ~= nil) then
        -- body
        err("RlpEncode err:"..err)
    end

    local bs = byteSlice.new()
    print("", bs.toHexString(signData))

    tablemgrcontract.Transact("submitNotary", signData)

    print("judge.Result[curTurn] = ", judge.Result[curTurn])

    return 0 --要返回0，表示0个补齐消息
end
