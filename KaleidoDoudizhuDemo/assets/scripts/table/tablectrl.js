// 加载扑克类
var Poker = require("poker")
// 加载玩家类
var Player = require("player")
// 抢地主操作面板
var Operatepanel = require("operatepanel")
// 倒计时
var CountDown = require("countdown")
// 结束面板
var GameOverPanel = require("gameoverpanel")

cc.Class({
    extends: cc.Component,

    properties: {
        // 牌桌ID
        tableId: cc.Label,
        // 倍数
        gameMultiple: cc.Label,

        // 扑克数组
        pokers: {
            default: [],
            type: [Poker],
        },

        // 地主牌
        landlordPokers: {
            default: [],
            type: [Poker],
        },

        // 牌桌
        table: {
            default: null,
            type: cc.Node,
        },

        // UI层
        uiLayer: {
            default: null,
            type: cc.Node,
        },

        // 扑克prefab
        pokerPrefab: {
            default: null,
            type: cc.Prefab,
        },

        // 玩家
        playerMyself: {
            default: null,
            type: Player,
        },

        // 上家
        playerUp: {
            default: null,
            type: Player,
        },

        // 下家
        playerDown: {
            default: null,
            type: Player,
        },

        // 自定义控件
        // 抢地主操作面板
        operatePanel: {
            default: null,
            type: Operatepanel,
        },

        // 玩家数组
        players: {
            default: [],
            type: [Player],
        },

        // 提示标签
        remindLabel: {
            default: null,
            type: cc.Label,
        },
        // 抢地主倒计时
        countDownPrefab: {
            default: null,
            type: cc.Prefab,
        },
        // 游戏结束面板
        gameOverPanel: {
            default: null,
            type: GameOverPanel,
        },
    },

    // LIFE-CYCLE CALLBACKS:
    onRecover: function(data) {
        console.log(data)
        var recoverData = JSON.parse(data)
        if (recoverData.Stage === "Grab") {
            this.handleGrabTurnInfo(recoverData.GrabTurnInfo)
        } else if (recoverData.Stage === "PlayCard") {
            this.handlePlayCardInfo(recoverData.PlayCardInfo)
        }
    },

    recoverPlayCardInfo: function(data) {
        this.playerMyself.setHandPokers(data.SelfRemainIndex)
        for (var i = 0; i < data.OtherremainIndex.length; i++) {
            var player = this.getPlayerByPos(data.OtherremainIndex[i].Id)
            player.setHandPokers(data.OtherremainIndex[i].RemainIndex)
        }
    },

    onRecoverOrNot: function(data) {
        console.log(data)
        var recoverData = JSON.parse(data)
        if (recoverData.SeatStatus === 5) {
            this.playerInfo.needFastjoin = false
            this.operatePanel.startGame()
            this.onAllotTable(recoverData.TableInfo)
            for (var i = 0; i < this.players.length; i++) {
                var player = this.players[i]
                player.hideReady()
            }
            if (recoverData.DealFlag) {
                this.handleStartInfo(recoverData.DealInfo, true)
            }
            if (recoverData.GrabSignFlag) {
                this.handleStartPlayCardInfo(recoverData.GrabResultInfo)
            }
            if (recoverData.PlayCardFlag) {
                this.recoverPlayCardInfo(recoverData.PlayInfo)
            }
            cc.dgame.net.sendMsg(["Recover", ""], this.onRecover.bind(this))
        } else {
            this.operatePanel.showStart()
        }
    },

    onLoad:function () {
        this.playerInfo = {}
        this.playerInfo.needFastjoin = true
        this.initConfigs()
        this.initWidget()
        this.addPokers()
        cc.dgame.net.sendMsg(["RecoverOrNot", ""], this.onRecoverOrNot.bind(this))
    },

    onDestroy:function() {
        this.listener.removeListener(this.listener.EVENTSTRINGS.PLAYER_READY, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.DEAL_POKERS, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.DECIDE_DIZHU_CALL_BACK, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.GAME_OVER_CALL_BACK, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.NEW_GAME_CALL_BACK, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.RE_DEAL_CALL_BACK, this)

        this.listener.removeListener(this.listener.EVENTSTRINGS.PLAYER_CALLDIZHU_OPERATE, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.PLAYER_ROBDIZHU_OPERATE, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.PLAYER_CALLOUTCARD_OPERATE, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.PLAYER_REMIND, this)
        this.listener.removeListener(this.listener.EVENTSTRINGS.HIDE_OPERATE_PANEL, this)

        this.unschedule(this.waitForStart)
    },

    // 加载配置
    initConfigs:function() {
        // 初始化事件中心
        this.listener = require("eventlistener")
        this.listener.init()

        this.rule = require("pokerrule")
        this.rule.init()
        // 配置提示语
        this.strings = require("string_zh")

        // 配置枚举
        this.enums = require("serverutils")

        // 注册消息接收
        this.initServerListener()
        this.initClientListener()
    },


    // 和服务器端的通信交互
    initServerListener:function() {
        var self = this
        // 本玩家点击开始游戏
        this.listener.registerListener(this.listener.EVENTSTRINGS.PLAYER_READY, function() {
            if (self.playerInfo.needFastjoin) {
                self.playerInfo.needFastjoin = false
                cc.dgame.net.addEventListener(["allotTable", 0], self.onAllotTable.bind(self));
                var fastjoin_cmd = {
                    "Level": cc.dgame.gameplay.Level
                };
                cc.dgame.net.sendMsg(["fastjoin", JSON.stringify(fastjoin_cmd)], self.onFastJoin.bind(self))
                self.waitCount = 0
                self.schedule(self.waitForStart, 0.5)
            } else {
                cc.dgame.net.sendMsg(["ready",""], self.onSelfReady.bind(self))
            }
/*
            self.scheduleOnce(function() {
                self.listener.broadcastListener(self.listener.EVENTSTRINGS.ALL_PLAYERS_READY)
            }, 5)
*/
        }, this)
        // 全体玩家就绪接收
        this.listener.registerListener(this.listener.EVENTSTRINGS.ALL_PLAYERS_READY, function() {
            //self.getComponent('AudioMng').playNormal()
            //self.unschedule(self.waitForStart)
            //self.listener.broadcastListener(self.listener.EVENTSTRINGS.NEW_GAME)
        }, this)
        // 发牌接收
        this.listener.registerListener(this.listener.EVENTSTRINGS.DEAL_POKERS, function(tableData) {
            self.dealPokerHandler(tableData, false)
        }, this)
        // 决定地主回调
        this.listener.registerListener(this.listener.EVENTSTRINGS.DECIDE_DIZHU_CALL_BACK, function(data) {
            self.decideDiZhuCallback(data)
        }, this)
        // 游戏结束回调
        this.listener.registerListener(this.listener.EVENTSTRINGS.GAME_OVER_CALL_BACK, function(data) {
            self.remindLabel.string = self.strings.GAME_OVER
            for (var i = 0; i < self.players.length; i++) {
                var player = self.getPlayerByPos(i)
                if (i === data.winner) {
                    self.playerInfo[i].amount = parseFloat(self.playerInfo[i].amount) + data.base * data.multiple
                    if (player.isDiZhu) {
                        self.playerInfo[i].amount = parseFloat(self.playerInfo[i].amount) + data.base * data.multiple
                    }
                } else {
                    self.playerInfo[i].amount = parseFloat(self.playerInfo[i].amount) - data.base * data.multiple
                    if (player.isDiZhu) {
                        self.playerInfo[i].amount = parseFloat(self.playerInfo[i].amount) - data.base * data.multiple
                    }
                }
                player.setStakeNum(self.playerInfo[i].amount)
            }
            var player = self.getPlayerByPos(data.winner)
            var landlordWin = false
            var hint = ""
            if (player.isDiZhu) {
                landlordWin = true
                hint = "地主 +" + (2 * data.base * data.multiple) + ", 农民 -" + (data.base * data.multiple)
            } else {
                hint = "地主 -" + (2 * data.base * data.multiple) + ", 农民 +" + (data.base * data.multiple)
            }
            self.getComponent('AudioMng').stopMusic()
            if (self.playerMyself.isDiZhu && player.isDiZhu || !self.playerMyself.isDiZhu && !player.isDiZhu) {
                self.getComponent('AudioMng').playWin()
            } else {
                self.getComponent('AudioMng').playLose()
            }
            self.gameOverPanel.setActive(player.isDiZhu ? "地主" : "农民", hint, function() {
                cc.log("游戏结束")
                self.gameMultiple.string = "0"
                self.newGameHandle()
            })
        }, this)
        // 新游戏回调
        this.listener.registerListener(this.listener.EVENTSTRINGS.NEW_GAME_CALL_BACK, function(data) {
            cc.log ("新游戏开始")
            self.newGameCallback(data)
        }, this)
        // 重新开始发牌
        this.listener.registerListener(this.listener.EVENTSTRINGS.RE_DEAL_CALL_BACK, function(data) {
            self.scheduleOnce(self.newGameHandle, 1)
        }, this)
    },

    // 和客户端的通信
    initClientListener:function() {
        var self = this
        // 叫地主操作
        this.listener.registerListener(this.listener.EVENTSTRINGS.PLAYER_CALLDIZHU_OPERATE, function(tableData) {
            self.operatePanel.showCallPanel()
            // 同时添加倒计时操作
            self.callCountDown.setActive(30, function() {
                // 不抢
                self.operatePanel.noCallDiZhuClicked()
            })
        }, this)
        // 抢地主操作
        this.listener.registerListener(this.listener.EVENTSTRINGS.PLAYER_ROBDIZHU_OPERATE, function(tableData) {
            self.operatePanel.showRob()
            // 同时添加倒计时操作
            self.robCountDown.setActive(30, function() {
                // 不抢
                self.operatePanel.noRob()
            })
        }, this)
        // 出牌操作
        this.listener.registerListener(this.listener.EVENTSTRINGS.PLAYER_CALLOUTCARD_OPERATE, function(tableData) {
            self.playerMyself.hideRemind()
            if (tableData == 2) {
                self.operatePanel.showOnlyOut()
                self.outCountDown.setActive(30, function() {
                    // 需要将所有牌置为不选
                    self.playerMyself.disposeHandPokers()
                    // 选择一张牌
                    var poker = self.playerMyself.handPoker[self.playerMyself.handPoker.length - 1]
                    poker.isSelected = true
                    // 出牌
                    self.operatePanel.outCard()
                })
            } else {
                self.operatePanel.showOut()
                self.followCountDown.setActive(30, function() {
                    // 不出
                    self.operatePanel.noOut()
                })
            }
        }, this)
        // 操作提示
        this.listener.registerListener(this.listener.EVENTSTRINGS.PLAYER_REMIND, function(tableData) {
            self.remindLabel.string = tableData

            // 3秒后将提示隐藏
            self.scheduleOnce(function() {
                self.remindLabel.string = ""
            }, 3)
        }, this)
        // 隐藏面板
        this.listener.registerListener(this.listener.EVENTSTRINGS.HIDE_OPERATE_PANEL, function(tableData) {
            self.operatePanel.hideOutPanel()
            self.followCountDown.setDisable()
            self.outCountDown.setDisable()
        }, this)
    },

    // 配置控件
    initWidget:function() {
        var self = this
        // 设置开始游戏回调
        this.operatePanel.setStartCallback(function() {
            var resultData = {}
            resultData.index = self.playerMyself.index
            resultData.state = self.enums.READY
            self.listener.broadcastListener(self.listener.EVENTSTRINGS.PLAYER_READY, resultData)
        })
        // 设置叫地主回调
        this.operatePanel.setCallCallback(function() {
            var calldizhu_cmd = {
                ID: cc.dgame.gameplay.seatId,
                OP: 1,
            }
            cc.dgame.net.sendMsg(["Grab", JSON.stringify(calldizhu_cmd)], self.onCallRobDizhu.bind(self))
            // 点击后会将倒计时隐藏
            self.callCountDown.setDisable()
        }, function() {
            var calldizhu_cmd = {
                ID: cc.dgame.gameplay.seatId,
                OP: 0,
            }
            cc.dgame.net.sendMsg(["Grab", JSON.stringify(calldizhu_cmd)], self.onCallRobDizhu.bind(self))
            self.callCountDown.setDisable()
        })
        // 设置抢地主回调
        this.operatePanel.setRobCallback(function() {
            var robdizhu_cmd = {
                ID: cc.dgame.gameplay.seatId,
                OP: 1,
            }
            cc.dgame.net.sendMsg(["Grab", JSON.stringify(robdizhu_cmd)], self.onCallRobDizhu.bind(self))
            // 点击后会将倒计时隐藏
            self.robCountDown.setDisable()
        }, function() {
            var robdizhu_cmd = {
                ID: cc.dgame.gameplay.seatId,
                OP: 0,
            }
            cc.dgame.net.sendMsg(["Grab", JSON.stringify(robdizhu_cmd)], self.onCallRobDizhu.bind(self))
            self.robCountDown.setDisable()
        })
        // 设置出牌回调
        this.operatePanel.setOutCallback(function() {
            self.playerMyself.playerOutCard()
/*
            var result = self.playerMyself.playerOutCard()

            if (result) {
                self.followCountDown.setDisable()
                self.outCountDown.setDisable()
            }
            // 重新调配位置
            self.playerMyself.disposeHandPokers()
*/
        }, function() {
            self.playerMyself.noOutCard()
/*
            self.followCountDown.setDisable()
            self.outCountDown.setDisable()
            // 重新调配位置
            self.playerMyself.disposeHandPokers()
*/
        })

        // 添加叫地主倒计时
        this.callCountDownNode = cc.instantiate (this.countDownPrefab)
        this.callCountDownNode.x = 0
        this.callCountDownNode.y = 0
        this.uiLayer.addChild(this.callCountDownNode)

        // 配置抢地主倒计时功能
        this.callCountDown = this.callCountDownNode.getComponent("countdown")
        this.callCountDown.setDisable()

        // 添加抢地主倒计时
        this.robCountDownNode = cc.instantiate (this.countDownPrefab)
        this.robCountDownNode.x = 0
        this.robCountDownNode.y = 0
        this.uiLayer.addChild(this.robCountDownNode)

        // 配置抢地主倒计时功能
        this.robCountDown = this.robCountDownNode.getComponent("countdown")
        this.robCountDown.setDisable()

        // 添加跟牌倒计时
        this.followCountDownNode = cc.instantiate (this.countDownPrefab)
        this.followCountDownNode.x = 0
        this.followCountDownNode.y = 0
        this.uiLayer.addChild(this.followCountDownNode)

        // 配置跟牌倒计时功能
        this.followCountDown = this.followCountDownNode.getComponent("countdown")
        this.followCountDown.setDisable()

        // 添加出牌倒计时
        this.outCountDownNode = cc.instantiate (this.countDownPrefab)
        this.outCountDownNode.x = 0
        this.outCountDownNode.y = 0
        this.uiLayer.addChild(this.outCountDownNode)

        // 配置出牌倒计时功能
        this.outCountDown = this.outCountDownNode.getComponent("countdown")
        this.outCountDown.setDisable()

        // 上家倒计时
        this.playerUpCountDownNode = cc.instantiate (this.countDownPrefab)
        this.playerUpCountDownNode.x = -300
        this.playerUpCountDownNode.y = 200
        this.uiLayer.addChild(this.playerUpCountDownNode)

        // 配置上家倒计时功能
        this.playerUpCountDown = this.playerUpCountDownNode.getComponent("countdown")
        this.playerUpCountDown.setDisable()

        // 下家倒计时
        this.playerDownCountDownNode = cc.instantiate (this.countDownPrefab)
        this.playerDownCountDownNode.x = 300
        this.playerDownCountDownNode.y = 200
        this.uiLayer.addChild(this.playerDownCountDownNode)

        // 配置下家倒计时功能
        this.playerDownCountDown = this.playerDownCountDownNode.getComponent("countdown")
        this.playerDownCountDown.setDisable()
    },

    // 根据位置获取玩家对象
    getPlayerByPos:function(pos) {
        if (pos < 0 || pos > 2)
            return null

        switch (cc.dgame.gameplay.seatId) {
            case 0:
                if (pos === 0)
                    return this.playerMyself
                else if (pos === 1)
                    return this.playerDown
                else
                    return this.playerUp
                break
            case 1:
                if (pos === 0)
                    return this.playerUp
                else if (pos === 1)
                    return this.playerMyself
                else
                    return this.playerDown
                break
            case 2:
                if (pos === 0)
                    return this.playerDown
                else if (pos === 1)
                    return this.playerUp
                else
                    return this.playerMyself
                break
        }

        return null
    },

    // 发牌回调
    dealPokerHandler:function(tableData, isRecover) {
        cc.log(JSON.stringify(tableData))
        if (!isRecover) {
            var index = 0
            var self = this
            this.getComponent('AudioMng').playCard()
            this.schedule (function() {
                for (var i = 0; i < 3; i++) {
                    var pokers = tableData.Pokers[i]
                    if (i == 0) {
                        self.pokers[pokers[index]].setValue(cc.dgame.gameplay.Pokers[pokers[index]])
                        self.pokers[pokers[index]].reveal(true)
                        self.playerMyself.pickUpOne(self.pokers[pokers[index]])
                    } else if (i == 1) {
                        self.pokers[pokers[index]].reveal(false)
                        self.playerDown.pickUpOne(self.pokers[pokers[index]])
                    } else {
                        self.pokers[pokers[index]].reveal(false)
                        self.playerUp.pickUpOne(self.pokers[pokers[index]])
                    }
                }
    
                if (16 == index) {
                    // 调整剩下的位置
                    self.pokers[tableData.Pokers[3][0]].reveal(false)
                    self.pokers[tableData.Pokers[3][1]].reveal(false)
                    self.pokers[tableData.Pokers[3][2]].reveal(false)
                    self.pokers[tableData.Pokers[3][0]].node.x -= 100
                    self.pokers[tableData.Pokers[3][2]].node.x += 100
                    // 告知服务器需要叫地主
                    if (cc.dgame.gameplay.seatId === tableData.Turn) {
                        self.operatePanel.showCallPanel()
                        // 同时添加倒计时操作
                        self.callCountDown.setActive(30, function() {
                            // 不抢
                            self.operatePanel.noCallDiZhuClicked()
                        })
                    } else {
                        var player = self.getPlayerByPos(tableData.Turn)
                        if (player === self.playerUp) {
                            self.playerUpCountDown.setActive(30, function() {
                                self.playerUpCountDown.setDisable()
                            })
                        } else {
                            self.playerDownCountDown.setActive(30, function() {
                                self.playerDownCountDown.setDisable()
                            })
                        }
                    }
                    self.printPokerInfo()
                }
                index++
            }, 0.22, 16)
        } else {
            for (var index = 0; index < 17; index++) {
                for (var i = 0; i < 3; i++) {
                    var pokers = tableData.Pokers[i]
                    if (i == 0) {
                        this.pokers[pokers[index]].setValue(cc.dgame.gameplay.Pokers[pokers[index]])
                        this.pokers[pokers[index]].reveal(true)
                        this.playerMyself.pickUpOne(this.pokers[pokers[index]])
                    } else if (i == 1) {
                        this.pokers[pokers[index]].reveal(false)
                        this.playerDown.pickUpOne(this.pokers[pokers[index]])
                    } else {
                        this.pokers[pokers[index]].reveal(false)
                        this.playerUp.pickUpOne(this.pokers[pokers[index]])
                    }
                }
            }
            // 调整剩下的位置
            this.pokers[tableData.Pokers[3][0]].reveal(false)
            this.pokers[tableData.Pokers[3][1]].reveal(false)
            this.pokers[tableData.Pokers[3][2]].reveal(false)
            this.pokers[tableData.Pokers[3][0]].node.x -= 100
            this.pokers[tableData.Pokers[3][2]].node.x += 100
        }
    },

    // 决定地主回调方法
    decideDiZhuCallback:function(data) {

        for (var i = 0; i < data.dizhuPoker.length; i++) {
            // 获取扑克
            var poker = this.pokers[data.dizhuPoker[i]]
            poker.reveal(true)
            // 设置位置
            // if (i == 0) {
            //     poker.node.x = poker.node.x - 100
            // } else if (i == 1) {
            //     poker.node.x = poker.node.x + 100
            // }
        }

        var self = this
        this.scheduleOnce(function() {
            for (var i = 0; i < self.players.length; i++) {
                var player = self.players[i]
                // 如果是地主
                if (player.index == data.index) {
                    player.setIsDiZhu(true)
                    // 将剩余的地主牌交给地主
                    for (var j = 0; j < data.dizhuPoker.length; j++) {
                        if (!player.isSelf) {
                            self.pokers[data.dizhuPoker[j]].reveal(false)
                        }
                        player.pickUpOne(self.pokers[data.dizhuPoker[j]])
                    }

                    player.setPokerAble()
                } else {
                    player.setIsDiZhu(false)
                }
                // 隐藏提示
                player.hideRemind()
            }
        }, 1)
    },

    // 重新开始的回调
    newGameCallback:function(data) {
        // 将手牌清理
        for (var i = 0; i < this.players.length; i++) {
            var player = this.players[i]
            player.clearHandPokers()
            player.setIsDiZhu(false)
        }

        this.remindLabel.string = ""
        this.getComponent('AudioMng').playNormal()
    },

    // 添加一组扑克
    addPokers:function() {
        for (var i = 0; i < 54; i++) {
            var pokerNode = cc.instantiate (this.pokerPrefab)
            var poker = pokerNode.getComponent("poker")
            poker.setIndex(i)
            poker.setValue(54)
            pokerNode.x = 0
            pokerNode.y = 250
            poker.reveal(false)
            this.table.addChild(pokerNode)
            this.pokers.push(poker)
        }
        for (var i = 0; i < 3; i++) {
            var pokerNode = cc.instantiate (this.pokerPrefab)
            var poker = pokerNode.getComponent("poker")
            poker.setIndex(i)
            poker.setValue(54)
            pokerNode.setScale(0.8)
            pokerNode.x = 0
            pokerNode.y = 250
            poker.reveal(false)
            poker.node.active = false
            this.table.addChild(pokerNode)
            this.landlordPokers.push(poker)
        }
        this.landlordPokers[0].node.x -= 60
        this.landlordPokers[2].node.x += 60
    },

    // 重新开始
    newGameHandle:function() {
        // 重置扑克位置
        for (var i = 0; i < this.pokers.length; i++) {
            var poker = this.pokers[i]
            poker.setIndex(i)
            poker.setValue(54)
            poker.node.active = true
            poker.node.x = 0
            poker.node.y = 250
            poker.scale = 1
            poker.reveal(false)
        }

        // 隐藏地主牌
        for (var i = 0; i < 3; i++) {
            var poker = this.landlordPokers[i]
            poker.setIndex(i)
            poker.setValue(54)
            poker.reveal(false)
            poker.node.active = false
        }

        // 将手牌清理
        for (var i = 0; i < this.players.length; i++) {
            var player = this.players[i]
            player.clearHandPokers()
            player.setIsDiZhu(false)
        }

        this.remindLabel.string = ""
        // 隐藏控制面板
        this.operatePanel.hideOutPanel()
        this.operatePanel.robPanel.active = false

        this.operatePanel.showStart()
        this.getComponent('AudioMng').playMusic()
        //this.listener.broadcastListener(this.listener.EVENTSTRINGS.NEW_GAME)
    },

    onLeaveTable: function(data) {
        console.log('[onLeaveTable]', JSON.stringify(data))
    },

    // 退出房间
    backToMenu:function() {
        cc.dgame.net.sendMsg(["leave", ""], this.onLeaveTable.bind(this))
    },

    // 等待开始...
    waitForStart: function() {
        if (this.waitCount === 0) {
            this.remindLabel.string = this.strings.WAITING_FOR_START
        }
        this.remindLabel.string += "."
        this.waitCount++
        if (this.waitCount == 5) {
            this.waitCount = 0
        }
    },

    // fastjoin消息响应函数
    onFastJoin: function(data) {
        cc.log(JSON.stringify(data))
    },

    // AllotTable事件响应函数
    onAllotTable: function(data) {
        cc.log(JSON.stringify(data))
        cc.dgame.gameplay.tableid = data.TableID
        var tableId = cc.find('Canvas/tablelayer/tablebg/tableid').getComponent(cc.Label)
        tableId.string = cc.dgame.gameplay.tableid
        tableId.node.active = true
        var temp = parseInt(cc.dgame.gameplay.tableid)
        cc.dgame.net.addEventListener(["leave", temp], this.onLeave.bind(this))
        cc.dgame.net.addEventListener(["ready", temp], this.onReady.bind(this))
        cc.dgame.net.addEventListener(["startGame", temp], this.onStartGame.bind(this))
        cc.dgame.net.addEventListener(["gameEvent", temp], this.onGameEvent.bind(this))
        cc.dgame.net.addEventListener(["settle", temp], this.onSettle.bind(this))
        this.onPlayersInfo(data.Players)
    },

    // 玩家信息
    onPlayersInfo: function(players) {
        // 本人玩的都在中间，按Pos顺序0、1、2；若本人是0，则1为下家，2为上家；若本人是1，则0为上家，2为下家；若本人是2，则1为上家，0为下家
        // this.players下标0、1、2固定对应为本人、下家、上家，而this.PlayerInfo的下标为牌桌中的顺序
        for (var i = 0; i < players.length; i++) {
            var seatid = players[i].Pos
            this.playerInfo[seatid] = {}
            this.playerInfo[seatid].playerAddr = players[i].PlayerAddr
            this.playerInfo[seatid].amount = players[i].Amount
            if (players[i].PlayerAddr.toLowerCase() === cc.dgame.gameplay.selfaddr) {
                cc.dgame.gameplay.seatId = seatid
                cc.dgame.gameplay.Multiple = 0
                this.playerMyself.setPlayerAddr(players[i].PlayerAddr)
                this.playerMyself.setStakeNum(players[i].Amount)
                cc.dgame.net.sendMsg(["ready",""], this.onSelfReady.bind(this))
            }
        }

        switch (cc.dgame.gameplay.seatId) {
            case 0:
                this.playerMyself.index = 0
                this.playerDown.index = 1
                this.playerUp.index = 2
                this.playerUp.setPlayerAddr(this.playerInfo[2].playerAddr)
                this.playerUp.setStakeNum(this.playerInfo[2].amount)
                this.playerDown.setPlayerAddr(this.playerInfo[1].playerAddr)
                this.playerDown.setStakeNum(this.playerInfo[1].amount)
                break
            case 1:
                this.playerMyself.index = 1
                this.playerDown.index = 2
                this.playerUp.index = 0
                this.playerUp.setPlayerAddr(this.playerInfo[0].playerAddr)
                this.playerUp.setStakeNum(this.playerInfo[0].amount)
                this.playerDown.setPlayerAddr(this.playerInfo[2].playerAddr)
                this.playerDown.setStakeNum(this.playerInfo[2].amount)
                break
            case 2:
                this.playerMyself.index = 2
                this.playerDown.index = 0
                this.playerUp.index = 1
                this.playerUp.setPlayerAddr(this.playerInfo[1].playerAddr)
                this.playerUp.setStakeNum(this.playerInfo[1].amount)
                this.playerDown.setPlayerAddr(this.playerInfo[0].playerAddr)
                this.playerDown.setStakeNum(this.playerInfo[0].amount)
                break
        }
    },

    // 玩家准备就绪响应函数
    onSelfReady: function(data) {
        cc.log(data)
        this.playerInfo[cc.dgame.gameplay.seatId].ready = true
        this.playerMyself.setReady()
    },

    // Leave事件响应函数
    onLeave: function(data) {
        console.log('[onLeave]', JSON.stringify(data))
        this.playerInfo.needFastjoin = true
        var temp = parseInt(cc.dgame.gameplay.tableid)
        if (!isNaN(temp)) {
            cc.dgame.net.removeEventListener(["leave"])
            cc.dgame.net.removeEventListener(["ready"])
            cc.dgame.net.removeEventListener(["startGame"])
            cc.dgame.net.removeEventListener(["gameEvent"])
            cc.dgame.net.removeEventListener(["settle"])
            cc.dgame.net.removeEventListener(["allotTable"])
        }
        for (var i = 0; i < this.players.length; i++) {
            var player = this.players[i]
            player.setPlayerAddr("")
            player.hideStake()
            this.playerInfo[i] = {}
        }
        cc.dgame.gameplay.tableid = ""
        var tableId = cc.find('Canvas/tablelayer/tablebg/tableid').getComponent(cc.Label)
        tableId.string = cc.dgame.gameplay.tableid
        tableId.node.active = false
        this.unschedule(this.waitForStart)
        this.waitCount = 0
        this.operatePanel.showStart()
        if (data.Addr.toLowerCase() == cc.dgame.gameplay.selfaddr.toLowerCase()) {
            cc.director.loadScene('GameHall')
        }
    },

    // Ready事件响应函数
    onReady: function(data) {
        cc.log(data)
        this.playerInfo[data.Pos].ready = true
        var player = this.getPlayerByPos(data.Pos)
        player.setReady()
    },

    // StartGame事件响应函数
    onStartGame: function(data) {
        cc.log(data)
    },

    handleStartInfo: function(data, isRecover) {
        for (var i = 0; i < this.players.length; i++) {
            var player = this.players[i]
            player.hideReady()
        }
        this.getComponent('AudioMng').playNormal()
        this.remindLabel.string = ""
        this.waitCount = 0
        this.unschedule(this.waitForStart)
        var tableData = {}
        tableData.Turn = data.Turn
        // 用于保存已显示的牌
        cc.dgame.gameplay.Pokers = new Array()
        var cards0 = new Array()
        var cards1 = new Array()
        var cards2 = new Array()
        for (var i = 0; i < 54; i++) {
            cc.dgame.gameplay.Pokers[i] = undefined
            if (i < 17) {
                cards0.push(i)
            } else if (i < 34) {
                cards1.push(i)
            } else if (i < 51) {
                cards2.push(i)
            }
        }
        for (var i = 0; i < data.SelfCard.privateIndex.length; i++) {
            cc.dgame.gameplay.Pokers[data.SelfCard.privateIndex[i]] = data.SelfCard.privateCard[i]
        }
        // tablectrl.players玩家数组以0为本玩家、1为下家、2为上家作为固定顺序
        // pokerData以Pos为序
        var pokerData = new Array()
        // 玩家Pos位置为0
        if (data.SelfCard.privateIndex[0] === 0) {
            pokerData.push(cards0)
            pokerData.push(cards1)
            pokerData.push(cards2)
        } else if (data.SelfCard.privateIndex[0] === 17) {
            pokerData.push(cards1)
            pokerData.push(cards2)
            pokerData.push(cards0)
        } else {
            pokerData.push(cards2)
            pokerData.push(cards0)
            pokerData.push(cards1)
        }
        // 剩下的三张牌
        var remainCards = new Array()
        remainCards.push(data.DeskCard.publicIndex[0])
        remainCards.push(data.DeskCard.publicIndex[1])
        remainCards.push(data.DeskCard.publicIndex[2])

        pokerData.push(remainCards)
        tableData.Pokers = pokerData
        this.dealPokerHandler(tableData, isRecover)
    },

    handleGrabTurnInfo: function(data) {
        // {"Event":"GrabTurnInfo","Params":{"Grab":{"ID":0,"OP":1},"Multiple":0,"CurnSeat":0,"CurnOPName":0,"IsMyTurn":false}}
        // Event -- 事件名称
        // Grab -- ID：上一位操作玩家的位置；OP：上一位玩家的操作，1为叫地主/抢地主，0为不叫/不抢
        // Multiple -- 倍数，初始倍数为0，叫地主x1，抢地主x2
        // CurnSeat -- 当前操作玩家的位置
        // CurnOPName -- 当前操作玩家可操作的动作，0为叫地主，1为抢地主
        // IsMyTurn -- 是否为本人轮次
        var lastPlayer = this.getPlayerByPos(data.Grab.ID)
        if (lastPlayer === this.playerUp) {
            this.playerUpCountDown.setDisable()
        } else if (lastPlayer === this.playerDown) {
            this.playerDownCountDown.setDisable()
        }
        // 标签更改
        if (lastPlayer !== null) {
            lastPlayer.remindLabel.node.active = true
            if (data.Multiple < 2) {
                lastPlayer.remindLabel.string = data.Grab.OP == 1 ? this.strings.CALL_DIZHU : this.strings.NO_CALL
            } else {
                lastPlayer.remindLabel.string = data.Grab.OP == 1 ? this.strings.ROB_DIZHU : this.strings.NO_ROB
            }
        }
        cc.dgame.gameplay.Multiple = data.Multiple
        this.gameMultiple.string = data.Multiple

        var curPlayer = this.getPlayerByPos(data.CurnSeat)
        if (curPlayer === this.playerUp) {
            var self = this
            this.playerUpCountDown.setActive(30, function() {
                self.playerUpCountDown.setDisable()
            })
        } else if (curPlayer === this.playerDown) {
            var self = this
            this.playerDownCountDown.setActive(30, function() {
                self.playerDownCountDown.setDisable()
            })
        }
        if (data.IsMyTurn) {
            var self = this
            if (data.CurnOPName === 0) {
                this.operatePanel.showCallPanel()
                // 同时添加倒计时操作
                this.callCountDown.setActive(30, function() {
                    // 不抢
                    self.operatePanel.noCallDiZhuClicked()
                })
            } else {
                this.operatePanel.showRob()
                // 同时添加倒计时操作
                this.robCountDown.setActive(30, function() {
                    // 不抢
                    self.operatePanel.noRob()
                })
            }
        }
    },

    handleStartPlayCardInfo: function(data) {
        this.playerUpCountDown.setDisable()
        this.playerDownCountDown.setDisable()
        cc.dgame.gameplay.Multiple = data.FinalMultiple
        cc.dgame.gameplay.LandlordSeat = data.LandlordSeat
        for (var i = 0; i < data.DeskCard.publicIndex.length; i++) {
            cc.dgame.gameplay.Pokers[data.DeskCard.publicIndex[i]] = data.DeskCard.publicCard[i]
            this.pokers[data.DeskCard.publicIndex[i]].setValue(data.DeskCard.publicCard[i])
            this.pokers[data.DeskCard.publicIndex[i]].reveal(true)
            this.landlordPokers[i].setValue(data.DeskCard.publicCard[i])
        }
        cc.log(new Date().toLocaleString() + " 显示最后三张牌")
        var self = this
        this.scheduleOnce(function() {
            for (var i = 0; i < self.players.length; i++) {
                var player = self.players[i]
                // 如果是地主
                if (player.index === cc.dgame.gameplay.LandlordSeat) {
                    player.setIsDiZhu(true)
                    // 将剩余的地主牌交给地主
                    for (var j = 0; j < data.DeskCard.publicIndex.length; j++) {
                        if (!player.isSelf) {
                            self.pokers[data.DeskCard.publicIndex[j]].reveal(false)
                        }
                        player.pickUpOne(self.pokers[data.DeskCard.publicIndex[j]])
                        self.landlordPokers[j].reveal(true)
                        self.landlordPokers[j].node.active = true
                    }
                    cc.log(new Date().toLocaleString() + " 地主拿走最后三张牌")

                    player.setPokerAble()
                } else {
                    player.setIsDiZhu(false)
                }
                // 隐藏提示
                player.hideRemind()
            }
        }, 1)
    },

    handlePlayCardInfo: function(data) {
        this.printTurnInfo(data)
        this.gameMultiple.string = data.CurrentMultiple
        if (data.CurrentPlay.Seat !== null && data.CurrentPlay.Seat !== undefined && data.CurrentPlay.Seat !== cc.dgame.gameplay.seatId) {
            for (var i = 0; i < data.CurrentPlay.Index.length; i++) {
                cc.dgame.gameplay.Pokers[data.CurrentPlay.Index[i]] = data.CurrentPlay.Card[i]
                this.pokers[data.CurrentPlay.Index[i]].setValue(data.CurrentPlay.Card[i])
                this.pokers[data.CurrentPlay.Index[i]].reveal(true)
            }
            var lastPlayer = this.getPlayerByPos(data.CurrentPlay.Seat)
            if (lastPlayer === this.playerUp) {
                this.playerUpCountDown.setDisable()
            } else if (lastPlayer === this.playerDown) {
                this.playerDownCountDown.setDisable()
            }
            lastPlayer.showOutCard(data.CurrentPlay)
        }
        if (data.IsMyTurn) {
            this.playerMyself.hideRemind()
            this.listener.broadcastListener(this.listener.EVENTSTRINGS.READY_PLAY_A_HAND_CALL_BACK, data)
        } else {
            // NextTurn为-1代表游戏结束
            if (data.NextTurn !== -1) {
                var curPlayer = this.getPlayerByPos(data.NextTurn)
                curPlayer.clearTablePokers()
                if (curPlayer === this.playerUp) {
                    var self = this
                    this.playerUp.hideRemind()
                    this.playerUpCountDown.setActive(30, function() {
                        self.playerUpCountDown.setDisable()
                    })
                } else if (curPlayer === this.playerDown) {
                    var self = this
                    this.playerDown.hideRemind()
                    this.playerDownCountDown.setActive(30, function() {
                        self.playerDownCountDown.setDisable()
                    })
                }
            }
        }
    },

    handleGameOverInfo: function(data) {
        for (var i = 0; i < data.RemainCard.length; i++) {
            var player = this.getPlayerByPos(data.RemainCard[i].Seat)
            cc.log("before getHandPokers(" + data.RemainCard[i].Seat + "): " + player.getHandPokers())
            for (var j = 0; j < data.RemainCard[i].Index.length; j++) {
                cc.dgame.gameplay.Pokers[data.RemainCard[i].Index[j]] = data.RemainCard[i].Card[j]
                this.pokers[data.RemainCard[i].Index[j]].setValue(data.RemainCard[i].Card[j])
            }
            cc.log("after getHandPokers(" + data.RemainCard[i].Seat + "): " + player.getHandPokers())
            player.hideDizhuMark()
            if (player !== this.playerMyself) {
                player.resortHandPokers(data.RemainCard[i].Card, data.RemainCard[i].Index)
                player.revealHandPokers()
            }
        }

        for (var i = 0; i < this.players.length; i++) {
            var player = this.players[i]
            if (player !== this.playerMyself) {
                player.hideCardsNum()
            }
            player.hideRemind()
        }
        this.printPokerInfo()
        // 配置游戏结束时的数据
        this.overData = {}
        this.overData.winner = data.Win
        this.overData.base = data.Base
        this.overData.multiple = data.Multiple
    },

    handleReshuffleInfo: function() {
        // 重置扑克位置
        for (var i = 0; i < this.pokers.length; i++) {
            var poker = this.pokers[i]
            poker.setIndex(i)
            poker.setValue(54)
            poker.node.active = true
            poker.node.x = 0
            poker.node.y = 250
            poker.scale = 1
            poker.reveal(false)
        }

        this.callCountDown.setDisable()
        this.robCountDown.setDisable()
        this.playerUpCountDown.setDisable()
        this.playerDownCountDown.setDisable()
        for (var i = 0; i < this.players.length; i++) {
            var player = this.players[i]
            player.clearHandPokers()
            player.setIsDiZhu(false)
            player.hideRemind()
        }
        this.remindLabel.string = ""
    },
    // GameEvent事件响应函数
    onGameEvent: function(data) {
        cc.log(data)
        if (data.Event === "StartInfo") {
            this.handleStartInfo(data.Params, false)
        } else if (data.Event === "GrabTurnInfo") {
            this.handleGrabTurnInfo(data.Params)
        } else if (data.Event === "StartPlayCardInfo") {
            this.handleStartPlayCardInfo(data.Params)
        } else if (data.Event === "PlayCardInfo") {
            this.handlePlayCardInfo(data.Params)
        } else if (data.Event === "GameOverInfo") {
            this.handleGameOverInfo(data.Params)
        } else if (data.Event === "ReshuffleInfo") {
            this.handleReshuffleInfo()
        }
    },

    // Settle事件响应函数
    onSettle: function(data) {
        cc.log(data)
        // 游戏结束
        this.listener.broadcastListener(this.listener.EVENTSTRINGS.GAME_OVER_CALL_BACK, this.overData)
    },

    // 叫地主消息响应
    onCallRobDizhu: function(data) {
        cc.log(data)
    },

    printTurnInfo: function(data) {
        if (data.CurrentPlay.Seat !== null && data.CurrentPlay.Seat !== undefined) {
            var player = this.getPlayerByPos(data.CurrentPlay.Seat)
            cc.log(new Date().toLocaleString() + " 上轮 " + (player === this.playerMyself ? "我" : (player === this.playerUp ? "上家" : "下家")) + " 出牌 " + JSON.stringify(data.CurrentPlay.Card))
        }
        if (data.NextTurn !== -1) {
            var player = this.getPlayerByPos(data.NextTurn)
            cc.log(new Date().toLocaleString() + " 本轮轮到 " + (player === this.playerMyself ? "我" : (player === this.playerUp ? "上家" : "下家")) + " 出牌")
        } else {
            cc.log(new Date().toLocaleString())
        }
    },

    printPokerInfo: function() {
        var result = new Array()
        for (var i = 0; i < this.pokers.length; i++) {
            result.push(this.pokers[i].getInfo())
        }
        cc.log(result)
        result = new Array()
        for (var i = 0; i < cc.dgame.gameplay.Pokers.length; i++) {
            result.push(cc.dgame.gameplay.Pokers[i])
        }
        cc.log(result)
    },
});
