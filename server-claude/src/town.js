'use strict';
const C = require('./config');
const T = require('./time');

// ============ 桥灯 ============

/** 捐了菜之后，桥灯进度 */
function lampProgress(totalDonated) {
  const lit = Math.min(C.LAMP_TOTAL, Math.floor(totalDonated / C.LAMP_COST));
  const intoCurrent = totalDonated - lit * C.LAMP_COST;
  return {
    lit,
    total: C.LAMP_TOTAL,
    allLit: lit >= C.LAMP_TOTAL,
    current: lit >= C.LAMP_TOTAL ? null : lit + 1,
    progress: lit >= C.LAMP_TOTAL ? null : `${intoCurrent}／${C.LAMP_COST}`,
  };
}

/** 每盏灯刻谁的名字：该盏灯期间捐得最多的前 5 */
function lampNames(donations) {
  // donations: [{who, count, at}]，按时间正序
  const lamps = [];
  let bucket = [];
  let acc = 0;
  for (const d of donations) {
    let remain = d.count;
    while (remain > 0 && lamps.length < C.LAMP_TOTAL) {
      const need = C.LAMP_COST - acc;
      const put = Math.min(need, remain);
      bucket.push({ who: d.who, count: put });
      acc += put; remain -= put;
      if (acc >= C.LAMP_COST) {
        lamps.push(topN(bucket));
        bucket = []; acc = 0;
      }
    }
  }
  return lamps;
}

function topN(bucket) {
  const sum = {};
  for (const b of bucket) sum[b.who] = (sum[b.who] || 0) + b.count;
  return Object.entries(sum)
    .sort((a, b) => b[1] - a[1])
    .slice(0, C.LAMP_NAME_TOP)
    .map(([who, count]) => ({ who, count }));
}

// ============ 踢球 ============

/** 每天给 4 个球随机位置。用日期做种子，同一天所有人看到的一样 */
function ballsOfDay(ts, spots, seedFn) {
  const date = T.localDate(ts);
  const out = [];
  const colors = ['red', 'yellow', 'blue', 'old'];
  for (let i = 0; i < C.BALL_COUNT; i++) {
    const r = seedFn(`${date}-ball-${i}`);
    out.push({ id: `${date}-${i}`, color: colors[i], spot: spots[Math.floor(r * spots.length) % spots.length] });
  }
  return out;
}

/** 能不能踢：一人一天在同一个球上只能踢一次 */
function canKick(who, ballId, todayKicks) {
  if (todayKicks.some(k => k.who === who && k.ballId === ballId)) {
    return { ok: false, reason: 'kicked_this_ball' };
  }
  return { ok: true };
}

/** 全镇当天累计够了没 */
function ballGoalReached(todayKickCount) {
  return todayKickCount >= C.BALL_GOAL;
}

// ============ 镇报 ============

/**
 * 每周一 0 点生成。五栏：手最长的、地最肥的、新来的、最安逸的屋、猫猫狗狗的一周
 * @param data {{
 *   steals:[{thief,owner,count,at}],
 *   sales:[{who,coin,at}],
 *   joins:[{who,parent,at}],
 *   houseRatings:[{house,owner,avg,count}],
 *   petEvents:[{pet,type,at}],
 *   lamps:{lit,total}
 * }}
 */
function weeklyPaper(data, weekStart, weekEnd, issue) {
  const inWeek = (at) => at >= weekStart && at < weekEnd;

  const stealBy = {}, stolenFrom = {};
  for (const s of data.steals.filter(x => inWeek(x.at))) {
    stealBy[s.thief] = (stealBy[s.thief] || 0) + s.count;
    stolenFrom[s.owner] = (stolenFrom[s.owner] || 0) + s.count;
  }
  const saleBy = {};
  for (const s of data.sales.filter(x => inWeek(x.at))) saleBy[s.who] = (saleBy[s.who] || 0) + s.coin;

  const joins = data.joins.filter(x => inWeek(x.at));
  const byBranch = {};
  for (const j of joins) byBranch[j.parent] = (byBranch[j.parent] || 0) + 1;

  const petCount = {};
  for (const p of data.petEvents.filter(x => inWeek(x.at))) {
    petCount[p.pet] = petCount[p.pet] || {};
    petCount[p.pet][p.type] = (petCount[p.pet][p.type] || 0) + 1;
  }

  const best = (obj) => {
    const e = Object.entries(obj).sort((a, b) => b[1] - a[1])[0];
    return e ? { who: e[0], n: e[1] } : null;
  };
  const bestHouse = [...data.houseRatings].filter(h => h.count > 0)
    .sort((a, b) => b.avg - a.avg)[0] || null;

  return {
    issue,
    weekStart, weekEnd,
    columns: {
      手最长的: { top: best(stealBy), victim: best(stolenFrom) },
      地最肥的: best(saleBy),
      新来的: { count: joins.length, byBranch },
      最安逸的屋: bestHouse,
      猫猫狗狗的一周: petCount,
    },
    lamps: data.lamps,
  };
}

module.exports = { lampProgress, lampNames, ballsOfDay, canKick, ballGoalReached, weeklyPaper };
