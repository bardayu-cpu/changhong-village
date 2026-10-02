// 云函数 saveProfile：存昵称、形象、邀请人、签到礼金、悄悄话（resident 表，一人一条）。
//
// 9/19 加（迎宾院签到，蓝图 3.1、2.4「签到名字、礼金数存服务器同一条记录，只有阿鱼后台能看」）：check_in_name
// 签到名字（1～12 字，跟昵称一样过敏感词和保留名），传了就在 checked_in_at 记下第一次签到的时间（以后再签不改）。
// 返回里带 checked_in（这个人签过到没有）：客户端进山庄时存资料就知道，换了手机签到桌也只显示「已签到」
// 昵称长度、悄悄话长度做了最小校验（rules/resident.js，回执 02-总策划答复-2 第 4 条）；
// 礼金夹到 0～9999，不拒绝。
// 敏感词/保留名校验（docs/敏感词模块-需求.md，回执 05）：nick 要过 rules/sensitive.js 的
// checkText，命中敏感词或保留名都不写库，直接把 {ok:false, reason} 原样返回给客户端；
// 悄悄话（whisper）不过滤，需求文档第 1 节写明私密祝福不改动现有逻辑。
// 客户端：wx.cloud.callFunction({ name: 'saveProfile', data: { nick, avatar, inviter, gift_value, whisper,
//   coins, games, dishes, gift_coins, gift_add, check_in_name, blessing } })
// 10/2 加 blessing（迎宾院签到的一句公开祝福，1～30 字、过敏感词），别人在祝福牌上能看到（readBlessings）
// 10/2 晚又加：祝福过了自己的词库，再过一遍微信的内容安全 msgSecCheck（01 E：公开给全场看的字要过官方的）。
// 要 config.json 里开 openapi 权限 security.msgSecCheck，部署时一起传上去
// 传哪个字段就存哪个，没传的不动。
//
// 9/19 加（蓝图 3.2「席间小游戏」，阿鱼 9/19 定）：coins 金币、games 各小游戏通关进度、
// dishes 吃席（连连看）解锁的菜、gift_coins 累计添进礼金的金币总数——全部纯客户端玩法，
// 这里只做类型和范围的兜底，不判定"打得对不对"（详见 rules/resident.js）。gift_add 是这次
// 要添的金币数，不存进 resident，转成 gift_coin 集合里的一条礼金流水，只有阿鱼在后台看。
// games/dishes 存的时候都跟旧值合并（mergeGames/mergeDishes），不是整个覆盖：客户端如果只传
// "这次变化的那一部分"（比如只传这一个游戏的新进度、只传新解锁的这一道菜），其它已经存的
// 不会被冲掉。coins/gift_value/gift_coins 是单个数字，没有这个问题，照常整体替换。
//
// 邀请人只存第一次（回执 03 第 3 项，依据阶段 1 设计"用谁的链接进来，就长在谁的枝上"）：
// 传了 inviter 时，只有同时满足"自己还没有邀请人、不是自己、这个人在 resident 表里存在"才会
// 真的写进去；不满足就只丢掉 inviter 这一个字段，nick/avatar 等其它字段照常存、照常返回
// {ok:true}，不能因为邀请人不对让整次保存失败。判定逻辑在 rules/resident.js 的 canAdoptInviter
// （同步自 src/resident.js），这里只负责把要判定的四个输入准备好。
const fs = require('fs');
const path = require('path');
const cloud = require('wx-server-sdk');
const resident = require('./rules/resident');
const sensitive = require('./rules/sensitive');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

const FIELDS = ['nick', 'avatar', 'inviter', 'gift_value', 'whisper', 'coins', 'games', 'dishes', 'gift_coins', 'gift_add', 'check_in_name', 'blessing'];

// 词库文件由 scripts/sync-cf-rules.js 同步进这个云函数自己的 words/ 文件夹（部署前必须先跑同步）。
// 模块加载时读一次、建好 AC 自动机；同一个容器热启动的后续调用复用，不重复读文件、不重复建。
function readWordFile(name) {
  const file = path.join(__dirname, 'words', name);
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8').split(/\r?\n/).map(s => s.trim()).filter(Boolean);
}
const SENSITIVE_MATCHER = sensitive.buildMatcher(readWordFile('base.txt'));
const RESERVED_SET = new Set(readWordFile('reserved.txt').map(sensitive.normalize));

