cc.Class({
    extends: cc.Component,

    properties: {
        loginMnemonic: cc.Node,
        createPassowrd: cc.Node,
        createNickname: cc.Node,
        editPassword: cc.EditBox,
        editNickname: cc.EditBox,
        loginMnemonicErrorTips: cc.Label,
        editMnemonics: {
            default: [],
            type: cc.EditBox,
        }
    },

    // LIFE-CYCLE CALLBACKS:

    // onLoad () {},
    onBack: function () {
        cc.director.loadScene('gamehall')
    },

    onLoad: function () {
    },

    onClickCloseLoginMnemonic: function() {
        cc.director.loadScene('splash')
    },

    onClickCloseCreatePassword: function() {
        this.loginMnemonic.active = true
        this.createPassowrd.active = false
        this.createNickname.active = false
    },

    onClickCloseCreateNickname: function() {
        this.loginMnemonic.active = false
        this.createPassowrd.active = true
        this.createNickname.active = false
    },

    // update (dt) {},

    onClickLoginMnemonicNext: function() {
        this.mnemonic = ""
        for (var i = 0; i < this.editMnemonics.length; i++) {
            if (i != this.editMnemonics.length - 1) {
                this.mnemonic = this.mnemonic + this.editMnemonics[i].string + " "
            } else {
                this.mnemonic = this.mnemonic + this.editMnemonics[i].string
            }
        }
        console.log("mnemonic: " + this.mnemonic)
        this.loginMnemonic.active = false
        this.createPassowrd.active = true
        this.createNickname.active = false
    },

    onClickCreatePassword: function() {
        var pubkey = ""
        if (cc.sys.os === cc.sys.OS_IOS) {
            pubkey = jsb.reflection.callStaticMethod("NativeGengine", "importAccount:withPassword:", this.mnemonic, this.editPassword.string)
        } else if (cc.sys.os === cc.sys.OS_ANDROID) {
            pubkey = jsb.reflection.callStaticMethod("io/kaleidochain/NativeGengine", "importAccountWithPassword", "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;", this.mnemonic, this.editPassword.string)
        }
        if (pubkey !== null && pubkey !== undefined && pubkey.length > 0) {
            this.loginMnemonic.active = false
            this.createPassowrd.active = false
            this.createNickname.active = true
            this.accountAddr = pubkey
        } else {
            this.loginMnemonicErrorTips.string = '账户导入失败，请返回重新输入助记词'
            this.scheduleOnce(function() {
                this.loginMnemonicErrorTips.string = ""
            }, 3)
        }
    },

    onClickCreateNickname: function() {
        var accountInfo = {}
        accountInfo.Nickname = this.editNickname.string
        accountInfo.Addr = this.accountAddr
        cc.dgame.settings.account = accountInfo
        cc.dgame.settings.accountsInfo.push(accountInfo)
        cc.sys.localStorage.setItem("accountsInfo", JSON.stringify(cc.dgame.settings.accountsInfo))
        cc.sys.localStorage.setItem("currentAccount", JSON.stringify(accountInfo))
        cc.dgame.settings.account.Password = this.editPassword.string
        cc.director.loadScene('gamehall')
    },

});
