// 云函数 saveProfile：存昵称、形象、邀请人、签到礼金、悄悄话（resident 表，一人一条）。
// 昵称长度、悄悄话长度做了最小校验（rules/resident.js，回执 02-总策划答复-2 第 4 条）；
// 礼金夹到 0～9999，不拒绝。
// 敏感词/保留名校验（docs/敏感词模块-需求.md，回执 05）：nick 要过 rules/sensitive.js 的
// checkText，命中敏感词或保留名都不写库，直接把 {ok:false, reason} 原样返回给客户端；
// 悄悄话（whisper）不过滤，需求文档第 1 节写明私密祝福不改动现有逻辑。
// 客户端：wx.cloud.callFunction({ name: 'saveProfile', data: { nick, avatar, inviter, gift_value, whisper } })
// 传哪个字段就存哪个，没传的不动。
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

const FIELDS = ['nick', 'avatar', 'inviter', 'gift_value', 'whisper'];

// 词库文件由 scripts/sync-cf-rules.js 同步进这个云函数自己的 words/ 文件夹（部署前必须先跑同步）。
// 模块加载时读一次、建好 AC 自动机；同一个容器热启动的后续调用复用，不重复读文件、不重复建。
function readWordFile(name) {
  const file = path.join(__dirname, 'words', name);
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8').split(/\r?\n/).map(s => s.trim()).filter(Boolean);
}
const SENSITIVE_MATCHER = sensitive.buildMatcher(readWordFile('base.txt'));
const RESERVED_SET = new Set(readWordFile('reserved.txt').map(sensitive.normalize));

// 主角名单：阿鱼、Toretto 的 openid，存在 config/banquet（和 enterHall 分座用的是同一份，initDb 建的，先是空数组）
async function isVip(openid) {
  const doc = await db.collection('config').doc('banquet').get().catch(() => null);
  const ids = (doc && doc.data && doc.data.vip_openids) || [];
  return ids.indexOf(openid) !== -1;
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

  const existing = await db.collection('resident').doc(OPENID).get().catch(() => null);
  const existingData = existing && existing.data;

  if (fields.nick !== undefined) {
    const wordCheck = sensitive.checkText(fields.nick, {
      sensitiveMatcher: SENSITIVE_MATCHER, reservedSet: RESERVED_SET,
    });
    if (!wordCheck.ok) {
      // 保留名是留给主角的：主角名单（config/banquet 的 vip_openids，阿鱼和 Toretto）不拦；
      // 已经用着这个名字的人接着用也不拦（9/18 助理 01：阿鱼自己起名「阿鱼」不能被拦）。敏感词对谁都拦
      let exempt = false;
      if (wordCheck.reason === 'reserved') {
        const keepsOwnName = !!(existingData && typeof existingData.nick === 'string'
          && sensitive.normalize(existingData.nick) === sensitive.normalize(fields.nick));
        exempt = keepsOwnName || await isVip(OPENID);
      }
      if (!exempt) return wordCheck; // reason: 'sensitive' | 'reserved'，不写库
    }
  }
  if (fields.gift_value !== undefined) fields.gift_value = resident.clampGiftValue(fields.gift_value);

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
  return { ok: true };
};
