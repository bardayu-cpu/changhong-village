// 微信登录：进镇流程「邀请卡片 → 微信授权 → 昵称」里的「授权」。
// 用云开发的 login 云函数（server-claude/cloudfunctions/login），不弹授权框，直接拿到自己的 openid。
// 在引擎下载的同时就去拿，结果放在 GameGlobal.__suqiUser，游戏里以后用它存名字、记邀请人。
// 日志里只打 openid 前 6 位。
// 只用老写法：开发者工具的编译器碰到新写法可能会崩。
var ENV = 'cloud1-d9ggg36tj34742bef';
GameGlobal.__suqiEnv = ENV;   // remote.js 下载失败时拿它和 File ID 里的环境对一下

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

// ---------------------------------------------------------------------------
// 云函数的桥。第 17、18 版真机上不通，重写成只用两种在真机上确定能用的写法
// （和日志面板读 __suqiLog.text() 是同一种）：
//
//   Godot → 这边：JavaScriptBridge.get_interface("名字")。名字是任意字符串，
//     我们把 96 个可打印字符各注册成一个名字，Godot 一个字符一个字符地「查」过来，
//     查到就等于送到。换行符是一条请求的结束符。
//     名字分 A、B 两套轮流用：适配层查一个名字会把属性读两遍（先 typeof 再取值），
//     靠「名字和上一个一样就忽略」去重；真正连着两个一样的字符会落在不同的套里，不会被吃掉。
//   这边 → Godot：无参方法返回字符串。pop() 取一条结果，openid() 取自己的 id，caps() 是自查。
//
// 不用带参数调方法，不用 eval。只用老写法。
// ---------------------------------------------------------------------------

var TX_PREFIX = '__sqT';
var TX_STUB = {};                 // get_interface 要有个返回值；固定同一个，免得每次都新建代理
var TX_MAX = 20000;               // 半截请求的上限，防止哪里出错一直往里塞
var tx = { buf: '', last: '', chars: 0, msgs: 0, bad: 0 };
var out = [];                     // 已经回来的结果，JSON 字符串，先进先出
var probe = { hit: false, got: '' };

function txFinish(id, result) {
    out.push(JSON.stringify({ id: id, r: result }));
}

function txDispatch(text) {
    var msg = null;
    try { msg = JSON.parse(text); } catch (e) { msg = null; }
    if (!msg || typeof msg.id === 'undefined' || !msg.fn) {
        tx.bad += 1;
        console.error('[suqi] 桥收到看不懂的请求 ' + String(text).slice(0, 80));
        return;
    }
    tx.msgs += 1;
    var id = msg.id;
    var name = msg.fn;
    var data = msg.d || {};
    // 名字以 @ 开头的不是云函数，是这一层自己做的事（比如 remote.js 的 @fetchFile：从云存储下载文件交给 Godot）
    if (String(name).charAt(0) === '@') {
        var fns = GameGlobal.__suqiLocalFns || {};
        if (typeof fns[name] !== 'function') {
            console.error('[suqi] 桥：没有这个本地功能 ' + name);
            txFinish(id, { ok: false, reason: 'no_handler' });
            return;
        }
        console.log('[suqi] 本地功能 ' + name + ' 开始 编号 ' + id);
        try {
            fns[name](data, function (result) { txFinish(id, result || { ok: false, reason: 'network' }); });
        } catch (e) {
            console.error('[suqi] 本地功能 ' + name + ' 出错 ' + (e && e.message));
            txFinish(id, { ok: false, reason: 'local_error', detail: String(e && e.message) });
        }
        return;
    }
    if (typeof wx === 'undefined' || !wx.cloud) {
        console.error('[suqi] 没有 wx.cloud，云函数 ' + name + ' 调不了');
        txFinish(id, { ok: false, reason: 'network' });
        return;
    }
    console.log('[suqi] 云函数 ' + name + ' 发出 编号 ' + id);
    try {
        wx.cloud.callFunction({
            name: name,
            data: data,
            success: function (res) {
                txFinish(id, (res && res.result) || { ok: false, reason: 'network' });
            },
            fail: function (err) {
                console.error('[suqi] 云函数 ' + name + ' 失败 ' + (err && err.errMsg ? err.errMsg : String(err)));
                txFinish(id, { ok: false, reason: 'network' });
            },
        });
    } catch (e) {
        console.error('[suqi] 云函数 ' + name + ' 出错 ' + (e && e.message));
        txFinish(id, { ok: false, reason: 'network' });
    }
}

function txChar(name, ch) {
    if (name === tx.last) return;   // 同一个名字连着读到，是适配层读了两遍，不是新字符
    tx.last = name;
    tx.chars += 1;
    if (ch === '\n') {
        var m = tx.buf;
        tx.buf = '';
        txDispatch(m);
        return;
    }
    if (tx.buf.length >= TX_MAX) {
        tx.buf = '';
        tx.bad += 1;
        console.error('[suqi] 桥收到的请求太长，丢掉');
        return;
    }
    tx.buf += ch;
}

function txDefine(name, ch) {
    try {
        Object.defineProperty(GameGlobal, name, {
            configurable: true,
            get: function () { txChar(name, ch); return TX_STUB; },
        });
    } catch (e) {
        console.error('[suqi] 桥注册名字失败 ' + (e && e.message));
    }
}

(function txRegister() {
    var chars = ['\n'];
    var c;
    for (c = 0x20; c <= 0x7e; c++) chars.push(String.fromCharCode(c));
    var banks = ['A', 'B'];
    var b, i;
    for (b = 0; b < banks.length; b++) {
        for (i = 0; i < chars.length; i++) {
            txDefine(TX_PREFIX + banks[b] + chars[i], chars[i]);
        }
    }
    console.log('[suqi] 桥备好了：' + (chars.length * banks.length) + ' 个名字');
})();

GameGlobal.__suqiCloud = {
    // 取一条已经回来的结果；没有就返回空串。无参、返回字符串
    pop: function () {
        return out.length ? out.shift() : '';
    },
    openid: function () {
        return (GameGlobal.__suqiUser && GameGlobal.__suqiUser.openid) || '';
    },
    // 点谁的分享卡片进来的（share.js 记在 GameGlobal.__suqiInviter），没有是空串
    inviter: function () {
        return GameGlobal.__suqiInviter || '';
    },
    // 自查：真机上点绿字看日志，这一行能看出请求有没有送到这边
    caps: function () {
        return '桥自查 收到字符 ' + tx.chars + ' 请求 ' + tx.msgs + ' 坏包 ' + tx.bad +
            ' 待取结果 ' + out.length + ' 半截 ' + tx.buf.length +
            ' 登录 ' + ((GameGlobal.__suqiUser && GameGlobal.__suqiUser.state) || '?') +
            ' 带参调用 ' + (probe.hit ? '到了 ' + probe.got : '没到');
    },
    // 只为查清适配层支不支持带参数调方法，玩法一概不走这条；见 godot/scripts/cloud.gd 的探针
    echo: function (a) {
        probe.hit = true;
        probe.got = String(a);
        return 'echo:' + String(a);
    },
};
