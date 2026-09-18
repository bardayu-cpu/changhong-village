extends "res://scripts/games/mini_game.gd"
## 吃席（连连看，T1、T2，蓝图 3.2）：点一张菜牌选中，再点一张一样的，能用拐弯不超过两次的折线连起来就消掉。
## 场上没有能连的对子了就自动洗一次牌。全部消完过关，时间到了就输。难度参数（minigames.json）：
## cols/rows 格子数，kinds 几种菜，time 秒数
## 棋盘坐标 x=列 y=行，board[y][x]；0=空，其余=第几种菜（1 起）。连线允许绕到棋盘外面一圈（一圈虚格永远算空）

const GOLD := Color("#d4af37")

var cols := 4
var rows := 4
var board: Array = []          # rows 行、每行 cols 个，0=空，k=第 k 种菜
var cell_panels: Array = []    # 跟 board 同形状，对应的 Panel（空格是 null）
var grid: Control
var cell_px := 64.0
var gap := 6.0
var selected := Vector2i.ZERO
var has_sel := false
var time_left := 90.0
var shuffle_msg_left := 0.0

func goal_text() -> String:
    return "%d 秒内把菜连完" % roundi(p_float("time", 90.0))

func status_text() -> String:
    if shuffle_msg_left > 0.0:
        return "洗一下牌"
    return "剩 %d 秒" % maxi(ceili(time_left), 0)

func _build() -> void:
    cols = maxi(p_int("cols", 4), 2)
    rows = maxi(p_int("rows", 4), 2)
    var kd := clampi(p_int("kinds", 4), 1, 12)
    time_left = maxf(p_float("time", 90.0), 1.0)
    board = make_board(cols, rows, kd, rng)
    rows = board.size()
    cols = (board[0] as Array).size() if rows > 0 else 0
    if not has_any_pair(board):
        board = reshuffle(board, rng)
    var avail_w: float = size.x - 16.0
    var avail_h: float = size.y - 16.0
    var cw := (avail_w - gap * (cols + 1)) / cols
    var ch := (avail_h - gap * (rows + 1)) / rows
    cell_px = clampf(minf(cw, ch), 20.0, 72.0)
    grid = Control.new()
    grid.size = Vector2(cols * (cell_px + gap) + gap, rows * (cell_px + gap) + gap)
    grid.position = (size - grid.size) * 0.5
    grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(grid)
    cell_panels = []
    for y in rows:
        var row: Array = []
        row.resize(cols)
        row.fill(null)
        cell_panels.append(row)
    _redraw_all()

func _cell_pos(x: int, y: int) -> Vector2:
    return Vector2(gap + x * (cell_px + gap), gap + y * (cell_px + gap))

func _cell_center(p: Vector2i) -> Vector2:
    return _cell_pos(p.x, p.y) + Vector2(cell_px, cell_px) * 0.5

func _redraw_all() -> void:
    for row in cell_panels:
        for p in row:
            if p != null and is_instance_valid(p):
                p.queue_free()
    for y in rows:
        for x in cols:
            cell_panels[y][x] = null
    var fs := 24 if cell_px >= 48.0 else 12
    for y in rows:
        for x in cols:
            var v := int(board[y][x])
            if v == 0:
                continue
            var t := Tiles.dish_tile(v - 1, cell_px, font, fs)
            t.position = _cell_pos(x, y)
            grid.add_child(t)
            cell_panels[y][x] = t

func _set_highlight(c: Vector2i, on: bool) -> void:
    var p: Panel = cell_panels[c.y][c.x]
    if p != null and is_instance_valid(p):
        Tiles.highlight(p, on)

# ---------- 手势 ----------
func _gui_input(e: InputEvent) -> void:
    if over or paused:
        return
    if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
        var local: Vector2 = e.position - grid.position
        var step := cell_px + gap
        var gx := int(floor(local.x / step))
        var gy := int(floor(local.y / step))
        if gx >= 0 and gx < cols and gy >= 0 and gy < rows:
            tap(Vector2i(gx, gy))
        accept_event()

