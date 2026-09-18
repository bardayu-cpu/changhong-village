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

// ================= 场景7：writeBook 带敏感词被拒、不写库；正常文本照样能写（回执 05：敏感词模块） =================
async function scenarioWriteBookSensitiveRejected() {
  const { sdk, state } = createFakeSdk();
  const ME = 'sensitive_guy';
  seed(state, 'seat', { _id: ME, openid: ME, table_id: 'T1', chair_no: 1, inviter: null, sat_at: 100, sat_tables: ['T1'], last_visit_at: 100 });
  state.currentOpenid = ME;

  const writeBook = loadCloudFunction('writeBook', sdk);

  // 敏感词（从 words/base.txt 真实词条挑的"情色"，跟误伤测试 test/words-false-positive.test.js 用的是同一个词）
  let res = await writeBook.main({ table: 'T1', text: '这里有情色内容' });
  check(res.ok === false && res.reason === 'sensitive', `场景7 桌簿含敏感词被拒（实际 ${JSON.stringify(res)}）`);
  const gbAfterReject = state.collections.guestbook ? Array.from(state.collections.guestbook.values()) : [];
  check(gbAfterReject.length === 0, `场景7 敏感词被拒不应该写进 guestbook（实际 ${gbAfterReject.length} 条）`);

  // 正常文本：不受影响，照样能写、真的落库
  res = await writeBook.main({ table: 'T1', text: '新婚快乐 百年好合' });
  check(res.ok === true, `场景7 正常文本能写（实际 ${JSON.stringify(res)}）`);
  const gbAfterOk = Array.from(state.collections.guestbook.values());
  check(gbAfterOk.length === 1 && gbAfterOk[0].text === '新婚快乐 百年好合', '场景7 正常文本确实写进了 guestbook');
}

// ================= 场景8：saveProfile 昵称命中保留名/敏感词被拒、不建档；正常昵称照样能存（回执 05：敏感词模块） =================
async function scenarioSaveProfileWordRejected() {
  const { sdk, state } = createFakeSdk();

  // 保留名（docs/敏感词模块-需求.md 第 5 节初始名单）：起昵称用"阿鱼"被拒，不写库
  state.currentOpenid = 'guest_a';
  let saveProfile = loadCloudFunction('saveProfile', sdk);
  let res = await saveProfile.main({ nick: '阿鱼' });
  check(res.ok === false && res.reason === 'reserved', `场景8 昵称是保留名被拒（实际 ${JSON.stringify(res)}）`);
  check(!(state.collections.resident && state.collections.resident.has('guest_a')), '场景8 保留名被拒不应该建 resident 记录');

  // 敏感词：起昵称含词库里的词被拒，不写库
  state.currentOpenid = 'guest_b';
  saveProfile = loadCloudFunction('saveProfile', sdk);
  res = await saveProfile.main({ nick: '情色达人' });
  check(res.ok === false && res.reason === 'sensitive', `场景8 昵称含敏感词被拒（实际 ${JSON.stringify(res)}）`);
  check(!(state.collections.resident && state.collections.resident.has('guest_b')), '场景8 敏感词被拒不应该建 resident 记录');

  // 正常昵称：不受影响，照样能存、真的落库
  state.currentOpenid = 'guest_c';
  saveProfile = loadCloudFunction('saveProfile', sdk);
  res = await saveProfile.main({ nick: '阿花' });
  check(res.ok === true, `场景8 正常昵称能存（实际 ${JSON.stringify(res)}）`);
  const docC = state.collections.resident.get('guest_c');
  check(!!docC && docC.nick === '阿花', '场景8 正常昵称确实存进了 resident');
}

