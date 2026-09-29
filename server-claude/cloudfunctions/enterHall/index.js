// 云函数 enterHall：走进宴会厅——第一次进厅自动分座，之后每次进厅返回本厅全部座位、桌牌、
// 和「老王敬了你一杯，簿子上多了 2 句」这类进厅合并提示。
// 判定逻辑在 rules/banquet.js（跟 server-claude/src/banquet.js 是同一份，部署前用
// node scripts/sync-cf-rules.js 同步过来的，改规则去改 src/banquet.js，不要直接改这里的 rules/）。
// 分页读全（rules/lib/db-page.js 同步来的）：见回执 03，座位/敬酒/簿子过了 100 条不分页会静默漏读。
// 客户端：wx.cloud.callFunction({ name: 'enterHall' })
// 前提：resident 表里已经有这个 openid 的记录（saveProfile 先存过昵称、邀请人）
// 9/19 加：返回里带 data.mine，是调用者自己的席间小游戏存档（coins/games/dishes/gift_coins，
// 蓝图 3.2「席间小游戏」，阿鱼 9/19 定），直接从上面已经查好的 residentDoc 里取，不额外查表；
// resident 记录里没存过这几个字段就给默认空值，不代表真的没有 resident 记录（那种情况前面
// 已经 return { ok:false, reason:'no_resident' } 了）。
// 9/23 加（01 派活「进厅先见人」）：返回里带 data.arrival——第一次进厅：first_visit、table_was_empty
// （客户端据此说「你坐谁那桌、谁带你来的」）；以后每次进厅：最多三行的小卡 rows（敬了你的 → 在你这桌簿子上
// 接了话的 → 你走后来过的，排法在 rules/banquet.js 的 arrivalCard），外加卡上用不完的明细 visitors、book_lines（各最多
// C.BANQUET_ARRIVAL_LIST_MAX 条，新的在前）。原来的 digest 照旧带着，没更新的旧客户端还能用。
const cloud = require('wx-server-sdk');
const banquet = require('./rules/banquet');
const C = require('./rules/config');
const { fetchAllPages } = require('./lib/db-page');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();
const _ = db.command;

