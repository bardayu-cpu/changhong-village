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
const canvasRules = require('../src/canvas');
const resident = require('../src/resident');
const sensitive = require('../src/sensitive');

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

// ---------- 宴会厅 · 换桌（蓝图 3.2 9/18 改：不限次数，去掉 changed_today，BANQUET_CHANGE_PER_VISIT 已删） ----------
eq(banquet.canChangeSeat({ occupant: null }).ok, true, '正常换到空椅子');
eq(banquet.canChangeSeat({ occupant: 'X' }).reason, 'seat_taken', '目标椅子有人');
eq(banquet.canChangeSeat({ occupant: null }).ok, true, '换过一次，同一次来访还能再换（不再判 changed_today）');
eq(banquet.canChangeSeat({ occupant: null }).ok, true, '连着换第二次也能换');
eq(banquet.canChangeSeat({ occupant: null }).ok, true, '连着换第三次也能换（不限次数）');
eq(banquet.canChangeSeat({ occupant: 'X', todayChanges: 99 }).reason, 'seat_taken', '调用方就算还传老字段 todayChanges，也不影响判断，只看座位有没有人');

// ---------- 宴会厅 · 敬酒 ----------
const toastBase = { from: 'A', to: 'B', todayToastCount: 0, todayToastToCount: 0 };
eq(banquet.canToast(toastBase).ok, true, '正常敬一杯');
eq(banquet.canToast({ ...toastBase, todayToastCount: 5 }).reason, 'toast_limit', '今天5杯敬完');
eq(banquet.canToast({ ...toastBase, todayToastToCount: 1 }).reason, 'toast_same_person', '对同一人今天敬过');
eq(banquet.canToast({ ...toastBase, to: 'A' }).reason, 'toast_self', '不能敬自己');
eq(banquet.canToast({ ...toastBase, todayToastCount: 0 }).ok, true, '跨北京时间0点：昨天5杯敬完，今天重新计数为0杯仍能敬');
eq(banquet.canToast({ ...toastBase, todayToastCount: 5, testMode: true }).ok, true, '测试模式：敬满5杯还能敬');
eq(banquet.canToast({ ...toastBase, todayToastToCount: 1, testMode: true }).ok, true, '测试模式：同一人今天敬过还能敬');
eq(banquet.canToast({ ...toastBase, to: 'A', testMode: true }).reason, 'toast_self', '测试模式：敬自己照样拒');
eq(banquet.canToast({ ...toastBase, todayToastCount: 5, testMode: false }).reason, 'toast_limit', '测试模式关着：照常5杯封顶');

// ---------- 宴会厅 · 想认识你（蓝图 3.2 加好友；9/19 总策划定「同桌」指现在同一桌，坐过不算） ----------
const meetBase = { from: 'A', to: 'B', alreadySent: false, fromTableId: 'T3', toTableId: 'T5', toasted: false };
eq(banquet.canWantToMeet({ ...meetBase, toTableId: 'T3' }), { ok: true, via: 'table' }, '想认识你：现在同一桌能发');
eq(banquet.canWantToMeet({ ...meetBase, toasted: true }), { ok: true, via: 'toast' }, '想认识你：不同桌、敬过酒能发');
eq(banquet.canWantToMeet(meetBase).reason, 'meet_not_met', '想认识你：不同桌、没敬过酒不能发（以前坐过同桌也不算，调用方只传现在的桌）');
eq(banquet.canWantToMeet({ ...meetBase, to: 'A', toTableId: 'T3', toasted: true }).reason, 'meet_self', '想认识你：对自己不能发');
eq(banquet.canWantToMeet({ ...meetBase, toTableId: 'T3', toasted: true, alreadySent: true }).reason, 'meet_already', '想认识你：同一对只记一次');
eq(banquet.canWantToMeet({ ...meetBase, fromTableId: C.BANQUET_BENCH_ID, toTableId: C.BANQUET_BENCH_ID }).reason, 'meet_not_met', '想认识你：两人都坐长凳不算同桌');
eq(banquet.canWantToMeet({ ...meetBase, fromTableId: C.BANQUET_BENCH_ID, toTableId: C.BANQUET_BENCH_ID, toasted: true }), { ok: true, via: 'toast' }, '想认识你：坐长凳敬过酒照样能发');
eq(banquet.canWantToMeet({ ...meetBase, fromTableId: null, toTableId: null }).reason, 'meet_not_met', '想认识你：两人都没座位不算同桌');

