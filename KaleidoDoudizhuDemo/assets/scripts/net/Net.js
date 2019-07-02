var Global = cc.Class({
    extends: cc.Component,
    statics: {
        netControl: null,
        _handlers: null,
        _msgid: null,
        _eventName2handler: null,
        _eventName2msgid: null,
        _subscriptionid2eventName: null,
        _eventName2subscriptionid: null,
        _msgId:function() {
            return this._msgid++;
        },

        _addHandler:function(msgid, fn) {
            if(this._handlers[msgid]){
                console.log("msgid:" + msgid + "' handler has been registered.");
                return;
            }
            var handler = function(data){
                //console.log(event + "(" + typeof(data) + "):" + (data? data.toString():"null"));
                //if(typeof(data) == "string"){
                //    data = JSON.parse(data);
                //}
                fn(data);
            };
            
            this._handlers[msgid] = handler; 
        },

        connect:function(fnConnect, fnError, addr) {
            this._handlers = {};
            this._msgid = 0;
            this._eventName2handler = {};
            this._eventName2msgid = {};
            this._subscriptionid2eventName = {};
            this._eventName2subscriptionid = {};
            this.netControl = require('NetControl');
            this.netControl.connect(addr);
            this.messageFire = onfire.on("onopen", fnConnect.bind(this));
            this.messageFire = onfire.on("onclose", fnError.bind(this));
            this.messageFire = onfire.on("onmessage", this._onMessage.bind(this));
        },

        sendMsg:function(params, msgHandler) {
            var data = {
                jsonrpc: "2.0",
                method: "dgame_call",
                params: params,
                id: this._msgId(),
            };
            if (msgHandler != null && msgHandler != undefined) {
                this._addHandler(data.id, msgHandler.bind(this));
            }
            this.netControl.send(JSON.stringify(data));
        },

        _eventHandler:function(result) {
            this._subscriptionid2eventName
        },

        addEventListener:function(params, eventHandler) {
            var data = {
                jsonrpc: "2.0",
                method: "dgame_subscribe",
                params: params,
                id: this._msgId(),
            };
            this._eventName2handler[params[0]] = eventHandler;
            this._eventName2msgid[params[0]] = data.id;
            this.netControl.send(JSON.stringify(data));
        },

        removeEventListener:function(params) {
            var data = {
                jsonrpc: "2.0",
                method: "dgame_unsubscribe",
                params: [this._eventName2subscriptionid[params[0]]],
                id: this._msgId(),
            };
            this._eventName2handler[params[0]] = null;
            this._eventName2subscriptionid[params[0]] = null;
            this._eventName2msgid[params[0]] = data.id;
            this.netControl.send(JSON.stringify(data));
        },

        _isSubscriptionMsgid:function(msgid) {
            for (var eventName in this._eventName2msgid) {
                if (this._eventName2msgid[eventName] == msgid)
                    return eventName;
            }
            return null;
        },

        _onMessage:function(obj){
            //cc.log(obj)·
            var jsonRpc = JSON.parse(obj.data);
            if (jsonRpc.id != undefined) {
                var eventName = this._isSubscriptionMsgid(jsonRpc.id);
                if (eventName != null) {
                    this._subscriptionid2eventName[jsonRpc.result] = eventName;
                    this._eventName2subscriptionid[eventName] = jsonRpc.result;
                    this._eventName2msgid[eventName] = null;
                } else {
                    if (this._handlers[jsonRpc.id]) {
                        this._handlers[jsonRpc.id](jsonRpc.result);
                    }
                }
                this._handlers[jsonRpc.id] = null;
            } else {
                var subscriptionid = jsonRpc.params.subscription;
                if (this._eventName2handler[this._subscriptionid2eventName[subscriptionid]]) {
                    this._eventName2handler[this._subscriptionid2eventName[subscriptionid]](jsonRpc.params.result);
                }
            }
        },
    },
});