// ================= 场景9：保留名留给主角——主角名单里的人、已经用着这个名字的人不拦；别人照拦；敏感词对谁都拦 =================
async function scenarioReservedNameExemptions() {
  const { sdk, state } = createFakeSdk();
  seed(state, 'config', { _id: 'banquet', vip_openids: ['vip_ayu'] });
  seed(state, 'resident', { _id: 'old_holder', openid: 'old_holder', nick: '新娘', avatar: 1, inviter: null });

  state.currentOpenid = 'vip_ayu';
  let saveProfile = loadCloudFunction('saveProfile', sdk);
  let res = await saveProfile.main({ nick: '阿鱼', avatar: 2 });
  check(res.ok === true, `场景9 主角名单里的人起名「阿鱼」放行（实际 ${JSON.stringify(res)}）`);
  const docVip = state.collections.resident.get('vip_ayu');
  check(!!docVip && docVip.nick === '阿鱼', '场景9 主角的昵称确实存上了');

  state.currentOpenid = 'old_holder';
  saveProfile = loadCloudFunction('saveProfile', sdk);
  res = await saveProfile.main({ nick: '新娘', avatar: 3 });
  check(res.ok === true, `场景9 已经叫「新娘」的人接着用放行（实际 ${JSON.stringify(res)}）`);

  state.currentOpenid = 'guest_d';
  saveProfile = loadCloudFunction('saveProfile', sdk);
  res = await saveProfile.main({ nick: '阿鱼' });
  check(res.ok === false && res.reason === 'reserved', `场景9 别人起名「阿鱼」照样拦（实际 ${JSON.stringify(res)}）`);

  state.currentOpenid = 'vip_ayu';
  saveProfile = loadCloudFunction('saveProfile', sdk);
  res = await saveProfile.main({ nick: '情色达人' });
  check(res.ok === false && res.reason === 'sensitive', `场景9 主角起名带敏感词照样拦（实际 ${JSON.stringify(res)}）`);
}

/** 包一层 sdk.database()，数出每个表被查询过几次——用来验证 hallPulse "toasts 为空时不查 resident" 这类性能约束 */
function withCallCounter(sdk) {
  const counts = {};
  const originalDatabase = sdk.database;
  sdk.database = () => {
    const realDb = originalDatabase();
    return Object.assign({}, realDb, {
      collection(name) {
        counts[name] = (counts[name] || 0) + 1;
        return realDb.collection(name);
      },
    });
  };
  return counts;
}

// ================= 场景10：hallPulse 的 since 缺/不是正数 → toasts、names 都是空，但带着 now；这种情况完全不查 toast 表 =================
async function scenarioHallPulseInvalidSince() {
  const { sdk, state } = createFakeSdk();
  const ME = 'pulse_me_10';
  // 提前埋一条本来会命中的敬酒——如果 hallPulse 在 since 不合法时仍然去查表，这条就会被误报出来
  seed(state, 'toast', { _id: 't10_old', from: 'someone_10', to: ME, date: '2026-09-18', created_at: 500 });
  state.currentOpenid = ME;
  const counts = withCallCounter(sdk);

  const hallPulse = loadCloudFunction('hallPulse', sdk);

  let res = await hallPulse.main({});
  check(res.ok === true, `场景10 不传 since：返回 ok:true（实际 ${JSON.stringify(res)}）`);
  check(Array.isArray(res.toasts) && res.toasts.length === 0, `场景10 不传 since：toasts 应为空（实际 ${JSON.stringify(res.toasts)}）`);
  check(!!res.names && Object.keys(res.names).length === 0, `场景10 不传 since：names 应为空对象（实际 ${JSON.stringify(res.names)}）`);
  check(typeof res.now === 'number' && res.now > 0, `场景10 不传 since：应该带上 now（实际 ${res.now}）`);

  res = await hallPulse.main({ since: 0 });
  check(res.ok === true && res.toasts.length === 0, `场景10 since=0（不是正数）：toasts 应为空（实际 ${JSON.stringify(res)}）`);

  res = await hallPulse.main({ since: -100 });
  check(res.ok === true && res.toasts.length === 0, `场景10 since 是负数：toasts 应为空（实际 ${JSON.stringify(res)}）`);

  res = await hallPulse.main({ since: 'not-a-number' });
  check(res.ok === true && res.toasts.length === 0, `场景10 since 不是数字：toasts 应为空（实际 ${JSON.stringify(res)}）`);

  check(!counts.toast, `场景10 since 不合法的这几次调用，一次都不该查 toast 表（实际查了 ${counts.toast || 0} 次）`);
  check(!counts.resident, `场景10 since 不合法时也不该查 resident 表（实际查了 ${counts.resident || 0} 次）`);
}