## 点一张菜牌；逻辑全同步（好测），画面上的连线只是好看，不挡下一步操作
func tap(c: Vector2i) -> void:
    if over:
        return
    if c.x < 0 or c.x >= cols or c.y < 0 or c.y >= rows:
        return
    if int(board[c.y][c.x]) == 0:
        return
    if not has_sel:
        selected = c
        has_sel = true
        _set_highlight(c, true)
        return
    if c == selected:
        _set_highlight(c, false)
        has_sel = false
        return
    var same_kind: bool = int(board[c.y][c.x]) == int(board[selected.y][selected.x])
    var path: Array = (can_link(board, selected, c) if same_kind else [])
    if path.is_empty():
        _set_highlight(selected, false)
        selected = c
        has_sel = true
        _set_highlight(c, true)
        return
    _set_highlight(selected, false)
    _flash_line(path)
    _remove_at(selected)
    _remove_at(c)
    has_sel = false
    if _all_cleared():
        win()
        return
    if not has_any_pair(board):
        board = reshuffle(board, rng)
        shuffle_msg_left = 1.0
        _redraw_all()

func _remove_at(c: Vector2i) -> void:
    board[c.y][c.x] = 0
    var p: Panel = cell_panels[c.y][c.x]
    if p != null and is_instance_valid(p):
        p.queue_free()
    cell_panels[c.y][c.x] = null

func _all_cleared() -> bool:
    for row in board:
        for v in row:
            if int(v) != 0:
                return false
    return true

func _flash_line(path: Array) -> void:
    var line := Line2D.new()
    line.width = 4.0
    line.default_color = GOLD
    var pts := PackedVector2Array()
    for p in path:
        pts.append(_cell_center(p))
    line.points = pts
    grid.add_child(line)
    var tw := create_tween()
    tw.tween_property(line, "modulate:a", 0.0, 0.25)
    tw.tween_callback(line.queue_free)

func _game_tick(dt: float) -> void:
    if shuffle_msg_left > 0.0:
        shuffle_msg_left = maxf(shuffle_msg_left - dt, 0.0)
    time_left -= dt
    if time_left <= 0.0:
        lose("时间到了")

# ---------- 逻辑（静态，好测） ----------
## 格子是不是空的能走：棋盘内要是 0；棋盘外一圈（-1 或 cols/rows）永远算空，可以绕；再往外不算
static func _is_open(board: Array, x: int, y: int, cols: int, rows: int) -> bool:
    if x < -1 or x > cols or y < -1 or y > rows:
        return false
    if x == -1 or x == cols or y == -1 or y == rows:
        return true
    return int(board[y][x]) == 0

## a、b 同行或同列，中间（不含端点）是不是都能走
static func _clear_between(board: Array, a: Vector2i, b: Vector2i, cols: int, rows: int) -> bool:
    if a.x == b.x and a.y != b.y:
        var lo: int = mini(a.y, b.y)
        var hi: int = maxi(a.y, b.y)
        for y in range(lo + 1, hi):
            if not _is_open(board, a.x, y, cols, rows):
                return false
        return true
    if a.y == b.y and a.x != b.x:
        var lo2: int = mini(a.x, b.x)
        var hi2: int = maxi(a.x, b.x)
        for x in range(lo2 + 1, hi2):
            if not _is_open(board, x, a.y, cols, rows):
                return false
        return true
    return a == b

## 从 a 出发四个方向能一路走到的格子（每一格都保证跟 a 之间是直线通的，可以当拐点）
static func _ray_points(board: Array, a: Vector2i, cols: int, rows: int) -> Array:
    var pts: Array = []
    for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        var p: Vector2i = a + d
        while _is_open(board, p.x, p.y, cols, rows):
            pts.append(p)
            p += d
    return pts

