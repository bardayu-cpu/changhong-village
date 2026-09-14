'use strict';
const C = require('./config');
const T = require('./time');
const tree = require('./tree');

// ============ 外殿：牵红线 ============

/**
 * 能不能牵这条线
 * @param ctx {{ maker, a, b, weekThreadCount, friends:Set, blocked:Set, pastThreads:Array, now }}
 *   pastThreads: [{a,b,status}]  同一人对同一对牵过且没成，不能再牵
 */
function canMakeThread(ctx) {
  const { maker, a, b, weekThreadCount, friends, blocked, pastThreads, now } = ctx;
  if (a === b) return { ok: false, reason: 'same_person' };
  if (maker === a || maker === b) return { ok: false, reason: 'cannot_include_self' };
  if (weekThreadCount >= C.THREAD_WEEKLY_QUOTA) return { ok: false, reason: 'weekly_quota' };
  if (friends.has(tree.pairKey(a, b))) return { ok: false, reason: 'already_friend' };
  if (blocked.has(tree.pairKey(a, b))) return { ok: false, reason: 'blocked' };
  const failed = pastThreads.filter(t =>
    tree.pairKey(t.a, t.b) === tree.pairKey(a, b) && t.maker === maker && t.status === 'broken');
  if (failed.length >= 1) return { ok: false, reason: 'already_tried' };
  return { ok: true, expireAt: now + C.THREAD_EXPIRE_MS };
}

/** 红线结算：双方都接才成；任一方拒或超时即断 */
function threadResult(thread, now) {
  if (thread.aAccepted === false || thread.bAccepted === false) return 'broken';
  if (thread.aAccepted === true && thread.bAccepted === true) return 'connected';
  if (now >= thread.expireAt) return 'broken';
  return 'pending';
}

// ============ 内殿：许愿与求签 ============

/** 今天还能不能求签 */
function canDrawStick(lastDrawAt, now) {
  if (!lastDrawAt) return { ok: true };
  if (T.localDayStart(lastDrawAt) === T.localDayStart(now)) {
    return { ok: false, reason: 'drawn_today' };
  }
  return { ok: true };
}

/**
 * 求签：从候选池抽一支
 * @param ctx {{
 *   me, wishers:[openid],           已许愿的人
 *   parentOf, familyOf:{openid:[]}, blocked:Set,
 *   kept:[openid],                  已收下的
 *   returned:[{who,at}],            放回过的
 *   rand: number,                   0~1，由调用方生成
 *   now
 * }}
 */
function drawStick(ctx) {
  const { me, wishers, parentOf, familyOf, blocked, kept, returned, rand, now } = ctx;
  const returnedRecently = new Set(
    returned.filter(r => now - r.at < C.STICK_RETURN_COOLDOWN_MS).map(r => r.who)
  );
  const family = new Set(familyOf[me] || []);
  const keptSet = new Set(kept);

  const pool = wishers.filter(w => {
    if (w === me) return false;
    if (keptSet.has(w)) return false;
    if (returnedRecently.has(w)) return false;
    if (blocked.has(tree.pairKey(me, w))) return false;
    if (family.has(w)) return false;
    if (parentOf[me] === w || parentOf[w] === me) return false; // 同枝
    return true;
  });

  if (pool.length === 0) return { ok: false, reason: 'no_stick_today' };
  const idx = Math.floor(rand * pool.length) % pool.length;
  return { ok: true, who: pool[idx] };
}

/** 两人都收下对方，才算接上 */
function isConnected(aKept, bKept, a, b) {
  return aKept.includes(b) && bKept.includes(a);
}

/**
 * 接上后显示"去找谁"：
 * 优先给对方写过推荐的人，其次两人所在枝的共同上游
 */
function findIntroducer(a, b, recommendsOf, parentOf) {
  const recA = (recommendsOf[a] || []).map(r => r.by);
  const recB = (recommendsOf[b] || []).map(r => r.by);
  const both = recA.filter(x => recB.includes(x));
  if (both.length) return { who: both[0], via: 'recommended_both' };
  if (recB.length) return { who: recB[0], via: 'recommended_them' };
  if (recA.length) return { who: recA[0], via: 'recommended_you' };
  // 共同上游
  const chain = (x) => { const out = []; let c = parentOf[x]; while (c && !out.includes(c)) { out.push(c); c = parentOf[c]; } return out; };
  const ca = chain(a), cb = chain(b);
  const common = ca.find(x => cb.includes(x));
  if (common) return { who: common, via: 'common_branch' };
  return { who: null, via: 'none' };
}

/** 能不能给某人写推荐 */
function canRecommend(by, target, existing) {
  if (by === target) return { ok: false, reason: 'self' };
  if (existing.some(r => r.by === by)) return { ok: false, reason: 'already_wrote' };
  if (existing.length >= 5) return { ok: false, reason: 'full' };
  return { ok: true };
}

module.exports = { canMakeThread, threadResult, canDrawStick, drawStick, isConnected, findIntroducer, canRecommend };
