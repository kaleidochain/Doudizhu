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
        // foo: {
        //     // ATTRIBUTES:
        //     default: null,        // The default value will be used only when the component attaching
        //                           // to a node for the first time
        //     type: cc.SpriteFrame, // optional, default is typeof default
        //     serializable: true,   // optional, default is true
        // },
        // bar: {
        //     get () {
        //         return this._bar;
        //     },
        //     set (value) {
        //         this._bar = value;
        //     }
        // },
    },

    // LIFE-CYCLE CALLBACKS:

    // onLoad () {},

    onLoad: function() {
        if (cc.dgame === null || cc.dgame === undefined) {
            cc.dgame = {};
            cc.dgame.net = require('Net'); //网络模块，通过websocket连接负责与gengine通讯
            cc.dgame.gameplay = {}; //牌局信息，保存每个玩家所在位置、玩家账号地址、牌点信息、地主信息等
            cc.dgame.settings = {}; //设置项，例如使用什么网络（外网、内网）、账号地址等
        }
        if (cc.sys.localStorage.getItem("accountsInfo") === null) {
            cc.sys.localStorage.setItem("accountsInfo", "[]")
            cc.dgame.settings.accountsInfo = []
        } else {
            cc.dgame.settings.accountsInfo = JSON.parse(cc.sys.localStorage.getItem("accountsInfo"))
        }
        //{"Addr":"0x019Dd28763B06CfC52A0a89efF7610d4FD5e1a6e","Nickname":"napster"}
        //校验当前账号是否在钱包当中
        if (cc.sys.isNative && cc.sys.isMobile) {
            var accounts = "[]";
            if (cc.sys.os === cc.sys.OS_IOS ) {
                accounts = jsb.reflection.callStaticMethod("NativeGengine", "getAccounts")
            } else if (cc.sys.os === cc.sys.OS_ANDROID) {
                accounts = jsb.reflection.callStaticMethod("io/kaleidochain/NativeGengine", "getAccounts", "()Ljava/lang/String;")
            }
            cc.dgame.settings.accounts = JSON.parse(accounts)
            var currentAccountInfo = cc.sys.localStorage.getItem("currentAccount")
            if (currentAccountInfo === null || currentAccountInfo === "") {
                cc.dgame.settings.account = null
            } else {
                cc.dgame.settings.account = JSON.parse(currentAccountInfo)
                var found = false
                for (var i = 0; i < cc.dgame.settings.accounts.length; i++) {
                    if (cc.dgame.settings.account.Addr.toLowerCase() === cc.dgame.settings.accounts[i].toLowerCase()) {
                        found = true
                        break
                    }
                }
                if (!found) {
                    cc.sys.localStorage.removeItem("currentAccount")
                    cc.dgame.settings.account = null
                }
            }
        }
        console.log("cur: " + JSON.stringify(cc.dgame.settings.account) + ", accounts: " + JSON.stringify(cc.dgame.settings.accounts) + ", accountsInfo: " + JSON.stringify(cc.dgame.settings.accountsInfo))
        cc.director.preloadScene('gamehall', function () {
            cc.log('Next scene preloaded')
        });
    },

    startGame: function() {
        //cc.director.loadScene('gamehall')
        if (cc.dgame.settings.account === null) {
            cc.director.loadScene('createAccount')
        } else {
            cc.director.loadScene('loginAccount')
        }
    },

    // update (dt) {},
});
