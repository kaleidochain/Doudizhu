/**
	扑克规则	
	用来实现判断牌型，比牌的功能
	*/
module.exports = {
	// 初始化
	init:function() {
		// 牌型
		this.handPatterns = {
			ROKET: 						1,		//火箭，王炸，即双王（大王和小王），最大的牌
			BOMB: 						2,		//炸弹，四张同数值牌（如四个7）
			SINGLE:						3,		//单牌，单个牌
			DOUBLE: 					4,		//双牌，一对，数值相同的两张牌（如梅花4+方块4）	
			THREE: 						5,		//三牌，三张，数值相同的三张牌（如三个J）
			THREETAKEONE:				6,		//三代一，数值相同的三张牌 + 一张单牌。例如：333+6
			THREETAKETWO:				7,		//三代二，三带一对，数值相同的三张牌 + 一对牌。例如：444+99
			SINGLESTRAIGHT:				8,		//单顺，顺子，五张或更多的连续单牌（如：45678 或 78910JQK）。不包括 2 点和双王
			DOUBLESTRAIGHT:				9,		//双顺，连对，三对或更多的连续对牌（如：334455、77 88 99 1010 JJ）。不包括 2 点和双王
			THREESTRAIGHT:				10,		//三顺，飞机，二个或更多的连续三张牌（如：333444、555 666 777 888）。不包括 2 点和双王
			THREESTRAIGHTTAKESINGLE:	11,		//三顺代一，三顺+同数量的单牌。如：444555+79 或 333444555+679
			THREESTRAIGHTTAKEDOUBLE:	12,		//三顺代双，三顺+同数量的对牌。如：333444555+7799JJ 或 333444555+66991010
			FOURTAKETWO: 				13,		//四代二，四张牌+两手牌（注意：四带二不是炸弹），如： 5555+3+8
			FOURTAKETWOPAIR:            14,     //四带两对，四张牌+两对牌，如：4444+55+77
			ERRORTYPE: 					15,		//废牌
			EVERYCARDTYPE: 				16,		//任意类型
		}

		this.handPatternStr = ['','王炸','炸弹','单牌','一对','三张','三带一','三带一对','顺子','连对','飞机','飞机（带单）','飞机（带对）','四带二','四带两对','废牌','任意类型'];
	},

	// 判断手牌数组的类型	
	judgePokerType:function(pokers) {
		// 首先从小到大进行排序
		for (var i = 0; i < pokers.length; i++) {
			for (var j = i; j < pokers.length; j++) {
				var a = pokers[i]
				var b = pokers[j]

				// 冒泡
				if (b < a) {
					var tmp = a
					pokers[i] = b
					pokers[j] = tmp
				}
			}
		}

		// type: 牌型，value: 为单张、一对、三张时的值，max: 顺子、连对、飞机时最大牌值，size: 顺子、连对、飞机时的牌有多少组
		var result = {}
		// index: 牌点，num: 牌点的个数
		var recordNum = this.getPokersDetail(pokers)

		// 如果长度为1，则是单牌	
		if (pokers.length == 1) {
			result.type = this.handPatterns.SINGLE
			result.value = pokers[0]
		} 
		// 如果长度为2，判断是否双牌（少加了火箭）
		else if (pokers.length == 2) {
			// 如果相等，则为双牌
			if (pokers[0] == pokers[1]) {
				result.type = this.handPatterns.DOUBLE
				result.value = pokers[0]
			} else {
				// 判断是否火箭
				if (pokers[0] == 16 && pokers[1] == 17) {
					result.type = this.handPatterns.ROKET
				} else {
					result.type = this.handPatterns.ERRORTYPE
				}
			}
		}
		// 如果长度为3，判断是否三牌
		else if (pokers.length == 3) {
			// 如果相等，则为三牌
			if ((pokers[0] == pokers[1]) && (pokers[1] == pokers[2])) {
				result.type = this.handPatterns.THREE
				result.value = pokers[0]
			} else {
				result.type = this.handPatterns.ERRORTYPE
			}
		}
		// 如果长度为4，判断是否炸弹或者三代一
		else if (pokers.length == 4) {
			// 如果结果数组的长度为1，则为炸弹
			if (recordNum.length == 1) {
				result.type = this.handPatterns.BOMB
				result.value = pokers[0]
			}
			// 如果结果数组的长度为2，则为三代一
			else if (recordNum.length == 2) {
				result.type = this.handPatterns.THREETAKEONE
				if (recordNum[0].num == 3) {
					result.value = recordNum[0].index
				} else if (recordNum[1].num == 3) {
					result.value = recordNum[1].index
				} else {
					result.type = this.handPatterns.ERRORTYPE
				}
			}
			// 其他情况都为非法牌型		
			else {
				result.type = this.handPatterns.ERRORTYPE
			}
		}
		// 如果长度为5，则有三代二和顺子的情况
		else if (pokers.length == 5) {
			// 当结果数组长度为2时，判断是否三代二
			if (recordNum.length == 2) {
				result.type = this.handPatterns.THREETAKETWO
				if (recordNum[0].num == 3) {
					result.value = recordNum[0].index
				} else {
					result.value = recordNum[1].index
				}
			}
			// 其他情况都为非法
			else {
				result.type = this.handPatterns.ERRORTYPE
			}
		}

		if (pokers.length >= 6 && (result.type == this.handPatterns.ERRORTYPE || result.type == null)) {
			// 判断是否四带两手牌（两个单张或两对）
			var hasSingleFour = false
			var fourValue = 0
			var pairs = new Array()
			var single = new Array()
			for (var i = 0; i < recordNum.length; i++) {
				if (recordNum[i].num == 4) {
					if (hasSingleFour == false) {
						hasSingleFour = true
						fourValue = recordNum[i].index
					} else {
						result.type = this.handPatterns.ERRORTYPE
						hasSingleFour = false
						break
					}
				} else if (recordNum[i].num == 2) {
					pairs.push(recordNum[i].index)
				} else if (recordNum[i].num == 1) {
					single.push(recordNum[i].index)
				} else {
					result.type = this.handPatterns.ERRORTYPE
					hasSingleFour = false
					break
				}
			}
			if (hasSingleFour) {
				if (pairs.length == 2 && single.length == 0) {
					// 四带两对
					result.value = fourValue
					result.type = this.handPatterns.FOURTAKETWOPAIR
				} else if (pairs.length == 1 && single.length == 0) {
					// 四带一对（两张）
					result.value = fourValue
					result.type = this.handPatterns.FOURTAKETWO
				} else if (pairs.length == 0 && single.length == 2) {
					// 四带二
					result.value = fourValue
					result.type = this.handPatterns.FOURTAKETWO
				} else {
					result.value = fourValue
					result.type = this.handPatterns.ERRORTYPE
				}
			}
		}

		if (pokers.length >= 8 && (result.type == this.handPatterns.ERRORTYPE || result.type == null)) {
			// 判断是否三顺+同数量的一手牌
			var threeStraight = new Array()
			var pairs = new Array()
			var single = new Array()
			var isvalid = true
			for (var i = 0; i < recordNum.length; i++) {
				if (recordNum[i].num == 3) {
					threeStraight.push(recordNum[i].index);
				} else if (recordNum[i].num == 2) {
					pairs.push(recordNum[i].index);
				} else if (recordNum[i].num == 1) {
					single.push(recordNum[i].index)
				} else {
					result.type = this.handPatterns.ERRORTYPE
					isvalid = false
					break
				}
			}
			if (isvalid && threeStraight.length > 0) {
				threeStraight.sort()
				for (var i = 1; i < threeStraight.length; i++) {
					if (threeStraight[i] - threeStraight[i-1] != 1) {
						result.type = this.handPatterns.ERRORTYPE
						isvalid = false
						break
					}
				}
				if (isvalid) {
					if (threeStraight.length != pairs.length && threeStraight.length != single.length && threeStraight.length != pairs.length * 2 + single.length) {
						result.type = this.handPatterns.ERRORTYPE
					} else {
						var max = threeStraight[threeStraight.length - 1]
						if (max > 14) {
							result.type = this.handPatterns.ERRORTYPE
						} else {
							if (threeStraight.length == pairs.length) {
								result.type = this.handPatterns.THREESTRAIGHTTAKEDOUBLE
							} else {
								result.type = this.handPatterns.THREESTRAIGHTTAKESINGLE
							}
							result.max = max
							result.size = threeStraight.length
						}
					}
				}
			}
		}

		// 判断是否是连对或飞机啥都不带
		if (pokers.length >= 6 && (pokers.length / 3 == recordNum.length || pokers.length / 2 == recordNum.length) && (result.type == this.handPatterns.ERRORTYPE || result.type == null)) {
			// 判断是否成顺
			if (this.judgePairIsStraight(recordNum)) {
				var max = pokers[pokers.length - 1]
				if (max > 14) {
					result.type = this.handPatterns.ERRORTYPE
				} else {
					if (pokers.length / 3 == recordNum.length) {
						result.type = this.handPatterns.THREESTRAIGHT
					} else {
						result.type = this.handPatterns.DOUBLESTRAIGHT
					}
					result.max = max
					result.size = recordNum.length
				}
			} else {
				result.type = this.handPatterns.ERRORTYPE
			}
		}

		// 最后判断是否顺子
		if (pokers.length > 4 && (result.type == this.handPatterns.ERRORTYPE || result.type == null)) {
			// 再判断牌数组和结果数组是否相等，如果相等，代表牌全部不同
			if (pokers.length == recordNum.length) {
				if (this.judgeIsStraight(pokers)) {
					var max = pokers[pokers.length - 1]
					// 顺子最高位不能超过A				
					if (max > 14) {
						result.type = this.handPatterns.ERRORTYPE
					} else {
						result.type = this.handPatterns.SINGLESTRAIGHT
						result.max = max
						result.size = recordNum.length
					}
				} else {
					result.type = this.handPatterns.ERRORTYPE
				}
			}
		}

		if (result.type == null) {
			result.type = this.handPatterns.ERRORTYPE
		}

		console.log('judgePokerType return ' + JSON.stringify(result))
		return result
	},

	// 返回牌详情数组
	getPokersDetail:function(pokers) {
		var recordNum = new Array()
		for (var i = 0; i < pokers.length; i++) {
			var num = 0
			// 遍历获取数字的长度
			for (var j = 0; j < pokers.length; j++) {
				if (i != j) {																								
					if (pokers[i] == pokers[j]) {
						num++
					}
				}
			}

			var alreadyAdd = false
			// 在遍历判断是否已经存在该数字
			for (var k = 0; k < recordNum.length; k++) {
				var result = recordNum[k]
				if (result.index == pokers[i]) {
					alreadyAdd = true
					break
				}
			}

			// 如果没有加进去，则添加详情，加到数组中
			if (alreadyAdd == false) {
				var result = {}
				result.index = pokers[i]
				result.num = num + 1
				recordNum.push(result)
			}
		}

		// 使用冒泡法从小到大进行排序
		for (var i = 0; i < recordNum.length; i++) {
			for (var j = i; j < recordNum.length; j++) {
				var a = recordNum[i]
				var b = recordNum[j]

				// 如果后面的小，进行交换
				if (b.num < a.num) {
					var tmp = a
					recordNum[i] = b
					recordNum[j] = tmp
				}
			}
		}

		console.log('getPokersDetail(' + JSON.stringify(pokers) + ') return ' + JSON.stringify(recordNum))
		return recordNum
	},

	// 判断结果数组是否对子
	judgeIsPair:function(recordNum) {
		// 遍历，判断每个数字个数是否相等
		var index = recordNum[0].num
		for (var i = 0; i < recordNum.length; i++) {
			if (recordNum[i].num != index) {
				return false
			}
		}

		return true
	},

	// 判断结果数组是否顺子
	judgePairIsStraight:function(recordNum) {
		// 首先保证长度必须大于1
		if (recordNum.length == 1) {
			return false
		}

		// 再遍历一次进行判断是否后面一个一定比前面一个大1		
		for (var i = 1; i < recordNum.length; i++) {
			var a = recordNum[i]
			var b = recordNum[i - 1]
			// 如果不符合，则不是顺子
			if ((a.index - b.index) != 1) {
				return false
			}
		}

		return true
	},


	// 判断出的牌是否顺子
	judgeIsStraight:function(pokers) {
		// 首先保证长度必须大于1
		if (pokers.length == 1) {
			return false
		}

		// 再遍历一次进行判断是否后面一个一定比前面一个大1		
		for (var i = 1; i < pokers.length; i++) {
			// 如果不符合，则不是顺子
			if ((pokers[i] - pokers[i - 1]) != 1) {
				return false
			}
		}

		return true
	},
}