// 微信内容安全（msgSecCheck 2.0，场景 2「评论」）：只有回 suggest 'pass' 才算过。
// 'review'（拿不准）、'risky' 都不让上祝福牌；接口出错（没开权限、超额、网络）也不让上——祝福是公开给全场看的，
// 宁可让这一位换个说法或跳过，也不放没查过的字上去。返回 {ok:true} 或 {ok:false, sec:'review'|'risky'|'error'}
async function secCheck(text, openid) {
  try {
    const r = await cloud.openapi.security.msgSecCheck({ openid, scene: 2, version: 2, content: text });
    const suggest = r && r.result && r.result.suggest;
    if (r && (r.errCode === 0 || r.errCode === undefined) && suggest === 'pass') return { ok: true };
    return { ok: false, sec: suggest || 'error' };
  } catch (e) {
    console.error('msgSecCheck 出错', e && (e.errCode || e.message));
    return { ok: false, sec: 'error' };
  }
}

// 主角名单：阿鱼、Toretto 的 openid，存在 config/banquet（和 enterHall 分座用的是同一份，initDb 建的，先是空数组）
async function isVip(openid) {
  const doc = await db.collection('config').doc('banquet').get().catch(() => null);
  const ids = (doc && doc.data && doc.data.vip_openids) || [];
  return ids.indexOf(openid) !== -1;
}

// 名字过敏感词和保留名：昵称、签到名字都走这里。保留名是留给主角的——主角名单（config/banquet 的 vip_openids）
// 不拦；已经用着这个名字的人接着用也不拦（9/18 助理 01：阿鱼自己起名「阿鱼」不能被拦），ownNames 是算「自己的名字」的那几个。
// 敏感词对谁都拦。返回 {ok:true} 或 {ok:false, reason:'sensitive'|'reserved'}
async function checkName(text, ownNames, openid) {
  const wordCheck = sensitive.checkText(text, { sensitiveMatcher: SENSITIVE_MATCHER, reservedSet: RESERVED_SET });
  if (wordCheck.ok) return wordCheck;
  if (wordCheck.reason === 'reserved') {
    const n = sensitive.normalize(text);
    const own = ownNames.some(x => typeof x === 'string' && sensitive.normalize(x) === n);
    if (own || await isVip(openid)) return { ok: true };
  }
  return wordCheck;
}

