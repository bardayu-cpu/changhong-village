'use strict';
/**
 * 苏七镇奇缘 · 服务端配置
 * 对应《苏七镇 · 阶段 1 设计 v1.0》第 3 节各表：3.3 种地、3.3a 集市、3.3b 桥灯、3.4 偷菜、3.8a 踢球、3.10 关系网、3.10a/b 月老庙、3.11 货币
 * 改这里的数值即可调整平衡，不要改各规则文件
 */

const HOUR = 3600 * 1000;
const DAY = 24 * HOUR;

module.exports = {
  HOUR,
  DAY,
  TZ_OFFSET: 8 * HOUR,              // 北京时间

  // 作物
  CROPS: {
    loubo:   { label: '楼卜', pinyin: '萝卜', growMs: 4 * HOUR, seedPrice: 2,  basePrice: 5  },
    haijiao: { label: '海椒', pinyin: '辣椒', growMs: 1 * DAY,  seedPrice: 5,  basePrice: 15 },
    guzi:    { label: '谷子', pinyin: '稻米', growMs: 3 * DAY,  seedPrice: 15, basePrice: 50 },
  },
  YIELD_PER_PLOT: 10,               // 一格产几棵
  ROT_AFTER_MS: 24 * HOUR,          // 熟后多久烂
  PLOT_COUNT: 6,                    // 每人几格地
  FREE_SEEDS: { loubo: 3 },         // 进镇送的种子
  START_COIN: 20,

  // 偷菜
  STEAL_RATIO: 0.3,                 // 偷走比例
  STEAL_DAILY_LIMIT: 10,            // 每人每天偷几格
  STEAL_PER_HOUSE_LIMIT: 3,         // 对同一家每天几格
  GUARD_BLOCK_RATE: 0.5,            // 喜多拦截概率
  GUARD_DURATION_MS: 24 * HOUR,     // 借一次看多久
  GUARD_DAILY_BORROW: 1,            // 每天能借几次

  // 集市
  TOURIST_BUY_MULT: 2.5,            // 游客集市收菜溢价
  TOURIST_SEED_MULT: 2,             // 游客集市种子加价

  // 桥灯
  LAMP_COST: 30,                    // 每盏几棵
  LAMP_TOTAL: 17,                   // 桥孔数
  LAMP_NAME_TOP: 5,                 // 灯下刻前几名

  // 关系网
  INVITE_QUOTA_BASE: 5,             // 初始邀请名额
  INVITE_QUOTA_PER_WEEK: 1,         // 住满一周加几个
  SUGGEST_LIMIT: 10,                // 可能认识的人最多几个

  // 月老庙
  THREAD_WEEKLY_QUOTA: 2,           // 每周牵几条红线
  THREAD_EXPIRE_MS: 7 * DAY,        // 红线多久没人接就断
  STICK_DAILY: 1,                   // 每天求几支签
  STICK_RETURN_COOLDOWN_MS: 7 * DAY,// 放回后多久可能再抽到

  // 踢球
  BALL_COUNT: 4,
  BALL_GOAL: 10,                    // 全镇当天累计几脚
  BALL_REWARD_COIN: 5,

  // 文本长度（图形簇）
  LEN: {
    nickname: [2, 12],
    message: [1, 100],              // 留言
    whisper: [1, 200],              // 悄悄话
    status: [1, 100],               // 动态
    threadNote: [1, 30],            // 红线附言
    recommend: [1, 50],             // 月老庙推荐语
  },

  HOUSE_CAPACITY: 5,                // 屋内摆件位
  RENAME_LIMIT: 1,                  // 改名次数

  // 宴会厅：一场不散的席（蓝图 3.2）
  BANQUET_TABLE_COUNT: 12,
  BANQUET_SEATS_PER_TABLE: 10,
  BANQUET_RESERVED_TABLES: 2,          // 离主桌最近的两桌，给阿鱼、Toretto 的枝
  BANQUET_TABLE_IDS: ['T1','T2','T3','T4','T5','T6','T7','T8','T9','T10','T11','T12'], // 数组顺序即桌序，前 BANQUET_RESERVED_TABLES 个是离主桌最近的
  BANQUET_BENCH_ID: 'bench',           // 长凳：seat 表里 table_id 写这个，chair_no 为 null，人数不限
  BANQUET_CHANGE_PER_VISIT: 1,         // 每次来访能换几次桌
  BANQUET_TOAST_DAILY: 5,              // 每人每天敬几杯
  BANQUET_TOAST_PER_PERSON_DAILY: 1,   // 对同一人每天几杯
  BANQUET_BOOK_MAX_LEN: 100,           // 桌簿一条最多几字
};
