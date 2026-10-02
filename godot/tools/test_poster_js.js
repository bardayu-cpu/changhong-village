// 合影海报，微信那一半（wxgame/poster.js，01 E 10/2 第三件）+ share.js 认海报码上的邀请人。
// 在电脑上用 node 装一个假的微信：假云函数 posterCode、假 GODOTSDK.copy_to_fs、假屏幕画布截图、假离屏画布、假分享弹窗。
// Godot 那一半：Godot --headless --path . --script res://tools/test_court_poster.gd
// 跑法：node tools/test_poster_js.js    最后一行 RESULT PASS 才算过

var ok = true;
function check(name, cond) {
    console.log((cond ? '  好 ' : '  不行 ') + name);
    ok = ok && !!cond;
}

var CODE = Buffer.from('PNG-假的小程序码-0123456789');
var mode = { code: 'ok', capture: 'ok', black: false, menu: true, menuResult: 'ok', copy: true };
var copied = [];       // copy_to_fs 收到的 {path, bytes}
var shotArgs = null;   // 屏幕画布 toTempFilePath 收到的参数
var shared = [];       // 分享弹窗 / 转发卡片收到的
var images = [];       // createImage 加载过的 src
var drawn = 0;         // 自己画了几张
var written = [];      // 写进微信用户目录的文件

function makeCtx() {
    return {
        fillRect: function () {}, beginPath: function () {}, arc: function () {}, fill: function () {},
        fillText: function () {}, drawImage: function () {},
        measureText: function (t) { return { width: String(t).length * 40 }; },
        getImageData: function (x, y, w, h) {
            var a = new Uint8ClampedArray(w * h * 4);
            if (!mode.black) for (var i = 0; i < a.length; i++) a[i] = 200;
            return { data: a };
        },
    };
}
var offscreen = 0;
global.GameGlobal = global;
GameGlobal.canvas = {
    width: 1080, height: 1920,
    toTempFilePath: function (o) {
        shotArgs = o;
        setTimeout(function () {
            if (mode.capture === 'fail') o.fail({ errMsg: 'toTempFilePath:fail 假装截不了' });
            else o.success({ tempFilePath: 'wxfile://tmp_shot.jpg' });
        }, 1);
    },
};
GameGlobal.GODOTSDK = {
    copy_to_fs: function (path, buf) {
        if (!mode.copy) throw new Error('假装写不进');
        copied.push({ path: path, bytes: Buffer.from(buf) });
    },
};
GameGlobal.__suqiUser = { openid: 'oSHARER0123456789abcdefghijk' };
global.wx = {
    env: { USER_DATA_PATH: 'wxfile://usr' },
    cloud: {
        callFunction: function (o) {
            setTimeout(function () {
                if (o.name !== 'posterCode') { o.success({ result: { ok: true } }); return; }
                if (mode.code === 'net') { o.fail({ errMsg: 'cloud.callFunction:fail 假装没网' }); return; }
                if (mode.code === 'no') { o.success({ result: { ok: false, reason: 'code_failed', errCode: 45009 } }); return; }
                o.success({ result: { ok: true, b64: CODE.toString('base64'), cached: false } });
            }, 1);
        },
    },
    getFileSystemManager: function () {
        return { writeFile: function (o) { written.push(o.filePath); setTimeout(function () { o.success(); }, 0); } };
    },
    createCanvas: function () {
        offscreen++;
        return {
            width: 0, height: 0,
            getContext: function () { return makeCtx(); },
            toTempFilePath: function (o) { drawn++; setTimeout(function () { o.success({ tempFilePath: 'wxfile://tmp_drawn.jpg' }); }, 1); },
        };
    },
    createImage: function () {
        var img = { width: 64, height: 84, onload: null, onerror: null };
        Object.defineProperty(img, 'src', {
            set: function (v) {
                images.push(v);
                setTimeout(function () { if (img.onload) img.onload(); }, 1);
            },
        });
        return img;
    },
    showShareImageMenu: function (o) {
        shared.push({ via: 'menu', path: o.path });
        setTimeout(function () {
            if (mode.menuResult === 'cancel') o.fail({ errMsg: 'showShareImageMenu:fail cancel' });
            else if (mode.menuResult === 'fail') o.fail({ errMsg: 'showShareImageMenu:fail 假装不行' });
            else o.success({});
        }, 1);
    },
    shareAppMessage: function (o) { shared.push({ via: 'card', path: o.imageUrl, query: o.query }); },
};

require('../wxgame/poster.js');
var fns = GameGlobal.__suqiLocalFns;

function call(name, d) {
    return new Promise(function (res) { fns[name](d, res); });
}
var REQ = { rect: { x: 44, y: 180, w: 452, h: 484 }, vw: 540, vh: 960,
    fallback: { preset: 2, pose: 'heart', line: '来苏七镇，吃阿鱼的喜酒', hint: '扫码进来坐坐', has_code: true } };