// ================= 场景11：A 敬 B 以后，B 带着上一次的 now 当 since 调 hallPulse → 拿到 1 条，from 是 A，names 里有 A 的昵称和形象 =================
async function scenarioHallPulseGetsNewToast() {
  const { sdk, state } = createFakeSdk();
  const A = 'pulse_A_11';
  const B = 'pulse_B_11';
  seed(state, 'resident', { _id: A, openid: A, nick: '阿强', avatar: 4, inviter: null });
  const lastNow = 1_700_000_000_000; // 假装是 B 上一次心跳（或者进厅那次）拿到的 now
  const toastAt = lastNow + 3000; // 之后 A 敬了 B 一杯
  seed(state, 'toast', { _id: 't11_a_to_b', from: A, to: B, date: '2026-09-18', created_at: toastAt });
  state.currentOpenid = B;

  const hallPulse = loadCloudFunction('hallPulse', sdk);
  const res = await hallPulse.main({ since: lastNow });

  check(res.ok === true, `场景11 返回 ok:true（实际 ${JSON.stringify(res)}）`);
  check(res.toasts.length === 1, `场景11 应该拿到 1 条敬酒（实际 ${res.toasts.length}）`);
  check(!!res.toasts[0] && res.toasts[0].from === A, `场景11 敬酒的 from 应该是 A（实际 ${res.toasts[0] && res.toasts[0].from}）`);
  check(!!res.toasts[0] && res.toasts[0].created_at === toastAt, `场景11 created_at 应该对得上（实际 ${res.toasts[0] && res.toasts[0].created_at}）`);
  check(!!res.names[A], `场景11 names 里应该有 A（实际 ${JSON.stringify(res.names)}）`);
  check(res.names[A] && res.names[A].nick === '阿强', `场景11 A 的昵称应该对得上（实际 ${res.names[A] && res.names[A].nick}）`);
  check(res.names[A] && res.names[A].avatar === 4, `场景11 A 的形象应该对得上（实际 ${res.names[A] && res.names[A].avatar}）`);
  check(typeof res.now === 'number' && res.now >= toastAt, `场景11 返回的 now 不应该比刚报出的敬酒还早，否则下次心跳会漏报（实际 now=${res.now}，created_at=${toastAt}）`);
}

// ================= 场景12：B 用第一次心跳返回的 now 当 since 再调一次 → 不再重复拿到同一条敬酒 =================
async function scenarioHallPulseNoDuplicateOnNextPoll() {
  const { sdk, state } = createFakeSdk();
  const A = 'pulse_A_12';
  const B = 'pulse_B_12';
  const lastNow = 1_700_000_000_000;
  const toastAt = lastNow + 3000;
  seed(state, 'toast', { _id: 't12_a_to_b', from: A, to: B, date: '2026-09-18', created_at: toastAt });
  state.currentOpenid = B;

  const hallPulse = loadCloudFunction('hallPulse', sdk);
  const first = await hallPulse.main({ since: lastNow });
  check(first.ok === true && first.toasts.length === 1, `场景12 第一次心跳应该先拿到那条敬酒，后面才谈得上"不重复"（实际 ${JSON.stringify(first)}）`);

  const second = await hallPulse.main({ since: first.now });
  check(second.ok === true, `场景12 第二次心跳返回 ok:true（实际 ${JSON.stringify(second)}）`);
  check(second.toasts.length === 0, `场景12 用第一次返回的 now 当 since 再调，不应该重复拿到（实际 ${JSON.stringify(second.toasts)}）`);
}

// ================= 场景13：别人（C）收到的敬酒不会出现在 B 这里 =================
async function scenarioHallPulseOnlyMine() {
  const { sdk, state } = createFakeSdk();
  const A = 'pulse_A_13';
  const B = 'pulse_B_13';
  const C = 'pulse_C_13';
  const lastNow = 1_700_000_000_000;
  seed(state, 'toast', { _id: 't13_to_b', from: A, to: B, date: '2026-09-18', created_at: lastNow + 100 });
  seed(state, 'toast', { _id: 't13_to_c', from: A, to: C, date: '2026-09-18', created_at: lastNow + 200 }); // 敬的是 C，不是 B
  state.currentOpenid = B;

  const hallPulse = loadCloudFunction('hallPulse', sdk);
  const res = await hallPulse.main({ since: lastNow });

  check(res.ok === true, `场景13 返回 ok:true（实际 ${JSON.stringify(res)}）`);
  check(res.toasts.length === 1, `场景13 B 应该只拿到敬给自己的那 1 条，敬给 C 的不该混进来（实际 ${res.toasts.length}）`);
  check(!!res.toasts[0] && res.toasts[0].from === A, '场景13 拿到的应该是敬给 B 的那条');
}

