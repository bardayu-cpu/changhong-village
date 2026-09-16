// 云函数 saveProfile：存昵称、形象、邀请人、签到礼金、悄悄话（resident 表，一人一条）。
// 昵称长度、悄悄话长度做了最小校验（rules/resident.js，回执 02-总策划答复-2 第 4 条）；
// 礼金夹到 0～9999，不拒绝。完整的字符集、敏感词校验见 docs/敏感词模块-需求.md，还没做。
// 客户端：wx.cloud.callFunction({ name: 'saveProfile', data: { nick, avatar, inviter, gift_value, whisper } })
// 传哪个字段就存哪个，没传的不动。
//
// 邀请人只存第一次（回执 03 第 3 项，依据阶段 1 设计"用谁的链接进来，就长在谁的枝上"）：
// 传了 inviter 时，只有同时满足"自己还没有邀请人、不是自己、这个人在 resident 表里存在"才会
// 真的写进去；不满足就只丢掉 inviter 这一个字段，nick/avatar 等其它字段照常存、照常返回
// {ok:true}，不能因为邀请人不对让整次保存失败。判定逻辑在 rules/resident.js 的 canAdoptInviter
// （同步自 src/resident.js），这里只负责把要判定的四个输入准备好。
const cloud = require('wx-server-sdk');
const resident = require('./rules/resident');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

const FIELDS = ['nick', 'avatar', 'inviter', 'gift_value', 'whisper'];

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
  if (fields.gift_value !== undefined) fields.gift_value = resident.clampGiftValue(fields.gift_value);

  const existing = await db.collection('resident').doc(OPENID).get().catch(() => null);
  const existingData = existing && existing.data;

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
