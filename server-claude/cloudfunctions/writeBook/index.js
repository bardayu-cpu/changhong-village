// 云函数 writeBook：在桌簿接一句。
// 判定逻辑在 rules/banquet.js，部署前用 node scripts/sync-cf-rules.js 同步。
// 客户端：wx.cloud.callFunction({ name: 'writeBook', data: { table, text } })
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
  const satTables = mySeat.sat_tables && mySeat.sat_tables.length ? mySeat.sat_tables : [mySeat.table_id];

  const result = banquet.canWriteBook({ table, satTables, text });
  if (!result.ok) return result;

  await db.collection('guestbook').add({ data: { table_id: table, openid: OPENID, text, created_at: now } });
  return { ok: true };
};
