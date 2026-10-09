extends "res://scripts/games/mini_game.gd"
## 记菜名（翻牌配对，T7、T8，蓝图 3.2）：开局全翻开给看几秒，然后扣下；点两张一样的就留着，不一样翻回去、算一次翻错。
## 翻错次数用完就输，配完全部就赢。难度参数（minigames.json）：pairs 对数，preview 预览秒数，misses 最多翻错次数
## 牌背红底金边、中间「囍」字（占位，正式美术到了换图）；牌面用 Tiles.dish_tile

const Cfg = preload("res://scripts/games/game_config.gd")
const BACK_BG := Color("#8a1a1a")
const BACK_BORDER := Color("#d4af37")
const BACK_CH := Color("#f4d97a")
const MISS_WAIT := 0.6
const POP_LEN := 0.35        # 配对成功那一下弹多久，秒
## 阿鱼 9/20 真机：「每行都必须是满的才对」。第 3 关 10 张摆成 4+4+2，最后一行缺两个。
## 这几个对数，牌数（对数×2）都排得成整行；难度表给别的数就往下取最近的一个
const PAIRS_OK := [3, 4, 5, 6, 8, 9, 10, 12]
## 牌最大多大（B7，体验第一轮）：原来封 110，屏幕空一半。牌面的菜图四周留 ART_PAD，
## 牌 152 时图正好 128（菜牌原图的大小），再大就是放大原图了
const MAX_CELL := 152.0

var pairs := 3
var misses_max := 8
var preview_total := 3.0
var deck: Array = []           # 每张牌的菜（0 起），长度 = pairs*2
var revealed: Array = []       # 正面朝上（预览、翻开中、已配对都算）
var matched: Array = []        # 已经配对成功、留着不再翻回去
var panels: Array = []
var total := 0
var cols := 3
var rows := 1
var grid: Control
var cell_px := 72.0
var gap := 8.0
var previewing := false
var preview_left := 0.0
var first_idx := -1
var pending_miss := false
var hide_at := 0.0
var miss_pair := Vector2i(-1, -1)
var misses := 0
var pop_left := 0.0            # 配对成功那一下的余韵，顶栏跟着说一句

func goal_text() -> String:
    return "配完 %d 对，最多翻错 %d 次" % [snap_pairs(p_int("pairs", 3)), p_int("misses", 8)]

func status_text() -> String:
    if previewing:
        return "记住它们"
    if pop_left > 0.0:
        return "配上了"
    return "翻错 %d/%d" % [misses, misses_max]

func _build() -> void:
    # 上限跟菜牌种数走（minigames.json 的 tiles 有 12 种），一对一种菜；9/19 01 定 pairs 封顶从 10 提到 12
    pairs = snap_pairs(clampi(p_int("pairs", 3), 3, maxi(Cfg.tiles().size(), 3)))
    misses_max = maxi(p_int("misses", 8), 0)
    preview_total = maxf(p_float("preview", 3.0), 0.0)
    deck = make_deck(pairs, maxi(Cfg.tiles().size(), 1), rng)
    total = deck.size()
    revealed = []
    matched = []
    panels = []
    for _i in total:
        revealed.append(true)   # 一开始全翻开，预览
        matched.append(false)
        panels.append(null)
    var avail_w: float = size.x - 16.0
    var avail_h: float = size.y - 16.0
    # 摆几列（B7）：原来一律「不小于 sqrt」往宽里摆，竖屏上 12 张摆成 4×3、牌只有 112；
    # 改成在排得成整行的那几种里挑牌最大的（12 张摆 3×4、牌 152）。每行照旧是满的（阿鱼 9/20）
    cols = cols_fit(total, avail_w, avail_h, gap, MAX_CELL)
    rows = int(ceil(float(total) / float(cols)))
    cell_px = clampf(_cell_for(cols, rows, avail_w, avail_h, gap), 32.0, MAX_CELL)
    grid = Control.new()
    grid.size = Vector2(cols * (cell_px + gap) + gap, rows * (cell_px + gap) + gap)
    grid.position = (size - grid.size) * 0.5
    grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(grid)
    previewing = preview_total > 0.0
    preview_left = preview_total
    _redraw_all()
    if not previewing:
        _set_all_face(false)

func _cell_pos(i: int) -> Vector2:
    var x := i % cols
    var y := i / cols
    return Vector2(gap + x * (cell_px + gap), gap + y * (cell_px + gap))

func _redraw_all() -> void:
    for p in panels:
        if p != null and is_instance_valid(p):
            p.queue_free()
    for i in total:
        _redraw_one(i)

func _redraw_one(i: int) -> void:
    var old = panels[i] if i < panels.size() else null
    if old != null and is_instance_valid(old):
        old.queue_free()
    var fs := 24 if cell_px >= 48.0 else 12
    var t: Panel
    if matched[i] or revealed[i]:
        # 牌面留底色：那是一张「牌」，牌需要一个面（阿鱼 A1 的例外）
        t = Tiles.dish_tile(deck[i], cell_px, font, fs, "", art_set, true)
    else:
        t = _back_tile(cell_px, font, fs)
    t.position = _cell_pos(i)
    grid.add_child(t)
    panels[i] = t

