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
    // （9/18 起换桌不限次数，changed_on 已不参与判定，留着只是记录。）
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
  // 敬酒另从「在厅里当场报过的」之后算（hallPulse 记的 toast_seen_at，9/19 加）：当场看过的不再在进厅时报一遍
  const toastSince = Math.max(since, mySeat.toast_seen_at || 0);
  const satTables = mySeat.sat_tables && mySeat.sat_tables.length ? mySeat.sat_tables : [mySeat.table_id];
  const [toasts, bookLines] = await Promise.all([
    fetchAllPages(() => db.collection('toast').where({ to: OPENID, created_at: _.gt(toastSince) }), PAGE_OPTS),
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

  // 本厅全部座位、桌牌：每个座位带 sat_at（9/18 加，只加字段），客户端取这桌 sat_at 最早的人拼「XX那桌」（蓝图 3.2：XX 是这桌第一个坐下的人）
  // 120 座满了就超过单页 100 条上限，分页读全，不然桌上会少画人、长凳也可能漏人。
  const allSeats = await fetchAllPages(() => db.collection('seat'), PAGE_OPTS);
  const byTableNow = {};
  const bench = [];
  for (const s of allSeats) {
    if (s.table_id === BENCH) bench.push(s.openid);
    else (byTableNow[s.table_id] = byTableNow[s.table_id] || []).push({ openid: s.openid, chair_no: s.chair_no, sat_at: s.sat_at || 0 });
  }

  // 昵称、形象、邀请人一起带回去：resident 表是「仅创建者可读写」，客户端查不到别人的，
  // 只能在这里用管理员权限查好。桌牌「XX 那桌」、敬酒提示的名字、看人卡片「XX 带进来的」都靠它。
  // _.in 一批最多 100 个 id，这里按 100 一批分批查（这个上限跟分页读全是两回事——每批传的 id
  // 不超过 100 个，命中的行数天然也不会超过 100，不需要再分页），回执 03 确认过这段本来就没问题。
  const ids = new Set(allSeats.map(s => s.openid));
  for (const t of digest.toasts) ids.add(t.from);
  const names = {};
  async function loadNames(idArray) {
    for (let i = 0; i < idArray.length; i += 100) {
      const { data: rs } = await db.collection('resident').where({ _id: _.in(idArray.slice(i, i + 100)) })
        .field({ _id: true, nick: true, avatar: true, inviter: true }).get();
      for (const r of rs) {
        names[r._id] = { nick: r.nick || '', avatar: r.avatar === undefined ? -1 : r.avatar, inviter: r.inviter || null };
      }
    }
  }
  await loadNames(Array.from(ids));

  // 邀请人本人可能没坐在厅里（没换过座、甚至从没进过厅），也要把邀请人的
  // {nick, avatar, inviter} 补进 names，客户端「看人」卡片才有「XX 带进来的」可显示（蓝图 3.2）。
  // 只找这一层：names 里已有的人的邀请人，不递归找邀请人的邀请人（看人卡片只需要一跳）。
  const missingInviterIds = Array.from(new Set(
    Object.values(names).map(n => n.inviter).filter(id => id && !names[id]),
  ));
  if (missingInviterIds.length) await loadNames(missingInviterIds);

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
