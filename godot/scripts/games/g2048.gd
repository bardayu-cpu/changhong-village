extends "res://scripts/games/mini_game.gd"
## 小菜合大菜（2048，T5、T6，蓝图 3.2）：上下左右滑，一样的菜碰到一起合成大一级的菜，合出这一关的目标菜就过。
## 没地方挪、也合不了就输。难度参数（minigames.json）：size 边长，target_pow 目标是第几级菜（5 = 第 5 级）
## 这个文件也是别的游戏的样板：逻辑写成静态函数好测，界面只管画和收手势

## 第 1～11 级菜（2、4、8……2048），名字占位、阿鱼可改；颜色借菜牌的
const DISHES := ["花生", "凉菜", "豆花", "清汤", "鱼", "甜皮鸭", "钵钵鸡", "回锅肉", "牛肉", "全家福", "大菜"]
const SWIPE := 30.0          # 手指划多远算一次滑动，像素

var n := 4
var target := 5
var board: Array = []        # n×n，0 = 空，k = 第 k 级菜
var cells: Array = []        # 每格一个 Panel（有菜时），重画时换
var grid: Control
var cell_px := 80.0
var gap := 8.0
var drag_from := Vector2.ZERO
var dragging := false

## 开始卡上的目标：外壳造的「探子」只 setup 没 _build，所以这里直接读参数，不读 _build 里才定的 target
## （9/19 分身查出来的：原来一直显示第 5 级那道菜）
func goal_text() -> String:
    return "合出「%s」" % DISHES[clampi(p_int("target_pow", 5) - 1, 0, DISHES.size() - 1)]

func status_text() -> String:
    return "目标 %s" % DISHES[clampi(p_int("target_pow", 5) - 1, 0, DISHES.size() - 1)]

func _build() -> void:
    n = maxi(p_int("size", 4), 3)
    target = clampi(p_int("target_pow", 5), 2, DISHES.size())
    board = []
    for i in n:
        var row: Array = []
        row.resize(n)
        row.fill(0)
        board.append(row)
    var side := minf(size.x, size.y) - 16.0
    cell_px = (side - gap * (n + 1)) / n
    grid = Panel.new()
    grid.size = Vector2(side, side)
    grid.position = (size - grid.size) * 0.5
    grid.add_theme_stylebox_override("panel", Tiles.box(Color("#5a3a2a"), 10))
    grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(grid)
    for j in n:
        for i in n:
            var bg := Panel.new()
            bg.size = Vector2(cell_px, cell_px)
            bg.position = _cell_pos(i, j)
            var st := StyleBoxFlat.new()
            st.bg_color = Color("#7a5a44")
            st.set_corner_radius_all(6)
            bg.add_theme_stylebox_override("panel", st)
            bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
            grid.add_child(bg)
    _spawn()
    _spawn()
    _redraw([])

func _cell_pos(i: int, j: int) -> Vector2:
    return Vector2(gap + i * (cell_px + gap), gap + j * (cell_px + gap))

## 往空格里放一道最小的菜（九成第 1 级，一成第 2 级）
func _spawn() -> void:
    var empty: Array = []
    for j in n:
        for i in n:
            if board[j][i] == 0:
                empty.append(Vector2i(i, j))
    if empty.is_empty():
        return
    var c: Vector2i = empty[rng.randi() % empty.size()]
    board[c.y][c.x] = 1 if rng.randf() < 0.9 else 2

func _redraw(merged: Array) -> void:
    for c in cells:
        c.queue_free()
    cells.clear()
    var fs := 24 if cell_px >= 70.0 else 12
    for j in n:
        for i in n:
            var k: int = board[j][i]
            if k == 0:
                continue
            var t := Tiles.dish_tile(k - 1, cell_px, font, fs)
            (t.get_child(0) as Label).text = DISHES[clampi(k - 1, 0, DISHES.size() - 1)]
            t.position = _cell_pos(i, j)
            if Vector2i(i, j) in merged:
                t.pivot_offset = t.size * 0.5
                t.scale = Vector2(1.15, 1.15)
                create_tween().tween_property(t, "scale", Vector2.ONE, 0.12)
            grid.add_child(t)
            cells.append(t)

# ---------- 手势 ----------
func _gui_input(e: InputEvent) -> void:
    if over or paused:
        return
    if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
        if e.pressed:
            dragging = true
            drag_from = e.position
        elif dragging:
            dragging = false
            _swipe(e.position - drag_from)
        accept_event()

func _unhandled_key_input(e: InputEvent) -> void:
    # 电脑上调试：方向键
    if over or paused or not (e is InputEventKey) or not e.pressed:
        return
    match e.keycode:
        KEY_LEFT: play(Vector2i(-1, 0))
        KEY_RIGHT: play(Vector2i(1, 0))
        KEY_UP: play(Vector2i(0, -1))
        KEY_DOWN: play(Vector2i(0, 1))

func _swipe(d: Vector2) -> void:
    if d.length() < SWIPE:
        return
    if absf(d.x) > absf(d.y):
        play(Vector2i(1 if d.x > 0 else -1, 0))
    else:
        play(Vector2i(0, 1 if d.y > 0 else -1))

## 往 dir 方向滑一步：动了就补一道菜、重画，然后看赢没赢、还能不能动
func play(dir: Vector2i) -> bool:
    var r := move(board, dir)
    if not r["changed"]:
        return false
    board = r["board"]
    _spawn()
    _redraw(r["merged"])
    if max_tile(board) >= target:
        win()
    elif not can_move(board):
        lose("没地方合了")
    return true

# ---------- 逻辑（静态，好测） ----------
## 一行往左挤：[1,1,2,0] → [2,2,0,0]，每道菜一步只合一次。返回 {line, merged: 合出来的下标}
static func slide_line(line: Array) -> Dictionary:
    var vals: Array = line.filter(func(v): return v != 0)
    var out: Array = []
    var merged: Array = []
    var i := 0
    while i < vals.size():
        if i + 1 < vals.size() and vals[i] == vals[i + 1]:
            out.append(vals[i] + 1)
            merged.append(out.size() - 1)
            i += 2
        else:
            out.append(vals[i])
            i += 1
    while out.size() < line.size():
        out.append(0)
    return {"line": out, "merged": merged}

## 整盘往 dir 滑：返回 {board, changed, merged: 合出来的格子 Vector2i}
static func move(b: Array, dir: Vector2i) -> Dictionary:
    var size_n := b.size()
    var nb: Array = []
    for row in b:
        nb.append(row.duplicate())
    var merged: Array = []
    for k in size_n:
        # 取出这一行（或列），按滑的方向排成「往左挤」的顺序
        var idx: Array = []
        for m in size_n:
            var p: Vector2i
            if dir.x != 0:
                p = Vector2i(m if dir.x < 0 else size_n - 1 - m, k)
            else:
                p = Vector2i(k, m if dir.y < 0 else size_n - 1 - m)
            idx.append(p)
        var line: Array = idx.map(func(p): return b[p.y][p.x])
        var r := slide_line(line)
        for m in size_n:
            var p: Vector2i = idx[m]
            nb[p.y][p.x] = r["line"][m]
        for m in r["merged"]:
            merged.append(idx[m])
    return {"board": nb, "changed": nb != b, "merged": merged}

static func max_tile(b: Array) -> int:
    var mx := 0
    for row in b:
        for v in row:
            mx = maxi(mx, v)
    return mx

static func can_move(b: Array) -> bool:
    for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        if move(b, d)["changed"]:
            return true
    return false
