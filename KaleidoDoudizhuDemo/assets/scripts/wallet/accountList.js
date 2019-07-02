cc.Class({
    extends: cc.Component,

    properties: {
        scrollView: cc.ScrollView,
        prefabAccountItem: cc.Prefab,
        accountNum: 0
    },

    // use this for initialization
    onLoad: function () {
        this.content = this.scrollView.content;
        //this.populateList();
    },

    populateList: function(data) {
        this.content.removeAllChildren()
        for (let i in data) {
            var accountInfo = {};
            accountInfo.Addr = data[i].Addr;
            accountInfo.Nickname = data[i].Nickname;
            var item = cc.instantiate(this.prefabAccountItem);
            item.getComponent('accountItem').init(accountInfo);
            this.content.addChild(item);
        }
    },

    // called every frame
    update: function (dt) {

    },
});
