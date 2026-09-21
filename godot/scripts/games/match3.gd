extends "res://scripts/games/mini_game.gd"
## 凑菜（三消，match3，T3、T4，蓝图 3.2）：换相邻两道菜，凑成横或竖 3 个以上一样的就消掉，分数够了就过。
## 步数用完还没到分就输。难度参数（minigames.json）：size 边长、kinds 几种菜、moves 步数、target 目标分
## 逻辑写成静态函数好测，界面只管画和收手势（照 g2048.gd 的结构）：
##   - 静态函数直接拿盘面算，不碰节点，方便测试和「不等动画直接算」
##   - 手势收完立刻同步算出最终盘面/分数/输赢，动画只是照着结果补一层「看着顺眼」的效果，不挡逻辑

const SWIPE := 24.0          # 手指划多远算一次滑动，像素
const CLEAR_T := 0.15        # 消掉缩小的时长
const FALL_T := 0.15         # 下落的时长

var n := 7
var kinds := 4
var moves := 20
var target := 300
var score := 0
var board: Array = []                 # n×n，board[row][col] = 第几种菜（0 开始）；-1 只在 resolve() 中间态出现
var grid: Control
var cell_px := 60.0
var gap := 6.0
var tile_nodes: Dictionary = {}       # Vector2i(col,row) -> Panel，每次 _redraw 全部换掉
var selected := Vector2i(-1, -1)      # 先点一道等第二下：那一道的位置；没有就 (-1,-1)
var press_cell := Vector2i(-1, -1)
var press_pos := Vector2.ZERO
var dragging := false
var busy := false                     # 动画播放中：不收手势（逻辑已经算完了，这只锁界面）
var shuffle_flash := 0.0              # >0 时 status 显示「洗一下」，_game_tick 里倒数

func goal_text() -> String:
    # 注意：开始卡是拿一个只 setup() 没 start() 的探针实例来读 goal_text()（game_host.gd _show_start），
    # _build() 还没跑，moves/target 都还是声明时的默认值；这里改成直接读 params，跟 g2048.gd 的 goal_text()
    # 读 target（_build() 以后才对）不一样，见回报「框架哪里用着别扭」
    # 体验评审第 10 条：原来只写「N 步内凑够 M 分」，玩家算不出一次消三个值多少，
    # 更不知道连锁第 2 轮起翻倍。把最小一次消多少分写在明处
    return "%d 步内凑够 %d 分（一次消三个 = 30 分，连着消还翻倍）" % [p_int("moves", moves), p_int("target", target)]

func status_text() -> String:
    if shuffle_flash > 0.0:
        return "洗一下"
    return "%d/%d 分 剩 %d 步" % [score, target, moves]

func _build() -> void:
    n = clampi(p_int("size", 7), 4, 10)
    kinds = clampi(p_int("kinds", 4), 3, 8)
    moves = maxi(p_int("moves", 20), 1)
    target = maxi(p_int("target", 300), 10)
    score = 0
    selected = Vector2i(-1, -1)
    tile_nodes = {}
    gap = 6.0
    cell_px = minf(68.0, (minf(size.x, size.y) - 16.0 - gap * (n + 1)) / float(n))
    var side := cell_px * n + gap * (n + 1)
    board = make_board(n, kinds, rng)
    grid = Panel.new()
    grid.size = Vector2(side, side)
    grid.position = (size - grid.size) * 0.5
    grid.add_theme_stylebox_override("panel", Tiles.box(Color("#5a3a2a"), 10))
    grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(grid)
    for r in n:
        for c in n:
            var bg := Panel.new()
            bg.size = Vector2(cell_px, cell_px)
            bg.position = _cell_pos(c, r)
            var st := StyleBoxFlat.new()
            st.bg_color = Color("#7a5a44")
            st.set_corner_radius_all(6)
            bg.add_theme_stylebox_override("panel", st)
            bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
            grid.add_child(bg)
    _redraw(board)

func _game_tick(dt: float) -> void:
    if shuffle_flash > 0.0:
        shuffle_flash = maxf(0.0, shuffle_flash - dt)

