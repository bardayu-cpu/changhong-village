'use strict';
const C = require('./config');

/**
 * 存资料前的最小校验（总策划 9/16 定，回执 02-总策划答复-2 第 4 条）：
 * 只查昵称长度、悄悄话长度。完整的字符集、敏感词校验见 `docs/敏感词模块-需求.md`，还没做，
 * 那个模块做出来之前先用这个最小版顶着。
 * 礼金不在这判——礼金是夹到范围，不是拒绝，见 clampGiftValue。
 * @param ctx {{ nick?: string, whisper?: string }}  只传要校验的字段，没传的不查
 * @returns {{ok:true}|{ok:false, reason:string, field:string}}
 */
function canSaveProfile(ctx) {
  const { nick, whisper } = ctx;
  if (nick !== undefined) {
    const len = nick.trim().length;
    if (len < C.LEN.nickname[0]) return { ok: false, reason: 'nick_too_short', field: 'nick' };
    if (len > C.LEN.nickname[1]) return { ok: false, reason: 'book_too_long', field: 'nick' };
  }
  if (whisper !== undefined && whisper.length > C.LEN.whisper[1]) {
    return { ok: false, reason: 'book_too_long', field: 'whisper' };
  }
  return { ok: true };
}

/** 礼金夹到 0～9999 的非负整数，不拒绝，直接改成合法值（蓝图 3.1："超上限按上限"） */
function clampGiftValue(v) {
  const n = Math.floor(Number(v) || 0);
  return Math.max(0, Math.min(9999, n));
}

/**
 * 邀请人只存第一次（阶段 1 设计：用谁的链接进来，就长在谁的枝上）。
 * 三条同时满足才能记：自己还没有邀请人、邀请人不是自己、邀请人在 resident 表里存在。
 * 不满足不是"拒绝存资料"——调用方（saveProfile）应该只丢掉 inviter 这一个字段，
 * 其它字段照常存、照常返回 {ok:true}，不能因为邀请人不对让整次保存失败。
 * @param ctx {{
 *   existingInviter: string|null,  这个人 resident 记录里已经存的 inviter，没有记录/没存过都算 null
 *   selfOpenid: string,            自己的 openid
 *   inviter: string,               这次传来的邀请人 openid
 *   inviterExists: boolean,        这个 inviter 在 resident 表里存不存在，由调用方查好传入（不做 I/O）
 * }}
 * @returns {boolean} 能不能记
 */
function canAdoptInviter(ctx) {
  const { existingInviter, selfOpenid, inviter, inviterExists } = ctx;
  if (!inviter) return false;             // 没传等于没有候选人
  if (existingInviter) return false;      // 已经有邀请人了，只认第一次
  if (inviter === selfOpenid) return false; // 不能是自己
  if (!inviterExists) return false;       // 邀请人得真的存在
  return true;
}

// ---------- 席间小游戏存档（蓝图 3.2「席间小游戏」，阿鱼 9/19 定）----------
// 金币、通关进度、解锁的菜、礼金簿记都走住民资料加字段。全部纯客户端玩法，这里只做类型和
// 范围的兜底，不判定"打得对不对"：格式不合格的，要么夹进范围，要么整个丢掉这个字段/这一项，
// 不能让一次上报格式不对就让整条 resident 记录存失败（跟 inviter 的"只丢一个字段"是同一个原则）。

/**
 * coins（金币）、gift_coins（累计添进礼金的金币总数）公用的校验：0～999999 的非负整数。
 * 不是数字（字符串、布尔、对象、NaN、Infinity……）就整个丢掉这个字段——调用方应该
 * delete 这个 key，不写库、也不覆盖已经存的旧值（跟 clampGiftValue 不同，那个不管传什么
 * 都会硬转成数字存；这两个字段格式不对就宁可不存，不瞎存）。
 * @param v {*}
 * @returns {number|undefined} undefined 表示这个字段不合格，整个丢掉
 */
function sanitizeCoins(v) {
  if (typeof v !== 'number' || !isFinite(v)) return undefined;
  return Math.max(0, Math.min(999999, Math.floor(v)));
}

const GAME_ID_RE = /^[A-Za-z0-9_]{1,20}$/;
const GAMES_MAX_KEYS = 12;

