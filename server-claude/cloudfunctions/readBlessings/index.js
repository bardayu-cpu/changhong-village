// 云函数 readBlessings：迎宾院祝福牌，读最近写下的公开祝福（01 E 10/2，迎宾院玩家说明 v1 第 1 条）。
// 祝福是签到时 saveProfile 存进 resident 自己那条的 blessing / blessing_at（已经过了敏感词）；
// 这里按 blessing_at 从新到旧取最近 C.BLESSING_READ_MAX 条，带上写的人签到时的名字（没有就用昵称）。
// 客户端：wx.cloud.callFunction({ name: 'readBlessings', data: {} }) → { ok, items: [{ name, text, at }] }
// 10/2 新写，**没部署**：部署要阿鱼在 02 窗口点头（连同改过的 saveProfile）
const cloud = require('wx-server-sdk');
const C = require('./rules/config');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();
const _ = db.command;

exports.main = async () => {
  const res = await db.collection('resident')
    .where({ blessing_at: _.gt(0) })
    .orderBy('blessing_at', 'desc')
    .limit(C.BLESSING_READ_MAX)
    .get();
  const items = (res.data || [])
    .filter(d => typeof d.blessing === 'string' && d.blessing !== '')
    .map(d => ({ name: d.check_in_name || d.nick || '', text: d.blessing, at: d.blessing_at }));
  return { ok: true, items };
};