func _cell_pos(c: int, r: int) -> Vector2:
    return Vector2(gap + c * (cell_px + gap), gap + r * (cell_px + gap))

## 全部重画：tile_nodes 换成 b 这份盘面对应的菜牌。animate_fall 时每道菜从上面一格的位置落到位（占位动画，够用）
func _redraw(b: Array, animate_fall := false) -> void:
    for node in tile_nodes.values():
        if is_instance_valid(node):
            node.queue_free()
    tile_nodes.clear()
    var fs := 24 if cell_px >= 44.0 else 12
    for r in n:
        for c in n:
            var kd: int = b[r][c]
            if kd < 0:
                continue
            var t := Tiles.dish_tile(kd, cell_px, font, fs, "", art_set)
            var final_pos := _cell_pos(c, r)
            if animate_fall:
                t.position = final_pos - Vector2(0, cell_px + gap)
                grid.add_child(t)
                create_tween().tween_property(t, "position", final_pos, FALL_T)
            else:
                t.position = final_pos
                grid.add_child(t)
            tile_nodes[Vector2i(c, r)] = t
    if selected != Vector2i(-1, -1) and tile_nodes.has(selected):
        Tiles.highlight(tile_nodes[selected], true)

func _flash_cleared(cells: Array) -> void:
    for p in cells:
        var node = tile_nodes.get(p)
        if node != null and is_instance_valid(node):
            node.pivot_offset = node.size * 0.5
            create_tween().tween_property(node, "scale", Vector2.ZERO, CLEAR_T)

# ---------- 手势：按住一道往上下左右划，或者先点一道再点相邻的一道 ----------
func _gui_input(e: InputEvent) -> void:
    # paused 也要判（03 9/20 测出来：歇着照样能换块、步数和分数照走）。
    # 六个游戏里只有这一处漏了，别的五个本来就判了
    if over or paused or busy:
        return
    if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
        if e.pressed:
            var c := _cell_at(e.position)
            if c != Vector2i(-1, -1):
                press_cell = c
                press_pos = e.position
                dragging = true
            accept_event()
        elif dragging:
            dragging = false
            _release(e.position)
            accept_event()

func _release(pos: Vector2) -> void:
    var start := press_cell
    var d := pos - press_pos
    if d.length() >= SWIPE:
        var t := start + _dir4(d)
        _clear_selection()
        if _in_bounds(t):
            play(start, t)
        return
    # 没划够距离：当成点一下
    if selected == Vector2i(-1, -1):
        selected = start
        _highlight_selected()
    elif selected == start:
        _clear_selection()
    elif _adjacent(selected, start):
        var a := selected
        _clear_selection()
        play(a, start)
    else:
        _clear_selection()
        selected = start
        _highlight_selected()

func _highlight_selected() -> void:
    if tile_nodes.has(selected) and is_instance_valid(tile_nodes[selected]):
        Tiles.highlight(tile_nodes[selected], true)

func _clear_selection() -> void:
    if selected != Vector2i(-1, -1) and tile_nodes.has(selected) and is_instance_valid(tile_nodes[selected]):
        Tiles.highlight(tile_nodes[selected], false)
    selected = Vector2i(-1, -1)

func _dir4(d: Vector2) -> Vector2i:
    if absf(d.x) > absf(d.y):
        return Vector2i(1 if d.x > 0 else -1, 0)
    return Vector2i(0, 1 if d.y > 0 else -1)

func _cell_at(pos: Vector2) -> Vector2i:
    var local := pos - grid.position
    if local.x < 0 or local.y < 0 or local.x >= grid.size.x or local.y >= grid.size.y:
        return Vector2i(-1, -1)
    var c := int(local.x / (cell_px + gap))
    var r := int(local.y / (cell_px + gap))
    if c < 0 or c >= n or r < 0 or r >= n:
        return Vector2i(-1, -1)
    return Vector2i(c, r)

func _in_bounds(p: Vector2i) -> bool:
    return p.x >= 0 and p.x < n and p.y >= 0 and p.y < n

