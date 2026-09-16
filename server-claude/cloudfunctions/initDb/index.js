// 云函数 initDb：只建 config/banquet 这一条配置文档。
// 改动记录：最早这个函数想用 db.createCollection() 顺手把 5 张业务表也建出来，
// 调用后报 "scf/Invoke 请求失败 [-3] system error"（不是我代码里 catch 得到的错误，
// 是云端调用本身崩溃）——大概率是 wx-server-sdk 在云函数里根本没有 createCollection
// 这个方法，我当时没有把握确认过就用了，现在去掉，不再猜。
// resident、seat、toast、guestbook、friend_request 这 5 张业务表请去
// 云开发控制台 → 数据库 → 新建集合，手动建（反正权限「仅创建者可读写」也要在那边手动设，
// 建集合和设权限在同一个界面，一起弄比较顺）。
// config 集合不用手动建：下面 db.collection('config').add() 第一次写文档时，
// 云函数用管理员权限写一个不存在的集合，云开发会自动把集合建出来，这个操作是有把握的。
// 客户端不要调这个函数；只在部署后手动调一次。
// 部署：见 server-claude/README.md「云函数」
const cloud = require('wx-server-sdk');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

exports.main = async () => {
  // config/banquet：阿鱼、Toretto 的 openid，还没有就留空数组，enterHall 会按空处理
  // （回执 02-总策划答复-2 第 3 条：不写死在代码里，等后台脚本把两人的 openid 填进来）
  const existing = await db.collection('config').doc('banquet').get().catch(() => null);
  if (existing && existing.data) {
    return { ok: true, data: { config_banquet: 'existed' } };
  }
  await db.collection('config').add({ data: { _id: 'banquet', vip_openids: [] } });
  return { ok: true, data: { config_banquet: 'created' } };
};