exports.main = async (event) => {
  const { OPENID } = cloud.getWXContext();
  const now = Date.now();

  const fields = {};
  for (const k of FIELDS) {
    if (event && event[k] !== undefined) fields[k] = event[k];
  }
  if (Object.keys(fields).length === 0) return { ok: false, reason: 'bad_request' };

  const check = resident.canSaveProfile({ nick: fields.nick, whisper: fields.whisper });
  if (!check.ok) return check;
  if (fields.check_in_name !== undefined) {
    const ci = resident.canCheckIn(fields.check_in_name);
    if (!ci.ok) return ci;
    fields.check_in_name = fields.check_in_name.trim();
  }

  if (fields.blessing !== undefined) {
    // 迎宾院签到的一句公开祝福（01 E 10/2，迎宾院玩家说明 v1）：1～30 字、过敏感词（不查保留名），
    // 命中就整次不写库、返回 {ok:false, reason:'sensitive', field:'blessing'}，客户端回到祝福那屏说「换个说法吧」，
    // 前面填的名字、礼金不丢（客户端留着）。存在 resident 自己那条，blessing_at 是最后一次写的时间，祝福牌按它排
    const bl = resident.canBless(fields.blessing);
    if (!bl.ok) return bl;
    fields.blessing = fields.blessing.trim();
    const wc = sensitive.checkText(fields.blessing, { sensitiveMatcher: SENSITIVE_MATCHER });
    if (!wc.ok) return { ok: false, reason: wc.reason, field: 'blessing' };
    // 自己的词库过了再问微信：不过跟敏感词走同一条路（客户端说「换个说法吧」），sec 只是留着查日志
    const sc = await secCheck(fields.blessing, OPENID);
    if (!sc.ok) return { ok: false, reason: 'sensitive', field: 'blessing', sec: sc.sec };
    fields.blessing_at = now;
  }
  const existing = await db.collection('resident').doc(OPENID).get().catch(() => null);
  const existingData = existing && existing.data;

  if (fields.nick !== undefined) {
    const nickCheck = await checkName(fields.nick, [existingData && existingData.nick], OPENID);
    if (!nickCheck.ok) return nickCheck; // reason: 'sensitive' | 'reserved'，不写库
  }
  if (fields.check_in_name !== undefined) {
    // 签到名字默认带昵称：跟自己现有的昵称、这次一起存的昵称一样的，保留名不拦
    const nameCheck = await checkName(fields.check_in_name, [existingData && existingData.nick, fields.nick], OPENID);
    if (!nameCheck.ok) return nameCheck; // 不写库，客户端退回签到第一页显示原因
    fields.checked_in_at = (existingData && existingData.checked_in_at) || now; // 第一次签到的时间，再签不改
  }
  if (fields.gift_value !== undefined) fields.gift_value = resident.clampGiftValue(fields.gift_value);

  // 席间小游戏：只做类型和范围的兜底，不合格就丢这一个字段，不影响其它字段照常存（蓝图 3.2）
  if (fields.coins !== undefined) {
    const v = resident.sanitizeCoins(fields.coins);
    if (v === undefined) delete fields.coins; else fields.coins = v;
  }
  if (fields.gift_coins !== undefined) {
    const v = resident.sanitizeCoins(fields.gift_coins);
    if (v === undefined) delete fields.gift_coins; else fields.gift_coins = v;
  }
  if (fields.games !== undefined) {
    const v = resident.sanitizeGames(fields.games);
    if (v === undefined) {
      delete fields.games;
    } else {
      // 跟旧值合并再存：不能因为这次只传了一个游戏的进度，就把别的游戏已经存的进度冲掉
      const existingGames = (existingData && existingData.games && typeof existingData.games === 'object'
        && !Array.isArray(existingData.games)) ? existingData.games : {};
      fields.games = resident.mergeGames(existingGames, v);
    }
  }
  if (fields.dishes !== undefined) {
    const v = resident.sanitizeDishes(fields.dishes);
    if (v === undefined) {
      delete fields.dishes;
    } else {
      // 跟旧值取并集再存：数组类型字段云开发 update() 是整体覆盖，不像 games 那样能指望数据库
      // 帮忙按 key 合并，这一步必须服务端自己做，不然这次只传新解锁的一道菜会把旧的冲掉
      const existingDishes = Array.isArray(existingData && existingData.dishes) ? existingData.dishes : [];
      fields.dishes = resident.mergeDishes(existingDishes, v);
    }
  }

  // gift_add 不存进 resident：只用来决定要不要往 gift_coin 集合加一条礼金流水；
  // 不合格就不记这一笔，跟其它字段互不影响（存在 fields 之外的 giftAddCoins 里，写库之后再用）。
  let giftAddCoins = null;
  if (fields.gift_add !== undefined) {
    giftAddCoins = resident.sanitizeGiftAdd(fields.gift_add);
    delete fields.gift_add;
  }

  if (fields.inviter !== undefined) {
    if (!fields.inviter) {
      delete fields.inviter; // 空/假值当没传，不覆盖已有邀请人
    } else {
      const existingInviter = (existingData && existingData.inviter) || null;
      let inviterExists = false;
      if (fields.inviter !== OPENID) {
        const inviterDoc = await db.collection('resident').doc(fields.inviter).get().catch(() => null);
        inviterExists = !!(inviterDoc && inviterDoc.data);
      }
      const allowed = resident.canAdoptInviter({
        existingInviter, selfOpenid: OPENID, inviter: fields.inviter, inviterExists,
      });
      if (!allowed) delete fields.inviter;
    }
  }

  if (existingData) {
    if (Object.keys(fields).length > 0) {
      await db.collection('resident').doc(OPENID).update({ data: fields });
    }
  } else {
    await db.collection('resident').add({
      data: { _id: OPENID, openid: OPENID, created_at: now, checked_in_at: null, ...fields },
    });
  }

  if (giftAddCoins !== null) {
    // nick 用 resident 里现有的昵称：这次调用如果同时改了昵称就用刚存的新值，没改就用存量的旧值
    // （这就是"礼金簿记一笔『XX 添了 88 金』"，写进 gift_coin 集合，只有阿鱼在后台看）。
    const nick = fields.nick !== undefined ? fields.nick : ((existingData && existingData.nick) || '');
    try {
      await db.collection('gift_coin').add({
        data: { openid: OPENID, nick, coins: giftAddCoins, created_at: now },
      });
    } catch (e) {
      // gift_coin 集合还没建（云开发不一定帮忙自动建，initDb 注释里有前车之鉴）：先记在自己这条 resident 的
      // gift_log 上，这一笔不丢；控制台建好 gift_coin 以后照常记进集合（主程 9/19 加）
      await db.collection('resident').doc(OPENID)
        .update({ data: { gift_log: db.command.push([{ coins: giftAddCoins, created_at: now }]) } })
        .catch(() => null);
    }
  }

  // 签过到没有（这次签的，或者以前签过的）：客户端进山庄时据此让签到桌显示「已签到」
  const checkedIn = !!(fields.checked_in_at || (existingData && existingData.checked_in_at));
  return { ok: true, checked_in: checkedIn };
};
