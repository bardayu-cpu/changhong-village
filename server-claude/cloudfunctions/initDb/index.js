// 云函数 initDb：建宴会厅要用的 5 张数据表（云开发数据库集合）。
// 微信开发者工具的 CLI 没有建集合的命令，只能在云函数里用管理员权限的 SDK 建；
// 所以专门写这一个函数，建完之后不用管它，重复跑也没事（已存在的集合会跳过）。
// 建完集合后，权限（全部「仅创建者可读写」）还要去云开发控制台手动设置，这个函数不改权限。
// 客户端不要调这个函数；只在部署后手动调一次。
// 部署：见 server-claude/README.md「云函数」
const cloud = require('wx-server-sdk');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

const COLLECTIONS = ['resident', 'seat', 'toast', 'guestbook', 'friend_request'];

exports.main = async () => {
  const created = [];
  const existed = [];
  for (const name of COLLECTIONS) {
    try {
      await db.createCollection(name);
      created.push(name);
    } catch (e) {
      // -501001: 集合已存在
      if (e && (e.errCode === -501001 || /exist/i.test(e.errMsg || ''))) {
        existed.push(name);
      } else {
        return { ok: false, reason: 'create_failed', at: name, error: e && e.errMsg };
      }
    }
  }
  return { ok: true, data: { created, existed } };
};
