// 打开用时（02 10/3「性能-真人物满厅」第 2 条：从点开小程序到能走路，分几段花多少）。导出时排在最前面导入，最早记下时间：
//   t0 点开（这份脚本跑到的时候，主包已经下好）；sub_start / sub_done 引擎分包（引擎 + 游戏包）开始下、下完；sub_mb 多大
// Godot 那边经桥（cloud.js 的 boot()）取这份，自己再记引擎起来、标题、进院、进厅能走，日志里打一行「[suqi] 打开用时」，
// 调试版点绿字就看得见，阿鱼验的时候顺手拍下来就有真机的数。只记时间，不改任何东西。只用老写法
(function () {
    var G = typeof GameGlobal !== 'undefined' ? GameGlobal : this;
    var b = G.__suqiBoot = { t0: Date.now(), sub_start: 0, sub_done: 0, sub_progress: 0 };
    if (typeof wx === 'undefined' || typeof wx.loadSubpackage !== 'function') return;
    var orig = wx.loadSubpackage;
    try {
        wx.loadSubpackage = function (o) {
            b.sub_start = Date.now();
            var ok = o && o.success;
            var opt = {};
            for (var k in o) opt[k] = o[k];
            opt.success = function (r) { b.sub_done = Date.now(); if (ok) ok(r); };
            var task = orig.call(wx, opt);
            // 进度：包住加载页自己挂的那个回调（有的版本只认一个回调，自己再挂一个会把它顶掉）
            if (task && typeof task.onProgressUpdate === 'function') {
                var on = task.onProgressUpdate;
                task.onProgressUpdate = function (f) {
                    return on.call(task, function (p) {
                        b.sub_progress = p.progress;
                        if (p.totalBytesExpectedToWrite) b.sub_mb = Math.round(p.totalBytesExpectedToWrite / 104857.6) / 10;
                        if (f) f(p);
                    });
                };
            }
            return task;
        };
    } catch (e) {
        console.log('[suqi] 打开用时：包不了 loadSubpackage ' + (e && e.message));
    }
})();