// ---------- 画布图远程加载（云函数 canvasFile，HANDOFF §0.9）：只许读 canvas/ 下面的，一块一块回 ----------
const CV_ID = 'cloud://cloud1-d9ggg36tj34742bef.636c-cloud1-d9ggg36tj34742bef-1488216695/canvas/scene_roman_banquet/base.png';
eq(canvasRules.canReadCanvas(CV_ID), true, '画布图：canvas/ 下面的能读');
eq(canvasRules.canReadCanvas(CV_ID.replace('/canvas/', '/private/')), false, '画布图：canvas/ 以外的不给');
eq(canvasRules.canReadCanvas(CV_ID.replace('/canvas/', '/canvas/../private/')), false, '画布图：路径里有 .. 不给');
eq(canvasRules.canReadCanvas(CV_ID + ' '), false, '画布图：带空白不给');
eq(canvasRules.canReadCanvas('https://x.com/canvas/a.png'), false, '画布图：不是 cloud:// 不给');
eq(canvasRules.canReadCanvas(undefined), false, '画布图：没传不给');
// 白名单（01 9/20 定，起因 03 查出 %2e%2e 绕过了只查字面「..」的写法）：编码、花样字符一律拒，每种钉一条
const CV = 'cloud://env-1.bucket-2/canvas/';
eq(canvasRules.canReadCanvas(CV + 'sub_dir-1/a.b.png'), true, '画布图：正常的子目录、点、下划线、连字符能读');
eq(canvasRules.canReadCanvas(CV + '%2e%2e/secret.png'), false, '画布图：%2e%2e 不给');
eq(canvasRules.canReadCanvas(CV + '%2E%2E/secret.png'), false, '画布图：%2E%2E 不给');
eq(canvasRules.canReadCanvas(CV + '%252e%252e/secret.png'), false, '画布图：%252e 双重编码不给');
eq(canvasRules.canReadCanvas(CV + 'a%00.png'), false, '画布图：%00 不给');
eq(canvasRules.canReadCanvas(CV + 'a.png?x=1'), false, '画布图：问号不给');
eq(canvasRules.canReadCanvas(CV + 'a.png#f'), false, '画布图：井号不给');
eq(canvasRules.canReadCanvas('cloud://env-1.bucket-2/canvas\\..\\secret.png'), false, '画布图：反斜杠不给');
eq(canvasRules.canReadCanvas(CV + '．．/secret.png'), false, '画布图：全角点不给');
eq(canvasRules.canReadCanvas(CV + './a.png'), false, '画布图：单独一个点不给');
eq(canvasRules.canReadCanvas(CV + '/a.png'), false, '画布图：空段 // 不给');
eq(canvasRules.canReadCanvas(CV + '../secret.png'), false, '画布图：连着两个点不给');
eq(canvasRules.canReadCanvas('cloud://env-1.bucket-2/Canvas/a.png'), false, '画布图：大小写不一样不给');
eq(canvasRules.canReadCanvas('cloud://env-1.bucket-2//canvas/a.png'), false, '画布图：前导斜杠不给');
eq(canvasRules.canReadCanvas('cloud://env-1.bucket-2/canvasXXX/a.png'), false, '画布图：前缀伪装 canvasXXX 不给');
eq(canvasRules.canReadCanvas('cloud://envbucket/canvas/a.png'), false, '画布图：环境.桶 不成样子不给');
eq(canvasRules.canReadCanvas(CV + '中文.png'), false, '画布图：中文不给');
eq(canvasRules.canReadCanvas(CV), false, '画布图：canvas/ 后面空的不给');
eq(canvasRules.canReadCanvas(CV + 'a'.repeat(600) + '.png'), false, '画布图：超长不给');
eq(canvasRules.chunkRange(600, 0, 256), { ok: true, start: 0, end: 256, done: false }, '画布图：第一块');
eq(canvasRules.chunkRange(600, 512, 256), { ok: true, start: 512, end: 600, done: true }, '画布图：最后一块不满也算完');
eq(canvasRules.chunkRange(600, 600, 256).done, true, '画布图：正好要到末尾算完');
eq(canvasRules.chunkRange(600, 601, 256).reason, 'bad_request', '画布图：超过文件大小回 bad_request');
eq(canvasRules.chunkRange(600, -1, 256).reason, 'bad_request', '画布图：负数回 bad_request');
eq(canvasRules.chunkRange(600, 1.5, 256).reason, 'bad_request', '画布图：不是整数回 bad_request');
eq(canvasRules.chunkRange(C.CANVAS_CHUNK * 3, C.CANVAS_CHUNK).end, C.CANVAS_CHUNK * 2, '画布图：默认一块 CANVAS_CHUNK');

