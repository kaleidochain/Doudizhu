/**
	消息中心，所有的消息都通过这里来注册，广播
	实现：用一个数组保存回调，目标，标示等信息
	每一个标示对应一个数组
*/
module.exports = {
	// 保存回调的数组
	listeners: {
		default: [],
		type: [Object],
	},

	// 初始化
	init: function() {
    	// 加载事件配置
    	this.EVENTSTRINGS = require("eventutils")
	},

	// 注册消息
	registerListener:function(id, callback, target) {
		// 打包，使id和回调一一对应
		var pack = {}
		pack.callback = callback
		pack.target = target

		// 将包放入数组，在保存在回调数组中 
		if (this.listeners[id] == null) {
			var callbacks = new Array()
			callbacks.push(pack)
			this.listeners[id] = callbacks
		} else {
			var callbacks = this.listeners[id]
			callbacks.push(pack)
		}
	},

	// 注销消息
	removeListener:function(id, target) {
		// 根据标示获取到回调数组
		var callbacks = this.listeners[id]
		if (callbacks) {
			// 创建移除数组
			var eraseArray = new Array()
			// 循环从数组中获取回调
			for (var i = 0; i < callbacks.length; i++) {
				var pack = callbacks[i]
				// 如果是指定目标，则下标放入移除数组
				if (pack.target == target) {
					eraseArray.push(i)
				}
			}

			// 循环移除数组，将其删除
			for (var i = eraseArray.length - 1; i >= 0; i--) {
				callbacks.splice(eraseArray[i], 1)
			}
		}
	},

	// 广播消息
	broadcastListener:function(id, data) {
		var callbacks = this.listeners[id]

		// 如果为空则不执行
		if (callbacks) {
			// 循环从数组中获取回调
			for (var i = 0; i < callbacks.length; i++) {
				var pack = callbacks[i]

				// 从包中获取回调和目标
				var callback = pack.callback
				var target = pack.target
				callback(data)
			}
		}
	},
};