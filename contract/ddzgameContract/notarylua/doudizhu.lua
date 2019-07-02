require ("init")
local json = require("json")

PokerRule = class()


function PokerRule:ctor()
    self.HandPatternsType = CreateEnumTable({
        "ROCKET",                -- 火箭，王炸，即双王（大王和小王），最大的牌
        "BOMB",                  -- 炸弹，四张同数值牌（如四个7）
        "SINGLE",                -- 单牌，单个牌
        "DOUBLE",                -- 双牌，一对，数值相同的两张牌（如梅花4+方块4）
        "THREE",                 -- 三牌，三张，数值相同的三张牌（如三个J）
        "THREETAKEONE",          -- 三带一，数值相同的三张牌 + 一张单牌。例如：333+6
        "THREETAKETWO",          -- 三带二，三带一对，数值相同的三张牌 + 一对牌。例如：444+99
        "SINGLESTRAIGHT",        -- 单顺，顺子，五张或更多的连续单牌（如：45678 或 78910JQK）。不包括 2 点和双王
        "DOUBLESTRAIGHT",        -- 双顺，连对，三对或更多的连续对牌（如：334455、77 88 99 1010 JJ）。不包括 2 点和双王
        "THREESTRAIGHT",         -- 三顺，飞机，二个或更多的连续三张牌（如：333444、555 666 777 888）。不包括 2 点和双王
        "THREESTRAIGHTTAKEONE",  -- 三顺带一，三顺+同数量的单牌。如：444555+79 或 333444555+679
        "THREESTRAIGHTTAKETWO",  -- 三顺代双，三顺+同数量的对牌。如：333444555+7799JJ 或 333444555+66991010
        "FOURTAKETWO",           -- 四带二，四张牌+两手牌（注意：四带二不是炸弹），如： 5555+3+8
        "FOURTAKETWOPAIR",       -- 四带两对，四张牌+两对牌，如：4444+55+77
        "ERRORTYPE",             -- 废牌
        "EVERYCARDTYPE"          -- 任意类型
    },0)
    self.HandPatternsTypeStr = {'王炸','炸弹','单牌','一对','三张','三带一','三带一对','顺子','连对','飞机','飞机（带单）','飞机（带对）','四带二','四带两对','废牌','任意类型'}
end

-- 返回牌详情数组
function PokerRule:getPokersDetail(pokers)
    local recordNum = {}
    for i = 1, #pokers do
        local num = 0
        -- 遍历获取数字的长度
        for j = 1, #pokers do
            if i ~= j then                                                                                             
                if pokers[i] == pokers[j] then
                    num = num + 1
                end
            end
        end

        local alreadyAdd = false
        -- 再遍历判断是否已经存在该数字
        for k = 1, #recordNum do
            local result = recordNum[k]
            if result.index == pokers[i] then
                alreadyAdd = true
                break
            end
        end

        -- 如果没有加进去，则添加详情，加到数组中
        if alreadyAdd == false then
            local result = {}
            result.index = pokers[i]
            result.num = num + 1
            table.insert(recordNum, result)
        end
    end

    -- 使用冒泡法从小到大进行排序
    for i = 1, #recordNum do
        for j = i, #recordNum do
            local a = recordNum[i]
            local b = recordNum[j]

            -- 如果后面的小，进行交换
            if b.num < a.num then
                local tmp = a
                recordNum[i] = b
                recordNum[j] = tmp
            end
        end
    end

    --print('getPokersDetail(' .. json.encode(pokers) .. ') return ' .. json.encode(recordNum))
    return recordNum
end

-- 判断结果数组是否对子
function PokerRule:judgeIsPair(recordNum)
    -- 遍历，判断每个数字个数是否相等
    local index = recordNum[0].num
    for i = 1, #recordNum do
        if recordNum[i].num ~= index then
            return false
        end
    end

    return true
end

-- 判断结果数组是否顺子
function PokerRule:judgePairIsStraight(recordNum)
    -- 首先保证长度必须大于1
    if #recordNum == 1 then
        return false
    end

    -- 再遍历一次进行判断是否后面一个一定比前面一个大1     
    for i = 2, #recordNum do
        local a = recordNum[i]
        local b = recordNum[i - 1]
        -- 如果不符合，则不是顺子
        if (a.index - b.index) ~= 1 then
            return false
        end
    end

    return true
end


-- 判断出的牌是否顺子
function PokerRule:judgeIsStraight(pokers)
    -- 首先保证长度必须大于1
    if #pokers == 1 then
        return false
    end

    -- 再遍历一次进行判断是否后面一个一定比前面一个大1     
    for i = 2, #pokers do
        -- 如果不符合，则不是顺子
        if (pokers[i] - pokers[i - 1]) ~= 1 then
            return false
        end
    end

    return true
