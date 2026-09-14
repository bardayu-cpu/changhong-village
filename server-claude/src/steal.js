'use strict';
const C = require('./config');
const T = require('./time');
const farm = require('./farm');

/**
 * 能不能偷这一格
 * @param ctx {{
 *   thief: string,                 偷的人 openid
 *   owner: string,                 地主人 openid
 *   plot: object|null,             那一格
 *   todayStealCount: number,       偷的人今天总共偷了几格
 *   todayStealOnOwner: number,     今天偷这一家几格
 *   guardUntil: number|null,       主人借的喜多看到什么时候
 *   guardRoll: number,             0~1 随机数，由调用方生成（便于测试）
 *   now: number
 * }}
 * @returns {{ok:boolean, reason?:string, yield?:number}}
 */
function canSteal(ctx) {
  const { thief, owner, plot, todayStealCount, todayStealOnOwner, guardUntil, guardRoll, now } = ctx;

  if (thief === owner) return { ok: false, reason: 'own_plot' };

  const st = farm.plotState(plot, now);
  if (st.state !== 'ripe') return { ok: false, reason: 'not_ripe' };

  // 一格只能被偷一次
  if ((plot.stolenCount || 0) >= 1) return { ok: false, reason: 'already_stolen' };

  if (todayStealCount >= C.STEAL_DAILY_LIMIT) return { ok: false, reason: 'daily_limit' };
  if (todayStealOnOwner >= C.STEAL_PER_HOUSE_LIMIT) return { ok: false, reason: 'house_limit' };

  // 喜多看家
  if (guardUntil && now < guardUntil && guardRoll < C.GUARD_BLOCK_RATE) {
    return { ok: false, reason: 'guarded' };
  }

  return { ok: true, yield: farm.stealYield() };
}

/** 能不能借喜多看家 */
function canBorrowGuard(todayBorrowCount) {
  if (todayBorrowCount >= C.GUARD_DAILY_BORROW) return { ok: false, reason: 'borrowed_today' };
  return { ok: true, durationMs: C.GUARD_DURATION_MS };
}

module.exports = { canSteal, canBorrowGuard };
