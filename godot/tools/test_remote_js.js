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
var mode = { download: 'ok', read: 'ok', copy: 'ok' };

global.GameGlobal = global;
global.wx = {
    cloud: {
        init: function () {},
        callFunction: function (o) {
            calls.push(o.name);
            setTimeout(function () { o.success({ result: o.name === 'login' ? { openid: 'op_test' } : { ok: true } }); }, 0);
        },
        downloadFile: function (o) {
            setTimeout(function () {
                if (mode.download === 'fail') o.fail({ errMsg: 'downloadFile:fail 假装没网' });
                else o.success({ tempFilePath: 'wxfile://tmp_' + o.fileID.slice(-8), statusCode: 200 });
            }, 5);
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
global.GODOTSDK = {
    copy_to_fs: function (path, buf) {
        if (mode.copy === 'throw') throw new Error('rtenv is null');
        copied.push({ path: path, len: buf.byteLength });
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
