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
 *     branch: string|null,      这桌现在服务谁的邀请（第一个坐下那人的邀请人 openid），没人坐过是 null
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

  // 邀请人这枝已经开的桌里，找一桌还有位置的（邀请人那桌，满了就是同枝的下一桌）
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
 *   todayChanges: number,    这次来访（今天）已经换过几次，调用方按北京时间今天算好传入
 * }}
 */
function canChangeSeat(ctx) {
  const { occupant, todayChanges } = ctx;
  if (todayChanges >= C.BANQUET_CHANGE_PER_VISIT) return { ok: false, reason: 'changed_today' };
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
 * }}
 */
function canToast(ctx) {
  const { from, to, todayToastCount, todayToastToCount } = ctx;
  if (from === to) return { ok: false, reason: 'toast_self' };
  if (todayToastCount >= C.BANQUET_TOAST_DAILY) return { ok: false, reason: 'toast_limit' };
  if (todayToastToCount >= C.BANQUET_TOAST_PER_PERSON_DAILY) return { ok: false, reason: 'toast_same_person' };
  return { ok: true };
}

// ============ 桌簿 ============

/**
 * 能不能在这桌写一句
 * @param ctx {{
 *   table: string,          要写的桌 id
 *   satTables: string[],    我坐过的桌 id 列表
 *   text: string,
 * }}
 * 敏感词校验走敏感词模块（`docs/敏感词模块-需求.md`，还没做），这里不判；由云函数在敏感词模块接好后另外拦
 */
function canWriteBook(ctx) {
  const { table, satTables, text } = ctx;
  if (!satTables || !satTables.includes(table)) return { ok: false, reason: 'not_sat_here' };
  if (!text || text.length > C.BANQUET_BOOK_MAX_LEN) return { ok: false, reason: 'book_too_long' };
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

module.exports = { assignSeat, canChangeSeat, canToast, canWriteBook, arrivalDigest };
