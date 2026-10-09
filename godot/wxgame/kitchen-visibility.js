// 厨房独立前后台状态；不改登录、云函数、全局暂停或其他小游戏。
(function () {
    if (typeof GameGlobal === 'undefined' || GameGlobal.__suqiKitchenVisibility) return;
    var isHidden = false;
    var revision = 0;
    GameGlobal.__suqiKitchenVisibility = {
        epoch: function () { return String(revision); },
        hidden: function () { return isHidden ? "1" : "0"; }
    };
    if (typeof wx !== 'undefined') {
        if (wx.onHide) wx.onHide(function () { isHidden = true; revision += 1; });
        if (wx.onShow) wx.onShow(function () { isHidden = false; revision += 1; });
    }
}());
