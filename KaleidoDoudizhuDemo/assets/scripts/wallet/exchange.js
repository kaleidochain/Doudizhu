cc.Class({
    extends: cc.Component,

    properties: {
        //五个子场景
        exchangeGold: cc.Node,
        exchangeUSDT: cc.Node,
        exchangeUSDTConfirm: cc.Node,
        donate: cc.Node,
        donateConfirm: cc.Node,
        //TabBar
        btnExchangeGoldPress: cc.Node,
        btnExchangeUSDTPress: cc.Node,
        btnDonatePress: cc.Node,
        //exchangeGold
        exchangeGoldAddr: cc.Label,
        exchangeGoldCurrentGold: cc.Label,
        copyTips: cc.Node,
        //exchangeUSDT
        editGoldNumber: cc.EditBox,
        editExchangeAddr: cc.EditBox,
        exchangeUSDTCurrentGold: cc.Label,
        //exchangeUSDTConfirm
        exchangeUSDTConfimGoldNumber: cc.Label,
        exchangeUSDTConfimExchangeAddr: cc.Label,
        exchangeUSDTTips: cc.Node,
        //donate
        editDonateGoldNumber: cc.EditBox,
        editDonateFriendID: cc.EditBox,
        myID: cc.Label,
        totalGoldNumber: cc.Label,
        //donateConfirm
        donateConfirmGoldNumber: cc.Label,
        donateConfirmFirendID: cc.Label,
        donateTips: cc.Node,
    },

    // LIFE-CYCLE CALLBACKS:

    // onLoad () {},
    onClickClose: function () {
        cc.director.loadScene('gamehall')
    },

    onLoad: function () {
        cc.dgame.currentScene = "Exchange"
        this.exchangeGold.active = true
        this.exchangeUSDT.active = false
        this.exchangeUSDTConfirm.active = false
        this.donate.active = false
        this.donateConfirm.active = false
        this.btnExchangeGoldPress.active = true
        this.btnExchangeUSDTPress.active = false
        this.btnDonatePress.active = false

        if (cc.dgame.settings.account != null && cc.dgame.settings.account != undefined && cc.dgame.settings.account.Addr != null && cc.dgame.settings.account.Addr != undefined) {
            this.exchangeGoldAddr.string = cc.dgame.settings.account.Addr
        }
        if (cc.dgame.settings.account != null && cc.dgame.settings.account != undefined && cc.dgame.settings.account.Gold != null && cc.dgame.settings.account.Gold != undefined) {
            this.exchangeGoldCurrentGold.string = cc.dgame.settings.account.Gold
            this.exchangeUSDTCurrentGold.string = cc.dgame.settings.account.Gold
            this.totalGoldNumber.string = cc.dgame.settings.account.Gold
        }
    },

    onClickCopyToClipboard: function() {
        this.copyTips.active = true
        this.scheduleOnce(function() {
            this.copyTips.active = false
        }, 3)
    },

    onClickExchangeGoldNormal: function() {
        this.exchangeGold.active = true
        this.exchangeUSDT.active = false
        this.exchangeUSDTConfirm.active = false
        this.donate.active = false
        this.donateConfirm.active = false
        this.btnExchangeGoldPress.active = true
        this.btnExchangeUSDTPress.active = false
        this.btnDonatePress.active = false
    },

    onClickExchangeUSDTNormal: function() {
        this.exchangeGold.active = false
        this.exchangeUSDT.active = true
        this.exchangeUSDTConfirm.active = false
        this.donate.active = false
        this.donateConfirm.active = false
        this.btnExchangeGoldPress.active = false
        this.btnExchangeUSDTPress.active = true
        this.btnDonatePress.active = false
    },

    onClickDonateNormal: function() {
        this.exchangeGold.active = false
        this.exchangeUSDT.active = false
        this.exchangeUSDTConfirm.active = false
        this.donate.active = true
        this.donateConfirm.active = false
        this.btnExchangeGoldPress.active = false
        this.btnExchangeUSDTPress.active = false
        this.btnDonatePress.active = true
    },

    // update (dt) {},

    onClickExchangeUSDTOK: function() {
        this.exchangeGold.active = false
        this.exchangeUSDT.active = false
        this.exchangeUSDTConfirm.active = true
        this.donate.active = false
        this.donateConfirm.active = false

        this.exchangeUSDTConfimGoldNumber.string = this.editGoldNumber.string
        this.exchangeUSDTConfimExchangeAddr.string = this.editExchangeAddr.string
    },

    onClickDonateOK: function() {
        this.exchangeGold.active = false
        this.exchangeUSDT.active = false
        this.exchangeUSDTConfirm.active = false
        this.donate.active = false
        this.donateConfirm.active = true

        this.donateConfirmGoldNumber.string = this.editDonateGoldNumber.string
        this.donateConfirmFirendID.string = this.editDonateFriendID.string
    },

    onClickExchangeUSDTConfirmOK: function() {
        this.exchangeUSDTTips.active = true
        this.scheduleOnce(function() {
            this.exchangeUSDTTips.active = false
        }, 3)
    },

    onClickDonateConfirmOK: function() {
        this.donateTips.active = true
        this.scheduleOnce(function() {
            this.donateTips.active = false
        }, 3)
    },
});
