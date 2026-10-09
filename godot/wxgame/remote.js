// 远程加载的最小验证（HANDOFF §0.9，01 9/19 派；回执 godot/回执/远程加载-最小验证.md）。只进调试版。
// 只证明这条路在真机上通，不是正式加载器：Godot 经云桥发来 {fileID, path}（桥怎么走见 cloud.js 开头），这边
//   1) wx.cloud.downloadFile 从云存储下到微信的临时文件（不用配合法域名）
//   2) readFile 读成 ArrayBuffer
//   3) GODOTSDK.copy_to_fs(path, buffer) 写进 Godot 的文件系统。path 是 Godot 给的 user:// 绝对路径（/userfs/...），
//      模板把 /userfs 挂成 WXMEMFS：写完关文件时同步写到 wx.env.USER_DATA_PATH 下，下次启动挂载时读回来，所以第二次打开不用再下。
//      不能自己往 USER_DATA_PATH 写：引擎只在启动挂载时读一次，这次运行 Godot 看不到
// 每一步用时放进结果带回去，Godot 那边打进「[suqi] 远程加载」日志。
// 下载失败时再问一次临时链接（wx.cloud.getTempFileURL），把它回的 status、errMsg 放进结果的 diag 带回去：
// 权限不够、文件不在、环境对不上，一般它会直接说（01 9/19：第 30 版真机只看到「empty download url」，分不出是哪种）。
// 注册在 GameGlobal.__suqiLocalFns 里，cloud.js 看到名字以 @ 开头就交给这里，不去调云函数。
// 两条路：@fetchFile 小程序自己从云存储下（要云存储「所有用户可读」）；@fetchChunks 走云函数 canvasFile 一块一块要
// （云函数有管理员权限，存储是「仅创建者可读写」也读得到，9/19 第 30 版真机查实走这条）。用哪条看 assets/remote_probe.json 的 via。
// 只用老写法：开发者工具的编译器碰到新写法可能会崩。

GameGlobal.__suqiLocalFns = GameGlobal.__suqiLocalFns || {};

