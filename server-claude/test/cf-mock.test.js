'use strict';
/**
 * 假 db 跑一遍云函数（回执 03：宴会厅服务端加固）。
 *
 * rules.test.js 只测 src/ 里的纯函数，测不到云函数里的 I/O 代码（分页读全、names 怎么拼、
 * saveProfile 怎么接线邀请人判定）。这个脚本不装任何依赖（不装真的 wx-server-sdk），
 * 用一个内存里的假数据库 + 劫持 require('wx-server-sdk') 的办法，把 enterHall/readBook/
 * saveProfile 这三个云函数的 index.js 源码原样跑起来，断言真实行为。
 *
 * 跑之前先跑一遍 node scripts/sync-cf-rules.js（把 src/、lib/ 同步进各云函数自己的 rules、lib
 * 子文件夹），这个脚本才能 require 到各云函数目录下 rules、lib 里的文件。
 *
 * 用法：
 *   node scripts/sync-cf-rules.js   # 先同步（改过 src/ 或 lib/ 就要重跑）
 *   node test/cf-mock.test.js
 */
const path = require('path');
const assert_module = require('module');

let pass = 0, fail = 0;
const failures = [];
function check(cond, name) {
  if (cond) pass++;
  else { fail++; failures.push(name); }
}

// ---------- 劫持 require('wx-server-sdk')，喂假的进去 ----------
// 不装依赖、不碰真的 wx-server-sdk：Module._load 是 Node 内部所有 require() 最终都会走到的
// 入口，这里只拦截 request === 'wx-server-sdk' 这一个字符串，其它全部照常走原来的逻辑。
let CURRENT_FAKE_SDK = null;
const originalLoad = assert_module._load;
assert_module._load = function (request, parent, isMain) {
  if (request === 'wx-server-sdk') {
    if (!CURRENT_FAKE_SDK) throw new Error('cf-mock: 还没设置假 wx-server-sdk 就被 require 了');
    return CURRENT_FAKE_SDK;
  }
  return originalLoad.apply(this, arguments);
};

const CF_ROOT = path.join(__dirname, '..', 'cloudfunctions');

/** 重新加载一个云函数的 index.js，绑定到指定的假 sdk 上（每个场景要用干净的库就重新 load 一次） */
function loadCloudFunction(name, fakeSdk) {
  const indexPath = require.resolve(path.join(CF_ROOT, name, 'index.js'));
  delete require.cache[indexPath]; // 逼它重新执行，重新 require('wx-server-sdk') 拿到新的假 db
  CURRENT_FAKE_SDK = fakeSdk;
  const mod = require(indexPath);
  CURRENT_FAKE_SDK = null;
  return mod;
}

// ---------- 内存假数据库：只实现这三个云函数真正用到的那部分 wx-server-sdk 行为 ----------
function ensureColl(state, name) {
  if (!state.collections[name]) state.collections[name] = new Map();
  return state.collections[name];
}

function matchOne(docValue, cond) {
  if (cond && typeof cond === 'object' && cond.__cmd) {
    switch (cond.__cmd) {
      case 'eq': return docValue === cond.value;
      case 'neq': return docValue !== cond.value;
      case 'gt': return docValue > cond.value;
      case 'gte': return docValue >= cond.value;
      case 'lt': return docValue < cond.value;
      case 'lte': return docValue <= cond.value;
      case 'in': return Array.isArray(cond.value) && cond.value.includes(docValue);
      default: throw new Error('假 db 不支持的操作符：' + cond.__cmd);
    }
  }
  return docValue === cond;
}
function matchesAll(doc, cond) {
  return Object.keys(cond).every(k => matchOne(doc[k], cond[k]));
}

function makeDocRef(state, collName, id) {
  return {
    async get() {
      const doc = state.collections[collName] && state.collections[collName].get(String(id));
      if (!doc) throw new Error(`假 db：${collName}/${id} 不存在`); // 跟真的 SDK 一样，查不到就 reject
      return { data: JSON.parse(JSON.stringify(doc)) };
    },
    async update({ data }) {
      const coll = state.collections[collName];
      const doc = coll && coll.get(String(id));
      if (!doc) throw new Error(`假 db：${collName}/${id} 不存在，update 失败`);
      Object.assign(doc, data);
      return { stats: { updated: 1 } };
    },
  };
}

