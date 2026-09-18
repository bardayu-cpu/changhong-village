extends SceneTree
## 验收：三消（match3，蓝图 3.2）的静态逻辑 + 在外壳里走一整关（赢、输各一次）
## 用法：Godot --headless --path . --script res://tools/test_game_match3.gd

const Cfg = preload("res://scripts/games/game_config.gd")
const Save = preload("res://scripts/games/game_save.gd")
const Match3 = preload("res://scripts/games/match3.gd")
const Host = preload("res://scripts/games/game_host.gd")

var started := false

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

## 背景棋盘：(r+c)%3，相邻格子必然不同，绝不会自己连成 3 个——测试摆样子用，专给要测的格子留位置
func _safe(rows: int, cols: int) -> Array:
    var b: Array = []
    for r in rows:
        var row: Array = []
        for c in cols:
            row.append((r + c) % 3)
        b.append(row)
    return b

func _find_bad_swap(board: Array) -> Array:
    var rows: int = board.size()
    var cols: int = board[0].size() if rows > 0 else 0
    for r in rows:
        for c in cols:
            if c + 1 < cols and not Match3.try_swap(board, Vector2i(c, r), Vector2i(c + 1, r)):
                return [Vector2i(c, r), Vector2i(c + 1, r)]
            if r + 1 < rows and not Match3.try_swap(board, Vector2i(c, r), Vector2i(c, r + 1)):
                return [Vector2i(c, r), Vector2i(c, r + 1)]
    return []

