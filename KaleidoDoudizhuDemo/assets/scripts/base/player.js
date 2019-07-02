// 加载扑克类
var Poker = require("poker")

cc.Class({
    extends: cc.Component,

    properties: {
        // 索引
        index: 0,
        // 手牌
        handPoker: {
            default: [],
            type: [Poker],
        },
        // 是否自己
        isSelf: false,
        // 手牌数标签
        cardsNumLabel: {
        	default: null,
        	type: cc.Label,
        },
        // 提示标签
        remindLabel: {
        	default: null,
        	type: cc.Label,
        },
        // 准备就绪标签
        readyLabel: {
            default: null,
            type: cc.Node,
        },
        // 地主标签
        dizhuLabel: {
            default: null,
            type: cc.Node,
        },
        // 筹码位置
        stakeNum: {
            default: null,
            type: cc.Label,
        },
        // 翻牌位置
        downLoc: {
            default: null,
            type: cc.Node,
        },
        // 筹码层
        stakeNode: {
            default: null,
            type: cc.Node,
        },
        // 玩家地址
        playerAddr: {
            default: null,
            type: cc.Label,
        },
    },

    // LIFE-CYCLE CALLBACKS:

    onLoad:function () {
    	this.initEventListeners()
        this.initConfigs()
    },

    onDestroy:function () {
        this.listener.removeListener(this.listener.EVENTSTRINGS.CALL_DIZHU_CALL_BACK, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.ROB_DIZHU_CALL_BACK, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.DECIDE_ROB_DIZHU_CALL_BACK, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.READY_PLAY_A_HAND_CALL_BACK, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.PLAY_A_HAND_CALL_BACK, this)
    },
    // 配置和参数等
    initConfigs:function() {
        // 配置规则
        this.rule = require("pokerrule")
        this.rule.init()

        // 配置提示语
        this.strings = require("string_zh")

        // 配置枚举
        this.enums = require("serverutils")

        this.tablePokers = new Array()
        // 配置筹码位置
        // var stakeNode = cc.instantiate(this.stakePrefab)
        // this.stakeLoc.addChild(stakeNode)
        // console.log("x = " + this.stakeLoc.x + ", y = " + this.stakeLoc.y + ", px = " + this.node.x + ", py = " + this.node.y)
        //this.setStakeNum("12312")
    },

    // 配置消息
    initEventListeners:function() {
        // 初始化事件中心
        this.listener = require("eventlistener")

        var self = this
        // 注册消息接收
        // 叫地主回调
        this.listener.registerListener(this.listener.EVENTSTRINGS.CALL_DIZHU_CALL_BACK, function(data) {
            self.callDiZhuHandler(data)
        }, this)
        // 抢地主回调
        this.listener.registerListener(this.listener.EVENTSTRINGS.ROB_DIZHU_CALL_BACK, function(data) {
            self.robDiZhuCallback(data)
        }, this)
        this.listener.registerListener(this.listener.EVENTSTRINGS.DECIDE_ROB_DIZHU_CALL_BACK, function(data) {
            self.robDiZhuDecide(data)
        }, this)
        // 出牌准备回调
        this.listener.registerListener(this.listener.EVENTSTRINGS.READY_PLAY_A_HAND_CALL_BACK, function(data) {
            self.readyPlayCallback(data)
        }, this)
        // 出牌回调
        this.listener.registerListener(this.listener.EVENTSTRINGS.PLAY_A_HAND_CALL_BACK, function(data) {
        	self.playAHandCallback(data)
        }, this)
    },

    // 叫地主回调
    callDiZhuHandler:function(data) {
        // 进行区分，如果是电脑玩家，则告知服务器叫地主，如果是真人玩家，则弹出叫地主页面
        // 索引一致时进行判断
        if (data.index == this.index) {
            cc.log ("通知玩家 : %d 叫地主", data.index)
            // 再判断是否真人玩家
            if (!this.isSelf) {
                // 回传给服务器的数据包括位置和决定的状态
                var resultData = {}
                resultData.index = this.index
                resultData.state = this.enums.CALL_DIZHU_STATE
                this.listener.broadcastListener(this.listener.EVENTSTRINGS.CALL_DIZHU_DECIDE, resultData)
                // 标签更改
                this.remindLabel.string = this.strings.CALL_DIZHU
            } else {
                this.listener.broadcastListener(this.listener.EVENTSTRINGS.PLAYER_CALLDIZHU_OPERATE)
            }
        }
    },

    // 抢地主回调方法
    robDiZhuCallback:function(data) {
    	if (data.index == this.index) {
    		if (data.state == this.enums.ROB_DIZHU_STATE) {
    			// 抢地主状态
    			this.remindLabel.string = this.strings.ROB_DIZHU
    		} else if (data.state == this.enums.NO_ROB_STATE) {
    			// 不抢状态
    			this.remindLabel.string = this.strings.NO_ROB
    		}
    	}
    },

    // 抢地主决定回调
    robDiZhuDecide:function(data) {
        // 当索引不一致时，可以进行抢地主
        if (data.index == this.index) {
            // 真人玩家和电脑玩家分别作出选择
            if (!this.isSelf) {
                // 电脑玩家不抢地主
                var callData = {}
                callData.index = this.index
                callData.state = this.enums.NO_ROB_STATE
                this.listener.broadcastListener(this.listener.EVENTSTRINGS.ROB_DIZHU, callData)
            } else {
                this.listener.broadcastListener(this.listener.EVENTSTRINGS.PLAYER_ROBDIZHU_OPERATE)
            }
        }
    },

    // 出牌准备的回调
    readyPlayCallback:function(data) {
        //cc.log("data.NextTurn: " + data.NextTurn + ", this.index: " + this.index + ", this.isSelf: " + this.isSelf)
        if (data.NextTurn != this.index) {
            return
        }

        // 如果是我的，则弹出框
        if (this.isSelf) {
            // 设置玩家可以和手牌交互
            this.setPokerAble()
            // 对结果进行判断
            this.result = data.Result

            // 如果自身的牌桌上的牌还存在，在将其隐藏
            this.clearTablePokers()
            // 如果是
            // 传入类型，1为全显示，2为只显示出牌
            cc.log ("出牌准备 : %d", this.result.Type)
            if ((this.result.Type == null) || (this.result.Type == this.rule.handPatterns.EVERYCARDTYPE)) {
                this.listener.broadcastListener(this.listener.EVENTSTRINGS.PLAYER_CALLOUTCARD_OPERATE, 2)
            } else {
                this.listener.broadcastListener(this.listener.EVENTSTRINGS.PLAYER_CALLOUTCARD_OPERATE, 1)
            }
        }
    },

    // 出牌回调
    playAHandCallback:function(data) {
        var arrays = new Array()
        this.setPokerDisable()
        // 捕捉到确定玩家
        if (data.index == this.index) {
            // 牌桌上的牌
            this.clearTablePokers()

            this.tablePokers = null
            this.tablePokers = new Array()
            // 先循环回调的牌数组，再循环自身手牌，能避免出现因删除数组元素导致的长度变化问题
            for (var i = 0; i< data.pokers.length; i++) {
                for (var j = 0; j < this.handPoker.length; j++) {
                    var poker = this.handPoker[j]
                    // 获取到指定的牌
                    if (poker.value == data.pokers[i]) {
                        this.tablePokers.push(poker.node)
                        poker.reveal(true)
                        // 把牌扔回牌桌
                        var node = poker.node
                        node.zIndex = this.tablePokers.length
                        // 移动动作
                        var move = cc.moveTo (0.1, cc.v2(this.downLoc.x + (node.width) * (i - this.tablePokers.length / 2), this.downLoc.y))
                        node.runAction(move)
                        // 将其从手牌数组中移除
                        this.handPoker.splice(j, 1)
                        break
                    }
                }
            }

            // 隐藏操作面板
            this.listener.broadcastListener(this.listener.EVENTSTRINGS.HIDE_OPERATE_PANEL)
        } else {
            // 如果不是，则将其他玩家的牌桌上的牌隐藏
            if (this.tablePokers) {
                for (var i = 0; i < this.tablePokers.length; i++) {
                    var node = this.tablePokers[i]
                    node.active = false
                }
            }
        }

        this.disposeHandPokers()

        if (data.result) {
            this.result = data.result
        }
    },

    // 抽牌
    pickUpOne:function(poker) {
        // 添加卡牌
        // 按照牌数字从大到小来排序
        // 当数组为空时，直接加入
        if (this.handPoker.length == 0) {
            this.handPoker.push(poker)
        }
        // 当数组为1时，进行比较后加入
        else if (this.handPoker.length == 1) {
            if (this.handPoker[0].num < poker.num) {
                this.handPoker.splice(0, 0, poker)
            } else {
                this.handPoker.push(poker)
            }
        }
        // 当处于其他情况时
        else {
            // 将其添加到比选中的牌小的位置
            var isAdd = false
            for (var i = 0; i < this.handPoker.length; i++) {
                if (this.handPoker[i].num < poker.num) {
                    this.handPoker.splice(i, 0, poker)
                    isAdd = true
                    break
                }
            }

            // 如果没有添加上，则放在数组末尾
            if (!isAdd) {
                this.handPoker.push(poker)
            }
        }

        // cc.log ("适配位置")
        this.disposeHandPokers()

    	// 如果是电脑
    	if (!this.isSelf) {
            this.cardsNumLabel.node.active = true;
    		this.cardsNumLabel.string = this.handPoker.length
    	} else {
	    	// 如果是玩家，则和牌进行关联
    		poker.player = this
    	}
    },

    // 调配手牌位置
    disposeHandPokers:function() {
        if (!this.isSelf) {
            // 对手牌的位置进行调整
            for (var i = 0; i < this.handPoker.length; i++) {
                var onePoker = this.handPoker[i]

                onePoker.node.x = this.node.x
                onePoker.node.y = onePoker.node.height * i * 0.3 - (this.handPoker.length * onePoker.node.height / 2 * 0.3)
                onePoker.node.zIndex = this.handPoker.length - i
            }

        } else {
            // 对手牌的位置进行调整
            for (var i = 0; i < this.handPoker.length; i++) {
                var onePoker = this.handPoker[i]

                onePoker.isSelected = false
                onePoker.node.x = onePoker.node.width * i * 0.5 - (this.handPoker.length * onePoker.node.width / 2 * 0.5)
                onePoker.node.y = this.node.y
                onePoker.node.zIndex = i
            }
        }
    },

    // 隐藏提示标签
    hideRemind:function() {
        this.remindLabel.string = ""
    },

    // 选中牌
    pokerSelected:function(poker) {
    	// 判断是否升起来
    	if (poker.isSelected) {
    		poker.node.y = poker.node.y + 30
    	} else {
    		poker.node.y = poker.node.y - 30
    	}
    },

    // 不出
    noOutCard:function() {
        this.outPokers = new Array()
        this.outIndexes = new Array()
        var play_cmd = {
            ID: cc.dgame.gameplay.seatId,
            OP: 0,
            Index: [],
            Card: [],
        }
        cc.dgame.net.sendMsg(["Play", JSON.stringify(play_cmd)], this.onPlayCard.bind(this))
    },

    dumpPokers:function(pokers) {
        var result = ""
        for (var i = 0; i < pokers.length; i++) {
            if (i != pokers.length - 1)
                result = result + "[" + pokers[i].index + ", " + pokers[i].value + "], "
            else
                result = result + "[" + pokers[i].index + ", " + pokers[i].value + "]"
        }
        return result
    },
    // 出牌消息回调
    onPlayCard:function(data) {
        cc.log(data)
        var result = JSON.parse(data)
        if (result.state == 0) {
            // 如果自身的牌桌上的牌还存在，在将其隐藏
            if (this.tablePokers) {
                for (var i = 0; i < this.tablePokers.length; i++) {
                    var node = this.tablePokers[i]
                    node.active = false
                }
            }

            this.setPokerDisable()
            this.tablePokers = null
            this.tablePokers = new Array()
            // 先循环回调的牌数组，再循环自身手牌，能避免出现因删除数组元素导致的长度变化问题
            //cc.log("this.outPokers: " + JSON.stringify(this.outPokers) + ", this.handPoker.length: " + this.handPoker.length)
            //cc.log("this.handPoker: " + this.dumpPokers(this.handPoker))
            if (this.outPokers.length == 0) {
                this.remindLabel.string = this.strings.NO_OUT
            }
            for (var i = 0; i < this.outPokers.length; i++) {
                for (var j = 0; j < this.handPoker.length; j++) {
                    var poker = this.handPoker[j]
                    // 获取到指定的牌
                    if (poker.value == this.outPokers[i]) {
                        this.tablePokers.push(poker.node)
                        poker.reveal(true)
                        // 把牌扔回牌桌
                        var node = poker.node
                        node.zIndex = this.tablePokers.length
                        // 移动动作
                        var move = cc.moveTo (0.1, cc.v2(this.downLoc.x + (node.width) * (i - this.tablePokers.length / 2), this.downLoc.y))
                        //cc.log(poker.value + " moveTo(" + (this.downLoc.x + (node.width) * (i - this.tablePokers.length / 2)) + ", " + this.downLoc.y + ")")
                        node.runAction(move)
                        // 将其从手牌数组中移除
                        this.handPoker.splice(j, 1)
                        break
                    }
                }
            }
            //cc.log("this.handPoker.length: " + this.handPoker.length + ", " + this.dumpPokers(this.handPoker))

            // 隐藏操作面板
            this.listener.broadcastListener(this.listener.EVENTSTRINGS.HIDE_OPERATE_PANEL)
    
            this.disposeHandPokers()
        } else {
            this.listener.broadcastListener(this.listener.EVENTSTRINGS.PLAYER_REMIND, this.strings.POKERS_NOT_MATCHING)
        }
    },

    // 出牌
    playerOutCard:function() {
        this.outPokers = new Array()
        this.outIndexes = new Array()
        for (var i = 0; i < this.handPoker.length; i++) {
            var poker = this.handPoker[i]
            // 拿到牌了
            if (poker.isSelected) {
                this.outPokers.push(poker.value)
                this.outIndexes.push(poker.index)
            }
        }

        var play_cmd = {
            ID: cc.dgame.gameplay.seatId,
            OP: 0,
            Index: this.outIndexes,
            Card: this.outPokers,
        }
        cc.dgame.net.sendMsg(["Play", JSON.stringify(play_cmd)], this.onPlayCard.bind(this))
        return true
    },

    // 功能方法
    // 设置手牌可以响应
    setPokerAble:function() {
        cc.log ("我这里有 : %d 张牌", this.handPoker.length)
        for (var i = 0; i < this.handPoker.length; i++) {
            var poker = this.handPoker[i]
            poker.disabled = false
        }
    },
    // 设置手牌不可以响应
    setPokerDisable:function() {
        for (var i = 0; i < this.handPoker.length; i++) {
            var poker = this.handPoker[i]
            poker.disabled = true
            poker.isSelected = false
        }
    },
    // 设置手牌可视
    revealHandPokers:function() {
        for (var i = 0; i < this.handPoker.length; i++) {
            var poker = this.handPoker[i]
            poker.reveal(true)
        }
    },
    // 清理手牌
    clearHandPokers:function() {
        cc.log("清理手牌")
        this.setPokerDisable()
        // 手牌清零
        this.handPoker = new Array()
        // 牌桌上的牌清零
        this.tablePokers = new Array()
        // 在重置提示
        this.remindLabel.string = ""
        this.result = null
    },
    // 设置是否地主
    setIsDiZhu:function(state) {
        this.isDiZhu = state
        this.dizhuLabel.active = state
    },

    hideCardsNum:function() {
        this.cardsNumLabel.node.active = false
    },

    hideDizhuMark:function() {
        this.dizhuLabel.active = false
    },
    
    setReady:function() {
        this.readyLabel.active = true
    },

    hideReady:function() {
        this.readyLabel.active = false
    },

    setPlayerAddr:function(addr) {
        this.playerAddr.string = addr
        this.playerAddr.node.active = true
    },

    setStakeNum:function(value) {
        this.stakeNum.string = value
        this.stakeNode.active = true
    },

    hideStake:function() {
        this.stakeNode.active = false
    },

    showOutCard:function(data) {
        // 如果自身的牌桌上的牌还存在，在将其隐藏
        this.clearTablePokers()

        this.tablePokers = null
        this.tablePokers = new Array()
        //cc.log("this.handPoker.length: " + this.handPoker.length + ", " + this.dumpPokers(this.handPoker))
        for (var i = 0; i < data.Index.length; i++) {
            for (var j = 0; j < this.handPoker.length; j++) {
                var poker = this.handPoker[j]
                // 获取到指定的牌
                if (poker.index == data.Index[i]) {
                    this.tablePokers.push(poker.node)
                    poker.reveal(true)
                    // 把牌扔回牌桌
                    var node = poker.node
                    node.zIndex = this.tablePokers.length
                    // 移动动作
                    var move = cc.moveTo (0.1, cc.v2(this.downLoc.x + (node.width) * (i - this.tablePokers.length / 2), this.downLoc.y))
                    //cc.log(poker.value + " moveTo(" + (this.downLoc.x + (node.width) * (i - this.tablePokers.length / 2)) + ", " + this.downLoc.y + ")")
                    node.runAction(move)
                    // 将其从手牌数组中移除
                    this.handPoker.splice(j, 1)
                    break
                }
            }
        }

        // 修改标签
        if (this.cardsNumLabel) {
            this.cardsNumLabel.string = this.handPoker.length
        }

        if (data.Index.length == 0 || data.Index.length == undefined) {
            this.remindLabel.string = this.strings.NO_OUT
        }
        //cc.log("this.handPoker.length: " + this.handPoker.length + ", " + this.dumpPokers(this.handPoker))

        this.disposeHandPokers()
    },

    clearTablePokers:function() {
        if (this.tablePokers) {
            for (var i = 0; i < this.tablePokers.length; i++) {
                var node = this.tablePokers[i]
                node.active = false
            }
        }
    },

    resortHandPokers: function(pokers, indexes) {
        cc.log("pokers.length = " + pokers.length + ", this.handPoker.length = " + this.handPoker.length)
        var result = new Array()
        var resultIdx = new Array()
        for (var i = 0; i < pokers.length; i++) {
            var poker = this.handPoker[i]
            poker.setValue(pokers[i])
            poker.setIndex(indexes[i])
            result.push(poker.value)
            resultIdx.push(poker.index)
        }
        cc.log("before: " + JSON.stringify(result) + ", idx: " + JSON.stringify(resultIdx))
        for (var i = 0; i < this.handPoker.length; i++) {
            for (var j = i + 1; j < this.handPoker.length; j++) {
                var a = this.handPoker[i]
                var b = this.handPoker[j]

                // 冒泡
                if (b.num < a.num) {
                    var tmp = a
                    this.handPoker[i] = b
                    this.handPoker[j] = tmp
                }        
            }
        }
        result = new Array()
        resultIdx = new Array()
        for (var i = 0; i < this.handPoker.length; i++) {
            result.push(this.handPoker[i].value)
            resultIdx.push(this.handPoker[i].index)
        }
        cc.log("after: " + JSON.stringify(result) + ", idx: " + JSON.stringify(resultIdx))
        this.disposeHandPokers()
    },

    getHandPokers: function() {
        var result = new Array()
        for (var i = 0; i < this.handPoker.length; i++) {
            result.push(this.handPoker[i].getDetail())
        }
        return JSON.stringify(result)
    },

    setHandPokers: function(pokers) {
        var result = new Array()
        for (var i = 0; i < pokers.length; i++) {
            var found = false
            for (var j = 0; j < this.handPoker.length; j++) {
                var poker = this.handPoker[j]
                // 获取到指定的牌
                if (poker.index === pokers[i]) {
                    result.push(this.handPoker[i])
                    break
                }
            }
        }
        this.handPoker = result
        this.disposeHandPokers()
    }
});