## 配对成功：这两张描金边、弹一下（A4）
func _pop(i: int) -> void:
    if i < 0 or i >= panels.size():
        return
    var t = panels[i]
    if t == null or not is_instance_valid(t):
        return
    Tiles.highlight(t, true)
    var pan: Panel = t
    pan.pivot_offset = pan.size * 0.5
    pan.scale = Vector2(1.18, 1.18)
    create_tween().tween_property(pan, "scale", Vector2.ONE, POP_LEN)

func _set_all_face(up: bool) -> void:
    for i in total:
        if not matched[i]:
            revealed[i] = up
    _redraw_all()

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
            tap(gy * cols + gx)
        accept_event()

## 翻一张牌；预览中或者正等着把翻错的两张扣回去（那 0.6 秒）时不收
func tap(i: int) -> void:
    if over or previewing or pending_miss:
        return
    if i < 0 or i >= total:
        return
    if matched[i] or revealed[i]:
        return
    revealed[i] = true
    _redraw_one(i)
    if first_idx == -1:
        first_idx = i
        return
    var a := first_idx
    first_idx = -1
    if deck[a] == deck[i]:
        matched[a] = true
        matched[i] = true
        # 阿鱼 9/20：「配对成功后应该有明确的配对成功」。原来翻对了就那么消掉，没有「对了」的感觉
        _pop(a)
        _pop(i)
        pop_left = POP_LEN
        if _all_matched():
            win()
    else:
        pending_miss = true
        hide_at = MISS_WAIT
        miss_pair = Vector2i(a, i)
        misses += 1
        if misses > misses_max:
            lose("翻错太多次了")

func _resolve_miss() -> void:
    var a := miss_pair.x
    var b := miss_pair.y
    if a >= 0 and a < total and not matched[a]:
        revealed[a] = false
        _redraw_one(a)
    if b >= 0 and b < total and not matched[b]:
        revealed[b] = false
        _redraw_one(b)
    miss_pair = Vector2i(-1, -1)

func _all_matched() -> bool:
    for m in matched:
        if not m:
            return false
    return true

func _game_tick(dt: float) -> void:
    if pop_left > 0.0:
        pop_left = maxf(pop_left - dt, 0.0)
    if previewing:
        preview_left -= dt
        if preview_left <= 0.0:
            previewing = false
            _set_all_face(false)
        return
    if pending_miss:
        hide_at -= dt
        if hide_at <= 0.0:
            pending_miss = false
            _resolve_miss()

# ---------- 画法（静态，跟 Tiles.dish_tile 配一套） ----------
## 牌背：红底金边，中间一个「囍」字，正式美术到了换图
static func _back_tile(sz: float, font: Font, font_size: int) -> Panel:
    var p := Panel.new()
    p.size = Vector2(sz, sz)
    var st := StyleBoxFlat.new()
    st.bg_color = BACK_BG
    st.border_color = BACK_BORDER
    st.set_border_width_all(3)
    st.set_corner_radius_all(6)
    p.add_theme_stylebox_override("panel", st)
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var l := Label.new()
    l.text = "囍"
    l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", BACK_CH)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.size = p.size
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(l)
    return p

# ---------- 逻辑（静态，好测） ----------
## 对数取 PAIRS_OK 里不超过 p 的最大那个（牌数是双数还不够，还得排得成整行）
static func snap_pairs(p: int) -> int:
    var best: int = PAIRS_OK[0]
    for v in PAIRS_OK:
        if int(v) <= p:
            best = int(v)
    return best

## 牌该摆几列：**必须整除牌数**，不然最后一行是缺的（阿鱼 9/20）。
## 在因数里取不小于 sqrt 的最小那个，排出来最接近方块
static func _cols_for(total: int) -> int:
    var want := sqrt(float(total))
    var best := total
    for c in range(1, total + 1):
        if total % c != 0:
            continue
        if float(c) >= want:
            best = c
            break
    return maxi(best, 1)

## 按 cols 列 rows 行摆，牌能多大（不封顶）
static func _cell_for(c: int, r: int, w: float, h: float, g: float) -> float:
    return minf((w - g * (c + 1)) / c, (h - g * (r + 1)) / r)

## 这么多张牌在 w×h 里摆几列牌最大（B7）：只在**整除牌数**的列数里挑（每行都得是满的），
## 牌一样大（都顶到 max_cell）时挑更接近方块的那种，别摆成一长条
static func cols_fit(total: int, w: float, h: float, g: float, max_cell: float) -> int:
    var best := _cols_for(total)
    var best_px := minf(_cell_for(best, total / best, w, h, g), max_cell)
    for c in range(1, total + 1):
        if total % c != 0:
            continue
        var r := total / c
        var px := minf(_cell_for(c, r, w, h, g), max_cell)
        var squarer := absi(c - r) < absi(best - total / best)
        if px > best_px + 0.5 or (absf(px - best_px) <= 0.5 and squarer):
            best = c
            best_px = px
    return best

## 摆一副牌：pairs 对，从 kinds_total 种菜里选（菜不够就轮回去用），洗匀。返回长度 pairs*2 的菜序号数组
static func make_deck(pairs: int, kinds_total: int, rng: RandomNumberGenerator) -> Array:
    var kt := maxi(kinds_total, 1)
    var vals: Array = []
    for i in pairs:
        var kind := i % kt
        vals.append(kind)
        vals.append(kind)
    for i in range(vals.size() - 1, 0, -1):
        var j: int = rng.randi_range(0, i)
        var tmp = vals[i]
        vals[i] = vals[j]
        vals[j] = tmp
    return vals