## a、b 能不能用不超过两次拐弯的折线连起来；能就返回拐点路径（含 a、b 本身），不能返回 []
static func can_link(board: Array, a: Vector2i, b: Vector2i) -> Array:
    if board.is_empty() or a == b:
        return []
    var rows: int = board.size()
    var cols: int = (board[0] as Array).size()
    if (a.x == b.x or a.y == b.y) and _clear_between(board, a, b, cols, rows):
        return [a, b]
    for c in [Vector2i(a.x, b.y), Vector2i(b.x, a.y)]:
        if _is_open(board, c.x, c.y, cols, rows) and _clear_between(board, a, c, cols, rows) and _clear_between(board, c, b, cols, rows):
            return [a, c, b]
    for p1 in _ray_points(board, a, cols, rows):
        for c2 in [Vector2i(p1.x, b.y), Vector2i(b.x, p1.y)]:
            if c2 == p1:
                continue
            if _is_open(board, c2.x, c2.y, cols, rows) and _clear_between(board, p1, c2, cols, rows) and _clear_between(board, c2, b, cols, rows):
                return [a, p1, c2, b]
    return []

## 场上还有没有能连起来的一对
static func has_any_pair(board: Array) -> bool:
    var by_kind := {}
    for y in board.size():
        var row: Array = board[y]
        for x in row.size():
            var v := int(row[x])
            if v == 0:
                continue
            if not by_kind.has(v):
                by_kind[v] = []
            (by_kind[v] as Array).append(Vector2i(x, y))
    for v in by_kind:
        var pts: Array = by_kind[v]
        for i in range(pts.size()):
            for j in range(i + 1, pts.size()):
                if not can_link(board, pts[i], pts[j]).is_empty():
                    return true
    return false

## 摆一副新牌：cols×rows 格，kinds 种菜（1～12），每种成对、尽量平均；总数是奇数就少一行保证成对
static func make_board(cols: int, rows: int, kinds: int, rng: RandomNumberGenerator) -> Array:
    var c := maxi(cols, 2)
    var r := maxi(rows, 2)
    if (c * r) % 2 == 1:
        r = maxi(r - 1, 2)
    var total := c * r
    var pairs := total / 2
    var kk := clampi(kinds, 1, maxi(1, mini(12, pairs)))
    var base_pairs := pairs / kk
    var extra := pairs % kk
    var vals: Array = []
    for k in kk:
        var cnt := base_pairs + (1 if k < extra else 0)
        for _n in cnt:
            vals.append(k + 1)
            vals.append(k + 1)
    for i in range(vals.size() - 1, 0, -1):
        var j: int = rng.randi_range(0, i)
        var tmp = vals[i]
        vals[i] = vals[j]
        vals[j] = tmp
    var out: Array = []
    var idx := 0
    for _y in r:
        var row: Array = []
        for _x in c:
            row.append(vals[idx])
            idx += 1
        out.append(row)
    return out

## 没得连了：把剩下没消的牌位置打乱，打到有能连的对子为止（打不出也不死循环，最多试 500 次）
static func reshuffle(board: Array, rng: RandomNumberGenerator) -> Array:
    var rows: int = board.size()
    if rows == 0:
        return board
    var cols: int = (board[0] as Array).size()
    var positions: Array = []
    var vals: Array = []
    for y in rows:
        for x in cols:
            var v := int(board[y][x])
            if v != 0:
                positions.append(Vector2i(x, y))
                vals.append(v)
    var nb: Array = []
    for _y in rows:
        var row: Array = []
        row.resize(cols)
        row.fill(0)
        nb.append(row)
    if vals.size() <= 1:
        for k in positions.size():
            var p0: Vector2i = positions[k]
            nb[p0.y][p0.x] = vals[k]
        return nb
    var attempts := 0
    while attempts < 500:
        attempts += 1
        for i in range(vals.size() - 1, 0, -1):
            var j: int = rng.randi_range(0, i)
            var tmp = vals[i]
            vals[i] = vals[j]
            vals[j] = tmp
        for k in positions.size():
            var p: Vector2i = positions[k]
            nb[p.y][p.x] = vals[k]
        if has_any_pair(nb):
            return nb
    return nb
