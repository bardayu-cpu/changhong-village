'use strict';
const C = require('./config');

/**
 * 宴会厅：一场不散的席（蓝图 3.2）
 * 全部异步：入座、换桌、敬酒、桌簿都不要求双方同时在线。
 * 跟其它规则文件一样：同步纯函数，不做 I/O；随机数、"今天"的聚合都由调用方算好传入。
 */

// ============ 入座 ============

/**
 * 第一次进厅自动分座
 * @param ctx {{
 *   inviter: string|null,   邀请人 openid；没有邀请人（阿鱼后台直接加的），或邀请人所在枝被封，调用方传 null
 *   vip: Set<string>,       阿鱼、Toretto 的 openid
 *   tables: Array<{
 *     id: string,
 *     reserved: boolean,        是不是离主桌最近的两桌之一
 *     branch: string|null,      这桌是不是给谁的邀请开的溢出桌（第一个坐下那人的邀请人 openid）；
 *                               没人坐过，或第一个坐下的人自己没有邀请人，就是 null。
 *                               "邀请人那桌"不靠这个字段判——直接在 seats 里找邀请人本人；
 *                               这个字段只用来找"邀请人的桌满了之后开的下一桌"
 *     seats: string[],          已经坐下的人的 openid 列表
 *   }>,                     12 桌现状，数组顺序就是桌序（reserved 的两桌排最前）
 * }}
 * @returns {{ok:true, tableId?:string, bench:boolean}}
 *   bench:true 表示 120 个座位坐满了，坐长凳（长凳不占 tables，调用方自己处理无限容量）
 */
function assignSeat(ctx) {
  const { inviter, vip, tables } = ctx;
  const CAP = C.BANQUET_SEATS_PER_TABLE;

  // 没有邀请人（含邀请人的枝被封，调用方已按此处理）：任意空桌
  if (!inviter) {
    const t = tables.find(t => t.seats.length < CAP);
    return t ? { ok: true, tableId: t.id, bench: false } : { ok: true, bench: true };
  }

  // 邀请人那桌：直接找邀请人自己坐在哪桌，不靠 branch 标记
  // （邀请人自己可能是没有邀请人、任意空桌坐下的，这种桌不会打 branch 标记，必须直接找人）
  const inviterTable = tables.find(t => t.seats.includes(inviter));
  if (inviterTable && inviterTable.seats.length < CAP) {
    return { ok: true, tableId: inviterTable.id, bench: false };
  }

  // 邀请人那桌满了，或邀请人还没坐过：找这一枝已经开过的溢出桌（branch 标记 = 邀请人 openid）
  const branchTables = tables.filter(t => t.branch === inviter);
  const withRoom = branchTables.find(t => t.seats.length < CAP);
  if (withRoom) return { ok: true, tableId: withRoom.id, bench: false };

  // 这枝还没有桌（邀请人自己也没坐过），或已开的桌都满了：开一桌
  if (vip && vip.has(inviter)) {
    const reserved = tables.find(t => t.reserved && t.branch == null);
    if (reserved) return { ok: true, tableId: reserved.id, bench: false };
  }
  const empty = tables.find(t => !t.reserved && t.seats.length === 0);
  if (empty) return { ok: true, tableId: empty.id, bench: false };

  return { ok: true, bench: true };
}

// ============ 换桌 ============

/**
 * 能不能换到这把椅子
 * @param ctx {{
 *   occupant: string|null,   目标椅子现在坐的人，没人是 null
 * }}
 * 蓝图 3.2 9/18 改：换桌不限次数，去掉「今天只能换一次」这条判定
 * （`todayChanges`/`BANQUET_CHANGE_PER_VISIT` 已不用，调用方不用再算「今天换过几次」）
 */
function canChangeSeat(ctx) {
  const { occupant } = ctx;
  if (occupant) return { ok: false, reason: 'seat_taken' };
  return { ok: true };
}

// ============ 敬酒 ============

/**
 * 能不能敬这一杯
 * @param ctx {{
 *   from: string, to: string,
 *   todayToastCount: number,    from 今天一共敬了几杯，调用方按今天算好传入
 *   todayToastToCount: number,  from 今天敬给 to 几杯
 *   testMode?: boolean,         测试期开关（config.BANQUET_TEST_MODE）：true 时不限每天杯数、不限对同一人，默认 false
 * }}
 */
function canToast(ctx) {
  const { from, to, todayToastCount, todayToastToCount, testMode } = ctx;
  if (from === to) return { ok: false, reason: 'toast_self' };
  if (!testMode && todayToastCount >= C.BANQUET_TOAST_DAILY) return { ok: false, reason: 'toast_limit' };
  if (!testMode && todayToastToCount >= C.BANQUET_TOAST_PER_PERSON_DAILY) return { ok: false, reason: 'toast_same_person' };
  return { ok: true };
}

// ============ 想认识你 ============

/**
 * 能不能对这个人说「想认识你」（蓝图 3.2 加好友：同桌、敬过酒的人可以发）
 * 9/19 总策划定：「同桌」指现在同一桌，两人此刻都坐在这桌，坐过不算（跟桌簿只认现在坐的桌同一个理）。
 * 阶段 1 只记请求（friend_request 表），对方看不到；好友关系本身在阶段 2。
 * @param ctx {{
 *   from: string, to: string,
 *   alreadySent: boolean,       from 以前对 to 说过。同一对只记一次；反过来 to 对 from 说是另一条，不拦
 *   fromTableId: string|null,   from 现在坐的桌（seat 表的 table_id），没座位是 null
 *   toTableId: string|null,     to 现在坐的桌，没座位是 null
 *   toasted: boolean,           两人之间有敬酒记录：谁敬谁都算，哪天敬的都算
 * }}
 * 长凳（config.BANQUET_BENCH_ID）不算一桌：长凳人数不限，算的话坐长凳的人互相都能发，
 * 「现在同一桌」就拦不住乱发了。坐长凳的人敬过酒照样能发
 * @returns {{ok:true, via:'table'|'toast'} | {ok:false, reason:string}}
 */
