// 调试用，只进预览版：记下启动日志和报错。
// 引擎一直没启动（90 秒；现在正常加载也要 30～60 秒）、或者出了未捕获的错误，就弹一次窗；进了游戏但有报错，5 秒后弹一次。
// 全部日志在游戏里看：调试版左上角的绿色帧率，点一下打开日志面板（main.gd 的 _read_js_log）。
// 日志边跑边存进本地缓存：要是整个卡死、弹窗也出不来，下次打开会先弹上一次的日志。
// 必须是 game.js 里第一个 import，才能在引擎之前接管 console。
// 只用老写法：开发者工具的编译器碰到新写法可能会崩。
var KEY = 'suqi_boot_log';
var BUILD = '__SUQI_BUILD__';   // 导出时换成导出时间，分清日志是哪一版的
var lines = [];
var t0 = Date.now();
var shown = false;
var started = false;
var errors = 0;
var total = 0;
var lastSave = 0;
var prevLines = [];   // 上一次打开时的日志：黑屏、闪退后重开，日志面板里还能看到
var prevBuild = '';

function device() {
    try {
        var s = wx.getSystemInfoSync();
        return '版本 ' + BUILD + ' / ' + s.model + ' / ' + s.system + ' / 微信 ' + s.version + ' / 基础库 ' + s.SDKVersion;
    } catch (e) { return ''; }
}

function save() {
    try { wx.setStorageSync(KEY, { ok: started, build: BUILD, lines: lines.slice(-80) }); } catch (e) { /* 存不了就算了 */ }
}

function fmt(a) {
    if (a instanceof Error) return a.message + (a.stack ? ' @ ' + String(a.stack).split('\n').slice(0, 2).join(' | ') : '');
    if (a && typeof a === 'object') {
        try { return JSON.stringify(a).slice(0, 200); } catch (e) { return String(a); }
    }
    return String(a);
}

function add(kind, args) {
    var text = Array.prototype.map.call(args, fmt).join(' ');
    var now = false;
    if (kind === 'E') errors++;
    if (!started && text.indexOf('Engine has started') >= 0) {
        started = true;
        now = true;
        setTimeout(function () { if (errors > 0) show('有 ' + errors + ' 条报错'); }, 5000);
    }
    lines.push(((Date.now() - t0) / 1000).toFixed(1) + 's ' + kind + ' ' + text.slice(0, 300));
    if (lines.length > 300) lines.shift();
    total++;
    // 一直存到退出，黑屏后重开还能查。报错和 [suqi] 行马上存；普通日志最多半秒存一次，免得刷屏时拖慢
    var important = now || kind !== 'L' || text.indexOf('[suqi]') >= 0;
    if (typeof wx !== 'undefined' && (important || Date.now() - lastSave > 500)) {
        lastSave = Date.now();
        save();
    }
}

['log', 'info', 'warn', 'error'].forEach(function (k) {
    var orig = typeof console[k] === 'function' ? console[k].bind(console) : function () {};
    var tag = k === 'error' ? 'E' : k === 'warn' ? 'W' : 'L';
    console[k] = function () {
        add(tag, arguments);
        orig.apply(null, arguments);
    };
});

// 弹窗里放不下几行：报错和警告放前面，重复的合并，再附启动进度
function summary(src) {
    var keys = [];
    var counts = {};
    var progress = [];
    for (var i = 0; i < src.length; i++) {
        var l = src[i];
        if (/ [EW] /.test(l)) {
            var k = l.replace(/^[0-9.]+s [EW] /, '').slice(0, 120);
            if (!counts.hasOwnProperty(k)) { counts[k] = 0; keys.push(k); }
            counts[k] += 1;
        } else if (l.indexOf('[suqi]') >= 0 || l.indexOf('engine init') >= 0 || l.indexOf('Engine has started') >= 0) {
            progress.push(l.replace(' L ', ' '));
        }
    }
    var out = [];
    for (var j = 0; j < keys.length && j < 6; j++) out.push(counts[keys[j]] > 1 ? keys[j] + ' x' + counts[keys[j]] : keys[j]);
    out.push('--');
    return out.concat(progress.slice(-5)).join('\n');
}

// 不用剪贴板：它在微信里算隐私接口，要先在后台填隐私指引，不然调了没反应
function show(title, src) {
    if (shown || typeof wx === 'undefined') return;
    shown = true;
    var all = src || lines;
    wx.showModal({
        title: title,
        content: (summary(all).slice(0, 600) || '（没有日志）') + (started ? '\n进游戏后点左上角绿字看全部日志' : ''),
        showCancel: false,
        confirmText: '知道了',
        complete: function () { if (src) shown = false; },
    });
}

// 给游戏里的日志面板用：这一次的最后 120 行（最新的在最上面），再附上一次的
GameGlobal.__suqiLog = {
    text: function () {
        var out = device() + '\n' + lines.slice(-120).reverse().join('\n');
        if (prevLines.length) out += '\n\n----- 上一次打开（版本 ' + prevBuild + '）-----\n' + prevLines.slice(-60).reverse().join('\n');
        return out;
    },
};

if (typeof wx !== 'undefined') {
    var prev = null;
    try { prev = wx.getStorageSync(KEY); } catch (e) { prev = null; }
    if (prev && prev.lines) { prevLines = prev.lines; prevBuild = prev.build || '旧版'; }
    // 只在同一版上次没进游戏时弹；换了新版，旧版的失败日志只放进日志面板
    if (prev && prev.build === BUILD && prev.ok === false && prev.lines && prev.lines.length) {
        setTimeout(function () { show('上次没进游戏', prev.lines); }, 800);
    }
    // 切后台、回前台（弹窗、转发面板、下拉通知都会触发），黑屏常出在这前后
    if (wx.onHide) wx.onHide(function () { console.log('[suqi] 切到后台'); });
    if (wx.onShow) wx.onShow(function () { console.log('[suqi] 回到前台'); });
    if (wx.onError) wx.onError(function (res) { add('E', [res && res.message ? res.message : res]); show('出错了'); });
    if (wx.onUnhandledRejection) wx.onUnhandledRejection(function (res) { add('E', ['Promise 未处理', res && res.reason]); show('出错了'); });
    setTimeout(function () { if (!started) show('90 秒还没进游戏'); }, 90000);
}
