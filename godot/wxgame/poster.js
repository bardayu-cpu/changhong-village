// 迎宾院合影海报（01 E 10/2 定；迎宾院玩家说明 v1 第 3 条；可行性回执 godot/回执/迎宾院-海报-可行性.md，试验在 poster-trial 分支）。
// 海报的样子 Godot 自己在屏幕上拼好（相纸 + 一句话 + 小程序码 + 「扫码进来坐坐」），这边只做 Godot 做不了的两件事：
//   @posterCode {path}：调云函数 posterCode 拿带分享人的小程序码（base64），写进 Godot 的文件系统 path（user:// 的绝对路径），
//                       Godot 读成图摆进海报。写法跟 remote.js 一样走模板的 GODOTSDK.copy_to_fs
//   @posterShare {rect, vw, vh, fallback}：把屏幕上海报那一块截成图（屏幕画布 toTempFilePath，不读显卡，README：get_image 在微信里崩），
//                       交给微信自己的分享图片弹窗 wx.showShareImageMenu（发给朋友、收藏、下载都在里面；01 E：第一版只这一个按钮）。
//                       基础库太老没有这个弹窗，退回 wx.shareAppMessage 带图转发
// 截出来是黑的（屏幕画布没留绘制缓冲，wxwebgl2 那条路真机没验过）的退路：这边自己照着画一张——花墙色块、金囍、新人合照、
// 玩家形象（poster/ 下的小图，tools/export_poster_assets.gd 导的）、姿势记号、一句话、码。样子跟 Godot 那张差不多，不是一模一样
// 注册成桥上的本地功能（名字以 @ 开头，cloud.js 交给这里）。只用老写法：开发者工具的编译器碰到新写法可能会崩。

GameGlobal.__suqiLocalFns = GameGlobal.__suqiLocalFns || {};

var POSTER_W = 750;        // 截下来、自己画的海报都出这么宽
var codeB64 = '';          // 最近一次拿到的码
var codeFile = '';         // 码另外存一份在微信自己的用户目录里，自己画的时候读（createImage 认不认 data: 网址没验过，不赌）

function posterLog(s) { console.log('[suqi] 海报 ' + s); }

// base64 → ArrayBuffer：微信有 base64ToArrayBuffer 就用它，没有自己解
function b64ToBuffer(b64) {
    if (typeof wx !== 'undefined' && wx.base64ToArrayBuffer) return wx.base64ToArrayBuffer(b64);
    var map = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    var clean = String(b64).replace(/[^A-Za-z0-9+\/]/g, '');
    var out = new Uint8Array(Math.floor(clean.length * 3 / 4));
    var acc = 0, bits = 0, n = 0;
    for (var i = 0; i < clean.length; i++) {
        acc = (acc << 6) | map.indexOf(clean.charAt(i));
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            if (n < out.length) out[n++] = (acc >> bits) & 0xff;
        }
    }
    return out.buffer.slice(0, n);
}

// @posterCode {path} → {ok} 或 {ok:false, reason: no_code, detail}
GameGlobal.__suqiLocalFns['@posterCode'] = function (d, done) {
    var t0 = Date.now();
    if (!d || !d.path) {
        done({ ok: false, reason: 'bad_request' });
        return;
    }
    var sdk = GameGlobal.GODOTSDK;
    if (!sdk || typeof sdk.copy_to_fs !== 'function') {
        done({ ok: false, reason: 'no_code', detail: 'no_copy_to_fs' });
        return;
    }
    if (typeof wx === 'undefined' || !wx.cloud) {
        done({ ok: false, reason: 'no_code', detail: 'no_cloud' });
        return;
    }
    wx.cloud.callFunction({
        name: 'posterCode',
        data: {},
        success: function (res) {
            var r = (res && res.result) || {};
            if (!r.ok || !r.b64) {
                posterLog('小程序码没拿到 ' + (r.reason || 'empty') + ' ' + (r.errCode || ''));
                done({ ok: false, reason: 'no_code', detail: String(r.reason || 'empty') });
                return;
            }
            try {
                sdk.copy_to_fs(d.path, b64ToBuffer(r.b64));
            } catch (e) {
                done({ ok: false, reason: 'no_code', detail: 'copy:' + (e && e.message) });
                return;
            }
            codeB64 = r.b64;
            codeFile = '';
            try {
                var cf = wx.env.USER_DATA_PATH + '/suqi_poster_code.png';
                wx.getFileSystemManager().writeFile({
                    filePath: cf, data: r.b64, encoding: 'base64',
                    success: function () { codeFile = cf; },
                    fail: function () { codeFile = ''; },
                });
            } catch (e) { codeFile = ''; }
            posterLog('小程序码到了 ' + (r.cached ? '（存着的）' : '（新生成）') + ' 用时 ' + (Date.now() - t0) + ' 毫秒');
            done({ ok: true, cached: !!r.cached, ms: Date.now() - t0 });
        },
        fail: function (err) {
            posterLog('小程序码 云函数没调通 ' + (err && err.errMsg));
            done({ ok: false, reason: 'no_code', detail: 'network' });
        },
    });
};

