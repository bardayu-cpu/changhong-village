// 云函数 readBook：翻一桌的簿子，接龙列表。任何人都能翻，不要求坐过这桌（蓝图 3.2 交互说明：
// 「走到桌边任一处出翻簿子」，没说要坐过），坐过才能写的限制只在 writeBook 判。
// 只带回最近 BANQUET_BOOK_READ_MAX 条（回执 03 第 1 项）：云开发 get() 不写 limit 时一次最多
// 回 100 条，原来 orderBy('created_at','asc') 不设 limit，桌簿写满 100 条后新句子反而看不到
// （拿到的是最老的 100 条）。改成按 created_at 倒序分页取最新一批，取够了再翻回正序返回，
// data.lines 每一条的字段结构不变。
// 客户端：wx.cloud.callFunction({ name: 'readBook', data: { table } })
const cloud = require('wx-server-sdk');
const C = require('./rules/config');
const { fetchAllPages } = require('./lib/db-page');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

exports.main = async (event) => {
  const { table } = event || {};
  if (!table) return { ok: false, reason: 'bad_request' };

  // 倒序（最新的在前）分页取够 BANQUET_BOOK_READ_MAX 条就停，再整体反转回正序——
  // 这样超过上限时丢掉的是最老的句子，留下的是最新的对话，跟原来"接龙从头看"的直觉不太一样，
  // 但原来的写法在超过 100 条时其实是静默丢最新的（更糟），这个改动待验证（回执 03）。
  const rowsDesc = await fetchAllPages(
    () => db.collection('guestbook').where({ table_id: table }),
    { orderBy: [['created_at', 'desc'], ['_id', 'desc']], maxTotal: C.BANQUET_BOOK_READ_MAX },
  );
  const rows = rowsDesc.slice().reverse();

  return { ok: true, data: { lines: rows.map(l => ({ openid: l.openid, text: l.text, at: l.created_at })) } };
};