// 问临时链接，结果交给 done(diag)。diag：env_in_id（File ID 里写的环境）、env_init（游戏 init 的环境）、
// status（0 是拿到了）、errMsg、url_host（拿到链接时链接的域名，不带签名）。最多等 DIAG_MS，不回就照样交
function diagnose(fileID, done) {
    var fired = false;
    var id = String(fileID);
    var diag = {
        env_in_id: id.replace(/^cloud:\/\//, '').split('.')[0],
        env_init: GameGlobal.__suqiEnv || '',
        id_len: id.length,
        id_clean: id === id.trim() && !/[\r\n\t ]/.test(id),   // File ID 首尾、中间有没有空白换行（复制粘贴带进来的）
    };
    try {
        diag.app_env = wx.getAccountInfoSync ? wx.getAccountInfoSync().miniProgram.envVersion : '';   // develop 开发版、trial 体验版、release 正式版
    } catch (e) {
        diag.app_env = '';
    }
    function finish() {
        if (fired) return;
        fired = true;
        console.log('[suqi] 远程加载 临时链接 ' + JSON.stringify(diag));
        done(diag);
    }
    if (!wx.cloud.getTempFileURL) {
        diag.errMsg = '没有 wx.cloud.getTempFileURL';
        finish();
        return;
    }
    setTimeout(function () {
        if (fired) return;
        diag.errMsg = '临时链接 ' + (GameGlobal.__suqiDiagMs || 8000) + ' 毫秒没回';
        finish();
    }, GameGlobal.__suqiDiagMs || 8000);
    try {
        wx.cloud.getTempFileURL({
            fileList: [fileID],
            success: function (res) {
                var f = res && res.fileList && res.fileList[0];
                if (!f) {
                    diag.errMsg = '临时链接没回 fileList';
                } else {
                    diag.status = f.status;
                    diag.errMsg = f.errMsg || '';
                    diag.url_host = f.tempFileURL ? String(f.tempFileURL).split('/')[2] || '' : '';
                }
                finish();
            },
            fail: function (err) {
                diag.errMsg = 'getTempFileURL 失败 ' + (err && err.errMsg ? err.errMsg : String(err));
                finish();
            },
        });
    } catch (e) {
        diag.errMsg = 'getTempFileURL 出错 ' + String(e && e.message ? e.message : e);
        finish();
    }
}

GameGlobal.__suqiLocalFns['@fetchFile'] = function (d, done) {
    var t0 = Date.now();
    if (!d || !d.fileID || !d.path) {
        done({ ok: false, reason: 'bad_request' });
        return;
    }
    var sdk = GameGlobal.GODOTSDK;
    if (!sdk || typeof sdk.copy_to_fs !== 'function') {
        done({ ok: false, reason: 'no_copy_to_fs', detail: '模板里没有 GODOTSDK.copy_to_fs' });
        return;
    }
    if (typeof wx === 'undefined' || !wx.cloud || !wx.cloud.downloadFile) {
        done({ ok: false, reason: 'network', detail: '没有 wx.cloud.downloadFile' });
        return;
    }
    console.log('[suqi] 远程加载 开始下载 ' + String(d.fileID).slice(-60));
    wx.cloud.downloadFile({
        fileID: d.fileID,
        success: function (res) {
            var t1 = Date.now();
            if (!res || !res.tempFilePath || (res.statusCode && res.statusCode !== 200)) {
                diagnose(d.fileID, function (diag) {
                    done({ ok: false, reason: 'download_failed', detail: '状态 ' + (res && res.statusCode), download_ms: t1 - t0, diag: diag });
                });
                return;
            }
            wx.getFileSystemManager().readFile({
                filePath: res.tempFilePath,
                success: function (r) {
                    var t2 = Date.now();
                    var buf = r && r.data;
                    if (!buf || typeof buf.byteLength !== 'number') {
                        done({ ok: false, reason: 'read_failed', detail: '读回来的不是 ArrayBuffer' });
                        return;
                    }
                    try {
                        sdk.copy_to_fs(d.path, buf);
                    } catch (e) {
                        done({ ok: false, reason: 'copy_failed', detail: String(e && e.message ? e.message : e) });
                        return;
                    }
                    var t3 = Date.now();
                    console.log('[suqi] 远程加载 写进 ' + d.path + ' ' + buf.byteLength + ' 字节');
                    done({ ok: true, bytes: buf.byteLength, download_ms: t1 - t0, read_ms: t2 - t1, write_ms: t3 - t2 });
                },
                fail: function (err) {
                    done({ ok: false, reason: 'read_failed', detail: err && err.errMsg ? err.errMsg : String(err) });
                },
            });
        },
        fail: function (err) {
            var ms = Date.now() - t0;
            diagnose(d.fileID, function (diag) {
                done({ ok: false, reason: 'download_failed', detail: err && err.errMsg ? err.errMsg : String(err), download_ms: ms, diag: diag });
            });
        },
    });
};

// ---------- 走云函数 canvasFile（HANDOFF §0.9）----------
// 一块一块要（每块 base64，服务端 CANVAS_CHUNK 256KB），解开拼进一个 Uint8Array，齐了用 GODOTSDK.copy_to_fs 写进 Godot 的文件系统。
// 块不经过 Godot 的云桥（桥只传一行请求、一行结果），在这边拼好。某一块网抖失败再要一次；云函数没部署回 no_function

var B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var B64_MAP = null;

// 把 base64 字符串解进 out（Uint8Array）从 at 开始的地方，返回解出多少字节。小游戏里不一定有 atob，自己解
function b64Into(s, out, at) {
    if (!B64_MAP) {
        B64_MAP = new Int16Array(128);
        for (var i = 0; i < 128; i++) B64_MAP[i] = -1;
        for (var j = 0; j < 64; j++) B64_MAP[B64.charCodeAt(j)] = j;
    }
    var n = 0;
    var bits = 0;
    var acc = 0;
    for (var k = 0; k < s.length; k++) {
        var c = s.charCodeAt(k);
        if (c === 61) break;                       // '=' 结尾
        var v = c < 128 ? B64_MAP[c] : -1;
        if (v < 0) continue;                       // 换行之类跳过
        acc = ((acc << 6) | v) & 0xffffff;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            if (at + n >= out.length) return -1;   // 比说好的大小多，不对
            out[at + n] = (acc >> bits) & 0xff;
            n++;
        }
    }
    return n;
}
GameGlobal.__suqiB64Into = b64Into;   // 测试用

