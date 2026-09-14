'use strict';
const C = require('./config');
const T = require('./time');

/**
 * 一格地的状态
 * plot: { crop, plantedAt, stolenCount } | null
 * 返回 { state, crop, remainMs, ripeAt, rotAt }
 *   state: 'empty' | 'growing' | 'ripe' | 'rotten'
 */
function plotState(plot, now) {
  if (!plot || !plot.crop) return { state: 'empty', crop: null, remainMs: 0, ripeAt: null, rotAt: null };
  const cfg = C.CROPS[plot.crop];
  if (!cfg) throw new Error(`未知作物: ${plot.crop}`);
  const ripeAt = plot.plantedAt + cfg.growMs;
  const rotAt = ripeAt + C.ROT_AFTER_MS;
  if (now < ripeAt) return { state: 'growing', crop: plot.crop, remainMs: ripeAt - now, ripeAt, rotAt };
  if (now < rotAt)  return { state: 'ripe',    crop: plot.crop, remainMs: rotAt - now,  ripeAt, rotAt };
  return { state: 'rotten', crop: plot.crop, remainMs: 0, ripeAt, rotAt };
}

/** 能不能种：格子空的且种子够 */
function canPlant(plot, crop, seedBag, now) {
  if (!C.CROPS[crop]) return { ok: false, reason: 'unknown_crop' };
  if (plotState(plot, now).state !== 'empty') return { ok: false, reason: 'plot_occupied' };
  if ((seedBag[crop] || 0) < 1) return { ok: false, reason: 'no_seed' };
  return { ok: true };
}

/** 主人收获这一格拿几棵：被偷 n 次就少 n*30%，向下取整，不为负 */
function harvestYield(plot, now) {
  if (plotState(plot, now).state !== 'ripe') return 0;
  const stolen = plot.stolenCount || 0;
  const left = C.YIELD_PER_PLOT * (1 - C.STEAL_RATIO * stolen);
  return Math.max(0, Math.floor(left));
}

/** 偷一格拿几棵 */
function stealYield() {
  return Math.floor(C.YIELD_PER_PLOT * C.STEAL_RATIO);
}

/** 卖价：market 为 'local' | 'tourist' */
function sellPrice(crop, count, market, now) {
  const cfg = C.CROPS[crop];
  if (!cfg) throw new Error(`未知作物: ${crop}`);
  if (market === 'local' && !T.isMarketDay(now)) return { ok: false, reason: 'local_market_closed' };
  const mult = market === 'tourist' ? C.TOURIST_BUY_MULT : 1;
  return { ok: true, coin: Math.floor(cfg.basePrice * count * mult) };
}

/** 种子价 */
function seedPrice(crop, count, market, now) {
  const cfg = C.CROPS[crop];
  if (!cfg) throw new Error(`未知作物: ${crop}`);
  if (market === 'local' && !T.isMarketDay(now)) return { ok: false, reason: 'local_market_closed' };
  const mult = market === 'tourist' ? C.TOURIST_SEED_MULT : 1;
  return { ok: true, coin: Math.ceil(cfg.seedPrice * count * mult) };
}

module.exports = { plotState, canPlant, harvestYield, stealYield, sellPrice, seedPrice };