// ================= 场景14：8 秒内被敬超过 10 杯，只回最早的 10 条，按时间升序 =================
async function scenarioHallPulseCapAtTen() {
  const { sdk, state } = createFakeSdk();
  const B = 'pulse_B_14';
  const lastNow = 1_700_000_000_000;
  const TOTAL = 15;
  for (let i = 0; i < TOTAL; i++) {
    seed(state, 'toast', { _id: `t14_${i}`, from: `friend_14_${i}`, to: B, date: '2026-09-18', created_at: lastNow + 10 + i });
  }
  state.currentOpenid = B;

  const hallPulse = loadCloudFunction('hallPulse', sdk);
  const res = await hallPulse.main({ since: lastNow });

  check(res.ok === true, `场景14 返回 ok:true（实际 ${JSON.stringify(res)}）`);
  check(res.toasts.length === 10, `场景14 超过 10 条只回 10 条（实际 ${res.toasts.length}）`);
  let ascending = true;
  for (let i = 1; i < res.toasts.length; i++) if (res.toasts[i].created_at <= res.toasts[i - 1].created_at) ascending = false;
  check(ascending, '场景14 返回的 10 条应该按 created_at 升序排列');
  check(res.toasts[0].created_at === lastNow + 10, `场景14 应该是最早的那条打头（实际偏移 ${res.toasts[0].created_at - lastNow}）`);
  check(res.toasts[9].created_at === lastNow + 19, `场景14 第 10 条应该是最早的第 10 条，即原始第 0~9 条（实际偏移 ${res.toasts[9].created_at - lastNow}）`);
  check(Object.keys(res.names).length === 10, `场景14 names 应该正好有这 10 个人（实际 ${Object.keys(res.names).length}）`);
}

// ================= 场景15（追加）：since 合法但确实没有新敬酒 → toasts/names 都是空，且不查 resident 表 =================
async function scenarioHallPulseNoneNewSkipsResident() {
  const { sdk, state } = createFakeSdk();
  const B = 'pulse_B_15';
  state.currentOpenid = B;
  const counts = withCallCounter(sdk);

  const hallPulse = loadCloudFunction('hallPulse', sdk);
  const res = await hallPulse.main({ since: 1_700_000_000_000 });

  check(res.ok === true, `场景15 返回 ok:true（实际 ${JSON.stringify(res)}）`);
  check(res.toasts.length === 0, `场景15 没有新敬酒时 toasts 应为空（实际 ${JSON.stringify(res.toasts)}）`);
  check(Object.keys(res.names).length === 0, `场景15 没有新敬酒时 names 应为空（实际 ${JSON.stringify(res.names)}）`);
  check(counts.toast === 1, `场景15 since 合法时应该查一次 toast 表（实际 ${counts.toast || 0} 次）`);
  check(!counts.resident, `场景15 toasts 为空时不该查 resident 表（实际查了 ${counts.resident || 0} 次）`);
}

// ================= 场景16（追加）：敬酒人在 resident 表里查不到记录时，names 仍要有这个人，兜底 nick=''、avatar=-1 =================
async function scenarioHallPulseGhostSenderNameFallback() {
  const { sdk, state } = createFakeSdk();
  const GHOST = 'pulse_ghost_16'; // 敬过酒但 resident 表里没有记录的人（理论上不该发生，但 names 兜底要能处理）
  const B = 'pulse_B_16';
  const lastNow = 1_700_000_000_000;
  seed(state, 'toast', { _id: 't16_ghost_to_b', from: GHOST, to: B, date: '2026-09-18', created_at: lastNow + 100 });
  state.currentOpenid = B;

  const hallPulse = loadCloudFunction('hallPulse', sdk);
  const res = await hallPulse.main({ since: lastNow });

  check(res.ok === true, `场景16 返回 ok:true（实际 ${JSON.stringify(res)}）`);
  check(res.toasts.length === 1, `场景16 应该拿到这 1 条敬酒（实际 ${res.toasts.length}）`);
  check(!!res.names[GHOST], `场景16 查不到 resident 记录的敬酒人也要出现在 names 里（实际 ${JSON.stringify(res.names)}）`);
  check(res.names[GHOST] && res.names[GHOST].nick === '' && res.names[GHOST].avatar === -1, `场景16 查不到的人应该兜底成 nick=''/avatar=-1（实际 ${JSON.stringify(res.names[GHOST])}）`);
}

// ================= 场景17（追加）：数据库异常时返回 {ok:false, reason:'network'}，不把异常抛给客户端 =================
async function scenarioHallPulseDbErrorReturnsNetwork() {
  const { sdk, state } = createFakeSdk();
  const B = 'pulse_B_17';
  state.currentOpenid = B;
  // 模拟数据库异常：让 toast 表的查询直接抛错
  const originalDatabase = sdk.database;
  sdk.database = () => {
    const realDb = originalDatabase();
    return Object.assign({}, realDb, {
      collection(name) {
        if (name === 'toast') throw new Error('模拟数据库异常');
        return realDb.collection(name);
      },
    });
  };

  const hallPulse = loadCloudFunction('hallPulse', sdk);
  const res = await hallPulse.main({ since: 1_700_000_000_000 });

  check(res.ok === false, `场景17 数据库异常时不应该返回 ok:true（实际 ${JSON.stringify(res)}）`);
  check(res.reason === 'network', `场景17 数据库异常应该返回 reason:'network'（实际 ${JSON.stringify(res)}）`);
}

