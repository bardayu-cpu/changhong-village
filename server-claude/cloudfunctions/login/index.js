// 云函数 login：返回调用者自己的微信身份编号（openid）。
// 只读调用者本人的身份，不读、不存任何别的信息。进镇流程「邀请卡片 → 微信授权 → 昵称」里的「授权」就是这一步，
// 用云开发时不需要弹授权框。
// 客户端：wx.cloud.callFunction({ name: 'login' })
// 部署：见 server-claude/README.md「云函数」
const cloud = require('wx-server-sdk');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });

exports.main = async () => {
    const { OPENID, APPID } = cloud.getWXContext();
    return { openid: OPENID, appid: APPID };
};
