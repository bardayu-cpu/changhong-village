// 云函数 enterHall：走进宴会厅——第一次进厅自动分座，之后每次进厅返回本厅全部座位、桌牌、
// 和「老王敬了你一杯，簿子上多了 2 句」这类进厅合并提示。
// 判定逻辑在 rules/banquet.js（跟 server-claude/src/banquet.js 是同一份，部署前用
// node scripts/sync-cf-rules.js 同步过来的，改规则去改 src/banquet.js，不要直接改这里的 rules/）。
// 分页读全（rules/lib/db-page.js 同步来的）：见回执 03，座位/敬酒/簿子过了 100 条不分页会静默漏读。
// 客户端：wx.cloud.callFunction({ name: 'enterHall' })
// 前提：resident 表里已经有这个 openid 的记录（saveProfile 先存过昵称、邀请人）
const cloud = require('wx-server-sdk');
const banquet = require('./rules/banquet');
const C = require('./rules/config');
const { fetchAllPages } = require('./lib/db-page');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();
const _ = db.command;

const TABLE_IDS = C.BANQUET_TABLE_IDS;
const RESERVED_IDS = new Set(TABLE_IDS.slice(0, C.BANQUET_RESERVED_TABLES));
const BENCH = C.BANQUET_BENCH_ID;
const PAGE_OPTS = { orderBy: [['_id', 'asc']], maxTotal: C.BANQUET_PAGE_MAX_TOTAL };

// 阿鱼、Toretto 的 openid 存在 config/banquet 文档里（initDb 建好，先是空数组），不写死在代码里。
// 后台脚本把两人的 openid 填进去之前，读到空数组，没人会命中"阿鱼/Toretto 的枝坐前两桌"这条，
// 不影响其它人正常入座，只是前两桌暂时按普通空桌分配（回执 02-总策划答复-2 第 3 条）。
async function loadVip() {
  const doc = await db.collection('config').doc('banquet').get().catch(() => null);
  const ids = (doc && doc.data && doc.data.vip_openids) || [];
  return new Set(ids);
}

async function loadTables() {
  // 12 桌满座就有 120 人，超过云开发 get() 不写 limit 时默认的单页 100 条上限，必须分页读全，
  // 不然会算错某桌已有几人、椅子号分重复（回执 03 第 1 项）。
  const seats = await fetchAllPages(() => db.collection('seat').where({ table_id: _.neq(BENCH) }), PAGE_OPTS);
  const byTable = {};
  for (const s of seats) (byTable[s.table_id] = byTable[s.table_id] || []).push(s);
  return {
    tables: TABLE_IDS.map(id => ({
      id,
      reserved: RESERVED_IDS.has(id),
      branch: byTable[id] && byTable[id][0] ? byTable[id][0].inviter || null : null,
      seats: (byTable[id] || []).map(s => s.openid),
    })),
    byTable,
  };
}

exports.main = async () => {
  const { OPENID } = cloud.getWXContext();
  const now = Date.now();

  const residentDoc = await db.collection('resident').doc(OPENID).get().catch(() => null);
  if (!residentDoc || !residentDoc.data) return { ok: false, reason: 'no_resident' };
  const inviter = residentDoc.data.inviter || null;

  let mySeat = await db.collection('seat').doc(OPENID).get().catch(() => null);
  mySeat = mySeat && mySeat.data;

  if (!mySeat) {
    const [{ tables, byTable }, vip] = await Promise.all([loadTables(), loadVip()]);
    const assigned = banquet.assignSeat({ inviter, vip, tables });

    // 注意：changed_on 这里不能写今天——它表示"最近一次换桌是哪天"，第一次自动分座不算换桌，
    // 写了今天会导致刚进厅的人当天不能再用 changeSeat（canChangeSeat 会判成 changed_today）。
    if (assigned.bench) {
      mySeat = {
        _id: OPENID, openid: OPENID, table_id: BENCH, chair_no: null, inviter,
        sat_at: now, changed_on: null, sat_tables: [], last_visit_at: now,
      };
    } else {
      const used = new Set((byTable[assigned.tableId] || []).map(s => s.chair_no));
      let chairNo = 1;
      while (used.has(chairNo)) chairNo++;
      mySeat = {
        _id: OPENID, openid: OPENID, table_id: assigned.tableId, chair_no: chairNo, inviter,
        sat_at: now, changed_on: null, sat_tables: [assigned.tableId], last_visit_at: now,
      };
    }
    await db.collection('seat').add({ data: mySeat });
  }

  // 进厅提示：上次离开到现在，收到的敬酒 + 坐过的桌新增的簿子句子
  // 同样要分页读全——常来的人攒的敬酒、坐过很多桌的人攒的簿子新句子，都可能过 100 条。
  const since = mySeat.last_visit_at || mySeat.sat_at;
  const satTables = mySeat.sat_tables && mySeat.sat_tables.length ? mySeat.sat_tables : [mySeat.table_id];
  const [toasts, bookLines] = await Promise.all([
    fetchAllPages(() => db.collection('toast').where({ to: OPENID, created_at: _.gt(since) }), PAGE_OPTS),
    fetchAllPages(() => db.collection('guestbook').where({ table_id: _.in(satTables), created_at: _.gt(since) }), PAGE_OPTS),
  ]);
  const digest = banquet.arrivalDigest({
    toasts: toasts.map(t => ({ from: t.from, at: t.created_at })),
    bookLines: bookLines.map(l => ({ tableId: l.table_id, at: l.created_at })),
    since,
  });

  if (mySeat.last_visit_at !== now) {
    await db.collection('seat').doc(OPENID).update({ data: { last_visit_at: now } });
  }

  // 本厅全部座位、桌牌（桌牌用桌上第一个人的 openid，客户端按 openid 查昵称拼「XX 那桌」）
  // 120 座满了就超过单页 100 条上限，分页读全，不然桌上会少画人、长凳也可能漏人。
  const allSeats = await fetchAllPages(() => db.collection('seat'), PAGE_OPTS);
  const byTableNow = {};
  const bench = [];
  for (const s of allSeats) {
    if (s.table_id === BENCH) bench.push(s.openid);
    else (byTableNow[s.table_id] = byTableNow[s.table_id] || []).push({ openid: s.openid, chair_no: s.chair_no });
  }

  // 昵称和形象一起带回去：resident 表是「仅创建者可读写」，客户端查不到别人的，
  // 只能在这里用管理员权限查好。桌牌「XX 那桌」和敬酒提示的名字都靠它。
  const ids = new Set(allSeats.map(s => s.openid));
  for (const t of digest.toasts) ids.add(t.from);
  const names = {};
  const idList = Array.from(ids);
  for (let i = 0; i < idList.length; i += 100) {
    const { data: rs } = await db.collection('resident').where({ _id: _.in(idList.slice(i, i + 100)) })
      .field({ _id: true, nick: true, avatar: true }).get();
    for (const r of rs) names[r._id] = { nick: r.nick || '', avatar: r.avatar === undefined ? -1 : r.avatar };
  }

  return {
    ok: true,
    data: {
      me: { table_id: mySeat.table_id, chair_no: mySeat.chair_no },
      tables: TABLE_IDS.map(id => ({ id, reserved: RESERVED_IDS.has(id), seats: byTableNow[id] || [] })),
      bench,
      digest,
      names,
    },
  };
};
