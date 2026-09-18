extends SceneTree
## 验收：席间小游戏的公用框架（蓝图 3.2）+ 样板游戏 2048。无界面跑，只看逻辑。
## 别的五个游戏各有自己的 tools/test_game_<id>.gd
## 用法：Godot --headless --path . --script res://tools/test_games.gd

const Cfg = preload("res://scripts/games/game_config.gd")
const Save = preload("res://scripts/games/game_save.gd")
const G2048 = preload("res://scripts/games/g2048.gd")
const Host = preload("res://scripts/games/game_host.gd")

var started := false

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func run() -> void:
    var ok := true

    # 1. 配置：6 个游戏、12 张桌两两一组，每桌都找得到游戏
    var ids: Array = []
    for gg in Cfg.data()["games"]: ids.append(gg["id"])
    var tables_ok := true
    for i in range(1, 13):
        if Cfg.game_for_table("T%d" % i).is_empty(): tables_ok = false
    print("1 游戏 ", ids, " 12 张桌都有游戏 ", tables_ok)
    ok = ok and ids.size() == 6 and tables_ok

    # 2. 难度：第 1 关、第 5 关、第 30 关的参数；难度倍数 1.5 时 hard=1 的变大、hard=-1 的变小，都不出 min/max
    var llk := Cfg.game("lianliankan")
    var p1 := Cfg.params(llk, 1)
    var p5 := Cfg.params(llk, 5)
    var p30 := Cfg.params(llk, 30)
    var p1h := Cfg.params(llk, 1, 1.5)
    print("2 连连看 第1关 ", p1, " 第5关 ", p5, " 第30关 ", p30, " 第1关难度×1.5 ", p1h)
    ok = ok and p1["kinds"] == 4.0 and p5["kinds"] == 8.0 and p30["kinds"] == 12.0 and p30["rows"] == 8.0
    ok = ok and p1h["kinds"] == 6.0 and p1h["time"] < p1["time"]
    print("  金币 第1关 ", Cfg.reward(llk, 1), " 第5关 ", Cfg.reward(llk, 5), " 第30关 ", Cfg.reward(llk, 30))
    ok = ok and Cfg.reward(llk, 1) == 10 and Cfg.reward(llk, 30) == 60

    # 3. 存档：通关加金币、记关、解锁菜；添礼金扣金币；金币不够添不了；存云上成功才算干净
    var s := Save.new()
    s.local_path = "user://test_games_save.json"
    var sent: Array = []
    var answer := [true]
    s.saver = func(payload, done): sent.append(payload); done.call(answer[0])
    s.clear_level("lianliankan", 1, 10, 0)
    s.clear_level("g2048", 1, 10)
    s.clear_level("g2048", 2, 15)
    var gift_ok: bool = s.give_gift(20)
    var gift_too_much: bool = s.give_gift(999)
    print("3 存档：金 ", s.coins, " 进度 ", s.games, " 菜 ", s.dishes, " 添礼金累计 ", s.gift_coins, " 添 20 ", gift_ok, " 添 999 ", gift_too_much,
        " 存了 ", sent.size(), " 次 最后一次 ", sent[-1] if not sent.is_empty() else {})
    ok = ok and s.coins == 15 and s.games["g2048"] == 2 and s.dishes == [0] and s.gift_coins == 20 and gift_ok and not gift_too_much
    ok = ok and sent[-1].get("gift_add", 0) == 20 and not s.dirty
    answer[0] = false
    s.clear_level("g2048", 3, 20)
    var dirty_after_fail := s.dirty
    var pushed_before := sent.size()
    s.apply_cloud({"coins": 0, "games": {}})   # 有没存上的改动：不拿云上的旧数盖，先推上去
    print("  存失败后 dirty ", dirty_after_fail, " 进厅时推上去 ", sent.size() > pushed_before, " 金币还是 ", s.coins)
    ok = ok and dirty_after_fail and sent.size() > pushed_before and s.coins == 35
    answer[0] = true
    var s2 := Save.new()
    s2.local_path = "user://test_games_save2.json"
    s2.apply_cloud({"coins": 77, "games": {"match3": 4}, "dishes": [0, 1], "gift_coins": 8})
    print("  换手机：拿云上的 金 ", s2.coins, " 进度 ", s2.games, " 下一关 ", s2.next_level("match3"))
    ok = ok and s2.coins == 77 and s2.next_level("match3") == 5

    # 4. 2048 逻辑：挤一行、合一次、整盘滑、能不能动
    var r1 := G2048.slide_line([1, 1, 2, 0])
    var r2 := G2048.slide_line([2, 2, 2, 2])
    var r3 := G2048.slide_line([0, 3, 0, 3])
    print("4 2048 [1,1,2,0]→", r1["line"], " [2,2,2,2]→", r2["line"], " [0,3,0,3]→", r3["line"])
    ok = ok and r1["line"] == [2, 2, 0, 0] and r2["line"] == [3, 3, 0, 0] and r3["line"] == [4, 0, 0, 0]
    var b := [[1, 0, 0, 1], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
    var mr := G2048.move(b, Vector2i(1, 0))
    var ml := G2048.move(b, Vector2i(0, 1))
    print("  往右 ", mr["board"][0], " 合在 ", mr["merged"], " 往下 第一列 ", [ml["board"][3][0], ml["board"][3][3]])
    ok = ok and mr["board"][0] == [0, 0, 0, 2] and mr["merged"] == [Vector2i(3, 0)] and ml["board"][3][0] == 1
    var stuck := [[1, 2, 1, 2], [2, 1, 2, 1], [1, 2, 1, 2], [2, 1, 2, 1]]
    print("  满盘没得合 能动 ", G2048.can_move(stuck))
    ok = ok and not G2048.can_move(stuck)

    # 5. 外壳 + 2048 走一整关：目标第 3 级，一直随便滑，要么过要么输，外壳要记金币
    var root := Control.new()
    root.size = Vector2(540, 960)
    get_root().add_child(root)
    var s3 := Save.new()
    s3.local_path = "user://test_games_save3.json"
    s3.saver = func(_p, done): done.call(true)
    var host = Host.new()
    root.add_child(host)
    host.open("g2048", "T5", s3, SystemFont.new(), true)
    host.k = 1.0
    host.g = Cfg.game("g2048").duplicate(true)
    host.g["levels"]["target_pow"] = {"base": 3, "step": 0, "int": true}
    host._start()
    var result := [null]
    host.game.finished.connect(func(w, _why): result[0] = w)
    var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
    for i in 400:
        if result[0] != null:
            break
        host.game.play(dirs[i % 4])
    print("5 外壳里玩 2048（目标第 3 级）：结果 ", result[0], " 金币 ", s3.coins, " 进度 ", s3.games)
    ok = ok and result[0] == true and s3.coins == Cfg.reward(host.g, 1) and s3.cleared("g2048") == 1

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
