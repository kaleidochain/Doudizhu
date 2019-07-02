cc.Class({
    extends: cc.Component,

    properties: {
        loginWithPassword: cc.Node,
        accountList: cc.Node,
        currentNickname: cc.Label,
        editPassword: cc.EditBox,
        loginMnemonicToast: cc.Node,
        createAccountToast: cc.Node,
        loginPasswordErrorTips: cc.Label,
    },

    // LIFE-CYCLE CALLBACKS:

    // onLoad () {},
    onBack: function () {
        cc.director.loadScene('gamehall')
    },

    onLoad: function () {
        this.currentNickname.string = cc.dgame.settings.account.Nickname
    },

    onClickCreateAccountLink: function() {
        this.createAccountToast.active = true
    },

    onClickCreateAccountToastOK: function() {
        this.createAccountToast.active = false
        cc.director.loadScene('createAccount')
    },

    onClickCreateAccountToastCancel: function() {
        this.createAccountToast.active = false
    },

    onClickLoginMnemonicToastOK: function() {
        this.loginMnemonicToast.active = false
        cc.director.loadScene('loginMnemonic')
    },

    onClickLoginMnemonicToastCancel: function() {
        this.loginMnemonicToast.active = false
    },

    onClickLoginMnemonicLink: function() {
        this.loginMnemonicToast.active = true
    },

    onClickCloseLoginWithPassword: function() {
        cc.director.loadScene('splash')
    },

    onSwitchAccount: function() {
        this.accountList.active = !this.accountList.active
        if (this.accountList.active) {
            this.loadLocalAccounts()
        }
    },

    loadLocalAccounts: function() {
        var accountList = this.accountList.getComponent('accountList');
        var data = new Array()
        for (var i = 0; i < cc.dgame.settings.accountsInfo.length; i++) {
            var accountInfo = {}
            accountInfo.Nickname = cc.dgame.settings.accountsInfo[i].Nickname
            accountInfo.Addr = cc.dgame.settings.accountsInfo[i].Addr
            data.push(accountInfo)
        }
        accountList.populateList(data)
    },
    // update (dt) {},

    //点击下拉列表中的昵称会调用
    tryVerifyAccount: function(nickname, addr) {
        console.log("clicked: " + nickname + ", " + addr)
        this.currentNickname.string = nickname
        cc.dgame.settings.account.Nickname = nickname
        cc.dgame.settings.account.Addr = addr
        this.accountList.active = false
    },

    onClickVerifyAccount: function() {
        var ret = false;
        if (cc.sys.isNative && cc.sys.isMobile) {
            if (cc.sys.os === cc.sys.OS_IOS) {
                ret = jsb.reflection.callStaticMethod("NativeGengine", "unlockAccount:withPassword:", cc.dgame.settings.account.Addr, this.editPassword.string)
            } else if (cc.sys.os === cc.sys.OS_ANDROID) {
                ret = jsb.reflection.callStaticMethod("io/kaleidochain/NativeGengine", "unlockAccountWithPassword", "(Ljava/lang/String;Ljava/lang/String;)Z", cc.dgame.settings.account.Addr, this.editPassword.string)
            }
        }
        if (ret) {
            cc.sys.localStorage.setItem("currentAccount", JSON.stringify(cc.dgame.settings.account))
            cc.dgame.settings.account.Password = this.editPassword.string
            cc.director.loadScene('gamehall')
        } else {
            this.loginPasswordErrorTips.string = '密码错误，请重新输入'
            this.scheduleOnce(function() {
                this.loginPasswordErrorTips.string = ""
            }, 3)
        }
    },
});
