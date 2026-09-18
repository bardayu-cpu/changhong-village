// 云函数 writeBook：在桌簿接一句。
// 判定逻辑在 rules/banquet.js，部署前用 node scripts/sync-cf-rules.js 同步。
// 客户端：wx.cloud.callFunction({ name: 'writeBook', data: { table, text } })
// 蓝图 3.2 9/18 改：只能写「现在坐的那桌」（seat 表的 table_id），不再是「坐过的桌都能写」（sat_tables）；
// 长凳的人 table_id 是 bench，跟任何桌都对不上，写哪桌都会被 canWriteBook 判 not_sat_here。
// 敏感词校验（docs/敏感词模块-需求.md，回执 05）：text 过 rules/sensitive.js 的 checkText，
// 只查敏感词、不查保留名（保留名只在起昵称时查）；命中就不写库，直接返回 {ok:false, reason:'sensitive'}。
// canWriteBook 本身仍然不判（保持纯函数、不做 I/O），敏感词这一步单独加在它之后。
const fs = require('fs');
const path = require('path');
const cloud = require('wx-server-sdk');
const banquet = require('./rules/banquet');
const sensitive = require('./rules/sensitive');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

// 词库文件由 scripts/sync-cf-rules.js 同步进这个云函数自己的 words/ 文件夹（部署前必须先跑同步）。
// 模块加载时读一次、建好 AC 自动机；同一个容器热启动的后续调用复用，不重复读文件、不重复建。
function readWordFile(name) {
  const file = path.join(__dirname, 'words', name);
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8').split(/\r?\n/).map(s => s.trim()).filter(Boolean);
}
const SENSITIVE_MATCHER = sensitive.buildMatcher(readWordFile('base.txt'));

exports.main = async (event) => {
  const { table, text } = event || {};
  if (!table || typeof text !== 'string') return { ok: false, reason: 'bad_request' };

  const { OPENID } = cloud.getWXContext();
  const now = Date.now();

  const mySeatDoc = await db.collection('seat').doc(OPENID).get().catch(() => null);
  const mySeat = mySeatDoc && mySeatDoc.data;
  if (!mySeat) return { ok: false, reason: 'no_seat' };

  const result = banquet.canWriteBook({ table, mySeatTableId: mySeat.table_id, text });
  if (!result.ok) return result;

  const wordCheck = sensitive.checkText(text, { sensitiveMatcher: SENSITIVE_MATCHER });
  if (!wordCheck.ok) return wordCheck; // reason: 'sensitive'，不写库

  await db.collection('guestbook').add({ data: { table_id: table, openid: OPENID, text, created_at: now } });
  return { ok: true };
};