function makeQuery(state, collName, initialCond) {
  let cond = Object.assign({}, initialCond);
  const order = [];
  let skipN = 0;
  let limitN = null;
  let proj = null;
  const q = {
    where(c) { cond = Object.assign({}, cond, c); return q; },
    orderBy(field, dir) { order.push([field, dir === 'desc' ? 'desc' : 'asc']); return q; },
    skip(n) { skipN = n; return q; },
    limit(n) { limitN = n; return q; },
    field(p) { proj = p; return q; },
    doc(id) { return makeDocRef(state, collName, id); },
    async add({ data }) {
      const coll = ensureColl(state, collName);
      const id = data._id != null ? String(data._id) : `auto_${String(++state.autoSeq).padStart(10, '0')}`;
      coll.set(id, Object.assign({}, data, { _id: id }));
      return { _id: id };
    },
    async get() {
      const coll = state.collections[collName];
      let rows = coll ? Array.from(coll.values()).filter(d => matchesAll(d, cond)) : [];
      if (order.length) {
        rows = rows.slice().sort((a, b) => {
          for (const [field, dir] of order) {
            const av = a[field] === undefined ? null : a[field];
            const bv = b[field] === undefined ? null : b[field];
            if (av < bv) return dir === 'desc' ? 1 : -1;
            if (av > bv) return dir === 'desc' ? -1 : 1;
          }
          return 0;
        });
      }
      if (skipN) rows = rows.slice(skipN);
      if (limitN != null) rows = rows.slice(0, limitN);
      if (proj) {
        const keys = Object.keys(proj).filter(k => proj[k]);
        if (!keys.includes('_id')) keys.push('_id');
        rows = rows.map(r => { const o = {}; for (const k of keys) o[k] = r[k]; return o; });
      }
      return { data: JSON.parse(JSON.stringify(rows)) };
    },
  };
  return q;
}

/** @returns {{sdk: object, state: object}} sdk 喂给 require('wx-server-sdk')；state 是测试代码直接摆数据、断言结果用的 */
function createFakeSdk() {
  const state = { collections: {}, autoSeq: 0, currentOpenid: null };
  const db = {
    collection: (name) => makeQuery(state, name, {}),
    command: {
      eq: (value) => ({ __cmd: 'eq', value }),
      neq: (value) => ({ __cmd: 'neq', value }),
      gt: (value) => ({ __cmd: 'gt', value }),
      gte: (value) => ({ __cmd: 'gte', value }),
      lt: (value) => ({ __cmd: 'lt', value }),
      lte: (value) => ({ __cmd: 'lte', value }),
      in: (value) => ({ __cmd: 'in', value }),
    },
  };
  const sdk = {
    init() {},
    database: () => db,
    getWXContext: () => ({ OPENID: state.currentOpenid, APPID: 'wx-fake-appid' }),
    DYNAMIC_CURRENT_ENV: 'fake-env',
  };
  return { sdk, state };
}

function seed(state, collName, doc) {
  ensureColl(state, collName).set(String(doc._id), Object.assign({}, doc));
}

