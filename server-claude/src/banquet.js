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
 *   me?: string,            这次入座的人自己的 openid。只在新规矩下用：没有邀请人、自己又是阿鱼/Toretto，
 *                           按"自己这一枝"算，可以坐前两桌；旧规矩下不看
 *   benchOnlyWhenFull?: boolean,  长凳门槛，不传就用 config.BANQUET_BENCH_ONLY_WHEN_FULL（见下面两套规矩）
 *   tables: Array<{
 *     id: string,
 *     reserved: boolean,        是不是离主桌最近的两桌之一
 *     branch: string|null,      这桌是不是给谁的邀请开的溢出桌（第一个坐下那人的邀请人 openid）；
 *                               没人坐过，或第一个坐下的人自己没有邀请人，就是 null。
 *                               "邀请人那桌"不靠这个字段判——直接在 seats 里找邀请人本人；
 *                               这个字段只用来找"邀请人的桌满了之后开的下一桌"
 *     seats: string[],          已经坐下的人的 openid 列表
 *   }>,                     全厅各桌现状（几桌都行，12 桌、55 桌都是这个格式，调用方按 config.BANQUET_TABLE_IDS 拼），
 *                           数组顺序就是桌序（reserved 的两桌排最前）。主桌不放在这里面，见 mainTable
 *   mainTable?: {id:string, seats:string[]},  主桌现状，只有 55 桌厅才传（调用方用 mainTableIdOf 判），12 桌厅不传
 * }}
 * @returns {{ok:true, tableId?:string, bench:boolean}}
 *   bench:true 表示没有能坐的桌了，坐长凳（长凳不占 tables，调用方自己处理无限容量）。
 *   什么叫"没有能坐的桌"，两套规矩不一样，见下面
 *
 * 主桌（9/29，55 桌厅才有，规矩【待确认】）：阿鱼、Toretto 本人（me 在 vip 里）先坐主桌，不管有没有邀请人；
 * 主桌满了才按下面两套规矩走。别人一律不分到主桌——下面两套规矩只在 tables 里挑，主桌不在 tables 里。
 * 他们请来的人照旧坐前两桌：阿鱼本人坐了主桌，他那桌（主桌）不在 tables 里找不到，就走"阿鱼的枝坐前两桌"那一步。
 */
function assignSeat(ctx) {
  const main = ctx.mainTable;
  // 主桌能给真人坐的只有阿鱼、Toretto 那两把（BANQUET_MAIN_VIP_CHAIRS），其余是阿鱼家里人（NPC）
  if (main && ctx.me && ctx.vip && ctx.vip.has(ctx.me) && main.seats.length < C.BANQUET_MAIN_VIP_CHAIRS.length) {
    return { ok: true, tableId: main.id, bench: false };
  }
  const onlyWhenFull = ctx.benchOnlyWhenFull === undefined ? C.BANQUET_BENCH_ONLY_WHEN_FULL : !!ctx.benchOnlyWhenFull;
  return onlyWhenFull ? assignSeatFillFirst(ctx) : assignSeatOld(ctx);
}

/**
 * 这个厅有没有主桌：桌表跟 config.BANQUET_TABLE_IDS_55 桌号一样（55 桌厅）就回主桌 id，否则回 null（12 桌厅没有主桌）。
 * 按桌号比，不按是不是同一个数组比：上线时 config 里不管写成引用还是重新列一遍，都认得出来。
 */
function mainTableIdOf(tableIds) {
  const ids55 = C.BANQUET_TABLE_IDS_55;
  if (!Array.isArray(tableIds) || tableIds.length !== ids55.length) return null;
  return tableIds.every((id, i) => id === ids55[i]) ? C.BANQUET_MAIN_TABLE_ID : null;
}

/**
 * 旧规矩（BANQUET_BENCH_ONLY_WHEN_FULL 为 false，现在线上用的）：
 * 邀请人那桌 → 这一枝开过的桌 → 开一张完全没人坐的新桌 → 长凳。
 * 开不出新桌就去长凳，哪怕别的桌还有空椅子；没有邀请人的人按桌序坐第一张有空位的桌，前两桌也坐。
 * 这段保持跟线上一样，只修了一处：阿鱼/Toretto 的枝找前两桌时先看满没满（9/24，原来会分到 11 号椅）。
 */
function assignSeatOld(ctx) {
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
  // 前两桌也要看满没满（9/24 01 定修）：阿鱼本人没有邀请人、坐在 T1，T1 的 branch 标记是 null，
  // 原来只看「没被别的枝占」，T1 坐满了他请的人还会分进 T1、拿到第 11 号椅。满了就往后找
  if (vip && vip.has(inviter)) {
    const reserved = tables.find(t => t.reserved && t.branch == null && t.seats.length < CAP);
    if (reserved) return { ok: true, tableId: reserved.id, bench: false };
  }
  const empty = tables.find(t => !t.reserved && t.seats.length === 0);
  if (empty) return { ok: true, tableId: empty.id, bench: false };

  return { ok: true, bench: true };
}