func _adjacent(a: Vector2i, b: Vector2i) -> bool:
    return absi(a.x - b.x) + absi(a.y - b.y) == 1

## 玩家操作：换 a、b（必须相邻）。凑不成：换一下又换回去，不扣步数，返回 false。
## 凑得成：真的换、扣一步、结算连锁（含后续掉落再消），再判赢/判输/判洗盘；全部同步算完，返回 true。
## 动画只是照着算好的结果补画面，_present() 不影响这里的判断（测试可以完全不管动画，直接看 board/score/moves/over）
func play(a: Vector2i, b: Vector2i) -> bool:
    if over:
        return false
    if not _in_bounds(a) or not _in_bounds(b) or not _adjacent(a, b):
        return false
    if not try_swap(board, a, b):
        _animate_bad_swap(a, b)
        return false
    board = swap_cells(board, a, b)
    moves -= 1
    var r := resolve(board, rng, kinds)
    board = r["board"]
    score += int(r["gained"])
    var rounds: Array = r["rounds"]
    var reshuffle_board: Array = []
    if score >= target:
        win()
    elif moves <= 0:
        lose("步数用完了")
    elif not has_move(board):
        board = make_board(n, kinds, rng)
        reshuffle_board = board
    _present(rounds, reshuffle_board)
    return true

## 换了凑不成：两道菜滑过去又滑回来，纯给玩家看，不改 board、不扣步
func _animate_bad_swap(a: Vector2i, b: Vector2i) -> void:
    var na: Panel = tile_nodes.get(a)
    var nb: Panel = tile_nodes.get(b)
    if na == null or nb == null or not is_instance_valid(na) or not is_instance_valid(nb):
        return
    busy = true
    var pa := na.position
    var pb := nb.position
    var tw := create_tween()
    tw.set_parallel(true)
    tw.tween_property(na, "position", pb, CLEAR_T)
    tw.tween_property(nb, "position", pa, CLEAR_T)
    await tw.finished
    if not is_instance_valid(self) or not is_instance_valid(na) or not is_instance_valid(nb):
        busy = false
        return
    var tw2 := create_tween()
    tw2.set_parallel(true)
    tw2.tween_property(na, "position", pa, CLEAR_T)
    tw2.tween_property(nb, "position", pb, CLEAR_T)
    await tw2.finished
    busy = false

## 把 resolve() 算好的每一轮连锁播出来：消掉缩小消失，下落补齐，一轮轮来；最后如果洗了盘再闪一下
func _present(rounds: Array, reshuffle_board: Array) -> void:
    busy = true
    for rd in rounds:
        if not is_instance_valid(self):
            return
        _redraw(rd["board_before"])
        _flash_cleared(rd["cleared"])
        await get_tree().create_timer(CLEAR_T).timeout
        if not is_instance_valid(self):
            return
        _redraw(rd["board_after"], true)
        await get_tree().create_timer(FALL_T).timeout
    if not is_instance_valid(self):
        return
    if not reshuffle_board.is_empty():
        shuffle_flash = 1.2
        _redraw(reshuffle_board)
    busy = false

# ---------- 逻辑（静态，好测） ----------
## 横、竖 3 个以上一样的都找出来（L 形、5 连都是横竖两路找到的格子并起来，交界处只算一次）。空格（-1）不算
static func find_matches(board: Array) -> Array:
    var rows := board.size()
    var cols: int = 0 if rows == 0 else board[0].size()
    var hit := {}
    for r in rows:
        var start := 0
        for c in range(1, cols + 1):
            var cont: bool = c < cols and board[r][c] == board[r][start] and board[r][start] >= 0
            if not cont:
                if c - start >= 3:
                    for cc in range(start, c):
                        hit[Vector2i(cc, r)] = true
                start = c
    for c in cols:
        var start := 0
        for r in range(1, rows + 1):
            var cont: bool = r < rows and board[r][c] == board[start][c] and board[start][c] >= 0
            if not cont:
                if r - start >= 3:
                    for rr in range(start, r):
                        hit[Vector2i(c, rr)] = true
                start = r
    return hit.keys()