GameGlobal.__suqiLocalFns['@fetchChunks'] = function (d, done) {
    var t0 = Date.now();
    if (!d || !d.fileID || !d.path) {
        done({ ok: false, reason: 'bad_request' });
        return;
    }
    var sdk = GameGlobal.GODOTSDK;
    if (!sdk || typeof sdk.copy_to_fs !== 'function') {
        done({ ok: false, reason: 'no_copy_to_fs', detail: '模板里没有 GODOTSDK.copy_to_fs' });
        return;
    }
    if (typeof wx === 'undefined' || !wx.cloud || !wx.cloud.callFunction) {
        done({ ok: false, reason: 'network', detail: '没有 wx.cloud.callFunction' });
        return;
    }
    var buf = null;
    var got = 0;
    var chunks = 0;
    var retried = 0;
    console.log('[suqi] 远程加载 走云函数 canvasFile ' + String(d.fileID).slice(-60));
    function fail(reason, detail) {
        console.log('[suqi] 远程加载 云函数这路失败 ' + reason + ' ' + detail);
        done({ ok: false, reason: reason, detail: detail, download_ms: Date.now() - t0, chunks: chunks });
    }
    function ask(offset, tries) {
        wx.cloud.callFunction({
            name: 'canvasFile',
            data: { fileID: d.fileID, offset: offset },
            success: function (res) {
                var r = res && res.result;
                if (!r || !r.ok) {
                    // 云函数自己说不行（不许读、文件不在）：不重试，原因带回去
                    fail((r && r.reason) || 'download_failed', 'canvasFile 第 ' + (chunks + 1) + ' 块：' + ((r && (r.detail || r.reason)) || '没回结果'));
                    return;
                }
                if (!buf) {
                    if (!(r.total > 0)) {
                        fail('download_failed', 'canvasFile 回的文件大小不对 ' + r.total);
                        return;
                    }
                    buf = new Uint8Array(r.total);
                }
                if (r.offset !== got || r.total !== buf.length) {
                    fail('download_failed', 'canvasFile 回的位置对不上 ' + r.offset + '/' + got);
                    return;
                }
                var n = b64Into(String(r.data || ''), buf, got);
                if (n !== r.size) {
                    fail('download_failed', '第 ' + (chunks + 1) + ' 块解出来 ' + n + ' 字节，应是 ' + r.size);
                    return;
                }
                got += n;
                chunks++;
                if (r.done || got >= buf.length) {
                    finish();
                    return;
                }
                ask(got, 0);
            },
            fail: function (err) {
                var msg = err && err.errMsg ? err.errMsg : String(err);
                if (/FunctionName|-501000|not found|不存在/i.test(msg)) {
                    fail('no_function', '云函数 canvasFile 还没部署：' + msg);
                    return;
                }
                if (tries < 1) {
                    retried++;
                    ask(offset, tries + 1);   // 网抖一下：这一块再要一次
                    return;
                }
                fail('download_failed', 'canvasFile 第 ' + (chunks + 1) + ' 块：' + msg);
            },
        });
    }
    function finish() {
        var t1 = Date.now();
        try {
            sdk.copy_to_fs(d.path, buf.buffer);
        } catch (e) {
            fail('copy_failed', String(e && e.message ? e.message : e));
            return;
        }
        var t2 = Date.now();
        console.log('[suqi] 远程加载 云函数 ' + chunks + ' 块 ' + got + ' 字节 写进 ' + d.path);
        done({ ok: true, bytes: got, download_ms: t1 - t0, read_ms: 0, write_ms: t2 - t1, chunks: chunks, retried: retried, via: 'function' });
    }
    ask(0, 0);
};
