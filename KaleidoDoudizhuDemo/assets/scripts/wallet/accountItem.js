cc.Class({
    extends: cc.Component,

    properties: {
        nickname: cc.Label,
        // ...
    },

    // use this for initialization
    init: function (accountInfo) {
//        this.indexNum.string = accountInfo.index.toString()
        this.nickname.string = accountInfo.Nickname
        this.accountAddr = accountInfo.Addr
//        this.labelGold.string = accountInfo.Gold.toString()
    },

    // called every frame
    update: function (dt) {

    },

    selectAccount: function() {
        var loginAccount = cc.find('loginAccount').getComponent('loginAccount')
        //wallet.updateCurrentAccount(this.accountAddr.string)
        loginAccount.tryVerifyAccount(this.nickname.string, this.accountAddr)
    },
});
