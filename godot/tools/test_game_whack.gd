extends SceneTree
## 验收：打地鼠（夹菜，T9/T10，蓝图 3.2）。无界面跑，只看逻辑。
## 用法：Godot --headless --path . --script res://tools/test_game_whack.gd

const Cfg = preload("res://scripts/games/game_config.gd")
const Save = preload("res://scripts/games/game_save.gd")
const Whack = preload("res://scripts/games/whack.gd")
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
    host.open("whack", "T9", save, SystemFont.new(), true)
    return host

func _first_up(w) -> int:
    for i in w.holes_state.size():
        if w.holes_state[i]["up"]:
            return i
    return -1

func run() -> void:
    var ok := true

    # 1. 逻辑：点空盘子没事、点到辣椒扣分（封底 0）、点到菜 +1（直接调 hit(i)，不用真点）
    var w = Whack.new()
    w.setup(1, Cfg.params(Cfg.game("whack"), 1), SystemFont.new(), 1)
    w.size = Vector2(504, 700)
    get_root().add_child(w)
    w.start()
    var r_empty = w.hit(0)
    w.bad_ratio = 1.0
    w._try_spawn()
    var r_bad = w.hit(_first_up(w))
    var score_after_bad = w.score
    w.bad_ratio = 0.0
    w._try_spawn()
    var r_good = w.hit(_first_up(w))
    print("1 点空盘子 ", r_empty, " 点到辣椒 ", r_bad, " 分 ", score_after_bad, " 点到菜 ", r_good, " 分 ", w.score)
    ok = ok and r_empty == 0 and r_bad == -1 and score_after_bad == 0 and r_good == 1 and w.score == 1
    w.queue_free()

    # 2. 外壳里玩一整关：推时间、菜一冒出来就夹，直到赢，检查金币和进度
    var s1 := Save.new()
    s1.local_path = "user://test_whack.json"
    s1.saver = func(_p, done): done.call(true)
    var host1 = _make_host(s1)
    host1.k = 1.0
    host1.g = Cfg.game("whack").duplicate(true)
    host1.g["levels"]["holes"] = {"base": 6, "step": 0, "int": true}
    host1.g["levels"]["target"] = {"base": 3, "step": 0, "int": true}
    host1.g["levels"]["duration"] = {"base": 30, "step": 0}
    host1.g["levels"]["show"] = {"base": 1.3, "step": 0}
    host1.g["levels"]["interval"] = {"base": 0.3, "step": 0}
    host1.g["levels"]["bad"] = {"base": 0.0, "step": 0}
    host1._start()
    var result := [null]
    var why := [""]
    host1.game.finished.connect(func(won, r2): result[0] = won; why[0] = r2)
    var guard := 0
    while result[0] == null and guard < 2000:
        host1.game._game_tick(0.05)
        for i in host1.game.holes_state.size():
            if result[0] != null:
                break
            if host1.game.holes_state[i]["up"]:
                host1.game.hit(i)
        guard += 1
    print("2 外壳里夹到赢：结果 ", result[0], " 金币 ", s1.coins, " 进度 ", s1.games, " 循环 ", guard, " 次")
    ok = ok and result[0] == true and s1.coins == Cfg.reward(host1.g, 1) and s1.cleared("whack") == 1

    # 3. 一直不点、时间推完，检查输的原因
    var s2 := Save.new()
    s2.local_path = "user://test_whack2.json"
    s2.saver = func(_p, done): done.call(true)
    var host2 = _make_host(s2)
    host2.k = 1.0
    host2.g = Cfg.game("whack").duplicate(true)
    host2.g["levels"]["duration"] = {"base": 1.0, "step": 0}
    host2.g["levels"]["target"] = {"base": 3, "step": 0, "int": true}
    host2._start()
    var result2 := [null]
    var why2 := [""]
    host2.game.finished.connect(func(won, r2): result2[0] = won; why2[0] = r2)
    var guard2 := 0
    while result2[0] == null and guard2 < 200:
        host2.game._game_tick(0.05)
        guard2 += 1
    print("3 不点、时间到：结果 ", result2[0], " 原因 ", why2[0])
    ok = ok and result2[0] == false and why2[0].begins_with("时间到了")

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
