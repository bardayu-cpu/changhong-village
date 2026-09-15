'use strict';
/** 无依赖的极简测试。运行： node test/rules.test.js */
const C = require('../src/config');
const T = require('../src/time');
const farm = require('../src/farm');
const steal = require('../src/steal');
const tree = require('../src/tree');
const temple = require('../src/temple');
const town = require('../src/town');
const banquet = require('../src/banquet');

let pass = 0, fail = 0;
const failures = [];
function eq(actual, expected, name) {
  const a = JSON.stringify(actual), b = JSON.stringify(expected);
  if (a === b) { pass++; } else { fail++; failures.push(`${name}\n    实际 ${a}\n    期望 ${b}`); }
}
function ok(cond, name) { eq(!!cond, true, name); }

// 用固定时间，避免测试随日期漂移
const D = (s) => Date.parse(s + '+08:00');
const T5 = D('2026-09-15T12:00:00');   // 15 号，单数 → 赶场日
const T6 = D('2026-09-16T12:00:00');   // 16 号，双数

// ---------- 时间 ----------
eq(T.localDate(T5), '2026-09-15', '本地日期');
ok(T.isMarketDay(T5), '15号赶场');
ok(!T.isMarketDay(T6), '16号不赶场');
ok(T.isFloodSeason(D('2026-07-01T00:00:00')), '7月涨水');
ok(!T.isFloodSeason(T5), '9月不涨水');
ok(T.isMorningMarket(D('2026-09-15T07:00:00')), '早市开');
ok(!T.isMorningMarket(T5), '中午早市关');
ok(T.isNightTour(D('2026-09-15T20:00:00')), '夜游中');
eq(T.localDate(T.localWeekStart(T5)), '2026-09-14', '周一是14号');

// ---------- 作物 ----------
eq(farm.plotState(null, T5).state, 'empty', '空地');
eq(farm.plotState({crop:'loubo',plantedAt:T5-1*C.HOUR}, T5).state, 'growing', '楼卜1小时=生长');
eq(farm.plotState({crop:'loubo',plantedAt:T5-4*C.HOUR}, T5).state, 'ripe', '楼卜4小时=熟');
eq(farm.plotState({crop:'loubo',plantedAt:T5-27*C.HOUR}, T5).state, 'ripe', '熟后23小时还没烂');
eq(farm.plotState({crop:'loubo',plantedAt:T5-28*C.HOUR}, T5).state, 'rotten', '熟后满24小时就烂');
eq(farm.plotState({crop:'loubo',plantedAt:T5-29*C.HOUR}, T5).state, 'rotten', '熟后超24小时=烂');
eq(farm.plotState({crop:'guzi',plantedAt:T5-3*C.DAY}, T5).state, 'ripe', '谷子3天=熟');
eq(farm.harvestYield({crop:'loubo',plantedAt:T5-5*C.HOUR,stolenCount:0}, T5), 10, '没被偷收10棵');
eq(farm.harvestYield({crop:'loubo',plantedAt:T5-5*C.HOUR,stolenCount:1}, T5), 7, '被偷1次收7棵');
eq(farm.harvestYield({crop:'loubo',plantedAt:T5-1*C.HOUR}, T5), 0, '没熟收0');
eq(farm.harvestYield({crop:'loubo',plantedAt:T5-40*C.HOUR}, T5), 0, '烂了收0');
eq(farm.stealYield(), 3, '偷一格3棵');

eq(farm.canPlant(null,'loubo',{loubo:1},T5).ok, true, '有种子能种');
eq(farm.canPlant(null,'loubo',{loubo:0},T5).reason, 'no_seed', '没种子');
eq(farm.canPlant({crop:'loubo',plantedAt:T5},'loubo',{loubo:1},T5).reason, 'plot_occupied', '格子占了');