// ================= 场景1：seat 有 250 条时 enterHall 能读全、椅子号不重复 =================
async function scenarioSeatPagination() {
  const { sdk, state } = createFakeSdk();
  const TABLE_IDS = ['T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8', 'T9', 'T10', 'T11', 'T12'];
  let n = 0;
  const mkSeat = (id, tableId, chairNo) => ({
    _id: id, openid: id, table_id: tableId, chair_no: chairNo, inviter: null,
    sat_at: 1000 + (++n), changed_on: null, sat_tables: tableId === 'bench' ? [] : [tableId], last_visit_at: 1000 + n,
  });
  // T1..T11 坐满（各 10 人），先插入——朴素的"不分页、默认最多读 100 条"如果只读到插入顺序里
  // 前 100 条，连 T11 都读不全，更别提之后插入的 T12、长凳
  for (const t of TABLE_IDS.slice(0, 11)) {
    for (let c = 1; c <= 10; c++) seed(state, 'seat', mkSeat(`seat_${t}_${c}`, t, c));
  }
  // 130 人坐长凳，插在 T12 之前
  for (let i = 1; i <= 130; i++) seed(state, 'seat', mkSeat(`bench_${String(i).padStart(4, '0')}`, 'bench', null));
  // T12 只坐了 9 人（1..9 号椅），10 号空着——全场唯一有空位的桌，最后插入
  for (let c = 1; c <= 9; c++) seed(state, 'seat', mkSeat(`seat_T12_${c}`, 'T12', c));
  // 到这里一共 110 + 130 + 9 = 249 条已有 seat 记录

  const NEW_GUY = 'newGuy';
  seed(state, 'resident', { _id: NEW_GUY, openid: NEW_GUY, nick: '新客', avatar: 3, inviter: null, created_at: 1, gift_value: 0, whisper: '', checked_in_at: null });
  state.currentOpenid = NEW_GUY;

  const enterHall = loadCloudFunction('enterHall', sdk);
  const res = await enterHall.main();

  check(res.ok === true, '场景1 enterHall 返回 ok:true');
  check(res.data && res.data.me.table_id === 'T12', `场景1 新客应分到唯一有空位的 T12（实际 ${res.data && res.data.me.table_id}）`);
  check(res.data && res.data.me.chair_no === 10, `场景1 T12 只空 10 号椅（实际 ${res.data && res.data.me.chair_no}）`);

  const t12 = res.data.tables.find(t => t.id === 'T12');
  check(!!t12 && t12.seats.length === 10, `场景1 T12 应满 10 人（实际 ${t12 && t12.seats.length}）`);
  const chairNos = t12.seats.map(s => s.chair_no).slice().sort((a, b) => a - b);
  check(JSON.stringify(chairNos) === JSON.stringify([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]), `场景1 T12 椅子号应是 1~10 且不重复（实际 ${JSON.stringify(chairNos)}）`);

  let allFull = true;
  for (const tid of TABLE_IDS.slice(0, 11)) {
    const t = res.data.tables.find(x => x.id === tid);
    if (!t || t.seats.length !== 10) allFull = false;
  }
  check(allFull, '场景1 T1~T11 应该都还是满的 10 人（分页没漏读）');
  check(res.data.bench.length === 130, `场景1 长凳应还是 130 人（实际 ${res.data.bench.length}）`);
}

// ================= 场景2：readBook 超过 200 条只回最新 200 条且正序 =================
async function scenarioReadBookLatest200() {
  const { sdk, state } = createFakeSdk();
  const TABLE = 'T3';
  const BASE = 1_700_000_000_000;
  const TOTAL = 260;
  for (let i = 0; i < TOTAL; i++) {
    seed(state, 'guestbook', {
      _id: `gb_${String(i).padStart(5, '0')}`, table_id: TABLE, openid: `writer_${i % 5}`,
      text: `第${i}句`, created_at: BASE + i,
    });
  }

  const readBook = loadCloudFunction('readBook', sdk);
  const res = await readBook.main({ table: TABLE });

  check(res.ok === true, '场景2 readBook 返回 ok:true');
  check(res.data.lines.length === 200, `场景2 超过 200 条只回 200 条（实际 ${res.data.lines.length}）`);
  check(res.data.lines[0].at === BASE + 60, `场景2 第一条应是第 60 句，即丢掉最老的 60 条（实际 at-BASE=${res.data.lines[0].at - BASE}）`);
  check(res.data.lines[199].at === BASE + 259, `场景2 最后一条应是最新的第 259 句（实际 at-BASE=${res.data.lines[199].at - BASE}）`);
  let ascending = true;
  for (let i = 1; i < res.data.lines.length; i++) if (res.data.lines[i].at <= res.data.lines[i - 1].at) ascending = false;
  check(ascending, '场景2 返回的 200 条仍按时间正序排列');
  check(res.data.lines.every(l => 'openid' in l && 'text' in l && 'at' in l && Object.keys(l).length === 3), '场景2 data.lines 每条结构不变（只有 openid/text/at）');
}

// ================= 场景3：readBook 带回 names（写过句子的人的 nick/avatar） =================
async function scenarioReadBookNames() {
  const { sdk, state } = createFakeSdk();
  const TABLE = 'T5';
  seed(state, 'guestbook', { _id: 'gb_a', table_id: TABLE, openid: 'W1', text: '新婚快乐', created_at: 100 });
  seed(state, 'guestbook', { _id: 'gb_b', table_id: TABLE, openid: 'W2', text: '百年好合', created_at: 200 });
  seed(state, 'resident', { _id: 'W1', openid: 'W1', nick: '阿强', avatar: 4, inviter: null });
  seed(state, 'resident', { _id: 'W2', openid: 'W2', nick: '阿美', avatar: 5, inviter: null });

  const readBook = loadCloudFunction('readBook', sdk);
  const res = await readBook.main({ table: TABLE });

  check(res.ok === true, '场景3 readBook 返回 ok:true');
  check(res.data.lines.length === 2, '场景3 data.lines 结构、条数不受 names 影响');
  check(!!res.data.names.W1 && res.data.names.W1.nick === '阿强', `场景3 names 里能查到写过句子的阿强（实际 ${JSON.stringify(res.data.names.W1)}）`);
  check(!!res.data.names.W2 && res.data.names.W2.avatar === 5, `场景3 names 的 avatar 对得上 resident 表（实际 ${JSON.stringify(res.data.names.W2)}）`);
}

