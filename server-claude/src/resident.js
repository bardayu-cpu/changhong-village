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

module.exports = { canSaveProfile, clampGiftValue };
