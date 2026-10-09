extends SceneTree
## 验收：连连看（吃席，蓝图 3.2）。无界面跑，只看逻辑。
## 用法：Godot --headless --path . --script res://tools/test_game_lianliankan.gd

const LLK = preload("res://scripts/games/lianliankan.gd")
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

func _zeros(cols: int, rows: int) -> Array:
    var b: Array = []
    for _y in rows:
        var row: Array = []
        row.resize(cols)
        row.fill(0)
        b.append(row)
    return b

func _find_pair(board: Array) -> Array:
    var by_val := {}
    for y in board.size():
        var row: Array = board[y]
        for x in row.size():
            var v := int(row[x])
            if v == 0:
                continue
            if not by_val.has(v):
                by_val[v] = []
            (by_val[v] as Array).append(Vector2i(x, y))
    for v in by_val:
        var pts: Array = by_val[v]
        for i in range(pts.size()):
            for j in range(i + 1, pts.size()):
                if not LLK.can_link(board, pts[i], pts[j]).is_empty():
                    return [pts[i], pts[j]]
    return []

func run() -> void:
    var ok := true
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345

    # 1. can_link：直连、一个拐、两个拐（不出圈）、绕到外圈、三个拐以上连不上、中间被挡但绕得出去
    var b1 := _zeros(4, 4)
    b1[0][0] = 1; b1[0][2] = 1
    var r1 := LLK.can_link(b1, Vector2i(0, 0), Vector2i(2, 0))
    print("1a 直连 ", r1)
    ok = ok and r1 == [Vector2i(0, 0), Vector2i(2, 0)]

    var b2 := _zeros(4, 4)
    b2[0][0] = 1; b2[2][2] = 1
    var r2 := LLK.can_link(b2, Vector2i(0, 0), Vector2i(2, 2))
    print("1b 一个拐 ", r2)
    ok = ok and r2 == [Vector2i(0, 0), Vector2i(0, 2), Vector2i(2, 2)]

    var b3 := _zeros(4, 4)
    b3[0][0] = 1; b3[1][0] = 9; b3[2][0] = 1   # 同列，中间挡住，靠右边一列绕两拐
    var r3 := LLK.can_link(b3, Vector2i(0, 0), Vector2i(0, 2))
    print("1c 两个拐（棋盘内） ", r3)
    ok = ok and r3 == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 2), Vector2i(0, 2)]

    var b4 := _zeros(4, 4)
    for y in 4:
        b4[y][1] = 9
        b4[y][2] = 9
    b4[0][0] = 1; b4[0][3] = 1   # 中间两列堵死，只能从棋盘外面绕
    var r4 := LLK.can_link(b4, Vector2i(0, 0), Vector2i(3, 0))
    print("1d 绕到外圈 ", r4)
    ok = ok and r4 == [Vector2i(0, 0), Vector2i(0, 4), Vector2i(3, 4), Vector2i(3, 0)]

    var b5 := _zeros(5, 5)
    b5[2][2] = 3; b5[2][1] = 9; b5[2][3] = 10; b5[1][2] = 11; b5[3][2] = 12
    b5[0][0] = 3   # 四周封死，两拐怎么都连不出去（覆盖「拐三次以上/连不上」）
    var r5 := LLK.can_link(b5, Vector2i(2, 2), Vector2i(0, 0))
    print("1e 封死连不上 ", r5)
    ok = ok and r5.is_empty()

    var b6 := _zeros(4, 4)
    b6[0][0] = 1; b6[0][1] = 9; b6[0][2] = 1   # 中间被挡，但下面一排空着能绕过去
    var r6 := LLK.can_link(b6, Vector2i(0, 0), Vector2i(2, 0))
    print("1f 中间被挡、绕得出去 ", r6)
    ok = ok and not r6.is_empty() and r6 != [Vector2i(0, 0), Vector2i(2, 0)]
    ok = ok and r6 == [Vector2i(0, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(2, 0)]

    # 2. has_any_pair
    print("2 有能连的 ", LLK.has_any_pair(b1), " 封死的那盘没有 ", LLK.has_any_pair(b5))
    ok = ok and LLK.has_any_pair(b1) and not LLK.has_any_pair(b5)

    # 3. make_board：成对、尽量平均、总数是奇数时少一行保证成对
    var board_a := LLK.make_board(4, 4, 4, rng)
    var cnt_a := {}
    for row in board_a:
        for v in row:
            cnt_a[v] = int(cnt_a.get(v, 0)) + 1
    print("3a 4x4 4种 ", cnt_a)
    ok = ok and cnt_a.size() == 4 and cnt_a.values().all(func(n): return n == 4)

    var board_b := LLK.make_board(3, 3, 5, rng)   # 3x3=9 是奇数，少一行变 3x2=6
    var cnt_b := {}
    for row in board_b:
        for v in row:
            cnt_b[v] = int(cnt_b.get(v, 0)) + 1
    print("3b 3x3(奇数) 变成 ", board_b.size(), "x", (board_b[0] as Array).size(), " 数量 ", cnt_b)
    ok = ok and board_b.size() * (board_b[0] as Array).size() == 6
    ok = ok and cnt_b.size() == 3 and cnt_b.values().all(func(n): return n == 2)

    # 4. 外壳里自动玩：每次找一对能连的消掉，直到赢，检查金币、进度
    var root := Control.new()
    root.size = Vector2(540, 960)
    get_root().add_child(root)
    var s3 := Save.new()
    s3.local_path = "user://test_llk_win.json"
    s3.saver = func(_p, done): done.call(true)
    var host = Host.new()
    root.add_child(host)
    host.open("lianliankan", "T1", s3, SystemFont.new(), true)
    host.k = 1.0
    host.g = Cfg.game("lianliankan").duplicate(true)
    host.g["levels"]["time"] = {"base": 999.0, "step": 0.0}
    host._start()
    var result := [null]
    host.game.finished.connect(func(w, _why): result[0] = w)
    var rounds := 0
    while result[0] == null and rounds < 200:
        rounds += 1
        var pair := _find_pair(host.game.board)
        if pair.is_empty():
            break
        host.game.tap(pair[0])
        host.game.tap(pair[1])
    print("4 外壳里连消到赢：结果 ", result[0], " 用了 ", rounds, " 轮 金币 ", s3.coins, " 进度 ", s3.games)
    ok = ok and result[0] == true and s3.coins == Cfg.reward(host.g, 1) and s3.cleared("lianliankan") == 1

    # 5. 时间到了：直接调 _game_tick(999) 判负
    var s4 := Save.new()
    s4.local_path = "user://test_llk_lose.json"
    s4.saver = func(_p, done): done.call(true)
    var host2 = Host.new()
    root.add_child(host2)
    host2.open("lianliankan", "T1", s4, SystemFont.new(), true)
    host2.k = 1.0
    host2._start()
    var result2 := [null, ""]
    host2.game.finished.connect(func(w, why): result2[0] = w; result2[1] = why)
    host2.game._game_tick(999.0)
    print("5 时间到了 ", result2)
    ok = ok and result2[0] == false and result2[1] == "时间到了"

    # 6. 外圈连线画得进游戏区（01 9/19：原来左右会被裁掉一截）。1～20 关都在手机竖屏里摆一次（调试版，游戏区最小）：
    #    外圈那条线（B7 起画在牌边外 RING 像素，不再留一整格）再加半条线宽（2），四边都要在游戏区里；格子不小于 36 像素（字用 24 号）
    #    B7（体验第一轮）：牌放大——第 1 关 4×4 原来封 72，现在要到 100 以上；7 列那几关原来约 47，现在要到 55 以上；
    #    最大不超过 128（菜牌原图的大小，再大就糊）
    var ring_ok := true
    var min_cell := 999.0
    var max_cell := 0.0
    var lv1_cell := 0.0
    var wide_cell := 999.0
    var hosts: Array = []
    for lv in range(1, 21):
        var s6 := Save.new()
        s6.local_path = "user://test_llk_ring.json"
        s6.saver = func(_p, done): done.call(true)
        s6.games["lianliankan"] = lv - 1
        var h6 = Host.new()
        root.add_child(h6)
        hosts.append(h6)
        h6.open("lianliankan", "T1", s6, SystemFont.new(), true)
        h6.k = 1.0
        h6._start()
        var gm = h6.game
        var lo: Vector2 = gm._cell_center(Vector2i(-1, -1)) + gm.grid.position
        var hi: Vector2 = gm._cell_center(Vector2i(gm.cols, gm.rows)) + gm.grid.position
        var gl: float = lo.x - 2.0
        var gr: float = hi.x + 2.0
        var gt: float = lo.y - 2.0
        var gb: float = hi.y + 2.0
        # 外圈那条线要画在牌外面（不压在牌上）：离最外一张牌的边至少 6 像素
        if lo.x > gm.grid.position.x + gm.gap - 6.0 or hi.x < gm.grid.position.x + gm.grid.size.x - gm.gap + 6.0:
            ring_ok = false
            print("  第 %d 关 外圈的线贴着牌了" % lv)
        if gl < 0.0 or gt < 0.0 or gr > gm.size.x or gb > gm.size.y:
            ring_ok = false
            print("  第 %d 关 %dx%d 外圈出界：左 %.1f 右 %.1f/%.1f 上 %.1f 下 %.1f/%.1f" % [lv, gm.cols, gm.rows, gl, gr, gm.size.x, gt, gb, gm.size.y])
        min_cell = minf(min_cell, gm.cell_px)
        max_cell = maxf(max_cell, gm.cell_px)
        if lv == 1:
            lv1_cell = gm.cell_px
        if gm.cols >= 7:
            wide_cell = minf(wide_cell, gm.cell_px)
    print("6 1～20 关外圈都在游戏区里 ", ring_ok, "  最小的格子 ", snappedf(min_cell, 0.1), " 像素")
    ok = ok and ring_ok and min_cell >= 36.0
    print("6c 牌放大（B7）：第 1 关 %.1f（原来 72）、7 列那几关 %.1f（原来约 47）、最大 %.1f（不过 128）" % [lv1_cell, wide_cell, max_cell])
    ok = ok and lv1_cell >= 100.0 and wide_cell >= 55.0 and max_cell <= 128.0
    # 6d. 牌底（B8）：有图的牌垫浅米色牌底（和小菜合大菜那层一样），不是透明的光板
    var Tiles = load("res://scripts/games/tiles.gd")
    var carded := 0
    var n_tiles := 0
    for row in hosts[0].game.cell_panels:
        for p in row:
            if p == null:
                continue
            n_tiles += 1
            var st := (p as Panel).get_theme_stylebox("panel") as StyleBoxFlat
            if st.bg_color == Tiles.CARD_BG and st.border_color == Tiles.CARD_EDGE:
                carded += 1
    print("6d 牌底（B8）：%d/%d 张有浅米色牌底" % [carded, n_tiles])
    ok = ok and n_tiles > 0 and carded == n_tiles

    # 6b. 真消一对只能绕左边外圈的牌（第 9 关 7×7，奇数少一行变 7×6）：最左一列最上、最下两张换成同一种菜（跟别处同种的对换，数量不变），
    #     连线的每个点都要在游戏区里
    var g9 = hosts[8].game
    var b9: Array = g9.board
    var kk := int(b9[0][0])
    var bot := Vector2i(0, b9.size() - 1)
    if int(b9[bot.y][bot.x]) != kk:
        # 另一张同种牌可以在任何地方（包括最左一列，只是不能是 (0,0) 自己）：原来只在 x≥1 里找，同种牌恰好只在最左一列时
        # 换不成、两下点了也连不上，约 1.5% 的开局失败（10/2 03 查：20000 个种子 296 个）
        var done_swap := false
        for y in b9.size():
            for x in (b9[y] as Array).size():
                if Vector2i(x, y) == Vector2i(0, 0):
                    continue
                if not done_swap and int(b9[y][x]) == kk:
                    b9[y][x] = b9[bot.y][bot.x]
                    b9[bot.y][bot.x] = kk
                    done_swap = true
        g9._redraw_all()
    g9.tap(Vector2i(0, 0))
    g9.tap(bot)
    var line: Line2D = null
    for c in g9.grid.get_children():
        if c is Line2D:
            line = c
    var inside := line != null
    var went_left := false
    if line != null:
        for p in line.points:
            var q: Vector2 = p + g9.grid.position
            inside = inside and q.x - 2.0 >= 0.0 and q.x + 2.0 <= g9.size.x and q.y - 2.0 >= 0.0 and q.y + 2.0 <= g9.size.y
            went_left = went_left or p.x < 0.0
    print("6b 第 9 关 %dx%d 格子 %.1f 像素：绕左边外圈 %s，连线全在游戏区里 %s" % [g9.cols, g9.rows, g9.cell_px, went_left, inside])
    ok = ok and went_left and inside and int(g9.board[0][0]) == 0 and int(g9.board[bot.y][bot.x]) == 0

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
