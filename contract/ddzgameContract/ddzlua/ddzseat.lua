
require("init") 

game_seat = class()		-- 定义一个基类 game_seat
 
function game_seat:ctor(id, balance, addr)	-- 定义 game_seat 的构造函数
	print("game_seat ctor")
    self.id = id                --座位序号
    self.balance = balance:Uint64()      --账号余额
    self.ad = addr              --账号地址
    self.grab = 0               --是否抢地主 0-不抢 1-抢 
    self.optimes = 0            --操作次数，标识最后一个抢地主是否完成
    self.status = 0             --玩家状态
    self.privateCard = {}       --只能玩家自己看到的牌的牌点
    self.privateIndex = {}      --只能玩家自己看到的牌的序号
    self.publicCard = {}        --全部玩家都能看到的牌的牌点
    self.publicIndex = {}       --全部玩家都能看到的牌的序号
    self.currentRoundCard = {}  --当前轮出牌集合
    self.allRoundCard = {}      --所有轮出牌集合 
    self.playCardNum = 0        --出了多少牌 
    self.playIndex = {}         --出牌的cursor 
    
    self.grabstateSignData = ""     --抢地主签名数据
    self.grabstateSignDataHash = "" --抢地主签名数据哈希
    self.grabstateSign = ""         --抢地主签名

    self.settleSignData = ""        --结算签名数据
    self.settleSignDataHash = ""    --结算签名数据哈希
    self.settleSign = ""            --结算签名
end
 
return game_seat 











