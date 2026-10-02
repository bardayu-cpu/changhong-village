// 右上角「···」里的转发：小游戏默认是灰的，要自己打开。
// 邀请链（蓝图 3.2，9/18 接通）：卡片带上分享人自己的 openid（登录拿到的，见 cloud.js），
// 点卡片进来的人，启动参数 query.from 里就是邀请人。记在 GameGlobal.__suqiInviter，
// Godot 那边第一次存资料时带上（saveProfile 只认第一次、不认自己、不认查无此人，服务端判）。
// 日志里 openid 只打前 6 位。只用老写法：开发者工具的编译器碰到新写法可能会崩。

function myOpenid() {
    return (GameGlobal.__suqiUser && GameGlobal.__suqiUser.openid) || '';
}

function card() {
    var me = myOpenid();
    return {
        title: '苏七镇奇缘', // 卡片文案待阿鱼定，先只放游戏名
        imageUrl: 'images/share.jpg',
        // 登录还没回来时拿不到自己的 id，就不带：带个本机随机号服务端也不认
        query: me ? 'from=' + me : '',
    };
}

function short(id) {
    return id ? String(id).slice(0, 6) + '…' : '（空）';
}

// 合影海报上的小程序码（posterCode 云函数，10/2）：码里的 scene 是 'f=' + 分享人 openid，扫码进来时在 query.scene（可能被编码过）
function fromScene(q) {
    if (!q || !q.scene) return '';
    var s = String(q.scene);
    try { s = decodeURIComponent(s); } catch (e) { /* 不是编码过的就照原样 */ }
    var m = /(?:^|&)f=([^&]+)/.exec(s);
    return m ? m[1] : '';
}
GameGlobal.__suqiFromScene = fromScene;   // 测试用

function takeInviter(opts, when) {
    var q = (opts && opts.query) || {};
    var from = q.from ? String(q.from) : fromScene(q);
    // 只记第一次看到的邀请人；本机随机号（L 开头，旧卡片）不是 openid，不记
    if (from && from.charAt(0) !== 'L' && !GameGlobal.__suqiInviter) {
        GameGlobal.__suqiInviter = from;
    }
    console.log('[suqi] ' + when + ' 场景 ' + (opts && opts.scene) +
        (from ? ' 卡片、海报码上的邀请人 ' + short(from) : ' 没有邀请人') +
        ' 记下的邀请人 ' + short(GameGlobal.__suqiInviter || ''));
}

GameGlobal.__suqiInviter = GameGlobal.__suqiInviter || '';

if (typeof wx !== 'undefined') {
    if (wx.showShareMenu) wx.showShareMenu({ withShareTicket: true, menus: ['shareAppMessage', 'shareTimeline'] });
    if (wx.onShareAppMessage) wx.onShareAppMessage(card);
    if (wx.onShareTimeline) {
        wx.onShareTimeline(function () {
            var c = card();
            return { title: c.title, imageUrl: c.imageUrl, query: c.query };
        });
    }
    if (wx.getLaunchOptionsSync) takeInviter(wx.getLaunchOptionsSync(), '启动');
    if (wx.onShow) wx.onShow(function (res) { takeInviter(res, '回到前台'); });
}