// ---------- 宴会厅 · 桌簿（蓝图 3.2 9/18 改：只能写「现在坐的那桌」，不再是「坐过的桌都能写」） ----------
eq(banquet.canWriteBook({ table: 'T1', mySeatTableId: 'T1', text: '恭喜恭喜' }).ok, true, '坐在T1写T1能写');
eq(banquet.canWriteBook({ table: 'T2', mySeatTableId: 'T1', text: '恭喜恭喜' }).reason, 'not_sat_here', '坐在T1、写T2不行（哪怕以前坐过T2）');
eq(banquet.canWriteBook({ table: 'T1', mySeatTableId: 'T1', text: 'x'.repeat(100) }).ok, true, '边界：正好100字能写');
eq(banquet.canWriteBook({ table: 'T1', mySeatTableId: 'T1', text: 'x'.repeat(101) }).reason, 'book_too_long', '超过100字不能写');
eq(banquet.canWriteBook({ table: 'T1', mySeatTableId: 'T1', text: '' }).reason, 'bad_request', '空文本回bad_request（不再是book_too_long）');
eq(banquet.canWriteBook({ table: 'T1', mySeatTableId: C.BANQUET_BENCH_ID, text: '坐长凳也想说句话' }).reason, 'not_sat_here', '坐长凳的人写哪桌都不行');

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

// ---------- 宴会厅 · 进厅小卡（01 9/23「进厅先见人」：最多三行、每行一个人一件事） ----------
{
  const S = 1000;
  const card = banquet.arrivalCard({
    me: 'me', since: S,
    toasts: [{ from: '老王', at: S + 5 }, { from: '老王', at: S + 9 }, { from: '旧账', at: S }],
    bookLines: [{ from: '老王', at: S + 6 }, { from: '阿花', at: S + 3 }],
    visitors: [{ openid: '小李', at: S + 8 }, { openid: 'me', at: S + 9 }],
  });
  eq(card.rows, [
    { kind: 'toast', who: '老王', at: S + 9, count: 2 },
    { kind: 'book', who: '阿花', at: S + 3, count: 1 },
    { kind: 'visit', who: '小李', at: S + 8, count: 1 },
  ], '三类各一人：敬酒在前、簿子其次、来过最后；老王敬了又写只说敬酒；正好等于 since 的不算；自己不算');
  eq(card.hasNews, true, '有新鲜事');
  eq(banquet.arrivalCard({ me: 'me', since: S, toasts: [], bookLines: [], visitors: [] }), { rows: [], hasNews: false }, '没有新鲜事：不弹卡');
  const many = banquet.arrivalCard({
    me: 'me', since: S, toasts: [], bookLines: [],
    visitors: [1, 2, 3, 4, 5].map(i => ({ openid: 'v' + i, at: S + i })),
  });
  eq(many.rows, [
    { kind: 'visit', who: 'v5', at: S + 5, count: 1 },
    { kind: 'visit', who: 'v4', at: S + 4, count: 1 },
    { kind: 'more', count: 3 },
  ], '超过三位：新的在前列两位，第三行合成「还有 3 位」');
  eq(banquet.arrivalCard({
    me: 'me', since: S, toasts: [], visitors: [],
    bookLines: [{ from: '阿花', at: S + 1 }, { from: '阿花', at: S + 2 }],
  }).rows, [{ kind: 'book', who: '阿花', at: S + 2, count: 2 }], '同一人写两句并成一行，count 2');
}