## 每列里剩下的菜（非 -1）掉到底部，顺序不变；上面空出来的格子用 rng 随机补新的（0..kinds-1）
static func collapse(board: Array, rng: RandomNumberGenerator, kinds: int) -> Array:
    var rows := board.size()
    var cols: int = 0 if rows == 0 else board[0].size()
    var nb: Array = []
    for r in rows:
        var row: Array = []
        row.resize(cols)
        nb.append(row)
    for c in cols:
        var stack: Array = []
        for r in rows:
            if board[r][c] >= 0:
                stack.append(board[r][c])
        var empty_n := rows - stack.size()
        for r in rows:
            nb[r][c] = (rng.randi() % kinds) if r < empty_n else stack[r - empty_n]
    return nb

## 交换 a、b 两格，返回新盘面（不改传进来的这份）
static func swap_cells(board: Array, a: Vector2i, b: Vector2i) -> Array:
    var nb: Array = []
    for row in board:
        nb.append(row.duplicate())
    var t = nb[a.y][a.x]
    nb[a.y][a.x] = nb[b.y][b.x]
    nb[b.y][b.x] = t
    return nb

## 这一换（a、b 必须相邻，这里不检查）能不能凑成 3 个以上
static func try_swap(board: Array, a: Vector2i, b: Vector2i) -> bool:
    return not find_matches(swap_cells(board, a, b)).is_empty()

## 随便找一个换了能凑成的相邻格子对；测试、洗盘判定用。没有就空数组
static func find_a_move(board: Array) -> Array:
    var rows := board.size()
    var cols: int = 0 if rows == 0 else board[0].size()
    for r in rows:
        for c in cols:
            if c + 1 < cols and try_swap(board, Vector2i(c, r), Vector2i(c + 1, r)):
                return [Vector2i(c, r), Vector2i(c + 1, r)]
            if r + 1 < rows and try_swap(board, Vector2i(c, r), Vector2i(c, r + 1)):
                return [Vector2i(c, r), Vector2i(c, r + 1)]
    return []

static func has_move(board: Array) -> bool:
    return not find_a_move(board).is_empty()

## 开局盘面：size×size 格，kinds 种菜；不带现成的三连，至少有一步能走
static func make_board(size: int, kinds: int, rng: RandomNumberGenerator) -> Array:
    var board: Array = []
    var attempts := 0
    while true:
        board = []
        for r in size:
            var row: Array = []
            row.resize(size)
            board.append(row)
        for r in size:
            for c in size:
                var avoid := {}
                if c >= 2 and board[r][c - 1] == board[r][c - 2]:
                    avoid[board[r][c - 1]] = true
                if r >= 2 and board[r - 1][c] == board[r - 2][c]:
                    avoid[board[r - 1][c]] = true
                var k := rng.randi() % kinds
                var tries := 0
                while avoid.has(k) and tries < 20:
                    k = rng.randi() % kinds
                    tries += 1
                board[r][c] = k
        attempts += 1
        if find_matches(board).is_empty() and (has_move(board) or attempts > 50):
            break
    return board

## 一次交换以后的连锁：一路找/消/落，直到没得消。第 2 轮起分数倍数 ×2、×3……
## 返回 {board（最终盘面）, gained（这次交换一共加多少分）, rounds（每轮 {cleared, board_before, board_after}，动画用）}
static func resolve(board: Array, rng: RandomNumberGenerator, kinds: int) -> Dictionary:
    var b: Array = board
    var gained := 0
    var rounds: Array = []
    var round_n := 1
    while true:
        var matches: Array = find_matches(b)
        if matches.is_empty():
            break
        gained += matches.size() * 10 * round_n
        var cleared: Array = []
        for row in b:
            cleared.append(row.duplicate())
        for m in matches:
            cleared[m.y][m.x] = -1
        var after := collapse(cleared, rng, kinds)
        rounds.append({"cleared": matches, "board_before": b, "board_after": after})
        b = after
        round_n += 1
    return {"board": b, "gained": gained, "rounds": rounds}