end


function PokerRule:transformValue(pokers)
    local tresult = {} 

    for i,v in ipairs(pokers) do
        print(i,v)
        local x = self:transform(v)
        table.insert(tresult, x)
    end

    return tresult

end

function PokerRule:transform(value)
    -- body
    if (value > 53) then
        error("illegality value:", value)
    end

    if (value == 52) then
        -- 小王
        return 16 

    elseif (value == 53) then
        --大王
        return 17
    else 
        local x = math.fmod(value, 13)
        local temp = x + 1 

        if (temp == 1) then
            -- 牌面值为A 
            return 14 
        elseif(temp == 2) then
            --牌面值 2 
            return 15 
        else
            return  temp 
        end
    end

end


-- 判断手牌数组的类型
function PokerRule:judgePokerType(pokers)
    -- 首先从小到大进行排序
    local bpokerstr  = json.encode(pokers)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "bpokers:", bpokerstr)
    local pokers  = self:transformValue(pokers)
    local apokerstr = json.encode(pokers)
    print(os.date("%Y/%m/%d %H:%M:%S ") .. "apokers:", apokerstr)


    for i = 1, #pokers do
        for j = i, #pokers do
            local a = pokers[i]
            local b = pokers[j]

            -- 冒泡
            if b < a then
                local tmp = a
                pokers[i] = b
                pokers[j] = tmp
            end
        end
    end

    -- type: 牌型，value: 为单张、一对、三张时的值，max: 顺子、连对、飞机时最大牌值，size: 顺子、连对、飞机时的牌有多少组
    local result = {}
    -- index: 牌点，num: 牌点的个数
    local recordNum = self:getPokersDetail(pokers)

    -- 如果长度为1，则是单牌  
    if #pokers == 1 then
        result.Type = self.HandPatternsType.SINGLE
        result.Value = pokers[1]
    -- 如果长度为2，判断是否双牌（少加了火箭）
    elseif #pokers == 2 then
        -- 如果相等，则为双牌
        if pokers[1] == pokers[2] then
            result.Type = self.HandPatternsType.DOUBLE
            result.Value = pokers[1]
        else
            -- 判断是否火箭
            if pokers[1] == 16 and pokers[2] == 17 then
                result.Type = self.HandPatternsType.ROCKET
            else
                result.Type = self.HandPatternsType.ERRORTYPE
            end
        end
    -- 如果长度为3，判断是否三牌
    elseif #pokers == 3 then
        -- 如果相等，则为三牌
        if pokers[1] == pokers[2] and pokers[2] == pokers[3] then
            result.Type = self.HandPatternsType.THREE
            result.Value = pokers[1]
        else
            result.Type = self.HandPatternsType.ERRORTYPE
        end
    -- 如果长度为4，判断是否炸弹或者三代一
    elseif #pokers == 4 then
        -- 如果结果数组的长度为1，则为炸弹
        if #recordNum == 1 then
            result.Type = self.HandPatternsType.BOMB
            result.Value = pokers[1]
        -- 如果结果数组的长度为2，则为三代一
        elseif #recordNum == 2 then
            result.Type = self.HandPatternsType.THREETAKEONE
            if recordNum[1].num == 3 then
                result.Value = recordNum[1].index
            elseif recordNum[2].num == 3 then
                result.Value = recordNum[2].index
            else
                result.Type = self.HandPatternsType.ERRORTYPE
            end
        -- 其他情况都为非法牌型       
        else
            result.Type = self.HandPatternsType.ERRORTYPE
        end
    -- 如果长度为5，则有三代二和顺子的情况
    elseif #pokers == 5 then
        -- 当结果数组长度为2时，判断是否三代二
        if  #recordNum == 2 then
            result.Type = self.HandPatternsType.THREETAKETWO
            if recordNum[1].num == 3 then
                result.Value = recordNum[1].index
            else
                result.Value = recordNum[2].index
            end
        -- 其他情况都为非法
        else
            result.Type = self.HandPatternsType.ERRORTYPE
        end
    end

    if #pokers >= 6 and (result.Type == self.HandPatternsType.ERRORTYPE or result.Type == nil) then
        -- 判断是否四带两手牌（两个单张或两对）
        local hasSingleFour = false
        local fourValue = 0
        local pairsArr = {}
        local singleArr = {}
        for i = 1, #recordNum do
            if recordNum[i].num == 4 then
                if hasSingleFour == false then
                    hasSingleFour = true
                    fourValue = recordNum[i].index
                else
                    result.Type = self.HandPatternsType.ERRORTYPE
                    hasSingleFour = false
                    break
                end
            elseif recordNum[i].num == 2 then
                table.insert(pairsArr, recordNum[i].index)
            elseif recordNum[i].num == 1 then
                table.insert(singleArr, recordNum[i].index)
            else
                result.Type = self.HandPatternsType.ERRORTYPE
                hasSingleFour = false
                break
            end
        end

        if hasSingleFour then
            if #pairsArr == 2 and #singleArr == 0 then
                -- 四带两对
                result.Value = fourValue
                result.Type = self.HandPatternsType.FOURTAKETWOPAIR
            elseif #pairsArr == 1 and #singleArr == 0 then
                -- 四带一对（两张）
                result.Value = fourValue
                result.Type = self.HandPatternsType.FOURTAKETWO
            elseif #pairsArr == 0 and #singleArr == 2 then
                -- 四带二
                result.Value = fourValue
                result.Type = self.HandPatternsType.FOURTAKETWO
            else
                result.Type = self.HandPatternsType.ERRORTYPE
            end
        end
    end

    if #pokers >= 8 and (result.Type == self.HandPatternsType.ERRORTYPE or result.Type == nil) then
        -- 判断是否三顺+同数量的一手牌
        local threeStraight = {}
        local pairsArr = {}
        local singleArr = {}
        local isvalid = true
        for i = 1, #recordNum do
            if recordNum[i].num == 3 then
                table.insert(threeStraight, recordNum[i].index)
            elseif recordNum[i].num == 2 then
                table.insert(pairsArr, recordNum[i].index)
            elseif recordNum[i].num == 1 then
                table.insert(singleArr, recordNum[i].index)
            else
                result.Type = self.HandPatternsType.ERRORTYPE
                isvalid = false
                break
            end
        end
        if isvalid and #threeStraight > 0 then
            table.sort(threeStraight)
            for i = 2, #threeStraight do
                if threeStraight[i] - threeStraight[i-1] ~= 1 then
                    result.Type = self.HandPatternsType.ERRORTYPE
                    isvalid = false
                    break
                end
            end
            if isvalid then
                if #threeStraight ~= #pairsArr and #threeStraight ~= #singleArr and #threeStraight ~= #pairsArr * 2 + #singleArr then
                    result.Type = self.HandPatternsType.ERRORTYPE
                else
                    local max = threeStraight[#threeStraight]
                    if max > 14 then
                        result.Type = self.HandPatternsType.ERRORTYPE
                    else
                        if #threeStraight == #pairsArr then
                            result.Type = self.HandPatternsType.THREESTRAIGHTTAKETWO
                        elseif #threeStraight == #singleArr then
                            result.Type = self.HandPatternsType.THREESTRAIGHTTAKEONE
                        end
                        result.Max = max
                        result.Size = #threeStraight
                    end
                end
            end
        end
    end

    -- 判断是否是连对或飞机啥都不带
    if #pokers >= 6 and (#pokers / 3 == #recordNum or #pokers / 2 == #recordNum) and (result.Type == self.HandPatternsType.ERRORTYPE or result.Type == nil) then
        -- 判断是否成顺
        if self:judgePairIsStraight(recordNum) then
            local max = pokers[#pokers]
            if max > 14 then
                result.Type = self.HandPatternsType.ERRORTYPE
            else
                if #pokers / 3 == #recordNum then
                    result.Type = self.HandPatternsType.THREESTRAIGHT
                else
                    result.Type = self.HandPatternsType.DOUBLESTRAIGHT
                end
                result.Max = max
                result.Size = #recordNum
            end
        else
            result.Type = self.HandPatternsType.ERRORTYPE
        end
    end

    -- 最后判断是否顺子
    if #pokers > 4 and (result.Type == self.HandPatternsType.ERRORTYPE or result.Type == nil) then
        -- 再判断牌数组和结果数组是否相等，如果相等，代表牌全部不同
        if #pokers == #recordNum then
            if self:judgeIsStraight(pokers) then
                local max = pokers[#pokers]
                -- 顺子最高位不能超过A               
                if max > 14 then
                    result.Type = self.HandPatternsType.ERRORTYPE
                else
                    result.Type = self.HandPatternsType.SINGLESTRAIGHT
                    result.Max = max
                    result.Size = #recordNum
                end
            else
                result.Type = self.HandPatternsType.ERRORTYPE
            end
        end
    end

    if result.Type == nil then
        result.Type = self.HandPatternsType.ERRORTYPE
    end

    --print('judgePokerType return ' .. json.encode(result))
    return result
end

poker_rule = PokerRule.new()

return poker_rule 
