// Learn cc.Class:
//  - [Chinese] http://www.cocos.com/docs/creator/scripting/class.html
//  - [English] http://www.cocos2d-x.org/docs/editors_and_tools/creator-chapters/scripting/class/index.html
// Learn Attribute:
//  - [Chinese] http://www.cocos.com/docs/creator/scripting/reference/attributes.html
//  - [English] http://www.cocos2d-x.org/docs/editors_and_tools/creator-chapters/scripting/reference/attributes/index.html
// Learn life-cycle callbacks:
//  - [Chinese] http://www.cocos.com/docs/creator/scripting/life-cycle-callbacks.html
//  - [English] http://www.cocos2d-x.org/docs/editors_and_tools/creator-chapters/scripting/life-cycle-callbacks/index.html

cc.Class({
    extends: cc.Component,

    properties: {
        // 开始游戏面板
        startPanel: {
            default: null,
            type: cc.Node,
        },
        // 抢地主面板
        robPanel: {
            default: null,
            type: cc.Node,
        },
        // 出牌面板
        outPanel: {
            default: null,
            type: cc.Node,
        },
        // 只有出牌
        onlyOut: {
            default: null,
            type: cc.Node,
        },
        // 叫地主面板
        callPanel: {
            default: null,
            type: cc.Node,
        },
    },

    // LIFE-CYCLE CALLBACKS:

    onLoad:function () {},

    // 显示开始游戏面板
    showStart:function() {
        this.startPanel.active = true
    },

    // 设置开始游戏操作回调
    setStartCallback:function(startCallback) {
        this.startCallback = startCallback
    },

    // 开始游戏
    startGame:function() {
        if (this.startCallback) {
            this.startCallback()
        }

        this.startPanel.active = false
    },

    // 显示抢地主面板
    showRob:function() {
        this.robPanel.active = true
    },

    // 设置抢地主操作回调
    setRobCallback:function(robDiZhuCallback, noRobCallback) {
        this.robDiZhuCallback = robDiZhuCallback
        this.noRobCallback = noRobCallback
    },

    // 抢地主
    robDiZhu:function() {
        if (this.robDiZhuCallback) {
            this.robDiZhuCallback()
        }

        this.robPanel.active = false
    },

    // 不抢
    noRob:function() {
        if (this.noRobCallback) {
            this.noRobCallback()
        }

        this.robPanel.active = false
    },

    // 显示出牌面板
    showOut:function() {
        this.outPanel.active = true
    },

    // 显示只出牌面板
    showOnlyOut:function() {
        this.onlyOut.active = true
    },

    // 设置出牌操作回调
    setOutCallback:function(outCardCallback, noOutCallback) {
        this.outCardCallback = outCardCallback
        this.noOutCallback = noOutCallback
    },

    // 出牌
    outCard:function() {
        if (this.outCardCallback) {
            this.outCardCallback()
        }

        // this.outPanel.active = false
    },

    // 不出
    noOut:function() {
        if (this.noOutCallback) {
            this.noOutCallback()
        }

        this.outPanel.active = false
    },

    // 隐藏出牌面板
    hideOutPanel:function() {
        this.outPanel.active = false
        this.onlyOut.active = false
    },

    // 叫地主面板
    // 设置叫地主回调
    setCallCallback:function(callCallback, noCallCallback) {
        this.callCallback = callCallback
        this.noCallCallback = noCallCallback
    },

    // 显示叫地主面板
    showCallPanel:function() {
        this.callPanel.active = true
    },

    // 隐藏叫地主面板
    hideCallPanel:function() {
        this.callPanel.active = false
    },

    // 叫地主
    callDiZhuClicked:function() {
        if (this.callCallback) {
            this.callCallback()
        }

        this.callPanel.active = false
    },

    // 不叫
    noCallDiZhuClicked:function() {
        if (this.noCallCallback) {
            this.noCallCallback()
        }

        this.callPanel.active = false
    }
});
