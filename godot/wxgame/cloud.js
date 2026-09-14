// 微信登录：进镇流程「邀请卡片 → 微信授权 → 昵称」里的「授权」。
// 用云开发的 login 云函数（server-claude/cloudfunctions/login），不弹授权框，直接拿到自己的 openid。
// 在引擎下载的同时就去拿，结果放在 GameGlobal.__suqiUser，游戏里以后用它存名字、记邀请人。
// 日志里只打 openid 前 6 位。
// 只用老写法：开发者工具的编译器碰到新写法可能会崩。
var ENV = 'cloud1-d9ggg36tj34742bef';

GameGlobal.__suqiUser = { openid: '', state: 'pending' };

if (typeof wx !== 'undefined' && wx.cloud) {
    try {
        wx.cloud.init({ env: ENV, traceUser: false });
        var loginStart = Date.now();
        wx.cloud.callFunction({
            name: 'login',
            success: function (res) {
                var id = (res && res.result && res.result.openid) || '';
                GameGlobal.__suqiUser = { openid: id, state: id ? 'ok' : 'empty' };
                console.log('[suqi] 登录' + (id ? '成功' : '没拿到 openid') + ' 用时 ' + (Date.now() - loginStart) +
                    ' 毫秒 openid ' + id.slice(0, 6) + '…');
            },
            fail: function (err) {
                GameGlobal.__suqiUser = { openid: '', state: 'fail' };
                console.error('[suqi] 登录失败 ' + (err && err.errMsg ? err.errMsg : String(err)));
            },
        });
    } catch (e) {
        console.error('[suqi] 登录出错 ' + (e && e.message));
    }
} else {
    console.error('[suqi] 没有 wx.cloud，登录不了');
}