func run() -> void:
    var ok := true

    # 1. find_matches：横、竖、L 形、5 连、没有三连时干净
    var row_b := _safe(5, 5)
    row_b[2][0] = 9; row_b[2][1] = 9; row_b[2][2] = 9
    var m_row: Array = Match3.find_matches(row_b)
    print("1a 横 3 连 ", m_row)
    ok = ok and m_row.size() == 3 and Vector2i(0, 2) in m_row and Vector2i(1, 2) in m_row and Vector2i(2, 2) in m_row

    var col_b := _safe(5, 5)
    col_b[0][3] = 9; col_b[1][3] = 9; col_b[2][3] = 9
    var m_col: Array = Match3.find_matches(col_b)
    print("1b 竖 3 连 ", m_col)
    ok = ok and m_col.size() == 3 and Vector2i(3, 0) in m_col and Vector2i(3, 1) in m_col and Vector2i(3, 2) in m_col

    var l_b := _safe(5, 5)
    l_b[2][2] = 9; l_b[2][3] = 9; l_b[2][4] = 9   # 横：row2, col2~4
    l_b[0][2] = 9; l_b[1][2] = 9                   # 竖：col2, row0~2（row2/col2 是拐角，共用）
    var m_l: Array = Match3.find_matches(l_b)
    print("1c L 形 ", m_l.size(), " ", m_l)
    ok = ok and m_l.size() == 5

    var five_b := _safe(6, 6)
    for c in 5:
        five_b[1][c] = 9
    var m_five: Array = Match3.find_matches(five_b)
    print("1d 5 连 ", m_five.size())
    ok = ok and m_five.size() == 5

    var m_none: Array = Match3.find_matches(_safe(6, 6))
    print("1e 没有三连时干净 ", m_none.size())
    ok = ok and m_none.is_empty()

    # 2. make_board：不带现成三连，至少有一步能走（多试几个种子）
    var rng := RandomNumberGenerator.new()
    var make_ok := true
    for seed_i in 20:
        rng.seed = seed_i
        var b: Array = Match3.make_board(7, 4, rng)
        if not Match3.find_matches(b).is_empty() or not Match3.has_move(b):
            make_ok = false
    print("2 make_board 20 个种子都没有现成三连、都能走 ", make_ok)
    ok = ok and make_ok

    # 3. collapse：消完以后没有空格；掉落顺序不乱（原来的菜相对上下顺序不变，新补的在最上面）
    var holed := [[-1, -1, 0], [1, -1, 1], [-1, 0, -1], [2, 1, 0], [0, 2, 1]]
    rng.seed = 7
    var collapsed: Array = Match3.collapse(holed, rng, 4)
    var no_holes := true
    for row in collapsed:
        for v in row:
            if v < 0:
                no_holes = false
    print("3 collapse 以后没有空格 ", no_holes, " 第 0 列（原来 -1,1,-1,2,0）落完 ", [collapsed[2][0], collapsed[3][0], collapsed[4][0]])
    ok = ok and no_holes and collapsed[2][0] == 1 and collapsed[3][0] == 2 and collapsed[4][0] == 0

    # 3b. goal_text()：开始卡是拿只 setup() 没 start() 的探针实例读的（game_host.gd _show_start 那样），
    # _build() 没跑，得看 goal_text() 是不是照样读到这一关真的 moves/target（不是声明时的默认值）
    var probe := Match3.new()
    probe.setup(3, {"moves": 15, "target": 120, "size": 7, "kinds": 5}, SystemFont.new(), 1)
    var goal: String = probe.goal_text()
    print("3b 探针（没 _build）读到的 goal_text() ", goal)
    ok = ok and goal == "15 步内凑够 120 分"
    probe.free()

    # 4／6a. 换了凑不成：不扣步、不加分（用一局真的游戏测，跟第 6 条一起走）
    var root := Control.new()
    root.size = Vector2(500, 700)
    get_root().add_child(root)

    # 5. 外壳里玩到赢：target 调到 60，每步用 find_a_move 找一个能凑成的交换，直到 finished(true)
    var s3 := Save.new()
    s3.local_path = "user://test_m3_win.json"
    s3.saver = func(_p, done): done.call(true)
    var host = Host.new()
    root.add_child(host)
    host.open("match3", "T3", s3, SystemFont.new(), true)
    host.k = 1.0
    host.g = Cfg.game("match3").duplicate(true)
    host.g["levels"]["target"] = {"base": 60, "step": 0, "int": true}
    host._start()
    var win_result := [null]
    host.game.finished.connect(func(w, _why): win_result[0] = w)
    var steps := 0
    while win_result[0] == null and steps < 500:
        steps += 1
        var mv: Array = Match3.find_a_move(host.game.board)
        if mv.is_empty():
            break   # 不该发生：卡住的话游戏自己会洗盘
        host.game.play(mv[0], mv[1])
    print("5 外壳里玩三消（目标 60 分）：结果 ", win_result[0], " 用了 ", steps, " 步 分 ", host.game.score, " 金币 ", s3.coins, " 进度 ", s3.games)
    ok = ok and win_result[0] == true and s3.coins == Cfg.reward(host.g, 1) and s3.cleared("match3") == 1

    # 6. 步数用完输：单开一局，moves 调成 1、target 调得够高。先试一次凑不成的（不扣步），再走一步合法但不够分的（判负）
    var s4 := Save.new()
    s4.local_path = "user://test_m3_lose.json"
    s4.saver = func(_p, done): done.call(true)
    var host2 = Host.new()
    root.add_child(host2)
    host2.open("match3", "T3", s4, SystemFont.new(), true)
    host2.k = 1.0
    host2.g = Cfg.game("match3").duplicate(true)
    host2.g["levels"]["moves"] = {"base": 1, "step": 0, "int": true}
    host2.g["levels"]["target"] = {"base": 100000, "step": 0, "int": true}
    host2._start()
    var lose_result := [null]
    var lose_why := [""]
    host2.game.finished.connect(func(w, why): lose_result[0] = w; lose_why[0] = why)
    var moves_before: int = host2.game.moves
    var score_before: int = host2.game.score
    var bad: Array = _find_bad_swap(host2.game.board)
    var bad_ret := true
    if not bad.is_empty():
        bad_ret = host2.game.play(bad[0], bad[1])
    print("6a 凑不成的交换 返回 ", bad_ret, " 步没变 ", host2.game.moves == moves_before, " 分没变 ", host2.game.score == score_before)
    ok = ok and not bad.is_empty() and not bad_ret and host2.game.moves == moves_before and host2.game.score == score_before and not host2.game.over
    var good: Array = Match3.find_a_move(host2.game.board)
    var good_ret := false
    if not good.is_empty():
        good_ret = host2.game.play(good[0], good[1])
    print("6b 合法但不够分 返回 ", good_ret, " 剩步 ", host2.game.moves, " 分 ", host2.game.score, " 结束 ", lose_result[0], " 为什么 ", lose_why[0])
    ok = ok and not good.is_empty() and good_ret and host2.game.moves == 0 and lose_result[0] == false and lose_why[0] == "步数用完了"

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
