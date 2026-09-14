'use strict';
const C = require('./config');

/** 北京时间的 YYYY-MM-DD */
function localDate(ts) {
  return new Date(ts + C.TZ_OFFSET).toISOString().slice(0, 10);
}

/** 北京时间当天 0 点的 UTC 时间戳 */
function localDayStart(ts) {
  return Math.floor((ts + C.TZ_OFFSET) / C.DAY) * C.DAY - C.TZ_OFFSET;
}

/** 逢单日赶场：按北京时间的"日"是不是单数 */
function isMarketDay(ts) {
  return Number(localDate(ts).slice(8, 10)) % 2 === 1;
}

/** 夏季（6~8 月）桥面涨水 */
function isFloodSeason(ts) {
  const m = Number(localDate(ts).slice(5, 7));
  return m >= 6 && m <= 8;
}

/** 早市 6:00~10:00 */
function isMorningMarket(ts) {
  const h = new Date(ts + C.TZ_OFFSET).getUTCHours();
  return h >= 6 && h < 10;
}

/** 夜游 19:30~20:30 */
function isNightTour(ts) {
  const d = new Date(ts + C.TZ_OFFSET);
  const mins = d.getUTCHours() * 60 + d.getUTCMinutes();
  return mins >= 19 * 60 + 30 && mins < 20 * 60 + 30;
}

/** 本周一 0 点（北京时间）。周一算一周的开始 */
function localWeekStart(ts) {
  const dayStart = localDayStart(ts);
  const dow = new Date(dayStart + C.TZ_OFFSET).getUTCDay(); // 0=周日
  const back = (dow + 6) % 7;
  return dayStart - back * C.DAY;
}

module.exports = { localDate, localDayStart, isMarketDay, isFloodSeason, isMorningMarket, isNightTour, localWeekStart };