// ---------- 住民资料校验（最小版） ----------
eq(resident.canSaveProfile({ nick: '阿花' }).ok, true, '正常昵称能存');
eq(resident.canSaveProfile({ nick: ' 阿花 ' }), { ok: true }, '去掉首尾空白后正好2个字能存');
eq(resident.canSaveProfile({ nick: '阿 花' }), { ok: true }, '去空白只去首尾，中间空格不折叠，仍算3个字符');
eq(resident.canSaveProfile({ nick: 'x'.repeat(12) }).ok, true, '边界：正好12字能存');
eq(resident.canSaveProfile({ nick: 'x'.repeat(13) }), { ok: false, reason: 'book_too_long', field: 'nick' }, '昵称超过12字');
// 迎宾院签到的名字（蓝图 3.1：1～12 字，9/19）
eq(resident.canCheckIn('李'), { ok: true }, '签到名字 1 个字可以（比昵称的 2 字宽）');
eq(resident.canCheckIn('x'.repeat(12)), { ok: true }, '签到名字 正好 12 字可以');
eq(resident.canCheckIn('x'.repeat(13)), { ok: false, reason: 'bad_request', field: 'check_in_name' }, '签到名字 超过 12 字');
eq(resident.canCheckIn('   '), { ok: false, reason: 'bad_request', field: 'check_in_name' }, '签到名字 全是空白');
eq(resident.canCheckIn(88), { ok: false, reason: 'bad_request', field: 'check_in_name' }, '签到名字 不是字符串');
eq(resident.canSaveProfile({ nick: '' }), { ok: false, reason: 'nick_too_short', field: 'nick' }, '昵称空的（去空白后不够2字）');
eq(resident.canSaveProfile({ nick: '  ' }).reason, 'nick_too_short', '昵称全是空白');
eq(resident.canSaveProfile({ whisper: '新婚快乐' }).ok, true, '正常悄悄话能存');
eq(resident.canSaveProfile({ whisper: 'x'.repeat(200) }).ok, true, '边界：正好200字能存');
eq(resident.canSaveProfile({ whisper: 'x'.repeat(201) }), { ok: false, reason: 'book_too_long', field: 'whisper' }, '悄悄话超过200字');
eq(resident.canSaveProfile({}), { ok: true }, '没传要查的字段就不查');
eq(resident.clampGiftValue(88), 88, '正常礼金原样存');
eq(resident.clampGiftValue(99999), 9999, '超上限按上限');
eq(resident.clampGiftValue(-5), 0, '负数夹到0');
eq(resident.clampGiftValue(66.9), 66, '取整（向下）');

