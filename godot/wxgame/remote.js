// 远程加载的最小验证（HANDOFF §0.9，01 9/19 派；回执 godot/回执/远程加载-最小验证.md）。只进调试版。
// 只证明这条路在真机上通，不是正式加载器：Godot 经云桥发来 {fileID, path}（桥怎么走见 cloud.js 开头），这边
//   1) wx.cloud.downloadFile 从云存储下到微信的临时文件（不用配合法域名）
//   2) readFile 读成 ArrayBuffer
//   3) GODOTSDK.copy_to_fs(path, buffer) 写进 Godot 的文件系统。path 是 Godot 给的 user:// 绝对路径（/userfs/...），
//      模板把 /userfs 挂成 WXMEMFS：写完关文件时同步写到 wx.env.USER_DATA_PATH 下，下次启动挂载时读回来，所以第二次打开不用再下。
//      不能自己往 USER_DATA_PATH 写：引擎只在启动挂载时读一次，这次运行 Godot 看不到
// 每一步用时放进结果带回去，Godot 那边打进「[suqi] 远程加载」日志。
// 注册在 GameGlobal.__suqiLocalFns 里，cloud.js 看到名字以 @ 开头就交给这里，不去调云函数。
// 只用老写法：开发者工具的编译器碰到新写法可能会崩。

GameGlobal.__suqiLocalFns = GameGlobal.__suqiLocalFns || {};

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
                done({ ok: false, reason: 'download_failed', detail: '状态 ' + (res && res.statusCode), download_ms: t1 - t0 });
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
            done({ ok: false, reason: 'download_failed', detail: err && err.errMsg ? err.errMsg : String(err), download_ms: Date.now() - t0 });
        },
    });
};