// ================= 场景18：在厅里当场报过的敬酒，下次进厅不再报；没当场报过的照报（主程 9/19） =================
async function scenarioPulseSeenNotRepeatedOnEnter() {
  const { sdk, state } = createFakeSdk();
  const A = 'seen_A_18';
  const B = 'seen_B_18';
  seed(state, 'resident', { _id: A, openid: A, nick: '老王', avatar: 1, inviter: null });
  seed(state, 'resident', { _id: B, openid: B, nick: '小李', avatar: 5, inviter: null });
  const T0 = 1_700_000_000_000;   // B 上次进厅
  seed(state, 'seat', { _id: B, openid: B, table_id: 'T1', chair_no: 3, inviter: null, sat_at: T0, changed_on: null, sat_tables: ['T1'], last_visit_at: T0 });
  seed(state, 'toast', { _id: 't18_1', from: A, to: B, date: '2026-09-19', created_at: T0 + 5000 });
  state.currentOpenid = B;

  const hallPulse = loadCloudFunction('hallPulse', sdk);
  const pulse = await hallPulse.main({ since: T0 + 1000 });
  check(pulse.ok === true && pulse.toasts.length === 1, `场景18 当场收到 1 条（实际 ${JSON.stringify(pulse)}）`);
  const seat = state.collections.seat.get(B);
  check(seat.toast_seen_at === T0 + 5000, `场景18 seat 记下 toast_seen_at = 那条的时间（实际 ${seat.toast_seen_at}）`);

  // B 离开后 A 又敬了一杯，B 没在线、没当场收到
  seed(state, 'toast', { _id: 't18_2', from: A, to: B, date: '2026-09-19', created_at: T0 + 9000 });
  const enterHall = loadCloudFunction('enterHall', sdk);
  const res = await enterHall.main();
  check(res.ok === true, `场景18 enterHall ok（实际 ${JSON.stringify(res).slice(0, 200)}）`);
  const dg = res.data && res.data.digest;
  check(dg && dg.toastCount === 1, `场景18 进厅只报没当场看过的那 1 杯（实际 ${dg && dg.toastCount}）`);
  check(dg && dg.toasts[0] && dg.toasts[0].at === T0 + 9000, `场景18 报的是后来那杯（实际 ${dg && JSON.stringify(dg.toasts)}）`);
}

// ================= 场景19：往回多看 3 秒——上次心跳之前 2 秒写进库的敬酒（写库慢了一拍）这次还能拿到 =================
async function scenarioPulseOverlapCatchesLateWrite() {
  const { sdk, state } = createFakeSdk();
  const A = 'late_A_19';
  const B = 'late_B_19';
  const lastNow = 1_700_000_000_000;
  seed(state, 'toast', { _id: 't19', from: A, to: B, date: '2026-09-19', created_at: lastNow - 2000 });
  state.currentOpenid = B;
  const hallPulse = loadCloudFunction('hallPulse', sdk);
  const res = await hallPulse.main({ since: lastNow });
  check(res.ok === true && res.toasts.length === 1, `场景19 since 前 2 秒的那条也拿到（客户端去重）（实际 ${JSON.stringify(res.toasts)}）`);
  const old = await hallPulse.main({ since: lastNow + 10000 });
  check(old.toasts.length === 0, `场景19 超过 3 秒的旧敬酒不再拿（实际 ${JSON.stringify(old.toasts)}）`);
}