// ---------- 集市 ----------
eq(farm.sellPrice('loubo',10,'local',T5), {ok:true,coin:50}, '赶场日本地卖10棵楼卜=50');
eq(farm.sellPrice('loubo',10,'local',T6).reason, 'local_market_closed', '双日本地集市关');
eq(farm.sellPrice('loubo',10,'tourist',T6), {ok:true,coin:125}, '游客集市10棵楼卜=125');
eq(farm.sellPrice('guzi',10,'tourist',T6), {ok:true,coin:1250}, '游客集市10棵谷子=1250');
eq(farm.seedPrice('loubo',3,'tourist',T6), {ok:true,coin:12}, '游客集市3包楼卜种=12');

// ---------- 偷菜 ----------
const ripePlot = {crop:'loubo',plantedAt:T5-5*C.HOUR,stolenCount:0};
const base = {thief:'B',owner:'A',plot:ripePlot,todayStealCount:0,todayStealOnOwner:0,guardUntil:null,guardRoll:0.9,now:T5};
eq(steal.canSteal(base), {ok:true,yield:3}, '正常偷');
eq(steal.canSteal({...base,thief:'A'}).reason, 'own_plot', '不能偷自己');
eq(steal.canSteal({...base,plot:{...ripePlot,stolenCount:1}}).reason, 'already_stolen', '一格只能偷一次');
eq(steal.canSteal({...base,plot:{crop:'loubo',plantedAt:T5}}).reason, 'not_ripe', '没熟不能偷');
eq(steal.canSteal({...base,todayStealCount:10}).reason, 'daily_limit', '每天10格上限');
eq(steal.canSteal({...base,todayStealOnOwner:3}).reason, 'house_limit', '同一家3格上限');
eq(steal.canSteal({...base,guardUntil:T5+C.HOUR,guardRoll:0.1}).reason, 'guarded', '喜多拦住');
eq(steal.canSteal({...base,guardUntil:T5+C.HOUR,guardRoll:0.9}).ok, true, '喜多没拦住');
eq(steal.canSteal({...base,guardUntil:T5-C.HOUR,guardRoll:0.1}).ok, true, '喜多已过期');
eq(steal.canBorrowGuard(1).reason, 'borrowed_today', '一天只能借一次');

// ---------- 关系网 ----------
eq(tree.inviteQuota(0,0), {total:5,used:0,left:5}, '初始5个名额');
eq(tree.inviteQuota(2,3), {total:8,used:2,left:6}, '住3周共8个');
const parentOf = {B:'A', C:'A', D:'B', E:'D'};
eq(tree.relation('A','B',parentOf,new Set()), 'same_branch', 'A带B=同枝');
eq(tree.relation('B','C',parentOf,new Set()), 'sibling', 'B和C=邻叶');
eq(tree.relation('A','E',parentOf,new Set()), 'none', 'A和E隔太远');
const friendsOf = {B:['A','C'], C:['A','B'], E:['D']};
eq(tree.canRequestFriend('B','C',parentOf,new Set(),friendsOf), {ok:true,via:'sibling'}, '邻叶可加');
eq(tree.canRequestFriend('B','A',parentOf,new Set(),friendsOf).reason, 'already_friend', '同枝已是好友');
eq(tree.canRequestFriend('B','E',parentOf,new Set(),friendsOf).reason, 'too_far', '两跳外不能加');
const roots = tree.buildTree(['A','B','C','D','E'], parentOf);
eq(roots.length, 1, '一个根');
eq(roots[0].children.length, 2, 'A带了两个人');
eq(tree.rankSuggestions([
  {id:'X',signals:{sibling:false,mutualFriends:1}},
  {id:'Y',signals:{sibling:true,mutualFriends:0}},
  {id:'Z',signals:{sibling:false,mutualFriends:0,stoleFromMe:true}},
]).map(s=>s.id), ['Y','X','Z'], '可能认识的人排序');