// 厅里有哪些桌以 config.BANQUET_TABLE_IDS 为准（现在 12 桌，55 桌上线时换成 BANQUET_TABLE_IDS_55）
const TABLE_IDS = C.BANQUET_TABLE_IDS;
const RESERVED_IDS = new Set(TABLE_IDS.slice(0, C.BANQUET_RESERVED_TABLES));
// 主桌（9/29）：只有 55 桌厅有（TABLE_IDS 是 BANQUET_TABLE_IDS_55 时），12 桌厅是 null，下面跟主桌有关的都不做
const MAIN_ID = banquet.mainTableIdOf(TABLE_IDS);
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
  // 全厅坐满是 桌数 × 10 人（12 桌 120 人、55 桌 550 人），超过云开发 get() 不写 limit 时默认的单页 100 条上限，必须分页读全，
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
    // 主桌单独给，不混进 tables：分座规矩只在 tables 里挑，别人就不会被分到主桌
    mainTable: MAIN_ID ? { id: MAIN_ID, seats: (byTable[MAIN_ID] || []).map(s => s.openid) } : null,
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
  const firstVisit = !mySeat;
  let tableWasEmpty = false;
  let vip = null;   // 第一次进厅分座时读；55 桌厅回 mainSeatOk 时没读过再读一次

  if (!mySeat) {
    let tables, mainTable, byTable;
    [{ tables, mainTable, byTable }, vip] = await Promise.all([loadTables(), loadVip()]);
    // 长凳门槛看 config.BANQUET_BENCH_ONLY_WHEN_FULL（false 旧规矩 / true 普通桌全满才去长凳），规矩见 rules/banquet.js；
    // me 只在新规矩下用：阿鱼/Toretto 自己没有邀请人时也能坐前两桌
    // mainTable 只有 55 桌厅才有：阿鱼、Toretto 本人先坐主桌（12 桌厅是 null，跟原来一样）
    const assigned = banquet.assignSeat({
      inviter, vip, tables, me: OPENID, benchOnlyWhenFull: C.BANQUET_BENCH_ONLY_WHEN_FULL, mainTable,
    });

    // 注意：changed_on 这里不能写今天——它表示"最近一次换桌是哪天"，第一次自动分座不算换桌，
    // （9/18 起换桌不限次数，changed_on 已不参与判定，留着只是记录。）
    if (assigned.bench) {
      mySeat = {
        _id: OPENID, openid: OPENID, table_id: BENCH, chair_no: null, inviter,
        sat_at: now, changed_on: null, sat_tables: [], last_visit_at: now,
      };
    } else {
      tableWasEmpty = !(byTable[assigned.tableId] || []).length;
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
  // 「你走后谁来过」：seat 表的 last_visit_at 比我上次来得晚的人（第一次进厅 since 就是现在，查了也是空的，省掉）
  const [toasts, bookLines, visitorSeats] = await Promise.all([
    fetchAllPages(() => db.collection('toast').where({ to: OPENID, created_at: _.gt(toastSince) }), PAGE_OPTS),
    fetchAllPages(() => db.collection('guestbook').where({ table_id: _.in(satTables), created_at: _.gt(since) }), PAGE_OPTS),
    firstVisit ? Promise.resolve([])
      : fetchAllPages(() => db.collection('seat').where({ last_visit_at: _.gt(since) }), PAGE_OPTS),
  ]);
  const digest = banquet.arrivalDigest({
    toasts: toasts.map(t => ({ from: t.from, at: t.created_at })),
    bookLines: bookLines.map(l => ({ tableId: l.table_id, at: l.created_at })),
    since,
  });

  // 进厅小卡：簿子只算「我现在坐的这桌」（坐长凳的没有这桌，table_id 是 bench，对不上任何簿子），不算我自己写的
  const myTableLines = bookLines
    .filter(l => l.table_id === mySeat.table_id && l.openid && l.openid !== OPENID)
    .map(l => ({ from: l.openid, at: l.created_at, text: l.text || '' }))
    .sort((a, b) => b.at - a.at);
  const visitors = visitorSeats
    .filter(s => s.openid !== OPENID)
    .map(s => ({ openid: s.openid, at: s.last_visit_at }))
    .sort((a, b) => b.at - a.at);
  const card = banquet.arrivalCard({
    me: OPENID,
    since,
    toasts: digest.toasts,
    bookLines: myTableLines,
    visitors,
  });
  const arrival = {
    first_visit: firstVisit,
    table_was_empty: tableWasEmpty,
    rows: card.rows,
    hasNews: card.hasNews,
    visitors: visitors.slice(0, C.BANQUET_ARRIVAL_LIST_MAX),
    book_lines: myTableLines.slice(0, C.BANQUET_ARRIVAL_LIST_MAX),
  };

  if (mySeat.last_visit_at !== now) {
    await db.collection('seat').doc(OPENID).update({ data: { last_visit_at: now } });
  }

  // 本厅全部座位、桌牌：每个座位带 sat_at（9/18 加，只加字段），客户端取这桌 sat_at 最早的人拼「XX那桌」（蓝图 3.2：XX 是这桌第一个坐下的人）
  // 人数过了 100 就超过单页上限（12 桌坐满 120、55 桌坐满 550，再加长凳），分页读全，不然桌上会少画人、长凳也可能漏人。
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
  for (const r of card.rows) if (r.who) ids.add(r.who);
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

  // 席间小游戏存档（蓝图 3.2，阿鱼 9/19 定）：residentDoc.data 前面已经确认存在，这里只是
  // 挑几个字段带回去，没存过的字段给默认空值（类型不对也当没存，防御性兜底，不抛错）。
  const rd = residentDoc.data;
  const mine = {
    coins: typeof rd.coins === 'number' ? rd.coins : 0,
    games: (rd.games && typeof rd.games === 'object' && !Array.isArray(rd.games)) ? rd.games : {},
    dishes: Array.isArray(rd.dishes) ? rd.dishes : [],
    gift_coins: typeof rd.gift_coins === 'number' ? rd.gift_coins : 0,
  };

  const data = {
      me: { table_id: mySeat.table_id, chair_no: mySeat.chair_no },
      // 55 桌厅：主桌排第一项，带 main:true；12 桌厅没有这一项，跟原来一样
      tables: (MAIN_ID ? [{ id: MAIN_ID, main: true, reserved: false, seats: byTableNow[MAIN_ID] || [] }] : [])
        .concat(TABLE_IDS.map(id => ({ id, reserved: RESERVED_IDS.has(id), seats: byTableNow[id] || [] }))),
      bench,
      digest,
      arrival,
      names,
      mine,
  };
  // 55 桌厅才有：我是不是阿鱼、Toretto 本人（主桌 1、2 号能坐）。客户端别人走到那两把空椅子前就不冒「坐这儿」（01 D 9/29）。
  // 12 桌厅不回这个字段，返回跟原来一样
  if (MAIN_ID) data.mainSeatOk = (vip || await loadVip()).has(OPENID);
  return { ok: true, data };
};