// ================= 场景20：只传 coins、games → 存进去，nick 不变、也没跑昵称检查（resident 里原昵称是保留名也不会被拦，蓝图 3.2 席间小游戏） =================
async function scenarioSaveProfileGameFieldsNoNickCheck() {
  const { sdk, state } = createFakeSdk();
  const ME = 'game_guy_20';
  // "阿鱼"是保留名（场景8/9 已验证过），这里直接把它塞进 resident（模拟这是以前就存好的昵称），
  // 用来证明只传 coins/games 时完全不会去重新过一遍昵称检查——不然这条已经存在的记录会被"拦"下来
  seed(state, 'resident', { _id: ME, openid: ME, nick: '阿鱼', avatar: 2, inviter: null });
  state.currentOpenid = ME;

  const saveProfile = loadCloudFunction('saveProfile', sdk);
  const res = await saveProfile.main({ coins: 50, games: { t1_t2: 3 } });

  check(res.ok === true, `场景20 只传coins/games：返回ok:true（实际 ${JSON.stringify(res)}）`);
  const doc = state.collections.resident.get(ME);
  check(doc.nick === '阿鱼', `场景20 昵称没被动过、也没被拦下（实际 ${doc.nick}）`);
  check(doc.coins === 50, `场景20 coins存上了（实际 ${doc.coins}）`);
  check(!!doc.games && doc.games.t1_t2 === 3, `场景20 games存上了（实际 ${JSON.stringify(doc.games)}）`);
}

// ================= 场景21：coins负数/字符串夹到0/丢掉；games坏键坏值丢掉留好的；dishes去重、超范围丢掉（蓝图 3.2 席间小游戏） =================
async function scenarioSaveProfileGameFieldsSanitize() {
  const { sdk, state } = createFakeSdk();
  const ME = 'game_guy_21';
  seed(state, 'resident', { _id: ME, openid: ME, nick: '阿花21', avatar: 1, inviter: null });
  state.currentOpenid = ME;
  const saveProfile = loadCloudFunction('saveProfile', sdk);

  // 用例1：coins 是负数 → 夹到0
  let res = await saveProfile.main({ coins: -5 });
  check(res.ok === true, `场景21-用例1 coins负数：返回ok:true（实际 ${JSON.stringify(res)}）`);
  let doc = state.collections.resident.get(ME);
  check(doc.coins === 0, `场景21-用例1 coins负数应该夹到0（实际 ${doc.coins}）`);

  // 用例2：coins 是字符串 → 整个字段丢掉（不写库），旧值不受影响
  res = await saveProfile.main({ coins: 'abc' });
  check(res.ok === true, `场景21-用例2 coins字符串：仍返回ok:true（实际 ${JSON.stringify(res)}）`);
  doc = state.collections.resident.get(ME);
  check(doc.coins === 0, `场景21-用例2 coins是字符串应该被整个丢掉，旧值（0）不变（实际 ${doc.coins}）`);

  // 用例3：games 有坏键（格式不对）、坏值（不是数字），丢掉坏的、留下好的
  res = await saveProfile.main({ games: { 'bad key!': 9, ok_game: 3, another_bad: 'nope' } });
  check(res.ok === true, `场景21-用例3 games带坏键坏值：仍返回ok:true（实际 ${JSON.stringify(res)}）`);
  doc = state.collections.resident.get(ME);
  check(!!doc.games && doc.games.ok_game === 3, `场景21-用例3 合法键ok_game应该存上（实际 ${JSON.stringify(doc.games)}）`);
  check(!('bad key!' in (doc.games || {})), '场景21-用例3 格式不对的键"bad key!"应该被丢掉');
  check(!('another_bad' in (doc.games || {})), '场景21-用例3 值不是数字的键another_bad应该被丢掉');

  // 用例4：dishes 去重、超范围（负数、大于99）丢掉
  res = await saveProfile.main({ dishes: [3, 5, 3, -1, 100, 7] });
  check(res.ok === true, `场景21-用例4 dishes：返回ok:true（实际 ${JSON.stringify(res)}）`);
  doc = state.collections.resident.get(ME);
  check(JSON.stringify(doc.dishes) === JSON.stringify([3, 5, 7]), `场景21-用例4 dishes应该去重、丢掉超范围的（实际 ${JSON.stringify(doc.dishes)}）`);
}

