// 远程加载的最小验证，微信那一半（wxgame/remote.js + cloud.js 里 @ 开头的转发，HANDOFF §0.9）。
// 在电脑上用 node 装一个假的微信环境：假 wx.cloud.downloadFile、假 readFile、假 GODOTSDK.copy_to_fs，
// 照真机上的样子一个字符一个字符「查名字」把请求送过去，再用无参 pop() 取结果。
// Godot 那一半：Godot --headless --path . --script res://tools/test_remote_probe.gd
// 跑法：node tools/test_remote_js.js    最后一行 RESULT PASS 才算过

var ok = true;
function check(name, cond) {
    console.log((cond ? '  好 ' : '  不行 ') + name);
    ok = ok && !!cond;
}

var BYTES = 2317820;
var calls = [];      // 调了哪些云函数
var copied = [];     // copy_to_fs 收到的 {path, len}
var mode = { download: 'ok', read: 'ok', copy: 'ok', temp: 'ok' };
var tempAsked = [];  // getTempFileURL 被问过哪些 fileID
var tempAskedAt21 = 0;
// 云函数 canvasFile 的假服务端：600KB 的「图」，一块 256KB（和 server-claude config.CANVAS_CHUNK 一样），base64 回
var FN_FILE = Buffer.alloc(600 * 1024);
for (var fi = 0; fi < FN_FILE.length; fi++) FN_FILE[fi] = (fi * 31 + 7) & 0xff;
var FN_CHUNK = 256 * 1024;
var fnMode = 'ok';   // ok；flaky 第一次调失败一次；missing 没部署；deny 云函数回不许读；skew 回的位置对不上
var fnCalls = 0;
var fnFlaked = false;
function canvasFile(data) {
    var off = data.offset || 0;
    if (fnMode === 'deny') return { ok: false, reason: 'bad_request' };
    var end = Math.min(off + FN_CHUNK, FN_FILE.length);
    var part = FN_FILE.subarray(off, end);
    return { ok: true, total: FN_FILE.length, offset: fnMode === 'skew' ? off + 1 : off, size: part.length, data: part.toString('base64'), done: end >= FN_FILE.length };
}

global.GameGlobal = global;
global.wx = {
    cloud: {
        init: function () {},
        callFunction: function (o) {
            calls.push(o.name);
            if (o.name === 'canvasFile') {
                fnCalls++;
                setTimeout(function () {
                    if (fnMode === 'missing') { o.fail({ errMsg: 'cloud.callFunction:fail -501000 [ResourceNotFound] FunctionName parameter could not be found.' }); return; }
                    if (fnMode === 'flaky' && !fnFlaked) { fnFlaked = true; o.fail({ errMsg: 'cloud.callFunction:fail 假装网抖' }); return; }
                    o.success({ result: canvasFile(o.data) });
                }, 2);
                return;
            }
            setTimeout(function () { o.success({ result: o.name === 'login' ? { openid: 'op_test' } : { ok: true } }); }, 0);
        },
        downloadFile: function (o) {
            setTimeout(function () {
                if (mode.download === 'fail') o.fail({ errMsg: 'downloadFile:fail 假装没网' });
                else if (mode.download === 'empty') o.fail({ errMsg: 'cloud.downloadFile:fail internal server error: empty download url' });
                else if (mode.download === 'status') o.success({ tempFilePath: '', statusCode: 403 });
                else o.success({ tempFilePath: 'wxfile://tmp_' + o.fileID.slice(-8), statusCode: 200 });
            }, 5);
        },
        // 临时链接：ok 拿得到；deny 没权限；gone 文件不在；fail 接口自己失败；silent 一直不回
        getTempFileURL: function (o) {
            tempAsked.push(o.fileList[0]);
            if (mode.temp === 'silent') return;
            setTimeout(function () {
                var id = o.fileList[0];
                if (mode.temp === 'fail') { o.fail({ errMsg: 'getTempFileURL:fail 假装没网' }); return; }
                var f = { fileID: id, tempFileURL: '', maxAge: 7200, status: 0, errMsg: 'ok' };
                if (mode.temp === 'ok') f.tempFileURL = 'https://636c-cloud1-test-1488216695.tcb.qcloud.la/canvas/scene_roman_banquet/base.png?sign=xyz';
                if (mode.temp === 'deny') { f.status = -1; f.errMsg = 'STORAGE_EXCEED_AUTHORITY'; }
                if (mode.temp === 'gone') { f.status = -1; f.errMsg = 'STORAGE_FILE_NONEXIST'; }
                o.success({ fileList: [f] });
            }, 3);
        },
    },
    getFileSystemManager: function () {
        return {
            readFile: function (o) {
                setTimeout(function () {
                    if (mode.read === 'fail') o.fail({ errMsg: 'readFile:fail 假装读不了' });
                    else o.success({ data: new ArrayBuffer(BYTES) });
                }, 1);
            },
        };
    },
};
global.__suqiEnv = 'cloud1-d9ggg36tj34742bef';   // 真机上是 cloud.js 设的
global.__suqiDiagMs = 60;                          // 临时链接等多久不回算了（真机 8 秒，测试里别等那么久）
global.GODOTSDK = {
    copy_to_fs: function (path, buf) {
        if (mode.copy === 'throw') throw new Error('rtenv is null');
        copied.push({ path: path, len: buf.byteLength, bytes: new Uint8Array(buf) });
    },
};