// ---------- 月老庙 · 外殿 ----------
const tbase = {maker:'A',a:'B',b:'C',weekThreadCount:0,friends:new Set(),blocked:new Set(),pastThreads:[],now:T5};
eq(temple.canMakeThread(tbase).ok, true, '正常牵线');
eq(temple.canMakeThread({...tbase,a:'A'}).reason, 'cannot_include_self', '不能牵自己');
eq(temple.canMakeThread({...tbase,b:'B'}).reason, 'same_person', '不能牵同一人');
eq(temple.canMakeThread({...tbase,weekThreadCount:2}).reason, 'weekly_quota', '每周2条');
eq(temple.canMakeThread({...tbase,friends:new Set(['B|C'])}).reason, 'already_friend', '已是好友不牵');
eq(temple.canMakeThread({...tbase,pastThreads:[{maker:'A',a:'B',b:'C',status:'broken'}]}).reason, 'already_tried', '牵过没成不再牵');
eq(temple.threadResult({aAccepted:true,bAccepted:true,expireAt:T5+C.DAY},T5), 'connected', '双方都接=成');
eq(temple.threadResult({aAccepted:true,bAccepted:null,expireAt:T5+C.DAY},T5), 'pending', '一方未答=等');
eq(temple.threadResult({aAccepted:true,bAccepted:false,expireAt:T5+C.DAY},T5), 'broken', '一方拒=断');
eq(temple.threadResult({aAccepted:true,bAccepted:null,expireAt:T5-1},T5), 'broken', '超时=断');

// ---------- 月老庙 · 内殿 ----------
eq(temple.canDrawStick(null,T5).ok, true, '没求过能求');
eq(temple.canDrawStick(D('2026-09-15T01:00:00'),T5).reason, 'drawn_today', '今天求过了');
eq(temple.canDrawStick(D('2026-09-14T23:00:00'),T5).ok, true, '昨天求的不算');
// A 许愿；B 是 A 带进来的（同枝）；C 是家人；D 已收下；E 刚放回；F、G 是干净的候选
const dbase = {me:'A',wishers:['A','B','C','D','E','F','G'],parentOf:{B:'A'},familyOf:{A:['C']},blocked:new Set(['A|G']),kept:['D'],returned:[{who:'E',at:T5-C.HOUR}],rand:0.5,now:T5};
eq(temple.drawStick(dbase).who, 'F', '排除自己/同枝/家人/已收/刚放回/屏蔽后只剩F');
eq(temple.drawStick({...dbase,wishers:['A','B','C','D','E']}).reason, 'no_stick_today', '没人可抽');
eq(temple.drawStick({...dbase,returned:[{who:'E',at:T5-8*C.DAY}]}).ok, true, '放回超7天可再抽');
eq(temple.drawStick({...dbase,rand:0.99}).who, 'F', '只有一个候选时随机数不影响');
eq(temple.isConnected(['B'],['A'],'A','B'), true, '双方都收下=接上');
eq(temple.isConnected(['B'],[],'A','B'), false, '单方收下不算');
eq(temple.findIntroducer('A','B',{A:[{by:'Z'}],B:[{by:'Z'}]},{}), {who:'Z',via:'recommended_both'}, '共同推荐人');
eq(temple.findIntroducer('A','B',{},{A:'Y',B:'Y'}), {who:'Y',via:'common_branch'}, '共同上游');
eq(temple.canRecommend('A','A',[]).reason, 'self', '不能推荐自己');
eq(temple.canRecommend('A','B',[{by:'A'}]).reason, 'already_wrote', '一人只写一条');
eq(temple.canRecommend('A','B',[{by:'W'},{by:'X'},{by:'Y'},{by:'Z'},{by:'V'}]).reason, 'full', '最多5条');

// ---------- 桥灯 ----------
eq(town.lampProgress(0), {lit:0,total:17,allLit:false,current:1,progress:'0／30'}, '一盏没亮');
eq(town.lampProgress(30).lit, 1, '30棵点1盏');
eq(town.lampProgress(65), {lit:2,total:17,allLit:false,current:3,progress:'5／30'}, '65棵=2盏零5');
eq(town.lampProgress(17*30).allLit, true, '510棵全亮');
eq(town.lampProgress(9999).lit, 17, '超了也只有17盏');
const lamps = town.lampNames([{who:'A',count:20},{who:'B',count:15},{who:'C',count:40}]);
eq(lamps.length, 2, '75棵点亮2盏');
eq(lamps[0][0], {who:'A',count:20}, '第1盏A捐最多');