// ================= 场景22：gift_add 添礼金——合法记一笔流水，不合法不记，其它字段不受影响（蓝图 3.2 席间小游戏） =================
async function scenarioSaveProfileGiftAdd() {
  const { sdk, state } = createFakeSdk();
  const ME = 'gift_guy_22';
  seed(state, 'resident', { _id: ME, openid: ME, nick: '阿添', avatar: 1, inviter: null });
  state.currentOpenid = ME;
  const saveProfile = loadCloudFunction('saveProfile', sdk);

  // 用例1：gift_add=88 合法 → gift_coin 集合多一条 {openid, nick, coins:88, created_at}，不存进 resident
  let res = await saveProfile.main({ gift_add: 88 });
  check(res.ok === true, `场景22-用例1 gift_add=88：返回ok:true（实际 ${JSON.stringify(res)}）`);
  let giftDocs = state.collections.gift_coin ? Array.from(state.collections.gift_coin.values()) : [];
  check(giftDocs.length === 1, `场景22-用例1 gift_coin集合应该多一条（实际 ${giftDocs.length} 条）`);
  check(!!giftDocs[0] && giftDocs[0].coins === 88, `场景22-用例1 记录的coins字段应该是88（实际 ${giftDocs[0] && giftDocs[0].coins}）`);
  check(!!giftDocs[0] && giftDocs[0].nick === '阿添', `场景22-用例1 记录的nick应该是这人现在的昵称（实际 ${giftDocs[0] && giftDocs[0].nick}）`);
  check(!!giftDocs[0] && giftDocs[0].openid === ME, `场景22-用例1 记录的openid应该是这人自己（实际 ${giftDocs[0] && giftDocs[0].openid}）`);
  check(typeof giftDocs[0].created_at === 'number', '场景22-用例1 记录应该带created_at');
  let doc = state.collections.resident.get(ME);
  check(!('gift_add' in doc), '场景22-用例1 gift_add不应该存进resident');

  // 用例2：同一次调用顺带改了昵称，礼金流水的nick应该用这次刚存的新昵称
  res = await saveProfile.main({ nick: '阿添改名', gift_add: 66 });
  check(res.ok === true, `场景22-用例2 改名同时添礼金：返回ok:true（实际 ${JSON.stringify(res)}）`);
  giftDocs = Array.from(state.collections.gift_coin.values());
  check(giftDocs.length === 2, `场景22-用例2 gift_coin集合应该再多一条，一共2条（实际 ${giftDocs.length} 条）`);
  const second = giftDocs.find(g => g.coins === 66);
  check(!!second && second.nick === '阿添改名', `场景22-用例2 这条记录的nick应该是这次改的新昵称（实际 ${second && second.nick}）`);

  // 用例3：gift_add 不合格（0，不在1~999999范围）→ 不记这一笔，其它字段（nick）照常存
  const before = giftDocs.length;
  res = await saveProfile.main({ nick: '阿添三改', gift_add: 0 });
  check(res.ok === true, `场景22-用例3 gift_add不合格：仍返回ok:true（实际 ${JSON.stringify(res)}）`);
  giftDocs = Array.from(state.collections.gift_coin.values());
  check(giftDocs.length === before, `场景22-用例3 gift_coin集合不应该增加（实际从 ${before} 变成 ${giftDocs.length}）`);
  doc = state.collections.resident.get(ME);
  check(doc.nick === '阿添三改', `场景22-用例3 nick字段照常存上（实际 ${doc.nick}）`);
}

// ================= 场景23：enterHall 返回 data.mine（蓝图 3.2 席间小游戏，阿鱼 9/19） =================
async function scenarioEnterHallMine() {
  const { sdk, state } = createFakeSdk();

  // 用例1：resident 已经存了这些字段，data.mine 应该原样带回去
  const ME1 = 'mine_guy_23a';
  seed(state, 'resident', {
    _id: ME1, openid: ME1, nick: '阿存档', avatar: 1, inviter: null,
    coins: 233, games: { t1_t2: 5, t3_t4: 2 }, dishes: [1, 3, 5], gift_coins: 188,
  });
  state.currentOpenid = ME1;
  let enterHall = loadCloudFunction('enterHall', sdk);
  let res = await enterHall.main();
  check(res.ok === true, `场景23-用例1 enterHall返回ok:true（实际 ${JSON.stringify(res).slice(0, 200)}）`);
  check(!!res.data && !!res.data.mine, '场景23-用例1 返回里应该有data.mine');
  check(res.data.mine.coins === 233, `场景23-用例1 mine.coins应该对得上（实际 ${res.data.mine.coins}）`);
  check(JSON.stringify(res.data.mine.games) === JSON.stringify({ t1_t2: 5, t3_t4: 2 }), `场景23-用例1 mine.games应该对得上（实际 ${JSON.stringify(res.data.mine.games)}）`);
  check(JSON.stringify(res.data.mine.dishes) === JSON.stringify([1, 3, 5]), `场景23-用例1 mine.dishes应该对得上（实际 ${JSON.stringify(res.data.mine.dishes)}）`);
  check(res.data.mine.gift_coins === 188, `场景23-用例1 mine.gift_coins应该对得上（实际 ${res.data.mine.gift_coins}）`);

  // 用例2：resident 存在，但没存过这些游戏字段（老住民），data.mine 应该是默认空值
  const ME2 = 'mine_guy_23b';
  seed(state, 'resident', { _id: ME2, openid: ME2, nick: '阿旧', avatar: 2, inviter: null });
  state.currentOpenid = ME2;
  enterHall = loadCloudFunction('enterHall', sdk);
  res = await enterHall.main();
  check(res.ok === true, `场景23-用例2 老住民enterHall返回ok:true（实际 ${JSON.stringify(res).slice(0, 200)}）`);
  check(JSON.stringify(res.data.mine) === JSON.stringify({ coins: 0, games: {}, dishes: [], gift_coins: 0 }), `场景23-用例2 没存过时mine应该是默认空值（实际 ${JSON.stringify(res.data.mine)}）`);
}

