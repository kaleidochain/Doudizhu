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
        // 时间标签
        timeLabel: {
            default: null,
            type: cc.Label,
        },
    },

    // LIFE-CYCLE CALLBACKS:

    // 设置时间和回调
    setActive:function(time, callback) {
        this.node.active = true
        this.time = time
        // 设置倒计时
        this.timeLabel.string = this.time
        // 设置回调
        this.callback = callback
        // 设置时钟
        this.schedule (this.timerUpdate, 1, time - 1)
    },

    // 更新
    timerUpdate:function() {
        this.time = this.time - 1
        this.timeLabel.string = this.time

        // 结束后回调
        if (this.time == 0 && this.callback) {
            this.callback()
            this.setDisable()
        }
    },

    // 设置不可用
    setDisable:function() {
        // 关闭定时器
        this.unschedule(this.timerUpdate)
        this.node.active = false
    },
});