// ================= 场景4：enterHall 的 names 里有不在厅里的邀请人 =================
async function scenarioEnterHallOfflineInviterNames() {
  const { sdk, state } = createFakeSdk();
  // Y：邀请人，从没进过厅，没有 seat 记录
  seed(state, 'resident', { _id: 'Y', openid: 'Y', nick: '老王', avatar: 2, inviter: null });
  // X：坐在厅里，邀请人是 Y
  seed(state, 'resident', { _id: 'X', openid: 'X', nick: '小李', avatar: 1, inviter: 'Y' });
  seed(state, 'seat', { _id: 'X', openid: 'X', table_id: 'T1', chair_no: 1, inviter: 'Y', sat_at: 100, changed_on: null, sat_tables: ['T1'], last_visit_at: 100 });
  // Z：调用者自己，坐在厅里，没有邀请人
  seed(state, 'resident', { _id: 'Z', openid: 'Z', nick: '阿花', avatar: 0, inviter: null });
  seed(state, 'seat', { _id: 'Z', openid: 'Z', table_id: 'T1', chair_no: 2, inviter: null, sat_at: 90, changed_on: null, sat_tables: ['T1'], last_visit_at: 90 });
  state.currentOpenid = 'Z';

  const enterHall = loadCloudFunction('enterHall', sdk);
  const res = await enterHall.main();

  check(res.ok === true, '场景4 enterHall 返回 ok:true');
  check(!!res.data.names.X, '场景4 names 里有坐在厅里的小李');
  check(!!res.data.names.Y, '场景4 names 里也有从没进过厅的邀请人老王');
  check(res.data.names.Y && res.data.names.Y.nick === '老王', '场景4 老王的昵称对得上');
  check(res.data.names.X && res.data.names.X.inviter === 'Y', '场景4 小李的 names 条目带着 inviter=Y，客户端才能拼"老王带进来的"');
}

// ================= 场景5：saveProfile 邀请人只存第一次的接线 =================
async function scenarioSaveProfileInviter() {
  const { sdk, state } = createFakeSdk();
  seed(state, 'resident', { _id: 'B', openid: 'B', nick: '老王', avatar: 1, inviter: null });
  seed(state, 'resident', { _id: 'C', openid: 'C', nick: '小李', avatar: 2, inviter: null });

  // 用例1：A 首次存资料，带合法邀请人 B，应该存上，其它字段也存上
  state.currentOpenid = 'A';
  let saveProfile = loadCloudFunction('saveProfile', sdk);
  let res = await saveProfile.main({ nick: '阿花', inviter: 'B' });
  check(res.ok === true, '场景5-用例1 首次存资料+合法邀请人：返回 ok:true');
  let docA = state.collections.resident.get('A');
  check(!!docA, '场景5-用例1 resident 记录被创建');
  check(!!docA && docA.inviter === 'B', `场景5-用例1 首次合法邀请人应被记下（实际 ${docA && docA.inviter}）`);
  check(!!docA && docA.nick === '阿花', '场景5-用例1 昵称一起存上');

  // 用例2：A 第二次存资料，传不同邀请人 C，不应覆盖；其它字段照存
  state.currentOpenid = 'A';
  saveProfile = loadCloudFunction('saveProfile', sdk);
  res = await saveProfile.main({ nick: '阿花花', inviter: 'C', gift_value: 88 });
  check(res.ok === true, '场景5-用例2 第二次传不同邀请人：仍返回 ok:true（不整体失败）');
  docA = state.collections.resident.get('A');
  check(docA.inviter === 'B', `场景5-用例2 邀请人不应被 C 覆盖，应还是 B（实际 ${docA.inviter}）`);
  check(docA.nick === '阿花花', '场景5-用例2 昵称照常更新为新值');
  check(docA.gift_value === 88, '场景5-用例2 礼金照常更新');

  // 用例3：新人 D 传自己当邀请人，不应写入，其它字段照存
  state.currentOpenid = 'D';
  saveProfile = loadCloudFunction('saveProfile', sdk);
  res = await saveProfile.main({ nick: '阿德', inviter: 'D' });
  check(res.ok === true, '场景5-用例3 传自己当邀请人：仍返回 ok:true');
  const docD = state.collections.resident.get('D');
  check(!!docD && docD.nick === '阿德', '场景5-用例3 昵称照常创建/存上');
  check(!docD.inviter, `场景5-用例3 不能把自己记成邀请人（实际 ${docD.inviter}）`);

  // 用例4：新人 E 传一个不存在的邀请人 id，不应写入，其它字段照存
  state.currentOpenid = 'E';
  saveProfile = loadCloudFunction('saveProfile', sdk);
  res = await saveProfile.main({ nick: '阿E', inviter: 'not-exist-id' });
  check(res.ok === true, '场景5-用例4 邀请人不存在：仍返回 ok:true');
  const docE = state.collections.resident.get('E');
  check(!!docE && docE.nick === '阿E', '场景5-用例4 昵称照常创建/存上');
  check(!docE.inviter, `场景5-用例4 不存在的邀请人不能被记下（实际 ${docE.inviter}）`);
}

