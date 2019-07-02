--公证者与游戏的共用部分

require("init")

--local ge = require("gameengine")
local ddz = require("doudizhu")
--local st = require("ddzseat")
local json = require("json")
--local eth  = require("eth")
local rlp  = require("rlp")

--require("ddzabi")
--require("uihandler")



SeatStatusType = CreateEnumTable({"NOTJION", "NOTSEATED", "SITTING", "SEATED", "READY", "PLAYING", "DISCARD"},-1)

ConsensusStateType = CreateEnumTable({"Init_check", "Po_check", "Pk_check", "Sf_check", "Bl_check", "R2_check", 
                                        "R3_check", "R4_check", "Rf_check"},-1)

GameStatusType = CreateEnumTable({"DeskState_Init", "DeskState_Grab", "DeskState_Play", "DeskState_Over"},-1)

PlayMethondType = CreateEnumTable({"Pass", "Play"},-1)

DealStatusType = CreateEnumTable({"None", "Self", "All"},-1)

GrabDataCode    = 0x1000  --抢地主消息
GrabSignDataCode  = 0x1001 --抢地主结果签名消息
PlayDataCode = 0x1002 --过牌消息
SettleSignDataCode  = 0x1003 --结算签名消息 



function isCanPlay(result, preResult)
    -- body
    local selfreusltstr = json.encode(preResult)
    local resultstr = json.encode(result)
    --print(os.date("%Y/%m/%d %H:%M:%S ") .. "preResult:", selfreusltstr)
    --print(os.date("%Y/%m/%d %H:%M:%S ") .. "result:", resultstr) 

    if (preResult ~= nil) then
        -- body
        if (preResult.Type ~= ddz.HandPatternsType.EVERYCARDTYPE) then
            -- body 
            if (result.Type ~= preResult.Type) then
                --略过火箭和炸弹
                if (result.Type ~= ddz.HandPatternsType.ROCKET) then
                    if (result.Type ~= ddz.HandPatternsType.BOMB) then
                    
                        return false 
                    end
                end
            end
           
            --当牌型一致的时候
            if (result.Type == preResult.Type) then
                -- body
                if (result.Type == ddz.HandPatternsType.SINGLESTRAIGHT or
                result.Type == ddz.HandPatternsType.DOUBLESTRAIGHT or
                result.Type == ddz.HandPatternsType.THREESTRAIGHT or 
                result.Type == ddz.HandPatternsType.THREESTRAIGHTTAKESINGLE or
                result.Type == ddz.HandPatternsType.THREESTRAIGHTTAKEDOUBLE) then
                
                    if ((result.Size ~= preResult.Size) or (result.Max <= preResult.Max)) then
                        return false 
                    end
                else 
                        -- 其他的类型判断值是否不大
                    if (result.Value <= preResult.Value) then
                            -- body
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

function Settle(seat, lordSeat, tableid, hand, base, multiple)
    -- body
    print(base, multiple)

    local GameSettleData = {}
    table.insert(GameSettleData, "0x"..DDZRoomManagerAddr)--还区分大小写
    table.insert(GameSettleData, tableid)
    table.insert(GameSettleData, hand)

    local list = {} 
    if (seat == lordSeat) then
        -- 地主赢
        local gdb = {} 
        table.insert(gdb, seat)
        table.insert(gdb, 1)
        table.insert(gdb, 2 * multiple * base)
        table.insert(list, gdb)

        --local  ids = exceptIds(seat)
        --for i,v in ipairs(ids) do
        for i=0, 2 do
            if i ~= seat then
                local gdb = {} 
                table.insert(gdb, i)
                table.insert(gdb, 0)
                table.insert(gdb, multiple * base)
                table.insert(list, gdb)
            end
        end
    else 
        --农民赢
        local gdb = {} 
        table.insert(gdb, seat)
        table.insert(gdb, 1)
        table.insert(gdb, multiple * base) 
        table.insert(list, gdb)

        --local ids = exceptIds(seat) 

        --for i,v in ipairs(ids) do
        for i=0, 2 do
            if (i == lordseat) then
                local gdb = {} 
                table.insert(gdb, i)
                table.insert(gdb, 0)
                table.insert(gdb, 2 * multiple * base)
                table.insert(list, gdb)
            elseif i~=seat then
                local gdb = {} 
                table.insert(gdb, i)
                table.insert(gdb, 1)
                table.insert(gdb, multiple * base) 
                table.insert(list, gdb)
            end
        end
    end 

    table.insert(GameSettleData, list)
    --self.settlelist = list 

    local gsdstr = json.encode(GameSettleData)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "settleData$$$$$$$$$$", gsdstr)

    local signData, err = rlp.Encode(GameSettleData) 
    if (err ~= nil) then
        err("RlpEncode err:"..err)
    end

    return signData
end
