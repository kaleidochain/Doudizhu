pragma solidity >=0.4.21 <0.6.0;
contract ddzDao{
    event JoinSittingQueen(address  indexed playerAddr, address roomAddr);
    event AllotTable(address roomAddr, uint64 tableid,uint64 nextHand);
    event LeaveTable(address roomAddr, uint64 indexed tableid, address playerAddr, uint64 pos);
    event Start(address roomAddr, uint64 indexed tableid, address playerAddr, uint64 pos, uint64 hand);
    event GameStart(address roomAddr, uint64 indexed tableid, uint64 hand);
    event Discard(address roomAddr, uint64 indexed tableid, address playerAddr, uint64 pos, uint64 hand);
    event DismissTable(uint64 indexed tableid,uint64 hand);
    event SubmmitSettleData(address  nrAddr, uint64 datalength, bytes data);
    event Settle( uint64 hand, uint64 playingNum, uint64 indexed tableid,uint64 nextHand);
    event FinishNotary(uint64 indexed tableid, uint64 hand);
    event ReShaff(uint64 indexed tableid, uint64 hand);
    event SubmitPoint(uint64 indexed tableid,uint64 hand,address sender,string error);
    event SelectNotary(uint indexed tableid, uint number);
    event WithdrawChips(uint64 tableid,address indexed player,string error);
    uint8 constant PARTICIPATE_NUM = 3;    // 斗地主一桌 3 人
 
    // 玩家状态
    enum PlayerStatus {
        NOTJION,    // 未加入房间 0
        NOTSEATED,  // 弃用状态 1
        SITTING,    // 等待入座table 2
        SEATED,     // 已坐下table 3
        READY,      // 准备游戏 4
        PLAYING,    // 正在游戏中 5
        DISCARD     // 弃牌 6
    }

    enum TalbeStatus {NOTSTARTED, STARTED}      // table的状态，NOTSTARTED:未开始游戏; STARTED:已开始游戏

    struct LevelConfig {
        uint needChips;     // 参与筹码
        uint64 base;          // 底
    }

    enum Data_Src {PLAYER, NORTARY}

    struct Table {
        uint64        tbid;           //
        uint64        currentHand;    //当前正在局数，结算一次，局数加１
        TalbeStatus currentStatus;  //当前table的状态
        address[3]   players;        // table中的玩家
        uint64       level;          //当前场 训练场,宗师场
        uint8       interNum;       //申请到的inter数量
        uint8       nortaryNum;     //申请到的公正者数量
        uint        startBlock;      //游戏开始区块
    }

    struct PlayerInfo {
        uint64    tbid;           // table的号码
        uint    amount;         // 剩余金额
        PlayerStatus status;    // 玩家状态
        uint64    reshaff;        // 申请重新洗牌
        uint8   seatNum;        // 座位号
        uint64   level;          // 当前场 训练场,宗师场
        bytes32   pointHash;    //牌点验证hash
    }

    struct NotaryInfo {
        address nrAddr;
        bytes32   allocate;
    }

    address public owner;

	uint64	public multiple;		// 最大翻倍
    uint8   public tbInterNum;     // 给table申请的Inter数量
    uint8   public tbNotaryNum;     // 给table申请的Inter数量

    address public tokenAddress;        // token合约地址
    address public interManage;         // Inter合约地址
    address public notaryManage;        // 公证者合约地址
    address public authorityAddress;    // 权限合约地址
    address public funcAddress;         // 拆分合约 方法合约地址
    address public luaAddress;          // lua游戏脚本合约
    address public notaryluaAddress;    // 公证者lua脚本

    mapping (uint64 => LevelConfig)       lvlCfg;         // 分场的配置
    mapping (uint64 => Table)             Tables;         // table号码--table中玩家信息列表
    mapping (uint64 => NotaryInfo[])      Notarys;        // table号码 -- 公证信息列表
    mapping (address => PlayerInfo)     Players;        // 玩家地址--玩家信息

    uint64    joining_queue_size;                 // 排队入座的队列大小, 队列大小大于等于该值，给队列中玩家安排Table
    mapping (uint64 => address[]) joinings;         // 等待加入Table的玩家队列,1:玩家等待加入Table; 2:玩家已加入Table，重新等待加入其他Table;
    
    uint64 public currTableNum;   // 当前的台号
    mapping(bytes32=>address[]) PointHashs; //牌点验证
    uint blockout = 50;     //超时解散桌子
}