// 屏幕上海报那一块截成图。d.rect 是 Godot 视口里的坐标（540×960 那套），d.vw、d.vh 是视口大小
function capture(d, done) {
    var screen = GameGlobal.canvas;
    if (!screen || !screen.toTempFilePath) {
        done(null, 'no_screen');
        return;
    }
    var sx = screen.width / d.vw;
    var sy = screen.height / d.vh;
    screen.toTempFilePath({
        x: Math.round(d.rect.x * sx),
        y: Math.round(d.rect.y * sy),
        width: Math.round(d.rect.w * sx),
        height: Math.round(d.rect.h * sy),
        destWidth: POSTER_W,
        destHeight: Math.round(POSTER_W * d.rect.h / d.rect.w),
        fileType: 'jpg',
        quality: 0.92,
        success: function (res) { done(res.tempFilePath, ''); },
        fail: function (err) { done(null, 'capture:' + (err && err.errMsg)); },
    });
}

function loadImage(src, done) {
    var img = wx.createImage();
    img.onload = function () { done(img); };
    img.onerror = function () { done(null); };
    img.src = src;
}

// 截下来的是不是黑的：缩成 16×16 画到离屏画布上量平均亮度。量不了（没有 getImageData）当不是黑的
function isBlack(path, done) {
    loadImage(path, function (img) {
        if (!img) {
            done(true);
            return;
        }
        try {
            var c = wx.createCanvas();
            c.width = 16;
            c.height = 16;
            var ctx = c.getContext('2d');
            ctx.drawImage(img, 0, 0, 16, 16);
            var px = ctx.getImageData(0, 0, 16, 16).data;
            var sum = 0;
            for (var i = 0; i < px.length; i += 4) sum += px[i] + px[i + 1] + px[i + 2];
            done(sum / (px.length / 4) / 3 < 10);
        } catch (e) {
            done(false);
        }
    });
}

// 一句话按画布量出来的宽折行，最多两行
function wrapText(ctx, text, maxW) {
    var lines = [];
    var cur = '';
    for (var i = 0; i < text.length; i++) {
        var t = cur + text.charAt(i);
        if (ctx.measureText(t).width > maxW && cur) {
            lines.push(cur);
            cur = text.charAt(i);
        } else {
            cur = t;
        }
    }
    if (cur) lines.push(cur);
    return lines.slice(0, 2);
}