/**
 * games：{ 游戏id: 已通关的最高关数 }。最多收 12 个键；键要是 1～20 个字母、数字、下划线，
 * 值夹到 0～999 的整数。键格式不对、值不是数字，这一个键整个丢掉，其它合格的键照留。
 * 传的不是对象（数组、null、字符串……）就整个字段丢掉。
 * @param v {*}
 * @returns {Object<string,number>|undefined}
 */
function sanitizeGames(v) {
  if (typeof v !== 'object' || v === null || Array.isArray(v)) return undefined;
  const out = {};
  let count = 0;
  for (const key of Object.keys(v)) {
    if (count >= GAMES_MAX_KEYS) break; // 只收前 12 个合格的键，多的丢
    if (!GAME_ID_RE.test(key)) continue; // 键格式不对：丢这一个键
    const val = v[key];
    if (typeof val !== 'number' || !isFinite(val)) continue; // 值不是数字：丢这一个键
    out[key] = Math.max(0, Math.min(999, Math.floor(val)));
    count++;
  }
  return out;
}

/**
 * dishes：吃席（连连看）解锁的菜序号数组，整数 0～99，去重，最多 100 个。
 * 元素不是 0～99 的整数就丢这一项（不夹进范围，直接丢）；传的不是数组就整个字段丢掉。
 * @param v {*}
 * @returns {number[]|undefined}
 */
function sanitizeDishes(v) {
  if (!Array.isArray(v)) return undefined;
  const seen = new Set();
  const out = [];
  for (const item of v) {
    if (typeof item !== 'number' || !Number.isInteger(item)) continue;
    if (item < 0 || item > 99) continue;
    if (seen.has(item)) continue;
    seen.add(item);
    out.push(item);
    if (out.length >= 100) break; // 去重后按 0～99 的范围本来就不会超，这里只是再兜一道底
  }
  return out;
}

/**
 * games 存档合并：per 游戏 id 覆盖，没提到的游戏 id 保留旧值——不能因为这次只传了一个游戏的
 * 进度，就把其它游戏已经存的进度冲掉。（微信云开发 update() 对 object 类型字段本来就是逐 key
 * 合并，这里在服务端自己也做一遍：图的是不依赖数据库那边的合并行为，改天 update() 的语义变了
 * 也不怕，而且这样"存起来是安全的"这件事本身可以在 test/rules.test.js 里直接测。）
 * @param existing {Object<string,number>} 已经存的旧值，调用方保证是对象（没有就传 {}）
 * @param incoming {Object<string,number>} 这次的新值，已经过 sanitizeGames
 * @returns {Object<string,number>}
 */
function mergeGames(existing, incoming) {
  return Object.assign({}, existing, incoming);
}

/**
 * dishes 存档合并：新解锁的菜跟已经存的旧列表取并集、去重、按数字排序，仍然最多 100 个。
 * 不能因为这次只传了新解锁的那一个，就把以前解锁的都冲掉——微信云开发的 update() 对数组类型
 * 字段是整体覆盖（不像 object 字段那样逐 key 合并），这一步服务端必须自己做，不能指望数据库
 * 那边帮忙合并。
 * @param existing {number[]} 已经存的旧列表，调用方保证元素合法（没有就传 []）
 * @param incoming {number[]} 这次的新值，已经过 sanitizeDishes
 * @returns {number[]}
 */
function mergeDishes(existing, incoming) {
  const set = new Set(existing);
  for (const n of incoming) set.add(n);
  return Array.from(set).sort((a, b) => a - b).slice(0, 100);
}

/**
 * gift_add：这一次要添进礼金簿的金币数，整数 1～999999。不是数字、非正数、超上限都算不合格，
 * 返回 null 表示"不合格，不记这一笔"——这个字段本来就不写进 resident，调用方判定合不合法
 * 只是为了决定记不记 gift_coin 集合里的这一条礼金流水，不合格时其它字段照常存。
 * @param v {*}
 * @returns {number|null}
 */
function sanitizeGiftAdd(v) {
  if (typeof v !== 'number' || !isFinite(v)) return null;
  const n = Math.floor(v);
  if (n < 1 || n > 999999) return null;
  return n;
}

module.exports = {
  canSaveProfile, clampGiftValue, canAdoptInviter,
  sanitizeCoins, sanitizeGames, sanitizeDishes, sanitizeGiftAdd,
  mergeGames, mergeDishes,
};
