// 右上角「···」里的转发：小游戏默认是灰的，要自己打开。
// 卡片带上分享人的 id。现在是本机随机 id；接上登录以后换成住民 id（阶段 1 设计：用谁的卡片进来，就长在谁的枝上）。
// 点卡片进来的人，启动参数 query.from 里能读到分享人。结果打进日志，调试版的日志面板能看到。
// 只用老写法：开发者工具的编译器碰到新写法可能会崩。
var ID_KEY = 'suqi_local_id';

function localId() {
    var id = '';
    try { id = wx.getStorageSync(ID_KEY); } catch (e) { id = ''; }
    if (!id) {
        id = 'L' + Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36);
        try { wx.setStorageSync(ID_KEY, id); } catch (e) { /* 存不了就每次新生成 */ }
    }
    return id;
}

function card() {
    return {
        title: '苏七镇奇缘', // 卡片文案待阿鱼定，先只放游戏名
        imageUrl: 'images/share.jpg',
        query: 'from=' + localId(),
    };
}

function describe(opts, when) {
    var q = (opts && opts.query) || {};
    console.log('[suqi] ' + when + ' 场景 ' + (opts && opts.scene) +
        (q.from ? ' 邀请人 ' + q.from : ' 没有邀请人') + ' 本机 ' + localId());
}

if (typeof wx !== 'undefined') {
    if (wx.showShareMenu) wx.showShareMenu({ withShareTicket: true, menus: ['shareAppMessage', 'shareTimeline'] });
    if (wx.onShareAppMessage) wx.onShareAppMessage(card);
    if (wx.onShareTimeline) {
        wx.onShareTimeline(function () {
            var c = card();
            return { title: c.title, imageUrl: c.imageUrl, query: c.query };
        });
    }
    if (wx.getLaunchOptionsSync) describe(wx.getLaunchOptionsSync(), '启动');
    if (wx.onShow) wx.onShow(function (res) { describe(res, '回到前台'); });
}
