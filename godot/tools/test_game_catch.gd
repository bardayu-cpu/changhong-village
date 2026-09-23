extends SceneTree
## 验收：接彩头（接物，T11/T12，蓝图 3.2；原来叫接喜糖）。无界面跑，只看逻辑。
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
    c._game_tick(8.0)   # 一下推 8 秒：第 1 关落得慢（130 像素/秒），5 秒还没到篮口
    var miss_after_bad = c.misses
    var caught_after_bad = c.caught
    print("1 接到鞭炮：漏 ", miss_after_bad, " 接 ", caught_after_bad)
    ok = ok and miss_after_bad == 1 and caught_after_bad == 0

    c.bad_ratio = 0.0
    c._spawn_drop()
    c.basket_x = c.drops[0]["x"]
    c._layout_basket()
    c._game_tick(8.0)
    print("  接到有赏的：漏还是 ", c.misses, " 接变成 ", c.caught, " 金 ", c.coins)
    ok = ok and c.misses == 1 and c.caught == 1 and c.coins >= 1
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
    # 接到的全拿走（01 9/23）：钱包里加的是这一局接到的金，不是奖励表；至少够这关要的 3 金
    print("2 外壳里接到赢：结果 ", result[0], " 这局接到 ", host1.game.coins, " 金，钱包 ", s1.coins, " 进度 ", s1.games, " 循环 ", guard, " 次")
    ok = ok and result[0] == true and s1.coins == host1.game.coins and s1.coins >= 3 and s1.cleared("catch") == 1

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
    ok = ok and result3[0] == false and why3[0] == "接到的鞭炮太多了" and host3.game.misses == 3   # 接到第 3 个就输（01 9/23）

    # 4. 开始卡（B12，体验第一轮）：加一句「糖和红包给的金币不一样」；自己断行，一行不超过 16 个字，标点不在行首
    var probe = Catch.new()
    probe.setup(1, Cfg.params(Cfg.game("catch"), 1), SystemFont.new(), 1)
    var goal: String = probe.goal_text()
    var lines_ok := goal.contains("不一样")
    # 新 6（体验第二轮）：整张开始卡（json 的 goal、「第 1 关」、goal_text）原来七行，精简到五行以内；
    # 鞭炮别接、接到几个就输还得说到
    var card_text: String = str(Cfg.game("catch").get("goal", "")) + "\n第 1 关\n" + goal
    var card_lines: PackedStringArray = card_text.split("\n")
    for ln in card_lines:
        if ln.length() > 16 or (ln.length() > 0 and "，。、；：！？）」".contains(ln.substr(0, 1))):
            lines_ok = false
    var five_ok: bool = card_lines.size() <= 5 and card_text.contains("鞭炮别接") and goal.contains("接到 3 个就输")
    print("4 开始卡（B12、新 6）：%d 行 %s 每行≤16 字、行首没标点 %s，五行以内 %s" % [card_lines.size(), card_text.replace("\n", "／"), lines_ok, five_ok])
    ok = ok and lines_ok and five_ok
    probe.free()

    # 5. 没接住的落到地面线就收掉（B14）：原来掉到游戏区下沿再多 30 才删，穿过红毯往下沉。
    #    篮子挪开，每种都掉一个，一小步一小步推：收掉那一刻它的底边刚碰到红毯上沿（差不过一步），收之前一直在红毯上面
    var c5 = Catch.new()
    c5.setup(1, Cfg.params(Cfg.game("catch"), 1), SystemFont.new(), 5)
    c5.size = Vector2(504, 700)
    get_root().add_child(c5)
    c5.start()
    c5.interval = 9999.0
    c5.basket_x = -999.0
    var land_ok := true
    var land_notes: Array = []
    for kind in ["candy_a", "candy_b", "candy_c", "candy_d", "hongbao_s", "hongbao_l", "firecracker"]:
        c5.drops.clear()
        c5.time_left = 999.0   # 七样一样一样掉，别半路时间到了
        c5.bad_ratio = 1.0 if kind == "firecracker" else 0.0
        c5._spawn_drop()
        var d: Dictionary = c5.drops[0]
        d["kind"] = kind
        d["bottom"] = float(Catch.DROP_BOTTOM[kind]) * Catch.DROP_SCALE
        var step: float = c5.speed * 0.02
        var last_y := -999.0
        var guard5 := 0
        while not c5.drops.is_empty() and guard5 < 2000:
            last_y = float(c5.drops[0]["y"])
            c5._game_tick(0.02)
            guard5 += 1
        var bottom_at := last_y + step + float(d["bottom"])
        var gy: float = c5.ground_y()
        land_notes.append("%s 底边 %.0f/地面 %.0f" % [kind, bottom_at, gy])
        land_ok = land_ok and bottom_at >= gy - 0.5 and bottom_at <= gy + step + 0.5 and last_y + float(d["bottom"]) < gy
    print("5 落地就收（B14）：", land_notes, " ", land_ok, "  漏了 ", c5.misses)
    ok = ok and land_ok and c5.misses == 0 and not c5.over and c5.ground_y() < c5.size.y
    c5.queue_free()

    # 5b. 接到的判定没动：篮口那条线在地面上面，正下来的照样接到
    var c6 = Catch.new()
    c6.setup(1, Cfg.params(Cfg.game("catch"), 1), SystemFont.new(), 6)
    c6.size = Vector2(504, 700)
    get_root().add_child(c6)
    c6.start()
    c6.interval = 9999.0
    c6.bad_ratio = 0.0
    c6._spawn_drop()
    c6.basket_x = c6.drops[0]["x"]
    c6._layout_basket()
    var guard6 := 0
    while not c6.drops.is_empty() and guard6 < 2000:
        c6._game_tick(0.02)
        guard6 += 1
    print("5b 篮口 %.0f 在地面 %.0f 上面，正下来的接到了 %d 样" % [c6.basket_y, c6.ground_y(), c6.caught])
    ok = ok and c6.basket_y < c6.ground_y() and c6.caught == 1
    c6.queue_free()

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
