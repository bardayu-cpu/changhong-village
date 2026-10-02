// 云函数 posterCode：迎宾院合影海报上的小程序码（01 E 10/2 定，迎宾院玩家说明 v1 第 3 条；可行性回执 godot/回执/迎宾院-海报-可行性.md 第 3 节）。
// 用云调用 wxacode.getUnlimited（不限数量、永久有效，不用 AppSecret），码里带分享人：scene = 'f=' + openid（30 位，上限 32）。
// 扫码进来的人在启动参数 query.scene 里拿到它，share.js 认成邀请人，邀请链跟转发卡片一样接上。
// 码打开哪个版本看 C.POSTER_CODE_ENV：正式发布前只能是 'trial'（体验版），只有体验成员扫得开（01 E 定，阿鱼知道）。
// 同一个人第二次要直接给存着的（poster_code 集合，一人一条；换了版本才重生成）。集合没建也不挡，照样回码，只是下次再生成。
// 回 base64，不经云存储（绕开「仅创建者可读写」，canvasFile 那次就是被它卡的）。客户端写成文件交给 Godot（wxgame/poster.js 的 @posterCode）。
// 客户端：wx.cloud.callFunction({ name: 'posterCode', data: {} }) → { ok, b64, cached } 或 { ok:false, reason:'code_failed', errCode }
// 要 config.json 开 openapi 权限 wxacode.getUnlimited。10/2 新写，**没部署**：部署要阿鱼在 02 窗口点头
const cloud = require('wx-server-sdk');
const C = require('./rules/config');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

exports.main = async () => {
  const { OPENID } = cloud.getWXContext();
  if (!OPENID) return { ok: false, reason: 'bad_request' };
  const env = C.POSTER_CODE_ENV;
  const old = await db.collection('poster_code').doc(OPENID).get().catch(() => null);
  if (old && old.data && old.data.b64 && old.data.env === env) {
    return { ok: true, b64: old.data.b64, cached: true };
  }
  let buf;
  try {
    const r = await cloud.openapi.wxacode.getUnlimited({
      scene: 'f=' + OPENID,
      envVersion: env,
      checkPath: false,
      width: C.POSTER_CODE_WIDTH,
    });
    if (!r || (r.errCode !== undefined && r.errCode !== 0) || !r.buffer) {
      console.error('posterCode 生成失败', r && r.errCode, r && r.errMsg);
      return { ok: false, reason: 'code_failed', errCode: (r && r.errCode) || -1 };
    }
    buf = r.buffer;
  } catch (e) {
    console.error('posterCode 出错', e && (e.errCode || e.message));
    return { ok: false, reason: 'code_failed', errCode: (e && e.errCode) || -1 };
  }
  const b64 = Buffer.from(buf).toString('base64');
  const data = { openid: OPENID, b64, env, created_at: Date.now() };
  try {
    if (old && old.data) await db.collection('poster_code').doc(OPENID).update({ data });
    else await db.collection('poster_code').add({ data: { _id: OPENID, ...data } });
  } catch (e) {
    console.error('posterCode 存不进 poster_code（集合没建？），这次照样回码', e && e.message);
  }
  return { ok: true, b64, cached: false };
};
