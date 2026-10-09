// 打开用时（wxgame/boot_timer.js）：包住引擎分包下载，记开始、下完、多大；加载页自己的 success、进度回调照样收到。
// 跑法：node tools/test_boot_timer_js.js    最后一行 RESULT PASS 才算过
global.GameGlobal = global;
var prog = null;
global.wx = {
    loadSubpackage: function (o) {
        var t = { onProgressUpdate: function (f) { prog = f; } };   // 假的：只认一个回调（真机有的版本就这样）
        setTimeout(function () { prog({ progress: 50, totalBytesExpectedToWrite: 15290764 }); o.success({}); }, 20);
        return t;
    },
};
require('../wxgame/boot_timer.js');
var gotOk = false, gotProg = -1;
var task = wx.loadSubpackage({ name: 'engine', success: function () { gotOk = true; } });
task.onProgressUpdate(function (p) { gotProg = p.progress; });
setTimeout(function () {
    var b = GameGlobal.__suqiBoot;
    var ok = gotOk && gotProg === 50 && b.t0 > 0 && b.sub_start >= b.t0 && b.sub_done >= b.sub_start && b.sub_mb === 14.6;
    console.log((ok ? '  好 ' : '  不行 ') + '记下 ' + JSON.stringify(b) + '，加载页的 success ' + gotOk + '、进度 ' + gotProg);
    console.log(ok ? 'RESULT PASS' : 'RESULT FAIL');
    process.exit(ok ? 0 : 1);
}, 60);
