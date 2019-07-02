// Learn cc.Class:
//  - [Chinese] http://docs.cocos.com/creator/manual/zh/scripting/class.html
//  - [English] http://www.cocos2d-x.org/docs/creator/en/scripting/class.html
// Learn Attribute:
//  - [Chinese] http://docs.cocos.com/creator/manual/zh/scripting/reference/attributes.html
//  - [English] http://www.cocos2d-x.org/docs/creator/en/scripting/reference/attributes.html
// Learn life-cycle callbacks:
//  - [Chinese] http://docs.cocos.com/creator/manual/zh/scripting/life-cycle-callbacks.html
//  - [English] http://www.cocos2d-x.org/docs/creator/en/scripting/life-cycle-callbacks.html

cc.Class({
    extends: cc.Component,

    properties: {
        title: {
            default: null,
            type: cc.Label,
        },
        winloss: {
            default: null,
            type: cc.Label,
        },
    },

    // LIFE-CYCLE CALLBACKS:
    // 传入胜利者和回调
    setActive:function(name, winloss, callback) {
        this.node.active = true
        // 提示标签
        this.title.string = name + "获得胜利！"
        this.winloss.string = winloss
        this.callback = callback
    },

    // 按钮事件
    endClicked:function() {
        cc.log ("确定")
        this.node.active = false
        if (this.callback) {
            this.callback()
        }
    },
});