// 退路：自己画一张。f = {preset, pose, line, hint, has_code}；布局跟 Godot 那张一样从上往下：相纸、一句话、码和「扫码进来坐坐」
function drawPoster(f, done) {
    var W = POSTER_W;
    var hasCode = !!(f.has_code && codeFile);
    var H = hasCode ? 1080 : 660;
    var c = wx.createCanvas();
    c.width = W;
    c.height = H;
    var ctx = c.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#f6efe2';
    ctx.fillRect(0, 0, W, H);
    // 相纸：拍立得白边，里面花墙绿、底下红毯、顶上金囍
    var px = 40, py = 40, pw = W - 80, ph = 500;
    ctx.fillStyle = '#f4f1ea';
    ctx.fillRect(px, py, pw, ph + 60);
    var ix = px + 20, iy = py + 20, iw = pw - 40, ih = ph - 20;
    ctx.fillStyle = '#a8c48a';
    ctx.fillRect(ix, iy, iw, ih);
    ctx.fillStyle = '#c0392b';
    ctx.fillRect(ix, iy + ih - 60, iw, 60);
    ctx.fillStyle = '#b0322a';
    ctx.beginPath();
    ctx.arc(ix + iw / 2, iy + 60, 50, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#d4af37';
    ctx.font = '70px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('囍', ix + iw / 2, iy + 62);
    var pending = 2;
    var couple = null, me = null;
    function drawRest() {
        if (couple) {
            var chh = 300, cww = chh * couple.width / couple.height;
            ctx.drawImage(couple, ix + iw * 0.56, iy + ih - 40 - chh, cww, chh);
        }
        if (me) {
            var mh = 280, mw = mh * me.width / me.height;
            var mx = ix + iw * 0.28;
            ctx.drawImage(me, mx, iy + ih - 34 - mh, mw, mh);
            if (f.pose === 'heart') {
                ctx.fillStyle = '#e8424a';
                ctx.font = '48px sans-serif';
                ctx.fillText('♥', mx + mw * 0.5, iy + ih - 34 - mh * 0.55);
            } else if (f.pose === 'wave') {
                ctx.fillStyle = '#f1c9a1';
                ctx.fillRect(mx + mw + 4, iy + ih - 34 - mh + 30, 18, 26);
            }
        }
        var y = py + ph + 60 + 60;
        ctx.fillStyle = '#5a2a1a';
        ctx.font = '44px sans-serif';
        if (hasCode) {
            var lines = wrapText(ctx, f.line || '', W - 120);
            for (var i = 0; i < lines.length; i++) {
                ctx.fillText(lines[i], W / 2, y);
                y += 58;
            }
            loadImage(codeFile, function (code) {
                var cs = 240;
                if (code) ctx.drawImage(code, 90, H - cs - 50, cs, cs);
                ctx.fillStyle = '#8a6a50';
                ctx.font = '40px sans-serif';
                ctx.textAlign = 'left';
                ctx.fillText(f.hint || '', 90 + cs + 40, H - 50 - cs / 2);
                finish();
            });
        } else {
            finish();
        }
    }
    function finish() {
        c.toTempFilePath({
            fileType: 'jpg',
            quality: 0.92,
            success: function (res) { done(res.tempFilePath, ''); },
            fail: function (err) { done(null, 'draw:' + (err && err.errMsg)); },
        });
    }
    function one() {
        pending -= 1;
        if (pending === 0) drawRest();
    }
    loadImage('poster/couple.png', function (img) { couple = img; one(); });
    loadImage('poster/me_' + (f.preset >= 0 && f.preset <= 7 ? f.preset : 0) + '.png', function (img) { me = img; one(); });
}

function share(path, done) {
    if (wx.showShareImageMenu) {
        wx.showShareImageMenu({
            path: path,
            success: function () { done({ ok: true, via: 'menu' }); },
            fail: function (err) {
                var msg = String((err && err.errMsg) || '');
                // 玩家自己点了取消不算失败
                if (/cancel/.test(msg)) done({ ok: true, via: 'menu', cancel: true });
                else done({ ok: false, reason: 'share', detail: msg });
            },
        });
        return;
    }
    var me = (GameGlobal.__suqiUser && GameGlobal.__suqiUser.openid) || '';
    wx.shareAppMessage({ title: '苏七镇奇缘', imageUrl: path, query: me ? 'from=' + me : '' });
    done({ ok: true, via: 'card' });
}

// @posterShare {rect, vw, vh, fallback} → {ok, via: menu|card, drawn: screen|self} 或 {ok:false, reason}
GameGlobal.__suqiLocalFns['@posterShare'] = function (d, done) {
    var t0 = Date.now();
    if (!d || !d.rect || !d.vw || !d.vh) {
        done({ ok: false, reason: 'bad_request' });
        return;
    }
    function selfDraw(why) {
        posterLog('截屏不能用（' + why + '），自己画一张');
        drawPoster(d.fallback || {}, function (path, why2) {
            if (!path) {
                done({ ok: false, reason: 'draw', detail: why2 });
                return;
            }
            share(path, function (r) {
                r.drawn = 'self';
                r.ms = Date.now() - t0;
                done(r);
            });
        });
    }
    capture(d, function (path, why) {
        if (!path) {
            selfDraw(why);
            return;
        }
        isBlack(path, function (black) {
            if (black) {
                selfDraw('black');
                return;
            }
            share(path, function (r) {
                r.drawn = 'screen';
                r.ms = Date.now() - t0;
                posterLog('分享 ' + JSON.stringify(r));
                done(r);
            });
        });
    });
};

GameGlobal.__suqiPosterTest = { b64ToBuffer: b64ToBuffer, codeFile: function () { return codeFile; } };   // 测试用
