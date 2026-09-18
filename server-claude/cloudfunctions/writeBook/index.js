// 云函数 writeBook：在桌簿接一句。
// 判定逻辑在 rules/banquet.js，部署前用 node scripts/sync-cf-rules.js 同步。
// 客户端：wx.cloud.callFunction({ name: 'writeBook', data: { table, text } })
// 蓝图 3.2 9/18 改：只能写「现在坐的那桌」（seat 表的 table_id），不再是「坐过的桌都能写」（sat_tables）；
// 长凳的人 table_id 是 bench，跟任何桌都对不上，写哪桌都会被 canWriteBook 判 not_sat_here。
// 注：没做敏感词校验——敏感词模块（docs/敏感词模块-需求.md）还没做，等它做出来了，
// 在写库前再加一道 validate-text 调用，canWriteBook 本身不判（保持纯函数、不做 I/O）。
const cloud = require('wx-server-sdk');
const banquet = require('./rules/banquet');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

exports.main = async (event) => {
  const { table, text } = event || {};
  if (!table || typeof text !== 'string') return { ok: false, reason: 'bad_request' };

  const { OPENID } = cloud.getWXContext();
  const now = Date.now();

  const mySeatDoc = await db.collection('seat').doc(OPENID).get().catch(() => null);
  const mySeat = mySeatDoc && mySeatDoc.data;
  if (!mySeat) return { ok: false, reason: 'no_seat' };

  const result = banquet.canWriteBook({ table, mySeatTableId: mySeat.table_id, text });
  if (!result.ok) return result;

  await db.collection('guestbook').add({ data: { table_id: table, openid: OPENID, text, created_at: now } });
  return { ok: true };
};