// ---------- 踢球 ----------
eq(town.canKick('A','b1',[]).ok, true, '第一次能踢');
eq(town.canKick('A','b1',[{who:'A',ballId:'b1'}]).reason, 'kicked_this_ball', '同一球一天一次');
eq(town.canKick('A','b2',[{who:'A',ballId:'b1'}]).ok, true, '别的球能踢');
eq(town.ballGoalReached(10), true, '10脚达成');
eq(town.ballGoalReached(9), false, '9脚不够');

// ---------- 镇报 ----------
const ws = T.localWeekStart(T5), we = ws + 7*C.DAY;
const paper = town.weeklyPaper({
  steals:[{thief:'B',owner:'A',count:5,at:T5},{thief:'B',owner:'C',count:3,at:T5},{thief:'D',owner:'A',count:2,at:T5},{thief:'X',owner:'A',count:99,at:ws-C.DAY}],
  sales:[{who:'A',coin:340,at:T5},{who:'B',coin:100,at:T5}],
  joins:[{who:'E',parent:'A',at:T5},{who:'F',parent:'A',at:T5},{who:'G',parent:'B',at:T5}],
  houseRatings:[{house:'h1',owner:'A',avg:4.8,count:5},{house:'h2',owner:'B',avg:5.0,count:0}],
  petEvents:[{pet:'落落',type:'sleep',at:T5},{pet:'落落',type:'sleep',at:T5},{pet:'喜多',type:'guard',at:T5}],
  lamps:{lit:2,total:17},
}, ws, we, 3);
eq(paper.columns.手最长的.top, {who:'B',n:8}, '偷菜王是B偷8棵');
eq(paper.columns.手最长的.victim, {who:'A',n:7}, '被偷最惨是A（上周的99不算）');
eq(paper.columns.地最肥的, {who:'A',n:340}, '收成王A');
eq(paper.columns.新来的, {count:3,byBranch:{A:2,B:1}}, '新来3位分两枝');
eq(paper.columns.最安逸的屋.owner, 'A', '评分最高A（B没人评不算）');
eq(paper.columns.猫猫狗狗的一周['落落'], {sleep:2}, '落落睡了2次');

// ---------- 宴会厅 · 入座 ----------
const mkTable = (id, reserved, branch, seats) => ({ id, reserved, branch, seats });
const fullSeats = (n) => Array.from({ length: n }, (_, i) => `s${i}`);

eq(banquet.assignSeat({
  inviter: 'A', vip: new Set(),
  tables: [mkTable('T1', false, 'A', ['x1', 'x2'])],
}), { ok: true, tableId: 'T1', bench: false }, '坐邀请人那桌');

eq(banquet.assignSeat({
  inviter: 'A', vip: new Set(),
  tables: [mkTable('T1', false, 'A', fullSeats(10)), mkTable('T2', false, 'A', [])],
}), { ok: true, tableId: 'T2', bench: false }, '邀请人那桌满了坐同枝下一桌');

eq(banquet.assignSeat({
  inviter: 'A', vip: new Set(['A']),
  tables: [mkTable('R1', true, null, []), mkTable('R2', true, null, [])],
}), { ok: true, tableId: 'R1', bench: false }, '阿鱼/Toretto的枝第一次坐前两桌');

eq(banquet.assignSeat({
  inviter: null, vip: new Set(),
  tables: [mkTable('T1', false, null, fullSeats(10)), mkTable('T2', false, null, [])],
}), { ok: true, tableId: 'T2', bench: false }, '没有邀请人坐任意空桌');

eq(banquet.assignSeat({
  inviter: 'B', vip: new Set(),
  tables: [mkTable('R1', true, null, []), mkTable('R2', true, null, []), mkTable('T3', false, null, [])],
}), { ok: true, tableId: 'T3', bench: false }, '邀请人还没坐过就开一桌（非阿鱼/Toretto不占前两桌）');

