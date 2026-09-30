extends "res://scripts/games/mini_game.gd"
## 小菜合大菜（2048，T5、T6，蓝图 3.2）：上下左右滑，一样的菜碰到一起合成大一级的菜，合出这一关的目标菜就过。
## 没地方挪、也合不了就输。难度参数（minigames.json）：size 边长，target_pow 目标是第几级菜（5 = 第 5 级）
## 这个文件也是别的游戏的样板：逻辑写成静态函数好测，界面只管画和收手势

## 合上去那条路（阿鱼 9/20 定：原来的 11 级菜作废，改成农作物成长路径，先做水稻 10 级）。
## 名字、级数、用哪套图全在 assets/minigames/ladder.json，**改字改级数不改代码**；
## 哪一关用哪种作物也在那份 json 的 by_level 里（阿鱼在考虑以后每关换一种），这里只管按关数问它要
const LADDER := "res://assets/minigames/ladder.json"
static var _ladder: Dictionary = {}
const SWIPE := 30.0          # 手指划多远算一次滑动，像素
const UISkin = preload("res://scripts/games/ui_skin.gd")
var skin := false            # 外壳换 GPT 第 1 批（01 D 9/30）：棋盘底、格子底、合成时的星星

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
    var st := steps()
    return "从一粒%s合到「%s」" % [str(st[0]), str(st[clampi(p_int("target_pow", 5) - 1, 0, st.size() - 1)])]

func status_text() -> String:
    # 体验评审第 6 条：原来只写「目标 X」，不写现在最大合到哪，滑十分钟也不知道走到没走到
    var goal_name: String = steps()[clampi(p_int("target_pow", 5) - 1, 0, steps().size() - 1)]
    var mx := max_tile(board) if not board.is_empty() else 0
    if mx <= 0:
        return "目标 %s" % goal_name
    return "目标 %s 现在最大 %s" % [goal_name, steps()[clampi(mx - 1, 0, steps().size() - 1)]]

## 顶栏放图（B10，阿鱼 9/23「有图就别叠字」）：原来写「目标 抽杆 现在最大 谷种」，抽杆、谷种没人看得懂，
## 牌上又是图——改成「目标 [那一级的小图] 现在最大 [那一级的小图]」，级名一个字不写。
## 这一关图没交齐（整盘色块兜底，art_set 被清成空）就返回空，外壳照旧写上面那句带名字的
func status_parts() -> Array:
    if art_set == "" or board.is_empty():
        return []
    var goal_tex := Tiles.dish_art(target - 1, art_set)
    if goal_tex == null:
        return []
    var out: Array = ["目标", goal_tex]
    var mx := max_tile(board)
    var mx_tex := Tiles.dish_art(mx - 1, art_set) if mx > 0 else null
    if mx_tex != null:
        out.append_array(["现在最大", mx_tex])
    return out

## 外壳开局前问的（还没 _build）：这一关那套图齐了，顶栏就会放图，跟 _build 里定 art_set 是同一个判断
func status_has_icons() -> bool:
    return Tiles.art_ready(str(crop().get("art_set", art_set)), steps().size())

## 这一关用哪种作物（by_level 没写就用 default）
func crop() -> Dictionary:
    if _ladder.is_empty():
        var j = JSON.parse_string(FileAccess.get_file_as_string(LADDER))
        _ladder = j if j is Dictionary else {}
    var crops: Dictionary = _ladder.get("crops", {})
    var name := str(_ladder.get("default", ""))
    # 每关一种（阿鱼 9/20）：第 N 关用第 N 种，关号超过种数就一直用最后一种
    if bool(_ladder.get("per_level", false)) and not crops.is_empty():
        var keys: Array = crops.keys()
        keys.sort()
        name = str(keys[clampi(level - 1, 0, keys.size() - 1)])
    # by_level 有内容时它说了算（要按段分的时候用）
    for r in _ladder.get("by_level", []):
        var rr: Dictionary = r
        if level >= int(rr.get("from", 1)) and level <= int(rr.get("to", 9999)):
            name = str(rr.get("crop", name))
            break
    var c = crops.get(name, {})
    return c if c is Dictionary else {}

## 这条路上每一级叫什么
func steps() -> Array:
    var st = crop().get("steps", [])
    return st if st is Array and not st.is_empty() else ["种子"]

func _build() -> void:
    # 这一关那种作物有自己的一套图（art_set），没写就用 minigames.json 给这个游戏定的那套。
    # **十级的图少一张就整套不用**，那一关整盘退回「色块 + 名字」——半图半色块比全色块更难看，
    # 也更容易让人以为是坏了（01 9/20 定，03 9/21 测出来原来是一张张单独找的）
    var want: String = str(crop().get("art_set", art_set))
    art_set = want if Tiles.art_ready(want, steps().size()) else ""
    n = maxi(p_int("size", 4), 3)
    target = clampi(p_int("target_pow", 5), 2, steps().size())
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
    skin = UISkin.tex("base_ui_board_v1") != null
    var bsb: StyleBox = UISkin.box("base_ui_board_v1", UISkin.BOARD_M) if skin else null
    grid.add_theme_stylebox_override("panel", bsb if bsb != null else Tiles.box(Color("#5a3a2a"), 10))
    grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(grid)
    for j in n:
        for i in n:
            if skin:
                var cb := UISkin.cell(cell_px)
                cb.position = _cell_pos(i, j)
                grid.add_child(cb)
                continue
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
    var fs := 24 if cell_px >= 44.0 else 12
    for j in n:
        for i in n:
            var k: int = board[j][i]
            if k == 0:
                continue
            # 这条路有自己一套图（作物的 art_set），不是五个游戏共用的那 12 张菜牌——
            # 拿级数去共用那套里取会错位（03 9/20 报过）。水稻那套 GPT 还没交，
            # dish_tile 取不到就整套退回「色块 + 名字」；图往 assets/minigames/<art_set>/ 一放就自动用上。
            # 色块的时候名字一定要看得见（色块分不出哪级大）；有图的时候不叠字（阿鱼 9/23），垫一层浅色牌底，
            # 不然最低几级只有一小粒，看不出这格有牌（01 9/23）
            var st := steps()
            var t := Tiles.dish_tile(k - 1, cell_px, font, fs, str(st[clampi(k - 1, 0, st.size() - 1)]), art_set, false, true)
            t.position = _cell_pos(i, j)
            if Vector2i(i, j) in merged:
                t.pivot_offset = t.size * 0.5
                t.scale = Vector2(1.15, 1.15)
                create_tween().tween_property(t, "scale", Vector2.ONE, 0.12)
                if skin:
                    UISkin.pop(grid, t.position + t.size * 0.5, cell_px)
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