/**
 * 新规矩（BANQUET_BENCH_ONLY_WHEN_FULL 为 true，55 桌上线时打开）：普通桌全坐满了才去长凳。
 * "普通桌"指前两桌以外的桌。前两桌只给阿鱼/Toretto 那一枝，别人不坐（没有邀请人的人例外，见下）。
 *
 * 有邀请人：
 *   1. 邀请人那桌还有空椅子，坐那桌
 *   2. 这一枝开过的桌还有空椅子，坐那桌
 *   3. 阿鱼/Toretto 的枝：前两桌里没被别的枝占（branch 为 null）、还有空椅子的，坐那桌
 *   4. 开一张完全没人坐的普通桌
 *   5. 开不出新桌：按桌序坐第一张还有空椅子的普通桌（跟别的枝拼桌）
 *   6. 阿鱼/Toretto 的枝：前两桌只要还有空椅子就坐
 *   7. 都没有，坐长凳。别的枝的人，普通桌全满了就去长凳，不进前两桌
 * 没有邀请人：
 *   - 自己是阿鱼/Toretto（ctx.me 在 vip 里）：先坐前两桌（同上第 3 步），没有再往下走
 *   - 按桌序坐第一张还有空椅子的普通桌
 *   - 普通桌全满了，才坐前两桌里还有空椅子的
 *   - 都满了，坐长凳
 */
function assignSeatFillFirst(ctx) {
  const { inviter, vip, tables, me } = ctx;
  const CAP = C.BANQUET_SEATS_PER_TABLE;
  const hasRoom = t => t.seats.length < CAP;
  const seat = t => ({ ok: true, tableId: t.id, bench: false });
  // 算不算阿鱼/Toretto 那一枝：有邀请人看邀请人，没有邀请人看自己
  const vipBranch = !!(vip && (inviter ? vip.has(inviter) : (me && vip.has(me))));

  if (inviter) {
    const inviterTable = tables.find(t => t.seats.includes(inviter));
    if (inviterTable && hasRoom(inviterTable)) return seat(inviterTable);
    const branchTable = tables.find(t => t.branch === inviter && hasRoom(t));
    if (branchTable) return seat(branchTable);
  }

  if (vipBranch) {
    const reserved = tables.find(t => t.reserved && t.branch == null && hasRoom(t));
    if (reserved) return seat(reserved);
  }

  if (inviter) {
    const empty = tables.find(t => !t.reserved && t.seats.length === 0);
    if (empty) return seat(empty);
  }

  // 没有邀请人的人从这里开始；有邀请人的走到这里说明开不出新桌了，插到有空椅子的普通桌
  const normal = tables.find(t => !t.reserved && hasRoom(t));
  if (normal) return seat(normal);

  // 普通桌全满了：前两桌只让阿鱼/Toretto 的枝和没有邀请人的人坐
  if (vipBranch || !inviter) {
    const reserved = tables.find(t => t.reserved && hasRoom(t));
    if (reserved) return seat(reserved);
  }

  return { ok: true, bench: true };
}

// ============ 换桌椅子号校验 ============

/**
 * 换桌要去的桌号、椅子号是不是厅里真有的（changeSeat 用）
 * @param ctx {{
 *   tableId: any, chairNo: any,
 *   tableIds?: string[],   厅里有哪些桌，不传就用 config.BANQUET_TABLE_IDS
 *   mainTableId?: string|null,  主桌 id，只有 55 桌厅才传（mainTableIdOf 算），12 桌厅不传：不传时主桌 id 跟 T99 一样不认
 *   isVip?: boolean,       换桌的人是不是阿鱼、Toretto 本人；只在换进主桌时看
 * }}
 * 桌号必须在桌表里（长凳不算，长凳不是换过去的地方）；椅子号必须是 1..BANQUET_SEATS_PER_TABLE 的整数。
 * 不对都回 bad_request（客户端已经认这个原因）。
 * 主桌（9/29，55 桌厅才有）：桌号、椅子号都对，但换的人不是阿鱼、Toretto 本人，回 main_table_only_family
 * （新原因，客户端要认：主桌只坐阿鱼、Toretto 本人）。
 * 主桌（阿鱼 9/29）：阿鱼、Toretto 本人只能换到 1、2 号（BANQUET_MAIN_VIP_CHAIRS），
 * 3～10 号坐着阿鱼家里人，回 seat_taken（「这把有人坐了」）。
 */
function checkSeatTarget(ctx) {
  const { tableId, chairNo } = ctx;
  const ids = ctx.tableIds || C.BANQUET_TABLE_IDS;
  const isMain = !!ctx.mainTableId && tableId === ctx.mainTableId;
  if (typeof tableId !== 'string' || !(isMain || ids.includes(tableId))) return { ok: false, reason: 'bad_request' };
  if (!Number.isInteger(chairNo) || chairNo < 1 || chairNo > C.BANQUET_SEATS_PER_TABLE) return { ok: false, reason: 'bad_request' };
  if (isMain && !ctx.isVip) return { ok: false, reason: 'main_table_only_family' };
  if (isMain && !C.BANQUET_MAIN_VIP_CHAIRS.includes(chairNo)) return { ok: false, reason: 'seat_taken' };
  return { ok: true };
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

module.exports = { assignSeat, mainTableIdOf, checkSeatTarget, canChangeSeat, canToast, canWantToMeet, canWriteBook, arrivalDigest, arrivalCard };