// ---------- 席间小游戏存档校验（sanitizeCoins/sanitizeGames/sanitizeDishes/sanitizeGiftAdd，蓝图 3.2 席间小游戏，阿鱼 9/19） ----------
eq(resident.sanitizeCoins(88), 88, 'coins 正常数字原样存');
eq(resident.sanitizeCoins(0), 0, 'coins 边界：0能存');
eq(resident.sanitizeCoins(999999), 999999, 'coins 边界：正好上限能存');
eq(resident.sanitizeCoins(1000000), 999999, 'coins 超上限夹到999999');
eq(resident.sanitizeCoins(-5), 0, 'coins 负数夹到0');
eq(resident.sanitizeCoins(66.9), 66, 'coins 取整（向下）');
eq(resident.sanitizeCoins('88'), undefined, 'coins 字符串（哪怕像数字）整个丢掉');
eq(resident.sanitizeCoins('abc'), undefined, 'coins 非数字字符串整个丢掉');
eq(resident.sanitizeCoins(NaN), undefined, 'coins 是NaN整个丢掉');
eq(resident.sanitizeCoins(Infinity), undefined, 'coins 是Infinity整个丢掉');
eq(resident.sanitizeCoins(null), undefined, 'coins 是null整个丢掉');
eq(resident.sanitizeCoins(undefined), undefined, 'coins 是undefined整个丢掉');
eq(resident.sanitizeCoins(true), undefined, 'coins 是布尔值整个丢掉');
eq(resident.sanitizeCoins({}), undefined, 'coins 是对象整个丢掉');
eq(resident.sanitizeCoins(500), 500, 'gift_coins 跟coins共用同一个校验函数，正常数字原样存');

eq(resident.sanitizeGames({ t1_t2: 3, t3_t4: 5 }), { t1_t2: 3, t3_t4: 5 }, 'games 正常两个键都存');
eq(resident.sanitizeGames({ t1_t2: -1 }), { t1_t2: 0 }, 'games 值负数夹到0');
eq(resident.sanitizeGames({ t1_t2: 99999 }), { t1_t2: 999 }, 'games 值超上限夹到999');
eq(resident.sanitizeGames({ t1_t2: 3.9 }), { t1_t2: 3 }, 'games 值取整（向下）');
eq(resident.sanitizeGames({ 'bad key!': 3, ok_key: 2 }), { ok_key: 2 }, 'games 键带非法字符被丢，合法键照留');
eq(resident.sanitizeGames({ '': 1, ok_key: 2 }), { ok_key: 2 }, 'games 空字符串键被丢');
eq(resident.sanitizeGames({ [('k').repeat(21)]: 1, ok_key: 2 }), { ok_key: 2 }, 'games 键超过20字被丢');
eq(resident.sanitizeGames({ [('k').repeat(20)]: 1 }), { [('k').repeat(20)]: 1 }, 'games 边界：键正好20字能存');
eq(resident.sanitizeGames({ t1_t2: 'not-a-number', ok_key: 2 }), { ok_key: 2 }, 'games 值不是数字被丢，合法键照留');
eq(resident.sanitizeGames({ t1_t2: NaN, ok_key: 2 }), { ok_key: 2 }, 'games 值是NaN被丢');
{
  const many = {};
  for (let i = 0; i < 20; i++) many['g' + i] = i;
  const got = resident.sanitizeGames(many);
  eq(Object.keys(got).length, 12, 'games 最多只收12个键');
  eq(got.g0, 0, 'games 前12个键按原顺序保留（第1个）');
  eq(got.g11, 11, 'games 前12个键按原顺序保留（第12个）');
  eq(got.g12, undefined, 'games 第13个键起被丢');
}
eq(resident.sanitizeGames([1, 2, 3]), undefined, 'games 传数组整个字段丢掉');
eq(resident.sanitizeGames(null), undefined, 'games 传null整个字段丢掉');
eq(resident.sanitizeGames('x'), undefined, 'games 传字符串整个字段丢掉');
eq(resident.sanitizeGames({}), {}, 'games 空对象原样存空对象');

