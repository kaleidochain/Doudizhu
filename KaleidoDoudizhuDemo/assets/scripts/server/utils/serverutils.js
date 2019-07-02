// 服务器中的一些配置
module.exports = {
	// 枚举
	NOT_READY:              0,          //未准备就绪
	READY:                  1,          //准备就绪
	WAITING: 				2,			//还未行动
	NO_CALL_STATE: 			3,			//不叫
	NO_ROB_STATE: 			4,			//不抢
	CALL_DIZHU_STATE: 		5,			//叫地主
	ROB_DIZHU_STATE: 		6,			//抢地主

	FARMER_STATE: 			7,			//农民
	LADNLORD_STATE: 		8, 			//地主

	// 初始化服务器数据
	initServerData:function() {
		// 用来保存服务器数据
		this.serverData = {}
		this.serverData.lastWinner = -1
	},
};