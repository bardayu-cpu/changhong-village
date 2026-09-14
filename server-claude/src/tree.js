'use strict';
const C = require('./config');
const T = require('./time');

/**
 * 邀请名额：初始 5，每住满一周加 1
 * @param joinedAt 进镇时间
 * @param usedCount 已用掉几个
 * @param activeWeeks 住满几周（由调用方按留存定义算好传入）
 */
function inviteQuota(usedCount, activeWeeks) {
  const total = C.INVITE_QUOTA_BASE + C.INVITE_QUOTA_PER_WEEK * Math.max(0, activeWeeks);
  return { total, used: usedCount, left: Math.max(0, total - usedCount) };
}

/**
 * 三层关系判定
 * @param a, b openid
 * @param parentOf  {openid -> 带他进来的人openid}
 * @param friends   Set of "x|y"（小的在前）
 */
function pairKey(a, b) { return a < b ? `${a}|${b}` : `${b}|${a}`; }

function relation(a, b, parentOf, friends) {
  if (a === b) return 'self';
  if (parentOf[a] === b || parentOf[b] === a) return 'same_branch';   // 同枝：自动好友
  if (friends.has(pairKey(a, b))) return 'friend';
  if (parentOf[a] && parentOf[a] === parentOf[b]) return 'sibling';   // 邻叶
  return 'none';
}

/** 两跳内可扩列：a 的好友的好友里有 b */
function canRequestFriend(a, b, parentOf, friends, friendsOf) {
  const rel = relation(a, b, parentOf, friends);
  if (rel === 'self') return { ok: false, reason: 'self' };
  if (rel === 'friend' || rel === 'same_branch') return { ok: false, reason: 'already_friend' };
  if (rel === 'sibling') return { ok: true, via: 'sibling' };
  for (const f of (friendsOf[a] || [])) {
    if ((friendsOf[f] || []).includes(b)) return { ok: true, via: 'friend_of_friend' };
  }
  return { ok: false, reason: 'too_far' };
}

/**
 * 可能认识的人：按信号排序取前 N
 * signals: { sibling:bool, mutualFriends:number, stoleFromMe:bool, sameWeek:bool }
 */
function rankSuggestions(candidates) {
  const score = (s) =>
    (s.sibling ? 1000 : 0) +
    (s.mutualFriends || 0) * 100 +
    (s.stoleFromMe ? 50 : 0) +
    (s.sameWeek ? 10 : 0);
  return candidates
    .map(c => ({ ...c, _score: score(c.signals) }))
    .filter(c => c._score > 0)
    .sort((x, y) => y._score - x._score)
    .slice(0, C.SUGGEST_LIMIT);
}

/** 把 parentOf 展开成一棵树，用于黄葛树渲染 */
function buildTree(members, parentOf) {
  const nodes = {};
  for (const m of members) nodes[m] = { id: m, children: [] };
  const roots = [];
  for (const m of members) {
    const p = parentOf[m];
    if (p && nodes[p]) nodes[p].children.push(nodes[m]);
    else roots.push(nodes[m]);
  }
  return roots;
}

module.exports = { inviteQuota, relation, canRequestFriend, rankSuggestions, buildTree, pairKey };