eq(resident.sanitizeDishes([3, 5, 7]), [3, 5, 7], 'dishes 正常数组原样存');
eq(resident.sanitizeDishes([3, 5, 3, 7, 5]), [3, 5, 7], 'dishes 去重');
eq(resident.sanitizeDishes([0, 99]), [0, 99], 'dishes 边界：0和99都能存');
eq(resident.sanitizeDishes([-1, 100, 3]), [3], 'dishes 超范围（负数、大于99）被丢，合法的照留');
eq(resident.sanitizeDishes([3.5, 3]), [3], 'dishes 非整数被丢');
eq(resident.sanitizeDishes(['3', 3]), [3], 'dishes 字符串元素被丢，数字元素照留');
eq(resident.sanitizeDishes({ 0: 1 }), undefined, 'dishes 传对象（不是数组）整个字段丢掉');
eq(resident.sanitizeDishes('x'), undefined, 'dishes 传字符串整个字段丢掉');
eq(resident.sanitizeDishes([]), [], 'dishes 空数组原样存空数组');
{
  const full = Array.from({ length: 100 }, (_, i) => i); // 0~99每个整数各一个，正好100个
  const got = resident.sanitizeDishes(full);
  eq(got.length, 100, 'dishes 0~99全给，去重后应该是100个，不会被误裁');
}

eq(resident.sanitizeGiftAdd(88), 88, 'gift_add 正常数字能记');
eq(resident.sanitizeGiftAdd(1), 1, 'gift_add 边界：1能记');
eq(resident.sanitizeGiftAdd(999999), 999999, 'gift_add 边界：正好上限能记');
eq(resident.sanitizeGiftAdd(1000000), null, 'gift_add 超上限不记');
eq(resident.sanitizeGiftAdd(0), null, 'gift_add 是0不记');
eq(resident.sanitizeGiftAdd(-5), null, 'gift_add 负数不记');
eq(resident.sanitizeGiftAdd(0.5), null, 'gift_add 取整后是0不记');
eq(resident.sanitizeGiftAdd(88.9), 88, 'gift_add 取整（向下）后再判断范围');
eq(resident.sanitizeGiftAdd('88'), null, 'gift_add 字符串不记');
eq(resident.sanitizeGiftAdd(NaN), null, 'gift_add 是NaN不记');
eq(resident.sanitizeGiftAdd(null), null, 'gift_add 是null不记');
eq(resident.sanitizeGiftAdd(undefined), null, 'gift_add 是undefined不记');

// mergeGames/mergeDishes：只传变化的那一部分，不该把没提到的旧值冲掉
eq(resident.mergeGames({ t1_t2: 2, t3_t4: 5 }, { t1_t2: 4 }), { t1_t2: 4, t3_t4: 5 }, 'mergeGames 只传一个游戏的新进度，另一个游戏照样保留');
eq(resident.mergeGames({}, { t1_t2: 1 }), { t1_t2: 1 }, 'mergeGames 旧值是空对象也能正常合并');
eq(resident.mergeGames({ t1_t2: 2 }, {}), { t1_t2: 2 }, 'mergeGames 这次没传新值，旧值原样保留');
eq(resident.mergeDishes([1, 2, 3], [9]), [1, 2, 3, 9], 'mergeDishes 新解锁一道菜，旧的照样保留');
eq(resident.mergeDishes([1, 2, 3], [2]), [1, 2, 3], 'mergeDishes 重复解锁同一道菜不重复');
eq(resident.mergeDishes([], [5, 1, 3]), [1, 3, 5], 'mergeDishes 旧值是空数组时按数字排序返回');
eq(resident.mergeDishes([3, 1], []), [1, 3], 'mergeDishes 这次没有新菜，旧值原样保留（排序）');