require('../wxgame/cloud.js');
require('../wxgame/remote.js');

// 照 godot/scripts/cloud.gd 的 encode_names 把一条请求拆成名字（A、B 两套轮流用），
// 再照导出模板的 resolveNamedObject 查一遍（每个名字读两遍）
var bank = false;
function send(msg) {
    var text = JSON.stringify(msg) + '\n';
    for (var i = 0; i < text.length; i++) {
        bank = !bank;
        var name = '__sqT' + (bank ? 'A' : 'B') + text[i];
        if (typeof global[name] !== 'undefined') { var v = global[name]; }
    }
}

function waitResult(id, cb) {
    var tries = 0;
    (function poll() {
        var s;
        while ((s = GameGlobal.__suqiCloud.pop()) !== '') {
            var m = JSON.parse(s);
            if (m.id === id) { cb(m.r); return; }
        }
        if (++tries > 200) { cb(null); return; }
        setTimeout(poll, 5);
    })();
}

var PATH = '/userfs/canvas/scene_roman_banquet/base.png';
var FID = 'cloud://cloud1-d9ggg36tj34742bef.test-bucket/canvas/scene_roman_banquet/base.png';
var steps = [
    function (next) {
        console.log('1 正常：下载、读、写进 Godot 的文件系统，带回每步用时');
        send({ id: 1, fn: '@fetchFile', d: { fileID: FID, path: PATH } });
        waitResult(1, function (r) {
            check('成功 ' + JSON.stringify(r), r && r.ok === true && r.bytes === BYTES);
            check('三步用时都在', r && typeof r.download_ms === 'number' && typeof r.read_ms === 'number' && typeof r.write_ms === 'number');
            check('copy_to_fs 收到的路径和大小对', copied.length === 1 && copied[0].path === PATH && copied[0].len === BYTES);
            check('没去调云函数', calls.indexOf('@fetchFile') < 0);
            next();
        });
    },
    function (next) {
        console.log('2 下载失败');
        mode.download = 'fail';
        send({ id: 2, fn: '@fetchFile', d: { fileID: FID, path: PATH } });
        waitResult(2, function (r) {
            mode.download = 'ok';
            check('download_failed ' + JSON.stringify(r), r && r.ok === false && r.reason === 'download_failed' && /没网/.test(r.detail));
            check('没写文件', copied.length === 1);
            next();
        });
    },
    function (next) {
        console.log('2b 真机那种「empty download url」：顺手问临时链接，说是没权限');
        mode.download = 'empty';
        mode.temp = 'deny';
        send({ id: 21, fn: '@fetchFile', d: { fileID: FID, path: PATH } });
        waitResult(21, function (r) {
            check('还是 download_failed，原话带着 ' + JSON.stringify(r && r.detail), r && r.ok === false && r.reason === 'download_failed' && /empty download url/.test(r.detail));
            check('问了临时链接，问的就是这个 File ID', tempAsked[tempAsked.length - 1] === FID);
            check('diag 带回 status、errMsg ' + JSON.stringify(r && r.diag), r && r.diag && r.diag.status === -1 && r.diag.errMsg === 'STORAGE_EXCEED_AUTHORITY');
            check('diag 带回两边的环境，对得上', r && r.diag && r.diag.env_in_id === 'cloud1-d9ggg36tj34742bef' && r.diag.env_init === 'cloud1-d9ggg36tj34742bef');
            check('diag 带回 File ID 长度、干不干净', r && r.diag && r.diag.id_len === FID.length && r.diag.id_clean === true);
            check('没写文件', copied.length === 1);
            next();
        });
    },
    function (next) {
        console.log('2c 文件不在');
        mode.temp = 'gone';
        send({ id: 22, fn: '@fetchFile', d: { fileID: FID, path: PATH } });
        waitResult(22, function (r) {
            check('errMsg 是文件不在 ' + JSON.stringify(r && r.diag), r && r.diag && r.diag.errMsg === 'STORAGE_FILE_NONEXIST');
            next();
        });
    },
    function (next) {
        console.log('2d 临时链接拿得到（文件在、有权限）：带回链接的域名，不带签名');
        mode.temp = 'ok';
        send({ id: 23, fn: '@fetchFile', d: { fileID: FID, path: PATH } });
        waitResult(23, function (r) {
            check('status 0、域名 ' + JSON.stringify(r && r.diag), r && r.diag && r.diag.status === 0 && r.diag.url_host === '636c-cloud1-test-1488216695.tcb.qcloud.la' && !/sign/.test(JSON.stringify(r.diag)));
            next();
        });
    },
    function (next) {
        console.log('2e 临时链接接口自己失败、一直不回：照样把下载失败交回去');
        mode.temp = 'fail';
        send({ id: 24, fn: '@fetchFile', d: { fileID: FID, path: PATH } });
        waitResult(24, function (r) {
            check('接口失败也交回 ' + JSON.stringify(r && r.diag), r && r.reason === 'download_failed' && r.diag && /getTempFileURL 失败/.test(r.diag.errMsg));
            mode.temp = 'silent';
            send({ id: 25, fn: '@fetchFile', d: { fileID: FID, path: PATH } });
            waitResult(25, function (r2) {
                check('一直不回也交回 ' + JSON.stringify(r2 && r2.diag), r2 && r2.reason === 'download_failed' && r2.diag && /没回/.test(r2.diag.errMsg));
                next();
            });
        });
    },
    function (next) {
        console.log('2f 下载「成功」却没有临时文件（状态 403）：一样问临时链接');
        mode.download = 'status';
        mode.temp = 'deny';
        send({ id: 26, fn: '@fetchFile', d: { fileID: FID, path: PATH } });
        waitResult(26, function (r) {
            mode.download = 'ok';
            mode.temp = 'ok';
            check('状态 403 也带 diag ' + JSON.stringify(r), r && r.reason === 'download_failed' && /403/.test(r.detail) && r.diag && r.diag.errMsg === 'STORAGE_EXCEED_AUTHORITY');
            next();
        });
    },
    function (next) {
        console.log('2g 下载成功的时候不去问临时链接');
        var asked = tempAsked.length;
        tempAskedAt21 = asked;
        send({ id: 27, fn: '@fetchFile', d: { fileID: FID, path: PATH } });
        waitResult(27, function (r) {
            check('成功、没问临时链接', r && r.ok === true && tempAsked.length === asked);
            next();
        });
    },
    function (next) {
        console.log('2h 走云函数 canvasFile：一块一块要，拼起来和原图一样，写进 Godot 的文件系统');
        var before = copied.length;
        fnCalls = 0;
        send({ id: 31, fn: '@fetchChunks', d: { fileID: FID, path: PATH } });
        waitResult(31, function (r) {
            check('成功 ' + JSON.stringify(r), r && r.ok === true && r.bytes === FN_FILE.length && r.chunks === 3 && r.via === 'function');
            check('调了 3 次 canvasFile', fnCalls === 3);
            var c = copied[copied.length - 1];
            check('copy_to_fs 收到的和原图一字节不差', copied.length === before + 1 && c.path === PATH && c.len === FN_FILE.length && Buffer.from(c.bytes).equals(FN_FILE));
            check('没去问临时链接、没走 downloadFile', tempAsked.length === tempAskedAt21);
            next();
        });
    },
    function (next) {
        console.log('2i 某一块网抖失败：再要一次，照样成功');
        fnMode = 'flaky';
        fnFlaked = false;
        send({ id: 32, fn: '@fetchChunks', d: { fileID: FID, path: PATH } });
        waitResult(32, function (r) {
            fnMode = 'ok';
            check('重试 1 次成功 ' + JSON.stringify(r), r && r.ok === true && r.retried === 1 && r.bytes === FN_FILE.length);
            next();
        });
    },
    function (next) {
        console.log('2j 云函数还没部署：回 no_function，说清楚');
        fnMode = 'missing';
        var before = copied.length;
        send({ id: 33, fn: '@fetchChunks', d: { fileID: FID, path: PATH } });
        waitResult(33, function (r) {
            fnMode = 'ok';
            check('no_function ' + JSON.stringify(r), r && r.ok === false && r.reason === 'no_function' && /还没部署/.test(r.detail));
            check('没写文件', copied.length === before);
            next();
        });
    },
    function (next) {
        console.log('2k 云函数说不许读、回的位置对不上：不重试，原因带回');
        fnMode = 'deny';
        send({ id: 34, fn: '@fetchChunks', d: { fileID: FID, path: PATH } });
        waitResult(34, function (r) {
            check('不许读 ' + JSON.stringify(r), r && r.ok === false && r.reason === 'bad_request' && /第 1 块/.test(r.detail));
            fnMode = 'skew';
            send({ id: 35, fn: '@fetchChunks', d: { fileID: FID, path: PATH } });
            waitResult(35, function (r2) {
                fnMode = 'ok';
                check('位置对不上 ' + JSON.stringify(r2), r2 && r2.ok === false && r2.reason === 'download_failed' && /对不上/.test(r2.detail));
                next();
            });
        });
    },
    function (next) {
        console.log('3 临时文件读不了');
        mode.read = 'fail';
        send({ id: 3, fn: '@fetchFile', d: { fileID: FID, path: PATH } });
        waitResult(3, function (r) {
            mode.read = 'ok';
            check('read_failed ' + JSON.stringify(r), r && r.ok === false && r.reason === 'read_failed');
            next();
        });
    },
    function (next) {
        console.log('4 copy_to_fs 抛错（比如引擎还没起来）');
        mode.copy = 'throw';
        send({ id: 4, fn: '@fetchFile', d: { fileID: FID, path: PATH } });
        waitResult(4, function (r) {
            mode.copy = 'ok';
            check('copy_failed ' + JSON.stringify(r), r && r.ok === false && r.reason === 'copy_failed' && /rtenv/.test(r.detail));
            next();
        });
    },
    function (next) {
        console.log('5 模板里没有 GODOTSDK');
        var keep = global.GODOTSDK;
        delete global.GODOTSDK;
        send({ id: 5, fn: '@fetchFile', d: { fileID: FID, path: PATH } });
        waitResult(5, function (r) {
            global.GODOTSDK = keep;
            check('no_copy_to_fs ' + JSON.stringify(r), r && r.ok === false && r.reason === 'no_copy_to_fs');
            next();
        });
    },
    function (next) {
        console.log('6 少 fileID、没有这个本地功能');
        send({ id: 6, fn: '@fetchFile', d: { path: PATH } });
        send({ id: 7, fn: '@noSuchThing', d: {} });
        waitResult(6, function (r6) {
            check('少 fileID 回 bad_request', r6 && r6.reason === 'bad_request');
            waitResult(7, function (r7) {
                check('没有的本地功能回 no_handler', r7 && r7.reason === 'no_handler');
                next();
            });
        });
    },
    function (next) {
        console.log('7 普通云函数照旧走 wx.cloud.callFunction');
        send({ id: 8, fn: 'enterHall', d: {} });
        waitResult(8, function (r) {
            check('enterHall 调到了', r && r.ok === true && calls.indexOf('enterHall') >= 0);
            next();
        });
    },
];

(function run(i) {
    if (i >= steps.length) {
        console.log('RESULT ' + (ok ? 'PASS' : 'FAIL'));
        process.exit(ok ? 0 : 1);
    }
    steps[i](function () { run(i + 1); });
})(0);
