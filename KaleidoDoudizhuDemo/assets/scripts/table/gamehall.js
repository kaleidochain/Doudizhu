cc.Class({
    extends: cc.Component,

    properties: {
        nickname: cc.Label,
        currentGoldNum: cc.Label,
        loadinglayer: cc.Node,
        loadingTips: cc.Label,
        btnRetry: cc.Button,
        btnBack: cc.Button,
    },

    onSelfAddress: function(data) {
        console.log(data);
        if (typeof(data) === "string") {
            cc.dgame.gameplay.selfaddr = data.toLowerCase();
        }
    },

    onLeave: function(data) {
        console.log(data)
    },

    onBalanceOf: function(data) {
        console.log('onBalanceOf: ' + JSON.stringify(data))
        cc.dgame.settings.account.Gold = parseInt(data.Balance)
        if (this.currentGoldNum != null) {
            this.currentGoldNum.string = cc.dgame.settings.account.Gold;
        }
    },

    onGiveMeToken: function(data) {
        console.log(data)
        cc.dgame.net.sendMsg(["balanceOf", ""], this.onBalanceOf.bind(this))
    },

    onRunGame: function(data) {
        console.log("load complete(" + data + ")")
        if (cc.dgame.currentScene == "GameHall") {
            if (data.length > 25) {
                if (data.indexOf("msglist.txt: no such file or directory") !== -1) {
                    cc.dgame.net.sendMsg(["leave", ""], this.onLeave.bind(this))
                }
            }
            if (parseInt(data) === 0) {
                this.unschedule(this.updateLoadingTips)
                this.loadinglayer.active = false
                this.enableRoomBtn()
                cc.dgame.net.sendMsg(["givemetoken", ""], this.onGiveMeToken.bind(this))
            } else {
                this.unschedule(this.updateLoadingTips)
                this.loadingTips.string = this.strings.LOAD_FAIL_CHECK_NETWORK
                this.btnRetry.node.active = true
            }
        }
    },

    updateLoadingTips: function() {
        if (this.loadCount === 0) {
            this.loadingTips.string = this.strings.WAITING_FOR_LOAD
        }
        this.loadingTips.string += "."
        this.loadCount++
        if (this.loadCount == 5) {
            this.loadCount = 0
        }
    },

    runGame: function() {
        if (this.wsconnected) {
            var rungame_cmd = {
                game_contract_addr: cc.dgame.settings.game_contract_addr,
                game_nodes: JSON.parse(cc.dgame.settings.game_nodes)
            }
            cc.dgame.net.sendMsg(["rungame", JSON.stringify(rungame_cmd)], this.onRunGame.bind(this))
            this.btnRetry.node.active = false
            this.loadCount = 0
            this.loadingTips.string = this.strings.WAITING_FOR_LOAD
            this.schedule(this.updateLoadingTips, 0.5)
            this.loadinglayer.active = true
        }
    },

    onOpen: function(obj) {
        if (cc.dgame.currentScene == "GameHall") {
            this.wsconnected = true
            cc.dgame.net.sendMsg(["selfaddress", ""], this.onSelfAddress.bind(this))
            //cc.dgame.settings.game_contract_addr = "7be295035c500c374b1219e79e92ee2c6700f4b7"
            //cc.dgame.settings.game_nodes = JSON.stringify(["enode://9b93cf2e45d98d3c95c432ea0858bc41e3148bcb36226e9143c0780ba85e24b796a6e3c2401b7ff756ac7f1058310ca563f20700c3371930639feaa94505da1d"])
            // cc.dgame.settings.game_contract_addr = "6065538c541bddb9f3780f8866dbfc98e7f4431a";
            // cc.dgame.settings.game_nodes = JSON.stringify(['enode://2ef3a87ca373b003a3fe2ef3a30430698603039740779fafca2d129a263ea384248eb7e9ca96778d47068f43f8fd77d13af55356e42342a78b995d4d179ccfc8@192.168.0.211:38883']);
            //cc.dgame.settings.game_contract_addr = "462832aea3c380cb56d1112295e16658cd992679";
            //cc.dgame.settings.game_nodes = JSON.stringify(['enode://78afd98ec657a7320cb984ffc7c701ef439f717e1267b43fee7c8101e08939cafb2d7518eef69d4a0b982b5f206416036397f513b7817186249064063f4ce8d2@192.168.0.213:38883']);
            //cc.dgame.settings.game_nodes = JSON.stringify(['enode://3e256d081ca0bad611b3384058028f1640459f5d956f48644ccb37942ae7bbf9e06a15e6ed69a504a937d03e2be690c7e8e60372588bc3babc3caf4f663d4e95@106.75.184.214:38883']);
            //cc.dgame.settings.game_nodes = JSON.stringify(['enode://d75a7f554e4bff18cb10bcee2c46c6940ab6ccbbeb1409828cc9fb2a0707dd4b115c6559243c141a2f8019e2b90b6feec24097ad249b5475362be9af3d94267c@128.1.133.161:38883']);
            cc.dgame.settings.game_nodes = JSON.stringify(['enode://5b80ec4ffcc7054f8d22bbb946a78457975c6cc1c187f9261dea83bf4099091921ac9b64837f0e7d74c8b976a7d4ba28bdfb0c54bb1196e301f8ec3aa7c2aa1f@106.75.184.214:38883']);
            this.runGame()
        }
    },

    onClose: function(obj){
        console.log("连接断开");
        if (cc.dgame.currentScene == "GameHall") {
            this.wsconnected = false
            if (cc.sys.isNative && cc.sys.isMobile) {
                if (cc.sys.os === cc.sys.OS_IOS) {
                    jsb.reflection.callStaticMethod("NativeGengine", "stopGameEngine")
                    cc.audioEngine.stopAll()
                    cc.game.restart()
                } else if (cc.sys.os === cc.sys.OS_ANDROID) {
                    jsb.reflection.callStaticMethod("io/kaleidochain/NativeGengine", "stopGameEngine", "()Z")
                    cc.audioEngine.stopAll()
                    cc.game.restart()
                }
            }
        }
    },

    // use this for initialization
    onLoad: function () {
        cc.dgame.currentScene = "GameHall"
        this.strings = require("string_zh")
        this.nickname.string = cc.dgame.settings.account.Nickname
        this.wsconnected = false
        cc.sys.dump()
        cc.log("cc.sys.isNative = " + cc.sys.isNative)
        this.getComponent('AudioMng').playMusic()
        var isRunning = true;
        if (cc.sys.isNative && cc.sys.isMobile) {
            if (cc.sys.os === cc.sys.OS_IOS) {
                isRunning = jsb.reflection.callStaticMethod("NativeGengine", "isRunning")
            } else if (cc.sys.os === cc.sys.OS_ANDROID) {
                isRunning = jsb.reflection.callStaticMethod("io/kaleidochain/NativeGengine", "isRunning", "()Z")
            }
        }
        if (!isRunning) {
            this.scheduleOnce(this.startGengine, 0.1)
        } else {
            this.wsconnected = true
            this.enableRoomBtn()
            cc.dgame.net.sendMsg(["balanceOf", ""], this.onBalanceOf.bind(this));
        }
        cc.director.preloadScene('tablescene', function () {
            cc.log('Next scene preloaded')
        });
    },

    startGengine: function() {
        console.log("account: " + cc.dgame.settings.account.Addr + ", password: " + cc.dgame.settings.account.Password)
        var ret = false;
        if (cc.sys.isNative && cc.sys.isMobile) {
            if (cc.sys.os === cc.sys.OS_IOS) {
                ret = jsb.reflection.callStaticMethod("NativeGengine", "startGameEngineWithAccount:andPassword:", cc.dgame.settings.account.Addr, cc.dgame.settings.account.Password)
            } else if (cc.sys.os === cc.sys.OS_ANDROID) {
                ret = jsb.reflection.callStaticMethod("io/kaleidochain/NativeGengine", "startGameEngineWithAccountAndPassword", "(Ljava/lang/String;Ljava/lang/String;)Z", cc.dgame.settings.account.Addr, cc.dgame.settings.account.Password)
            }
        }
        if (ret === false) {
            if (cc.sys.os === cc.sys.OS_IOS) {
                jsb.reflection.callStaticMethod("NativeGengine", "callNativeUIWithTitle:andContent:", "Gengine启动失败","启动失败")
            } else if (cc.sys.os === cc.sys.OS_ANDROID) {
                jsb.reflection.callStaticMethod("org/cocos2dx/javascript/AppActivity", "showAlertDialog", "(Ljava/lang/String;Ljava/lang/String;)V", "Gengine启动失败","启动失败")
            }
        } else {
            let wsport = 0;
            if (cc.sys.os === cc.sys.OS_IOS) {
                wsport = jsb.reflection.callStaticMethod("NativeGengine", "getWSPort");
            } else if (cc.sys.os === cc.sys.OS_ANDROID) {
                wsport = jsb.reflection.callStaticMethod("io/kaleidochain/NativeGengine", "getWSPort", "()I")
            }
            console.log("开始连接：ws://127.0.0.1:" + wsport);
            cc.dgame.net.connect(this.onOpen.bind(this), this.onClose.bind(this), "127.0.0.1:" + wsport);
        }
    },

    enterPreviewRoom: function() {
        cc.dgame.gameplay.Level = 1
        cc.director.loadScene('tablescene')
    },

    enterLowLevelRoom: function() {
        cc.dgame.gameplay.Level = 2
        cc.director.loadScene('tablescene')
        // this.currentSceneUrl = 'tablescene';
        // cc.director.loadScene('tablescene', this.onLoadSceneFinish.bind(this));
        //cc.director.loadScene('tablescene')
    },

    enterMidLevelRoom: function() {
        cc.dgame.gameplay.Level = 3
        cc.director.loadScene('tablescene')
        //cc.director.loadScene('tablescene')
        //var ret = jsb.reflection.callStaticMethod("NativeGengine", "addPeer")
    },

    enterHighLevelRoom: function() {
        cc.dgame.gameplay.Level = 4
        cc.director.loadScene('tablescene')
        //cc.director.loadScene('tablescene')
        // var ret = jsb.reflection.callStaticMethod("NativeGengine", "resolveGameNode:", "enode://b03f992282d5418907d7627d142684785f344faa1bd2abc1ceb6e7e77d2b01980ca1849e35bba7c33cdd82cb288af87f990e8161b2c055fd8ffc3d847cae24ea")
        // jsb.reflection.callStaticMethod("NativeGengine", "callNativeUIWithTitle:andContent:", "resolveGameNode",ret)
    },

    // called every frame
    update: function (dt) {

    },

    onLoadSceneFinish: function() {
        cc.log(this.currentSceneUrl)
        this.btnBack.node.active = !(this.currentSceneUrl == 'gamehall')
    },

    // 退出房间
    backToMenu:function() {
        this.currentSceneUrl = 'gamehall'
        cc.director.loadScene('gamehall', this.onLoadSceneFinish.bind(this))
    },

    openAccountMgr:function() {
        cc.director.loadScene('loginAccount')
    },

    onClickExchange: function() {
        cc.director.loadScene('exchange')
    },

    onClickClearCache: function() {
        if (cc.sys.isNative && cc.sys.isMobile) {
            if (cc.sys.os === cc.sys.OS_IOS) {
                jsb.reflection.callStaticMethod("NativeGengine", "stopGameEngine")
                jsb.reflection.callStaticMethod("NativeGengine", "clearCache")
                this.getComponent('AudioMng').stopMusic()
                cc.game.restart()
            } else if (cc.sys.os === cc.sys.OS_ANDROID) {
                jsb.reflection.callStaticMethod("io/kaleidochain/NativeGengine", "stopGameEngine", "()Z")
                jsb.reflection.callStaticMethod("io/kaleidochain/NativeGengine", "clearCache", "()V")
                this.getComponent('AudioMng').stopMusic()
                cc.game.restart()
            }
        }
    },

    enableRoomBtn: function() {
        let btnPreviewRoom = cc.find('Canvas/roomlayer/previewroom').getComponent(cc.Button)
        let btnLowLevelRoom = cc.find('Canvas/roomlayer/lowlevelroom').getComponent(cc.Button)
        let btnMidLevelRoom = cc.find('Canvas/roomlayer/midlevelroom').getComponent(cc.Button)
        let btnHighLevelRoom = cc.find('Canvas/roomlayer/highlevelroom').getComponent(cc.Button)
        btnPreviewRoom.interactable = true
        btnLowLevelRoom.interactable = true
        btnMidLevelRoom.interactable = true
        btnHighLevelRoom.interactable = true
    },
});