// ---------- 邀请人只存第一次（canAdoptInviter，回执 03 第 3 项） ----------
eq(resident.canAdoptInviter({ existingInviter: null, selfOpenid: 'A', inviter: 'B', inviterExists: true }), true, '正常：第一次存、邀请人存在，能记');
eq(resident.canAdoptInviter({ existingInviter: 'X', selfOpenid: 'A', inviter: 'B', inviterExists: true }), false, '已经有邀请人了，只认第一次');
eq(resident.canAdoptInviter({ existingInviter: null, selfOpenid: 'A', inviter: 'A', inviterExists: true }), false, '不能填自己');
eq(resident.canAdoptInviter({ existingInviter: null, selfOpenid: 'A', inviter: 'B', inviterExists: false }), false, '邀请人不存在，不能记');
eq(resident.canAdoptInviter({ existingInviter: null, selfOpenid: 'A', inviter: null, inviterExists: true }), false, '边界：没传候选人（null）');
eq(resident.canAdoptInviter({ existingInviter: null, selfOpenid: 'A', inviter: '', inviterExists: true }), false, '边界：候选人是空字符串');
eq(resident.canAdoptInviter({ existingInviter: '', selfOpenid: 'A', inviter: 'B', inviterExists: true }), true, '边界：已有邀请人是空字符串，等同没有，能记');

// ---------- 敏感词与保留名校验（src/sensitive.js，docs/敏感词模块-需求.md 第 4 节） ----------
// normalize：去空白折叠、剥离零宽字符/变体选择符、全角转半角、大小写不敏感
eq(sensitive.normalize('  阿花  '), '阿花', 'normalize 去首尾空白');
eq(sensitive.normalize('阿    花'), '阿 花', 'normalize 连续空白折叠为一个');
eq(sensitive.normalize('ABC１２３'), 'abc123', 'normalize 全角转半角+大写转小写');
eq(sensitive.normalize('敏​感﻿词'), '敏感词', 'normalize 剥离零宽字符');
eq(sensitive.normalize('a️b'), 'ab', 'normalize 剥离变体选择符');

// stripForB：在 normalize 之后再去标点、空格、符号/emoji（抓"傻·逼""S B"这类插入变体）
eq(sensitive.stripForB(sensitive.normalize('傻·逼')), '傻逼', 'stripForB 去标点');
eq(sensitive.stripForB(sensitive.normalize('s b')), 'sb', 'stripForB 去空格');
eq(sensitive.stripForB(sensitive.normalize('正常文字')), '正常文字', 'stripForB 没有标点原样返回');
eq(sensitive.stripForB(sensitive.normalize('a😀b')), 'ab', 'stripForB 去 emoji');

// buildMatcher + checkText：AC 自动机命中判断、保留名完全匹配、A/B 双文本
const testMatcher = sensitive.buildMatcher(['敏感词', '坏话', 'abc']);
eq(sensitive.checkText('这是敏感词测试', { sensitiveMatcher: testMatcher }).reason, 'sensitive', 'checkText 命中敏感词（包含匹配）');
eq(sensitive.checkText('平安喜乐', { sensitiveMatcher: testMatcher }).ok, true, 'checkText 没命中就放行');
eq(sensitive.checkText('阿鱼', { reservedSet: new Set(['阿鱼']) }).reason, 'reserved', 'checkText 保留名完全匹配');
eq(sensitive.checkText('阿鱼真棒', { reservedSet: new Set(['阿鱼']) }).ok, true, 'checkText 保留名只做完全匹配，不做包含匹配');
eq(sensitive.checkText('敏·感·词', { sensitiveMatcher: sensitive.buildMatcher(['敏感词']) }).reason, 'sensitive', 'checkText 文本B抓住插入标点的变体');
eq(sensitive.checkText('ＡＢＣ', { sensitiveMatcher: testMatcher }).reason, 'sensitive', 'checkText 全角大写照样命中半角小写词条');

// ---------- 结果 ----------
console.log(`\n通过 ${pass}，失败 ${fail}`);
if (fail) { console.log('\n失败项：'); failures.forEach(f => console.log('  ✗ ' + f)); process.exit(1); }
else console.log('全部通过');
