// 云函数 readBook：翻一桌的簿子，接龙列表。任何人都能翻，不要求坐过这桌（蓝图 3.2 交互说明：
// 「走到桌边任一处出翻簿子」，没说要坐过），坐过才能写的限制只在 writeBook 判。
// 客户端：wx.cloud.callFunction({ name: 'readBook', data: { table } })
const cloud = require('wx-server-sdk');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

exports.main = async (event) => {
  const { table } = event || {};
  if (!table) return { ok: false, reason: 'bad_request' };

  const { data } = await db.collection('guestbook')
    .where({ table_id: table })
    .orderBy('created_at', 'asc')
    .get();

  return { ok: true, data: { lines: data.map(l => ({ openid: l.openid, text: l.text, at: l.created_at })) } };
};
