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

module.exports = { canSaveProfile, clampGiftValue, canAdoptInviter };
