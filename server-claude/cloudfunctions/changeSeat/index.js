// 云函数 changeSeat：换到指定的空椅子。
// 判定逻辑在 rules/banquet.js，部署前用 node scripts/sync-cf-rules.js 同步。
// 客户端：wx.cloud.callFunction({ name: 'changeSeat', data: { tableId, chairNo } })
// 蓝图 3.2 9/18 改：换桌不限次数，去掉「今天只能换一次」，不再需要算「今天换过几次」，
// 也就不用 rules/time.js 了（部署前跑 sync-cf-rules.js 时也不会再把它复制进来）。
// 注：没做并发事务锁，两人同一时刻抢同一把椅子理论上有极小概率都写进去，
// 量级（婚宴几百人）下不严重，先不做，写进回执待确认要不要加。
const cloud = require('wx-server-sdk');
const banquet = require('./rules/banquet');
const C = require('./rules/config');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

exports.main = async (event) => {
  const { tableId, chairNo } = event || {};
  if (!tableId || !chairNo) return { ok: false, reason: 'bad_request' };
  if (tableId === C.BANQUET_BENCH_ID) return { ok: false, reason: 'bad_request' };
  // 9/24 加：桌号要在 config.BANQUET_TABLE_IDS 里、椅子号要是 1..BANQUET_SEATS_PER_TABLE，
  // 不然传个 T99、11 号椅也能写进 seat 表（55 桌上线前补的，12 桌时一样拦）
  const target = banquet.checkSeatTarget({ tableId, chairNo, tableIds: C.BANQUET_TABLE_IDS });
  if (!target.ok) return target;

  const { OPENID } = cloud.getWXContext();
  const now = Date.now();

  const mySeatDoc = await db.collection('seat').doc(OPENID).get().catch(() => null);
  const mySeat = mySeatDoc && mySeatDoc.data;
  if (!mySeat) return { ok: false, reason: 'no_seat' };

  const { data: atTarget } = await db.collection('seat')
    .where({ table_id: tableId, chair_no: chairNo }).get();
  const occupant = atTarget.length ? atTarget[0].openid : null;

  const result = banquet.canChangeSeat({ occupant });
  if (!result.ok) return result;

  // sat_tables 还留着：enterHall 进厅提示要靠它算「坐过的桌新增了几句簿子」（跟 canWriteBook 无关，
  // canWriteBook 9/18 起只认「现在坐的桌」，见 writeBook/index.js）
  const satTables = mySeat.sat_tables && mySeat.sat_tables.length ? mySeat.sat_tables.slice() : [mySeat.table_id];
  if (!satTables.includes(tableId)) satTables.push(tableId);

  await db.collection('seat').doc(OPENID).update({
    data: { table_id: tableId, chair_no: chairNo, sat_at: now, sat_tables: satTables },
  });

  return { ok: true, data: { table_id: tableId, chair_no: chairNo } };
};