// ================= 场景24：games/dishes 存档是"跟旧值合并"，不是整体覆盖——只传一个游戏的新进度/一道新解锁的菜，不会把别的冲掉（蓝图 3.2 席间小游戏） =================
async function scenarioSaveProfileGameDishesMergeNotOverwrite() {
  const { sdk, state } = createFakeSdk();
  const ME = 'merge_guy_24';
  seed(state, 'resident', {
    _id: ME, openid: ME, nick: '阿合并', avatar: 1, inviter: null,
    games: { t1_t2: 2, t3_t4: 5 }, dishes: [1, 2, 3],
  });
  state.currentOpenid = ME;
  const saveProfile = loadCloudFunction('saveProfile', sdk);

  // 只传 t1_t2 一个游戏的新进度：t3_t4 应该照样保留
  let res = await saveProfile.main({ games: { t1_t2: 4 } });
  check(res.ok === true, `场景24-用例1 只传一个游戏的进度：返回ok:true（实际 ${JSON.stringify(res)}）`);
  let doc = state.collections.resident.get(ME);
  check(doc.games.t1_t2 === 4, `场景24-用例1 t1_t2应该更新成4（实际 ${doc.games.t1_t2}）`);
  check(doc.games.t3_t4 === 5, `场景24-用例1 t3_t4应该还是5，没被冲掉（实际 ${doc.games.t3_t4}）`);

  // 只传一道新解锁的菜（9）：之前的 1、2、3 应该照样保留
  res = await saveProfile.main({ dishes: [9] });
  check(res.ok === true, `场景24-用例2 只传一道新菜：返回ok:true（实际 ${JSON.stringify(res)}）`);
  doc = state.collections.resident.get(ME);
  check(JSON.stringify(doc.dishes) === JSON.stringify([1, 2, 3, 9]), `场景24-用例2 应该是旧的+新的合并、去重、排序（实际 ${JSON.stringify(doc.dishes)}）`);

  // 再传一道已经解锁过的菜（2）：应该还是去重，不会重复出现
  res = await saveProfile.main({ dishes: [2] });
  check(res.ok === true, `场景24-用例3 重复解锁同一道菜：返回ok:true（实际 ${JSON.stringify(res)}）`);
  doc = state.collections.resident.get(ME);
  check(JSON.stringify(doc.dishes) === JSON.stringify([1, 2, 3, 9]), `场景24-用例3 重复的菜不应该重复出现（实际 ${JSON.stringify(doc.dishes)}）`);
}

// ---------- 跑全部场景 ----------
(async () => {
  await scenarioSeatPagination();
  await scenarioReadBookLatest200();
  await scenarioReadBookNames();
  await scenarioEnterHallOfflineInviterNames();
  await scenarioSaveProfileInviter();
  await scenarioWriteBookCurrentTableOnly();
  await scenarioWriteBookSensitiveRejected();
  await scenarioSaveProfileWordRejected();
  await scenarioReservedNameExemptions();
  await scenarioHallPulseInvalidSince();
  await scenarioHallPulseGetsNewToast();
  await scenarioHallPulseNoDuplicateOnNextPoll();
  await scenarioHallPulseOnlyMine();
  await scenarioHallPulseCapAtTen();
  await scenarioHallPulseNoneNewSkipsResident();
  await scenarioHallPulseGhostSenderNameFallback();
  await scenarioHallPulseDbErrorReturnsNetwork();
  await scenarioPulseSeenNotRepeatedOnEnter();
  await scenarioPulseOverlapCatchesLateWrite();
  await scenarioSaveProfileGameFieldsNoNickCheck();
  await scenarioSaveProfileGameFieldsSanitize();
  await scenarioSaveProfileGiftAdd();
  await scenarioEnterHallMine();
  await scenarioSaveProfileGameDishesMergeNotOverwrite();

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
