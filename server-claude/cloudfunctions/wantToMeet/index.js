// 云函数 wantToMeet：看人卡片上的「想认识你」（蓝图 3.2 加好友，01 9/19 派）。
// 判定逻辑在 rules/banquet.js 的 canWantToMeet，部署前用 node scripts/sync-cf-rules.js 同步。
// 客户端：wx.cloud.callFunction({ name: 'wantToMeet', data: { to } })
// 谁能发：两人现在坐同一桌（长凳不算），或者两人之间敬过酒（谁敬谁、哪天都算）；同一对只记一次。
// 阶段 1 只往 friend_request 记一条（from、to、created_at、status: 'pending'，via 记是同桌还是敬过酒），
// 对方这时候什么也看不到；好友关系本身在阶段 2。friend_request 表 9/16 阿鱼已在控制台建好（README）。
const cloud = require('wx-server-sdk');
const banquet = require('./rules/banquet');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

/** 这人现在坐哪桌（seat 表 _id 就是 openid），没座位是 null */
async function tableOf(openid) {
  const doc = await db.collection('seat').doc(openid).get().catch(() => null);
  return (doc && doc.data && doc.data.table_id) || null;
}

/** 有没有一条 from → to 的记录（只要知道有没有，取一条就够） */
async function exists(coll, from, to) {
  const { data } = await db.collection(coll).where({ from, to }).limit(1).get();
  return data.length > 0;
}

exports.main = async (event) => {
  const { to } = event || {};
  if (!to || typeof to !== 'string') return { ok: false, reason: 'bad_request' };

  const { OPENID: from } = cloud.getWXContext();
  const now = Date.now();

  try {
    // 事实都查齐了再交给规则判（坐长凳的两人 table_id 一样却不算同桌，敬酒记录照样要查）
    const alreadySent = await exists('friend_request', from, to);
    const fromTableId = await tableOf(from);
    const toTableId = await tableOf(to);
    const toasted = await exists('toast', from, to) || await exists('toast', to, from);

    const result = banquet.canWantToMeet({ from, to, alreadySent, fromTableId, toTableId, toasted });
    if (!result.ok) return result;

    await db.collection('friend_request').add({
      data: { from, to, created_at: now, status: 'pending', via: result.via },
    });
    return { ok: true };
  } catch (e) {
    // 数据库出错：客户端按「没连上 再试一下」显示，真实原因打一行进云函数日志（点一下才调一次，不刷屏）
    console.error('wantToMeet 数据库出错：', e && e.message);
    return { ok: false, reason: 'network' };
  }
};
