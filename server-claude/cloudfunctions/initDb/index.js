// 云函数 initDb：建宴会厅要用的数据表（云开发数据库集合）。
// 微信开发者工具的 CLI 没有建集合的命令，只能在云函数里用管理员权限的 SDK 建；
// 所以专门写这一个函数，建完之后不用管它，重复跑也没事（已存在的集合、已有的配置文档都会跳过）。
// 建完集合后，权限（全部「仅创建者可读写」）还要去云开发控制台手动设置，这个函数不改权限。
// 客户端不要调这个函数；只在部署后手动调一次。
// 部署：见 server-claude/README.md「云函数」
const cloud = require('wx-server-sdk');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

const COLLECTIONS = ['resident', 'seat', 'toast', 'guestbook', 'friend_request', 'config'];

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

  // config/banquet：阿鱼、Toretto 的 openid，还没有就留空数组，enterHall 会按空处理
  // （回执 02-总策划答复-2 第 3 条：不写死在代码里，等后台脚本把两人的 openid 填进来）
  let vipDoc = 'created';
  const existing = await db.collection('config').doc('banquet').get().catch(() => null);
  if (existing && existing.data) {
    vipDoc = 'existed';
  } else {
    await db.collection('config').add({ data: { _id: 'banquet', vip_openids: [] } });
  }

  return { ok: true, data: { created, existed, config_banquet: vipDoc } };
};
