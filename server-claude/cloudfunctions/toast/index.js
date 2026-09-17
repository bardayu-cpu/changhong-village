// 云函数 toast：敬一杯。
// 判定逻辑在 rules/banquet.js，部署前用 node scripts/sync-cf-rules.js 同步。
// 客户端：wx.cloud.callFunction({ name: 'toast', data: { to } })
// 注：「敬过酒的两人互相进可能认识的人」（蓝图 3.2）要接 src/tree.js 的建议信号，
// 任务卡 02 没列这一步，这里没做，写进回执。
const cloud = require('wx-server-sdk');
const banquet = require('./rules/banquet');
const T = require('./rules/time');
const C = require('./rules/config');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

exports.main = async (event) => {
  const { to } = event || {};
  if (!to) return { ok: false, reason: 'bad_request' };

  const { OPENID: from } = cloud.getWXContext();
  const now = Date.now();
  const today = T.localDate(now);

  const { data: mine } = await db.collection('toast').where({ from, date: today }).get();
  const todayToastCount = mine.length;
  const todayToastToCount = mine.filter(t => t.to === to).length;

  const result = banquet.canToast({ from, to, todayToastCount, todayToastToCount, testMode: C.BANQUET_TEST_MODE });
  if (!result.ok) return result;

  await db.collection('toast').add({ data: { from, to, date: today, created_at: now } });
  return { ok: true };
};