// ================= 场景6：writeBook 只能写「现在坐的那桌」（蓝图 3.2 9/18 改） =================
async function scenarioWriteBookCurrentTableOnly() {
  const { sdk, state } = createFakeSdk();
  const ME = 'me6';
  seed(state, 'seat', { _id: ME, openid: ME, table_id: 'T1', chair_no: 1, inviter: null, sat_at: 100, sat_tables: ['T1'], last_visit_at: 100 });
  state.currentOpenid = ME;

  const writeBook = loadCloudFunction('writeBook', sdk);
  let res = await writeBook.main({ table: 'T1', text: '恭喜恭喜' });
  check(res.ok === true, `场景6 坐在T1写T1成功（实际 ${JSON.stringify(res)}）`);

  res = await writeBook.main({ table: 'T2', text: '恭喜恭喜' });
  check(res.ok === false && res.reason === 'not_sat_here', `场景6 坐在T1写T2被拒（实际 ${JSON.stringify(res)}）`);

  // 换到 T2：走真正的 changeSeat 云函数（跟真实流程一样，T2 4 号椅没人坐）
  const changeSeat = loadCloudFunction('changeSeat', sdk);
  res = await changeSeat.main({ tableId: 'T2', chairNo: 4 });
  check(res.ok === true, `场景6 换到T2应该成功（实际 ${JSON.stringify(res)}）`);

  res = await writeBook.main({ table: 'T2', text: '百年好合' });
  check(res.ok === true, `场景6 换到T2后写T2成功（实际 ${JSON.stringify(res)}）`);

  // 长凳的人写任何桌都拒
  const BENCH_GUY = 'bench6';
  seed(state, 'seat', { _id: BENCH_GUY, openid: BENCH_GUY, table_id: 'bench', chair_no: null, inviter: null, sat_at: 100, sat_tables: [], last_visit_at: 100 });
  state.currentOpenid = BENCH_GUY;
  res = await writeBook.main({ table: 'T1', text: '坐长凳也想说句话' });
  check(res.ok === false && res.reason === 'not_sat_here', `场景6 长凳的人写T1被拒（实际 ${JSON.stringify(res)}）`);
}

// ---------- 跑全部场景 ----------
(async () => {
  await scenarioSeatPagination();
  await scenarioReadBookLatest200();
  await scenarioReadBookNames();
  await scenarioEnterHallOfflineInviterNames();
  await scenarioSaveProfileInviter();
  await scenarioWriteBookCurrentTableOnly();

  assert_module._load = originalLoad; // 恢复，不影响这个进程里之后可能的其它 require

  console.log(`\n通过 ${pass}，失败 ${fail}`);
  if (fail) {
    console.log('\n失败项：');
    failures.forEach(f => console.log('  ✗ ' + f));
    process.exit(1);
  } else {
    console.log('全部通过');
  }
})().catch((e) => {
  console.error('测试脚本本身报错：', e);
  process.exit(1);
});