eq(banquet.assignSeat({
  inviter: 'A', vip: new Set(),
  tables: [mkTable('T1', false, null, ['A', 'x1'])],
}), { ok: true, tableId: 'T1', bench: false }, '邀请人自己是没有邀请人坐的（branch标记是null），也要直接找到那桌');

eq(banquet.assignSeat({
  inviter: 'A', vip: new Set(),
  tables: Array.from({ length: 12 }, (_, i) => mkTable(`T${i}`, i < 2, 'A', fullSeats(10))),
}), { ok: true, bench: true }, '120坐满了坐长凳');

// ---------- 宴会厅 · 换桌 ----------
eq(banquet.canChangeSeat({ occupant: null, todayChanges: 0 }).ok, true, '正常换到空椅子');
eq(banquet.canChangeSeat({ occupant: 'X', todayChanges: 0 }).reason, 'seat_taken', '目标椅子有人');
eq(banquet.canChangeSeat({ occupant: null, todayChanges: 1 }).reason, 'changed_today', '这次来访已经换过一次');
eq(banquet.canChangeSeat({ occupant: null, todayChanges: 0 }).ok, true, '跨北京时间0点：昨天换过，今天重新计数为0次仍能换');

// ---------- 宴会厅 · 敬酒 ----------
const toastBase = { from: 'A', to: 'B', todayToastCount: 0, todayToastToCount: 0 };
eq(banquet.canToast(toastBase).ok, true, '正常敬一杯');
eq(banquet.canToast({ ...toastBase, todayToastCount: 5 }).reason, 'toast_limit', '今天5杯敬完');
eq(banquet.canToast({ ...toastBase, todayToastToCount: 1 }).reason, 'toast_same_person', '对同一人今天敬过');
eq(banquet.canToast({ ...toastBase, to: 'A' }).reason, 'toast_self', '不能敬自己');
eq(banquet.canToast({ ...toastBase, todayToastCount: 0 }).ok, true, '跨北京时间0点：昨天5杯敬完，今天重新计数为0杯仍能敬');

// ---------- 宴会厅 · 桌簿 ----------
eq(banquet.canWriteBook({ table: 'T1', satTables: ['T1', 'T2'], text: '恭喜恭喜' }).ok, true, '坐过的桌能写');
eq(banquet.canWriteBook({ table: 'T3', satTables: ['T1', 'T2'], text: '恭喜恭喜' }).reason, 'not_sat_here', '没坐过的桌不能写');
eq(banquet.canWriteBook({ table: 'T1', satTables: ['T1'], text: 'x'.repeat(100) }).ok, true, '边界：正好100字能写');
eq(banquet.canWriteBook({ table: 'T1', satTables: ['T1'], text: 'x'.repeat(101) }).reason, 'book_too_long', '超过100字不能写');

// ---------- 宴会厅 · 进厅提示 ----------
eq(banquet.arrivalDigest({
  toasts: [{ from: '老王', at: T5 + 1 }],
  bookLines: [{ tableId: 'T1', at: T5 + 1 }, { tableId: 'T1', at: T5 + 2 }],
  since: T5,
}), { toasts: [{ from: '老王', at: T5 + 1 }], toastCount: 1, bookLineCount: 2, hasNews: true }, '正常合并新动静');
eq(banquet.arrivalDigest({ toasts: [], bookLines: [], since: T5 }).hasNews, false, '没有新动静');
eq(banquet.arrivalDigest({
  toasts: [{ from: '老王', at: T5 }],
  bookLines: [],
  since: T5,
}).toastCount, 0, '边界：正好等于since的不算新');
eq(banquet.arrivalDigest({
  toasts: [{ from: 'A', at: T5 + 1 }, { from: 'A', at: T5 + 2 }],
  bookLines: [],
  since: T5,
}).toastCount, 2, '同一人敬了两杯都算');

// ---------- 结果 ----------
console.log(`\n通过 ${pass}，失败 ${fail}`);
if (fail) { console.log('\n失败项：'); failures.forEach(f => console.log('  ✗ ' + f)); process.exit(1); }
else console.log('全部通过');
