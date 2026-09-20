extends SceneTree
## 验收：接喜糖（接物，T11/T12，蓝图 3.2）。无界面跑，只看逻辑。
## 用法：Godot --headless --path . --script res://tools/test_game_catch.gd

const Cfg = preload("res://scripts/games/game_config.gd")
const Save = preload("res://scripts/games/game_save.gd")
const Catch = preload("res://scripts/games/catch.gd")
const Host = preload("res://scripts/games/game_host.gd")

var started := false

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func _make_host(save):
    var root := Control.new()
    root.size = Vector2(540, 960)
    get_root().add_child(root)
    var host = Host.new()
    root.add_child(host)
    host.open("catch", "T11", save, SystemFont.new(), true)
    return host

func run() -> void:
    var ok := true

    # 1. 逻辑：接到鞭炮算漏（不算接到），接到喜糖才算接到（直接调 _spawn_drop/_game_tick，不用真拖）
    var c = Catch.new()
    c.setup(1, Cfg.params(Cfg.game("catch"), 1), SystemFont.new(), 1)
    c.size = Vector2(504, 700)
    get_root().add_child(c)
    c.start()
    c.interval = 9999.0   # 关掉自动掉落，自己控制这一颗

    c.bad_ratio = 1.0
    c._spawn_drop()
    c.basket_x = c.drops[0]["x"]
    c._layout_basket()
    c._game_tick(5.0)
    var miss_after_bad = c.misses
    var caught_after_bad = c.caught
    print("1 接到鞭炮：漏 ", miss_after_bad, " 接 ", caught_after_bad)
    ok = ok and miss_after_bad == 1 and caught_after_bad == 0

    c.bad_ratio = 0.0
    c._spawn_drop()
    c.basket_x = c.drops[0]["x"]
    c._layout_basket()
    c._game_tick(5.0)
    print("  接到喜糖：漏还是 ", c.misses, " 接变成 ", c.caught)
    ok = ok and c.misses == 1 and c.caught == 1
    c.queue_free()

    # 2. 外壳里玩一整关：每帧把篮子挪到最近一颗喜糖下面，推时间，直到赢，检查金币和进度
    var s1 := Save.new()
    s1.local_path = "user://test_catch.json"
    s1.saver = func(_p, done): done.call(true)
    var host1 = _make_host(s1)
    host1.k = 1.0
    host1.g = Cfg.game("catch").duplicate(true)
    host1.g["levels"]["target"] = {"base": 3, "step": 0, "int": true}
    host1.g["levels"]["duration"] = {"base": 30, "step": 0}
    host1.g["levels"]["interval"] = {"base": 0.3, "step": 0}
    host1.g["levels"]["speed"] = {"base": 170, "step": 0}
    host1.g["levels"]["misses"] = {"base": 6, "step": 0, "int": true}
    host1.g["levels"]["bad"] = {"base": 0.0, "step": 0}
    host1._start()
    var result := [null]
    var why := [""]
    host1.game.finished.connect(func(won, r2): result[0] = won; why[0] = r2)
    var guard := 0
    while result[0] == null and guard < 4000:
        var best := -1
        var best_y := -INF
        for i in host1.game.drops.size():
            var d: Dictionary = host1.game.drops[i]
            if d["y"] > best_y:
                best_y = d["y"]
                best = i
        if best >= 0:
            var g = host1.game
            g.basket_x = clampf(g.drops[best]["x"], g.basket_w * 0.5, g.size.x - g.basket_w * 0.5)
            g._layout_basket()
        host1.game._game_tick(0.05)
        guard += 1
    print("2 外壳里接到赢：结果 ", result[0], " 金币 ", s1.coins, " 进度 ", s1.games, " 循环 ", guard, " 次")
    ok = ok and result[0] == true and s1.coins == Cfg.reward(host1.g, 1) and s1.cleared("catch") == 1

    # 3. 篮子不动、糖一直掉：**这样不该输在「漏」上**（体验评审第 1 条，9/20 改）。
    #    糖落地不算漏——没接住的糖再掉一颗就是了，只有接到鞭炮才罚。所以输只能输在时间到
    var s2 := Save.new()
    s2.local_path = "user://test_catch2.json"
    s2.saver = func(_p, done): done.call(true)
    var host2 = _make_host(s2)
    host2.k = 1.0
    host2.g = Cfg.game("catch").duplicate(true)
    host2.g["levels"]["misses"] = {"base": 3, "step": 0, "int": true}
    host2.g["levels"]["interval"] = {"base": 0.3, "step": 0}
    host2.g["levels"]["duration"] = {"base": 30, "step": 0}
    host2.g["levels"]["target"] = {"base": 99, "step": 0, "int": true}   # 接不满，好看清是怎么输的
    host2.g["levels"]["bad"] = {"base": 0.0, "step": 0}
    host2._start()
    host2.game.basket_x = -999.0   # 篮子挪到场外，一颗也接不到
    host2.game._layout_basket()
    var result2 := [null]
    var why2 := [""]
    host2.game.finished.connect(func(won, r2): result2[0] = won; why2[0] = r2)
    var guard2 := 0
    while result2[0] == null and guard2 < 2000:
        host2.game._game_tick(0.05)
        guard2 += 1
    print("3 篮子挪开、糖全落地：结果 ", result2[0], " 原因 ", why2[0], " 漏了 ", host2.game.misses)
    ok = ok and result2[0] == false and why2[0].begins_with("时间到了") and host2.game.misses == 0

    # 3b. 只有接到鞭炮才算漏：全是炮、篮子接着，漏满就输
    var s3 := Save.new()
    s3.local_path = "user://test_catch3.json"
    s3.saver = func(_p, done): done.call(true)
    var host3 = _make_host(s3)
    host3.k = 1.0
    host3.g = Cfg.game("catch").duplicate(true)
    host3.g["levels"]["misses"] = {"base": 3, "step": 0, "int": true}
    host3.g["levels"]["interval"] = {"base": 0.3, "step": 0}
    host3.g["levels"]["duration"] = {"base": 30, "step": 0}
    host3.g["levels"]["bad"] = {"base": 1.0, "step": 0}   # 掉下来的全是炮
    host3._start()
    var result3 := [null]
    var why3 := [""]
    host3.game.finished.connect(func(won, r3): result3[0] = won; why3[0] = r3)
    var guard3 := 0
    while result3[0] == null and guard3 < 2000:
        # 篮子每帧贴到最靠下那颗底下，专去接炮
        var lowest := -1.0
        for d in host3.game.drops:
            if float(d["y"]) > lowest:
                lowest = float(d["y"])
                host3.game.basket_x = float(d["x"])
        host3.game._layout_basket()
        host3.game._game_tick(0.05)
        guard3 += 1
    print("3b 专接鞭炮：结果 ", result3[0], " 原因 ", why3[0], " 漏了 ", host3.game.misses)
    ok = ok and result3[0] == false and why3[0] == "漏掉太多了" and host3.game.misses > 3

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
