// 云函数 saveProfile：存昵称、形象、邀请人、签到礼金、悄悄话（resident 表，一人一条）。
// 这几个字段各自的校验规则（昵称长度、敏感词、礼金上限）在蓝图 3.1，不在这次任务卡对应的
// 3.2 范围内，也没有对应的纯函数，这里先只做存取，不做校验。校验谁来接、什么时候接，写进回执。
// 客户端：wx.cloud.callFunction({ name: 'saveProfile', data: { nick, avatar, inviter, gift_value, whisper } })
// 传哪个字段就存哪个，没传的不动。
const cloud = require('wx-server-sdk');

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
