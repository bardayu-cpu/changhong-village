extends SceneTree
## 验收：记菜名（翻牌配对，蓝图 3.2）。无界面跑，只看逻辑。
## 用法：Godot --headless --path . --script res://tools/test_game_memory.gd

const Memory = preload("res://scripts/games/memory.gd")
const Cfg = preload("res://scripts/games/game_config.gd")
const Save = preload("res://scripts/games/game_save.gd")
const Host = preload("res://scripts/games/game_host.gd")

var started := false

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func _pair_up(deck: Array) -> Dictionary:
    var by_kind := {}
    for i in deck.size():
        var k = deck[i]
        if not by_kind.has(k):
            by_kind[k] = []
        (by_kind[k] as Array).append(i)
    return by_kind

func run() -> void:
    var ok := true

    # 1. 预览期间点牌不算翻；预览结束后正常翻
    var g1 := Memory.new()
    g1.size = Vector2(500, 700)
    g1.setup(1, {"pairs": 3, "preview": 2.0, "misses": 8}, SystemFont.new(), 111)
    g1.start()
    var was_previewing: bool = g1.previewing
    var status_during: String = g1.status_text()
    g1.tap(0)
    var first_during_preview: int = g1.first_idx
    g1._game_tick(2.1)
    var previewing_after: bool = g1.previewing
    g1.tap(0)
    var first_after: int = g1.first_idx
    print("1 预览中 ", was_previewing, " 提示语「", status_during, "」 预览期间点牌记成 ", first_during_preview,
        " 预览结束 ", not previewing_after, " 结束后点牌记成 ", first_after)
    ok = ok and was_previewing and status_during == "记住它们" and first_during_preview == -1
    ok = ok and not previewing_after and first_after == 0
    g1.free()

    # 2. 自动配对（作弊读牌面）赢一关
    var g2 := Memory.new()
    g2.size = Vector2(500, 700)
    g2.setup(1, {"pairs": 4, "preview": 0.0, "misses": 8}, SystemFont.new(), 222)
    g2.start()
    var result2 := [null]
    g2.finished.connect(func(w, _why): result2[0] = w)
    var by_kind2 := _pair_up(g2.deck)
    for k in by_kind2:
        var idxs: Array = by_kind2[k]
        g2.tap(idxs[0])
        g2.tap(idxs[1])
    print("2 自动配对赢 ", result2[0], " 牌面 ", g2.deck)
    ok = ok and result2[0] == true
    g2.free()

    # 3. 故意一直翻错直到输；翻错等回去的 0.6 秒里点别的牌不算
    var g3 := Memory.new()
    g3.size = Vector2(500, 700)
    g3.setup(1, {"pairs": 3, "preview": 0.0, "misses": 1}, SystemFont.new(), 333)
    g3.start()
    var result3 := [null, ""]
    g3.finished.connect(func(w, why): result3[0] = w; result3[1] = why)
    var ia := -1
    var ib := -1
    for i in g3.deck.size():
        for j in range(i + 1, g3.deck.size()):
            if g3.deck[i] != g3.deck[j]:
                ia = i
                ib = j
                break
        if ia != -1:
            break
    g3.tap(ia)
    g3.tap(ib)   # 第一次翻错（misses=1，还没超过 misses_max=1）
    var other := 0
    while other == ia or other == ib:
        other += 1
    g3.tap(other)   # 翻回去之前点别的牌，应该不算
    var blocked_ok: bool = g3.first_idx == -1 and not g3.revealed[other]
    g3._game_tick(1.0)   # 把翻错的那对翻回去
    g3.tap(ia)
    g3.tap(ib)   # 第二次翻错，misses=2 超过 misses_max=1，判负
    print("3 翻错 ", g3.misses, " 次 判负 ", result3, " 等待期间点别的牌没生效 ", blocked_ok)
    ok = ok and result3[0] == false and result3[1] == "翻错太多次了" and blocked_ok
    g3.free()

    # 4. 外壳里也走一遍：自动配对赢，检查金币、进度记上了
    var root := Control.new()
    root.size = Vector2(540, 960)
    get_root().add_child(root)
    var s := Save.new()
    s.local_path = "user://test_memory_win.json"
    s.saver = func(_p, done): done.call(true)
    var host = Host.new()
    root.add_child(host)
    host.open("memory", "T7", s, SystemFont.new(), true)
    host.k = 1.0
    host.g = Cfg.game("memory").duplicate(true)
    host.g["levels"]["preview"] = {"base": 0.0, "step": 0.0}
    host._start()
    var result4 := [null]
    host.game.finished.connect(func(w, _why): result4[0] = w)
    var by_kind4 := _pair_up(host.game.deck)
    for k in by_kind4:
        var idxs: Array = by_kind4[k]
        host.game.tap(idxs[0])
        host.game.tap(idxs[1])
    print("4 外壳里配对赢 结果 ", result4[0], " 金币 ", s.coins, " 进度 ", s.games)
    ok = ok and result4[0] == true and s.coins == Cfg.reward(host.g, 1) and s.cleared("memory") == 1

    # 5. 牌放大（B7，体验第一轮）：原来封 110、一律往宽里摆，屏幕空一半。
    #    在手机竖屏的游戏区（外壳量出来的，调试版最小）里摆 3～12 对：每行都满（阿鱼 9/20），牌不超过 152（图正好 128），
    #    第 1 关 3 对要到 140 以上，12 对（24 张）要到 90 以上（原来 72；这是调试版的游戏区，正式版还高 56，约 104）
    var area: Vector2 = host.area.size
    var shapes: Array = []
    var full := true
    var sizes := {}
    for pairs in [3, 4, 5, 6, 8, 9, 10, 12]:
        var gm := Memory.new()
        gm.size = area
        gm.setup(1, {"pairs": pairs, "preview": 0.0, "misses": 8}, SystemFont.new(), 5)
        gm.start()
        if gm.total % gm.cols != 0:
            full = false
        sizes[pairs] = gm.cell_px
        var grid_ok: bool = gm.grid.position.x >= 0.0 and gm.grid.position.y >= 0.0 \
            and gm.grid.position.x + gm.grid.size.x <= area.x + 0.5 and gm.grid.position.y + gm.grid.size.y <= area.y + 0.5
        if not grid_ok:
            full = false
        shapes.append("%d对 %d×%d 牌%.0f" % [pairs, gm.cols, gm.rows, gm.cell_px])
        gm.free()
    print("5 牌放大（B7）游戏区 %s：%s" % [area, shapes])
    ok = ok and full and float(sizes[3]) >= 140.0 and float(sizes[12]) >= 90.0
    ok = ok and sizes.values().all(func(v): return float(v) <= 152.0)

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