function canWantToMeet(ctx) {
  const { from, to, alreadySent, fromTableId, toTableId, toasted } = ctx;
  if (from === to) return { ok: false, reason: 'meet_self' };
  if (alreadySent) return { ok: false, reason: 'meet_already' };
  if (fromTableId && fromTableId === toTableId && fromTableId !== C.BANQUET_BENCH_ID) return { ok: true, via: 'table' };
  if (toasted) return { ok: true, via: 'toast' };
  return { ok: false, reason: 'meet_not_met' };
}

// ============ 桌簿 ============

/**
 * 能不能在这桌写一句
 * @param ctx {{
 *   table: string,           要写的桌 id
 *   mySeatTableId: string,   我现在坐的桌 id（seat 表的 table_id）；坐长凳是 config.BANQUET_BENCH_ID，
 *                            跟任何桌 id 都对不上，写哪桌都会落到 not_sat_here
 *   text: string,
 * }}
 * 蓝图 3.2 9/18 改：人坐在哪桌就只能写哪桌，别的桌能看不能写；不再是「坐过的桌都能写」（sat_tables）
 * 敏感词校验走敏感词模块（`docs/敏感词模块-需求.md`，还没做），这里不判；由云函数在敏感词模块接好后另外拦
 */
function canWriteBook(ctx) {
  const { table, mySeatTableId, text } = ctx;
  if (mySeatTableId !== table) return { ok: false, reason: 'not_sat_here' };
  if (!text) return { ok: false, reason: 'bad_request' };
  if (text.length > C.BANQUET_BOOK_MAX_LEN) return { ok: false, reason: 'book_too_long' };
  return { ok: true };
}

// ============ 进厅提示 ============

/**
 * 进厅时合并显示上次走后到现在的新动静
 * @param ctx {{
 *   toasts: Array<{from:string, at:number}>,        我收到的敬酒
 *   bookLines: Array<{tableId:string, at:number}>,  我坐过的桌新增的句子
 *   since: number,   上次离开（或上次进厅）的时间
 * }}
 * @returns {{toasts:Array<{from,at}>, toastCount:number, bookLineCount:number, hasNews:boolean}}
 */
function arrivalDigest(ctx) {
  const { toasts, bookLines, since } = ctx;
  const newToasts = (toasts || []).filter(t => t.at > since);
  const newBookLines = (bookLines || []).filter(l => l.at > since);
  return {
    toasts: newToasts,
    toastCount: newToasts.length,
    bookLineCount: newBookLines.length,
    hasNews: newToasts.length > 0 || newBookLines.length > 0,
  };
}

/**
 * 进厅那张小卡（01 9/23 派活「进厅先见人」，体验评审 0923 改法一）：最多 C.BANQUET_ARRIVAL_ROWS 行，**每行一个人一件事**。
 * 排前面的：敬了你的 → 在你这桌簿子上接了话的 → 你走后来过的；同一类里新的在前；
 * 同一个人只出现一次，放在他排最前的那一类（敬了你又写了簿子的，只说敬酒那一件）。
 * 人数超过行数：前 N-1 行照排，最后一行合成「还有 M 位来过」（kind:'more'，count 是没列出来的人数）。
 * 没有新鲜事 hasNews:false，客户端就不弹卡（别写「没人来过」这种冷清话）。
 * @param ctx {{
 *   me: string,
 *   since: number,                                         上次离开（或上次进厅）的时间
 *   toasts: Array<{from:string, at:number}>,              我收到的敬酒（调用方已按 toast_seen_at 筛过）
 *   bookLines: Array<{from:string, at:number}>,           我现在坐的这桌簿子上新写的句子
 *   visitors: Array<{openid:string, at:number}>,          我走后来过厅里的人（at 是他最近一次进厅的时间）
 * }}
 * @returns {{rows:Array<{kind:'toast'|'book'|'visit'|'more', who?:string, at?:number, count:number}>, hasNews:boolean}}
 *   toast/book 的 count 是这个人敬了几杯、写了几句；visit 的 count 恒为 1；more 的 count 是还有几位
 */
function arrivalCard(ctx) {
  const { me, since } = ctx;
  const ROWS = C.BANQUET_ARRIVAL_ROWS;
  const seen = new Set([me]);
  const items = [];
  function collect(kind, list, whoKey) {
    const byWho = new Map();
    for (const x of list || []) {
      const who = x[whoKey];
      if (!who || !(x.at > since)) continue;
      const cur = byWho.get(who);
      if (cur) { cur.count++; cur.at = Math.max(cur.at, x.at); } else byWho.set(who, { kind, who, at: x.at, count: 1 });
    }
    const group = Array.from(byWho.values()).filter(it => !seen.has(it.who));
    group.sort((a, b) => b.at - a.at);
    for (const it of group) { seen.add(it.who); items.push(it); }
  }
  collect('toast', ctx.toasts, 'from');
  collect('book', ctx.bookLines, 'from');
  collect('visit', ctx.visitors, 'openid');
  for (const it of items) if (it.kind === 'visit') it.count = 1;
  if (items.length <= ROWS) return { rows: items, hasNews: items.length > 0 };
  const rows = items.slice(0, ROWS - 1);
  rows.push({ kind: 'more', count: items.length - (ROWS - 1) });
  return { rows, hasNews: true };
}

module.exports = { assignSeat, canChangeSeat, canToast, canWantToMeet, canWriteBook, arrivalDigest, arrivalCard };
