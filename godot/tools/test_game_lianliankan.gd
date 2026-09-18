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

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
