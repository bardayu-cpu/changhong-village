// 云函数 changeSeat：换到指定的空椅子。
// 判定逻辑在 rules/banquet.js，部署前用 node scripts/sync-cf-rules.js 同步。
// 客户端：wx.cloud.callFunction({ name: 'changeSeat', data: { tableId, chairNo } })
// 注：没做并发事务锁，两人同一时刻抢同一把椅子理论上有极小概率都写进去，
// 量级（婚宴几百人）下不严重，先不做，写进回执待确认要不要加。
const cloud = require('wx-server-sdk');
const banquet = require('./rules/banquet');
const T = require('./rules/time');
const C = require('./rules/config');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

exports.main = async (event) => {
  const { tableId, chairNo } = event || {};
  if (!tableId || !chairNo) return { ok: false, reason: 'bad_request' };
  if (tableId === C.BANQUET_BENCH_ID) return { ok: false, reason: 'bad_request' };

  const { OPENID } = cloud.getWXContext();
  const now = Date.now();
  const today = T.localDate(now);

  const mySeatDoc = await db.collection('seat').doc(OPENID).get().catch(() => null);
  const mySeat = mySeatDoc && mySeatDoc.data;
  if (!mySeat) return { ok: false, reason: 'no_seat' };

  const { data: atTarget } = await db.collection('seat')
    .where({ table_id: tableId, chair_no: chairNo }).get();
  const occupant = atTarget.length ? atTarget[0].openid : null;

  const todayChanges = mySeat.changed_on === today ? 1 : 0;
  const result = banquet.canChangeSeat({ occupant, todayChanges, testMode: C.BANQUET_TEST_MODE });
  if (!result.ok) return result;

  const satTables = mySeat.sat_tables && mySeat.sat_tables.length ? mySeat.sat_tables.slice() : [mySeat.table_id];
  if (!satTables.includes(tableId)) satTables.push(tableId);

  await db.collection('seat').doc(OPENID).update({
    data: { table_id: tableId, chair_no: chairNo, sat_at: now, changed_on: today, sat_tables: satTables },
  });

  return { ok: true, data: { table_id: tableId, chair_no: chairNo } };
};
