// 加载玩家类
var Player = require("player")

cc.Class({
    extends: cc.Component,

    properties: {
        // 牌序，0~54，根据这个来发牌
        index: 0,
    	// 牌值，0~54，根据这个来判断是什么花色什么数字
    	value: 0,
        // 上数值和花色
        upNumLabel: {
            default: null,
            type: cc.Label,
        },
        upColorSprite: {
            default: null,
            type: cc.Sprite,
        },
        // 下数值和花色
        downNumLabel: {
            default: null,
            type: cc.Label,
        },
        downColorSprite: {
            default: null,
            type: cc.Sprite,
        },

        // 花色资源
        colorFrames: {
            default: [],
            type: cc.SpriteFrame,
        },
        // 牌背景
        pokerBackground: {
            default: null,
            type: cc.Sprite,
        },
        pokerFrontBG: {
            default: null,
            type: cc.SpriteFrame,
        },
        pokerBackBG: {
            default: null,
            type: cc.SpriteFrame,
        },
        // 大小王
        sjokerSprite: {
            default: null,
            type: cc.Node,
        },
        bjokerSprite: {
            default: null,
            type: cc.Node,
        },
    },

    // LIFE-CYCLE CALLBACKS:

    onLoad:function () {
    	this.initConfigs()
    	this.setPoker()
    },

    // 获取配置
    initConfigs:function() {
        // 配置手牌花色信息
        this.pokerutils = require ("pokerutils")
        // 未选中
        this.isSelected = false
        // 持有该牌的玩家
        this.player = null

        // 不可用的
        this.disabled = true

        // 添加触摸开始事件
        var self = this
        this.node.on (cc.Node.EventType.TOUCH_START, function(event) {
            // 更改选中状态
            if (self.player && !self.disabled) {
                self.isSelected = !self.isSelected
                self.player.pokerSelected(self)
            }
        }, this.node);
    },

    // 设置牌序
    setIndex:function(value) {
        this.index = value
    },

    // 设置牌值
    setValue:function(value) {
    	this.value = value
    	if (this.pokerutils) {
    		this.setPoker()
    	}
    },

    // 配置扑克信息
    setPoker:function() {
    	// 如果数值超过53，则是错误的
    	if (this.value > 53) {
            this.info = "未知"
    		return
    	}

    	// 获取花色
    	// 0~12为红桃
    	// 13~25为黑桃
    	// 26~38为梅花
    	// 39~51为方块
    	// 52，53为大小王
    	switch (parseInt(this.value / 13)) {
    		case 0:
    			this.color = this.pokerutils.hearts
                this.setColorSprite(0)
                this.upNumLabel.node.color = cc.Color.RED
                this.downNumLabel.node.color = cc.Color.RED
                this.info = "红桃"
    			break;
    		case 1:
    			this.color = this.pokerutils.spade
                this.setColorSprite(1)
                this.upNumLabel.node.color = cc.Color.BLACK
                this.downNumLabel.node.color = cc.Color.BLACK
                this.info = "黑桃"
    			break;
    		case 2:
    			this.color = this.pokerutils.plum
                this.setColorSprite(2)
                this.upNumLabel.node.color = cc.Color.BLACK
                this.downNumLabel.node.color = cc.Color.BLACK
                this.info = "梅花"
    			break;
    		case 3:
    			this.color = this.pokerutils.diamonds
                this.setColorSprite(3)
                this.upNumLabel.node.color = cc.Color.RED
                this.downNumLabel.node.color = cc.Color.RED
                this.info = "方块"
    			break;
    		case 4:
    			// 超过的情况来判断是大王还是小王
    			if (this.value == 52) {
    				this.color = this.pokerutils.sjoker
                    this.num = 16
                    this.info = "小王"
    			} else if (this.value == 53) {
    				this.color = this.pokerutils.bjoker
                    this.num = 17
                    this.info = "大王"
    			}

                this.setNumLabel("")
    			break;
    	}

    	// 获取数值
    	// 当不为大小王时
    	if ((this.color != this.pokerutils.sjoker) && (this.color != this.pokerutils.bjoker)) {
    		this.num = this.value % 13 + 1
    		// 判断字母
    		if (this.num == 1) {
                this.setNumLabel("A")
                this.info += "A"
                this.num = 14
    		} else if (this.num == 2) {
                this.setNumLabel(2)
                this.info += "2"
                this.num = 15
            } else if (this.num == 11) {
                this.setNumLabel("J")
                this.info += "J"
            } else if (this.num == 12) {
                this.setNumLabel("Q")
                this.info += "Q"
    		} else if (this.num == 13) {
                this.setNumLabel("K")
                this.info += "K"
    		} else {
                this.setNumLabel(this.num)
                this.info += "" + this.num
    		}
    	}
    },

    // 设置数值
    setNumLabel:function(num) {
        this.upNumLabel.string = num
        this.downNumLabel.string = num
    },

    // 设置花色
    setColorSprite:function(color) {
        this.upColorSprite.spriteFrame = this.colorFrames[color]
        this.downColorSprite.spriteFrame = this.colorFrames[color]
    },

    // 返回花色
    getColor:function() {
        return this.colorLabel.string
    },

    // 返回数值
    getNum:function() {
        return this.numLabel.string
    },

    // 比牌的大小
    comparePoker:function(otherPoker) {

    },

    reveal: function(isFaceUp) {
        if (this.value == 52) {
            this.sjokerSprite.active = isFaceUp
            this.bjokerSprite.active = false
            this.upColorSprite.node.active = false
            this.downColorSprite.node.active = false
            this.pokerBackground.spriteFrame = isFaceUp ? this.pokerFrontBG : this.pokerBackBG
        } else if (this.value == 53) {
            this.sjokerSprite.active = false
            this.bjokerSprite.active = isFaceUp
            this.upColorSprite.node.active = false
            this.downColorSprite.node.active = false
            this.pokerBackground.spriteFrame = isFaceUp ? this.pokerFrontBG : this.pokerBackBG
        } else {
            this.sjokerSprite.active = false
            this.bjokerSprite.active = false
            this.upNumLabel.node.active = isFaceUp
            this.upColorSprite.node.active = isFaceUp
            this.downNumLabel.node.active = isFaceUp
            this.downColorSprite.node.active = isFaceUp
            this.pokerBackground.spriteFrame = isFaceUp ? this.pokerFrontBG : this.pokerBackBG
        }
    },

    getInfo: function() {
        return this.info
    },

    getDetail: function() {
        return "[" + this.index + ", " + this.value + ", " + this.info + "]: " + (this.pokerBackground.spriteFrame === this.pokerFrontBG ? "Up" : "Down") + " [sj: " + this.sjokerSprite.active + ", bj: " + this.bjokerSprite.active + "]"
    },
});
