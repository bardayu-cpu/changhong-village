// 云桥的另一半测试：在电脑上用 node 回放真机上那一串「查名字」，看 wxgame/cloud.js 能不能还原成请求。
// 回放时照着导出模板里 resolveNamedObject 的做法：查一个名字会把属性读两遍（先 typeof 再取值），
// 这正是 JS 那边要去重的地方。
// 跑法：node tools/replay_bridge.js <test_bridge.gd 写出来的 bridge_names.json>
// 最后一行 RESULT PASS 才算过。

var fs = require('fs');

var namesFile = process.argv[2];
if (!namesFile) {
    console.log('要给名字文件的路径');
    console.log('RESULT FAIL');
    process.exit(1);
}

// 装一个最小的微信环境：GameGlobal 就是全局，wx.cloud 把请求原样回声回来
var calls = [];
global.GameGlobal = global;
global.wx = {
    cloud: {
        init: function () {},
        callFunction: function (o) {
            calls.push({ name: o.name, data: o.data });
            if (o.name === 'login') {
                setTimeout(function () { o.success({ result: { openid: 'op_test_123456' } }); }, 0);
                return;
            }
            setTimeout(function () { o.success({ result: { ok: true, echo: o.data } }); }, 0);
        },
    },
};

require('../wxgame/cloud.js');

// 照 resolveNamedObject 的样子查一个名字：读两遍
function getInterface(name) {
    var v;
    if (typeof global[name] !== 'undefined') { v = global[name]; }
    return v;
}

var doc = JSON.parse(fs.readFileSync(namesFile, 'utf8'));
var ok = true;

doc.cases.forEach(function (c, idx) {
    var before = calls.length;
    c.names.forEach(getInterface);
    var got = calls.slice(before);
    if (got.length !== 1) {
        console.log((idx + 1) + ' 应该收到 1 条请求，实际 ' + got.length);
        ok = false;
        return;
    }
    var want = c.msg;
    var sameName = got[0].name === want.fn;
    var sameData = JSON.stringify(got[0].data) === JSON.stringify(want.d);
    console.log((idx + 1) + ' 还原出 ' + got[0].name + ' ' + JSON.stringify(got[0].data) +
        '  云函数名对 ' + sameName + '  参数对 ' + sameData);
    ok = ok && sameName && sameData;
});

// 结果要能用无参的 pop() 一条条取回去
setTimeout(function () {
    var popped = [];
    var s;
    while ((s = GameGlobal.__suqiCloud.pop()) !== '') { popped.push(JSON.parse(s)); }
    console.log('3 pop() 取回 ' + popped.length + ' 条：' + JSON.stringify(popped));
    ok = ok && popped.length === doc.cases.length;
    ok = ok && popped.every(function (p) { return p.r && p.r.ok === true; });
    // 编号要和送出去的对得上，不然回调会挂在错的请求上
    var ids = popped.map(function (p) { return p.id; }).sort();
    var wantIds = doc.cases.map(function (c) { return c.msg.id; }).sort();
    var idOk = JSON.stringify(ids) === JSON.stringify(wantIds);
    console.log('4 编号对得上 ' + idOk + ' ' + JSON.stringify(ids));
    ok = ok && idOk;
    console.log('5 openid() ' + GameGlobal.__suqiCloud.openid());
    ok = ok && GameGlobal.__suqiCloud.openid() === 'op_test_123456';
    console.log('6 ' + GameGlobal.__suqiCloud.caps());
    console.log('RESULT ' + (ok ? 'PASS' : 'FAIL'));
    process.exit(ok ? 0 : 1);
}, 50);
