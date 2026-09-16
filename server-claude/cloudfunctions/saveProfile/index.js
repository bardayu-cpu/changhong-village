// 云函数 saveProfile：存昵称、形象、邀请人、签到礼金、悄悄话（resident 表，一人一条）。
// 昵称长度、悄悄话长度做了最小校验（rules/resident.js，回执 02-总策划答复-2 第 4 条）；
// 礼金夹到 0～9999，不拒绝。完整的字符集、敏感词校验见 docs/敏感词模块-需求.md，还没做。
// 客户端：wx.cloud.callFunction({ name: 'saveProfile', data: { nick, avatar, inviter, gift_value, whisper } })
// 传哪个字段就存哪个，没传的不动。
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
  if (existing && existing.data) {
    await db.collection('resident').doc(OPENID).update({ data: fields });
  } else {
    await db.collection('resident').add({
      data: { _id: OPENID, openid: OPENID, created_at: now, checked_in_at: null, ...fields },
    });
  }
  return { ok: true };
};