(async function () {
    console.log('1 小程序码');
    var r = await call('@posterCode', { path: '/userfs/poster/code.png' });
    check('拿到码写进 Godot（' + JSON.stringify(r) + '）', r.ok && copied.length === 1 && copied[0].path === '/userfs/poster/code.png' && copied[0].bytes.equals(CODE));
    await new Promise(function (res) { setTimeout(res, 5); });
    check('另存一份在微信用户目录给自己画的时候用', written.indexOf('wxfile://usr/suqi_poster_code.png') >= 0 && GameGlobal.__suqiPosterTest.codeFile() === 'wxfile://usr/suqi_poster_code.png');
    mode.code = 'no';
    r = await call('@posterCode', { path: '/userfs/poster/code.png' });
    check('云函数说生成不了：no_code（' + JSON.stringify(r) + '）', !r.ok && r.reason === 'no_code');
    mode.code = 'net';
    r = await call('@posterCode', { path: '/userfs/poster/code.png' });
    check('云函数没调通：no_code', !r.ok && r.reason === 'no_code');
    mode.code = 'ok';
    mode.copy = false;
    r = await call('@posterCode', { path: '/userfs/poster/code.png' });
    check('写不进 Godot：no_code（' + r.detail + '）', !r.ok && r.reason === 'no_code');
    mode.copy = true;
    await call('@posterCode', { path: '/userfs/poster/code.png' });
    await new Promise(function (res) { setTimeout(res, 5); });

    console.log('2 发给朋友：截屏');
    r = await call('@posterShare', REQ);
    check('截屏幕上海报那一块，按屏幕像素换算（x ' + shotArgs.x + ' y ' + shotArgs.y + ' 宽 ' + shotArgs.width + ' 高 ' + shotArgs.height + '，出图宽 ' + shotArgs.destWidth + '）',
        shotArgs.x === 88 && shotArgs.y === 360 && shotArgs.width === 904 && shotArgs.height === 968 && shotArgs.destWidth === 750);
    check('截下来不是黑的：直接开分享弹窗（' + JSON.stringify(r) + '）', r.ok && r.via === 'menu' && r.drawn === 'screen' && shared[shared.length - 1].path === 'wxfile://tmp_shot.jpg' && drawn === 0);

    console.log('3 截出来是黑的：自己画');
    mode.black = true;
    images = [];
    r = await call('@posterShare', REQ);
    check('自己画了一张再分享（' + JSON.stringify(r) + '）', r.ok && r.drawn === 'self' && drawn === 1 && shared[shared.length - 1].path === 'wxfile://tmp_drawn.jpg');
    check('画的时候用了新人合照、形象 2、码（' + images.filter(function (s) { return s.indexOf('tmp_shot') < 0; }).join(' ') + '）',
        images.indexOf('poster/couple.png') >= 0 && images.indexOf('poster/me_2.png') >= 0 && images.indexOf('wxfile://usr/suqi_poster_code.png') >= 0);
    mode.black = false;
    mode.capture = 'fail';
    r = await call('@posterShare', REQ);
    check('截不了也自己画（' + JSON.stringify(r) + '）', r.ok && r.drawn === 'self' && drawn === 2);
    mode.capture = 'ok';
    images = [];
    mode.black = true;
    r = await call('@posterShare', { rect: REQ.rect, vw: 540, vh: 960, fallback: { preset: 9, pose: 'wave', has_code: false } });
    check('只有照片那张自己画：不用码、形象号不对用 0（' + images.join(' ') + '）', r.ok && images.indexOf('wxfile://usr/suqi_poster_code.png') < 0 && images.indexOf('poster/me_0.png') >= 0);
    mode.black = false;

    console.log('4 分享弹窗');
    mode.menuResult = 'cancel';
    r = await call('@posterShare', REQ);
    check('自己点了取消不算失败', r.ok && r.cancel === true);
    mode.menuResult = 'fail';
    r = await call('@posterShare', REQ);
    check('弹窗出不来：share 失败（Godot 说「没发出去 再试一下」）', !r.ok && r.reason === 'share');
    mode.menuResult = 'ok';
    var menu = wx.showShareImageMenu;
    wx.showShareImageMenu = undefined;
    r = await call('@posterShare', REQ);
    var last = shared[shared.length - 1];
    check('基础库太老没有分享弹窗：退回转发卡片带图、带分享人（' + JSON.stringify(last) + '）', r.ok && r.via === 'card' && last.path === 'wxfile://tmp_shot.jpg' && last.query === 'from=oSHARER0123456789abcdefghijk');
    wx.showShareImageMenu = menu;
    r = await call('@posterShare', { vw: 540 });
    check('请求不全：bad_request', !r.ok && r.reason === 'bad_request');

    console.log('5 扫海报码进来：认邀请人（share.js）');
    global.wx.getLaunchOptionsSync = function () { return { scene: 1047, query: { scene: encodeURIComponent('f=oSHARER0123456789abcdefghijk') } }; };
    global.wx.showShareMenu = function () {};
    global.wx.onShareAppMessage = function () {};
    GameGlobal.__suqiInviter = '';
    require('../wxgame/share.js');
    check('扫码进来，邀请人记成分享人（' + GameGlobal.__suqiInviter + '）', GameGlobal.__suqiInviter === 'oSHARER0123456789abcdefghijk');
    var f = GameGlobal.__suqiFromScene;
    check('码里没有 f= 不认', f({ scene: 'x=1' }) === '' && f({}) === '');

    console.log(ok ? 'RESULT PASS' : 'RESULT FAIL');
    process.exit(ok ? 0 : 1);
})();
