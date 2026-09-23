extends "res://scripts/games/mini_game.gd"
## 护菜（暂名，T9/T10，蓝图 3.2；原来叫「夹菜」）：做好的菜一盘盘摆在厨房案板上，**小松鼠**从菜后面探头来偷，
## 点中它就缩回去，算守住一次；没点到它就溜走，不扣分。辣椒照旧：点到倒扣一次。
## 说明：`回执/接彩头和护菜-玩法改.md` 第二节（01 9/23）。**小松鼠不能画成老鼠**（阿鱼原话），占位也带一条大尾巴
## 难度参数（minigames.json）：holes 几盘菜、duration 时限（秒）、target 要守住几次、
## show 松鼠探头停几秒、interval 隔多久探一次头、bad 探出来的是辣椒的比例（沿用夹菜那组数，03 测过的）
## 图：assets/minigames/guard/ 下那 14 张（出图清单第 3 批，02 接图时去掉前缀和 _v1），**一张不齐就整套占位**
## 逻辑（hit(i) 点第 i 盘菜）和画面分开，跟 g2048.gd 一样：测试直接调 hit()，不用真点

const Cfg = preload("res://scripts/games/game_config.gd")
const COLS := 3
const POP_TIME := 0.12   # 冒出来／缩回去的动画时长
const ART_DIR := "res://assets/minigames/guard/"
const ART_FILES := ["board", "plate", "dish_a", "dish_b", "dish_c", "dish_d", "dish_e", "dish_f",
    "squirrel", "squirrel_hit", "chili", "hit", "hand", "bg"]
const INK := Color("#2c1f1c")

var holes_n := 6
var duration := 30.0
var target := 12
var show_time := 1.3
var interval := 0.9
var bad_ratio := 0.0

var time_left := 0.0
var score := 0
var spawn_timer := 0.0
var holes_state: Array = []   # 每个盘子一个 {up, bad, timer, node}
var plates: Array = []
var flash: ColorRect
var art := {}           # 名字 -> Texture2D；空的就是用占位

func goal_text() -> String:
    return "%d 秒内挡回 %d 次来偷菜的小松鼠，别点辣椒" % [p_int("duration", 30), p_int("target", 12)]

func status_text() -> String:
    return "守住 %d/%d 剩 %d 秒" % [score, p_int("target", 12), int(ceil(time_left))]

func _build() -> void:
    holes_n = clampi(p_int("holes", 6), 3, 12)
    duration = p_float("duration", 30.0)
    target = p_int("target", 12)
    show_time = maxf(p_float("show", 1.3), 0.1)
    interval = maxf(p_float("interval", 0.9), 0.1)
    bad_ratio = clampf(p_float("bad", 0.0), 0.0, 1.0)
    time_left = duration
    score = 0
    spawn_timer = 0.0
    holes_state.clear()
    plates.clear()
    for c in get_children():
        c.queue_free()
    art = _load_art()
    if art.has("bg"):
        add_child(_pic(art["bg"], Vector2.ZERO, size, TextureRect.STRETCH_KEEP_ASPECT_COVERED))

    var rows := int(ceil(float(holes_n) / float(COLS)))
    var pad := 16.0
    var gap := 14.0
    var cell := minf((size.x - pad * 2.0 - gap * (COLS - 1)) / COLS, (size.y - pad * 2.0 - gap * (rows - 1)) / rows)
    cell = clampf(cell, 40.0, 130.0)
    var grid_w := cell * COLS + gap * (COLS - 1)
    var grid_h := cell * rows + gap * (rows - 1)
    var origin := Vector2((size.x - grid_w) * 0.5, (size.y - grid_h) * 0.5)
    # 案板：整个盘面的底，菜摆在上面
    var board_r := Rect2(origin - Vector2(pad, pad + cell * 0.4), Vector2(grid_w + pad * 2.0, grid_h + pad * 2.0 + cell * 0.4))
    if art.has("board"):
        add_child(_pic(art["board"], board_r.position, board_r.size, TextureRect.STRETCH_SCALE))
    else:
        var bd := Panel.new()
        var bst := StyleBoxFlat.new()
        bst.bg_color = Color("#c9965a")
        bst.border_color = Color("#7a5230")
        bst.set_border_width_all(4)
        bst.set_corner_radius_all(14)
        bd.add_theme_stylebox_override("panel", bst)
        bd.position = board_r.position
        bd.size = board_r.size
        bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bd.draw.connect(func():
            for k in 7:
                var yy := 18.0 + k * (bd.size.y - 36.0) / 6.0
                bd.draw_line(Vector2(14, yy), Vector2(bd.size.x - 14, yy + 6.0), Color("#b07f47"), 2.0))
        add_child(bd)
    for i in holes_n:
        var col := i % COLS
        var row := i / COLS
        var plate := Panel.new()
        plate.size = Vector2(cell, cell)
        plate.position = origin + Vector2(col * (cell + gap), row * (cell + gap))
        var st := StyleBoxFlat.new()
        if art.has("plate"):
            st.bg_color = Color(0, 0, 0, 0)
        else:
            st.bg_color = Color("#e8ddc0")
            st.border_color = Color("#c9b98a")
            st.set_border_width_all(3)
            st.set_corner_radius_all(int(cell * 0.5))
        plate.add_theme_stylebox_override("panel", st)
        plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(plate)
        plates.append(plate)
        if art.has("plate"):
            plate.add_child(_pic(art["plate"], Vector2.ZERO, plate.size, TextureRect.STRETCH_KEEP_ASPECT_CENTERED))
        # 盘里那道菜：一直摆着，松鼠从它后面探头（z 比松鼠高，挡住松鼠下半截）
        var dsz := cell * 0.62
        var dish: Control
        var dish_key := "dish_%s" % "abcdef"[i % 6]
        if art.has(dish_key):
            dish = _pic(art[dish_key], Vector2.ZERO, Vector2(dsz, dsz), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
        else:
            dish = Tiles.dish_tile(i % maxi(Cfg.tiles().size(), 1), dsz, font, 24 if dsz >= 44.0 else 12, "", art_set)
        dish.position = plate.position + Vector2((cell - dsz) * 0.5, cell * 0.5 - dsz * 0.38)
        dish.z_index = 2
        dish.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(dish)
        holes_state.append({"up": false, "bad": false, "timer": 0.0, "node": null})

    flash = ColorRect.new()
    flash.color = Color(1, 0, 0, 0)
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(flash)

func _game_tick(dt: float) -> void:
    for i in holes_state.size():
        var st: Dictionary = holes_state[i]
        if st["up"]:
            st["timer"] -= dt
            if st["timer"] <= 0.0:
                _retract(i)
    time_left = maxf(time_left - dt, 0.0)
    if time_left <= 0.0:
        if score < target:
            lose("时间到了，守住了 %d 次" % score)
        return
    spawn_timer += dt
    if spawn_timer >= interval:
        spawn_timer = 0.0
        _try_spawn()

## 第 i 盘菜被点了：点中松鼠 +1（守住）、点到辣椒 -1（最少到 0）、没东西探头 0
func hit(i: int) -> int:
    if i < 0 or i >= holes_state.size():
        return 0
    var st: Dictionary = holes_state[i]
    if not st["up"]:
        return 0
    if st["bad"]:
        score = maxi(score - 1, 0)
        _shake_bad(i)
        _retract(i)
        return -1
    score += 1
    _duck(i)
    if score >= target:
        win()
    return 1

func _try_spawn() -> void:
    var empty: Array = []
    for i in holes_state.size():
        if not holes_state[i]["up"]:
            empty.append(i)
    if empty.is_empty():
        return
    _spawn_at(empty[rng.randi() % empty.size()])

func _spawn_at(i: int) -> void:
    var plate: Panel = plates[i]
    var bad := rng.randf() < bad_ratio
    var dish_size := plate.size.x * 0.62
    var fs := 24 if dish_size >= 44.0 else 12
    var node: Control
    if bad:
        node = _pic(art["chili"], Vector2.ZERO, Vector2(dish_size, dish_size), TextureRect.STRETCH_KEEP_ASPECT_CENTERED) if art.has("chili") else _bad_tile(dish_size, fs)
    else:
        node = _squirrel(dish_size)
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    node.z_index = 1   # 在菜后面：菜挡住它下半截，像是从菜后面探头
    var up_pos: Vector2 = plate.position + Vector2((plate.size.x - dish_size) * 0.5, -dish_size * 0.32)
    var start_pos: Vector2 = plate.position + Vector2((plate.size.x - dish_size) * 0.5, plate.size.y * 0.5)
    node.position = start_pos
    add_child(node)
    var tw := create_tween()
    tw.tween_property(node, "position", up_pos, POP_TIME)
    holes_state[i] = {"up": true, "bad": bad, "timer": show_time, "node": node}

## 停留时间到了：自己缩回盘子里
func _retract(i: int) -> void:
    var st: Dictionary = holes_state[i]
    var node = st.get("node")
    if node != null and is_instance_valid(node):
        var plate: Panel = plates[i]
        var down_pos := Vector2(node.position.x, plate.position.y + plate.size.y * 0.5)
        var tw := create_tween()
        tw.tween_property(node, "position", down_pos, POP_TIME)
        tw.tween_callback(node.queue_free)
    holes_state[i] = {"up": false, "bad": false, "timer": 0.0, "node": null}

## 点中松鼠：它缩一下、缩回菜后面去（守住了），篮口闪一下那种光在这儿闪
func _duck(i: int) -> void:
    var st: Dictionary = holes_state[i]
    var node = st.get("node")
    if node != null and is_instance_valid(node):
        var c: Control = node
        if art.has("squirrel_hit") and c is TextureRect:
            (c as TextureRect).texture = art["squirrel_hit"]
        else:
            c.set_meta("hit", true)
            c.queue_redraw()
        var plate: Panel = plates[i]
        var tw := create_tween()
        tw.tween_interval(0.12)
        tw.tween_property(c, "position:y", plate.position.y + plate.size.y * 0.5, POP_TIME * 1.5)
        tw.tween_callback(c.queue_free)
        _hit_flash(c.position + c.size * 0.5, c.size.x)
    holes_state[i] = {"up": false, "bad": false, "timer": 0.0, "node": null}

func _hit_flash(at: Vector2, sz: float) -> void:
    var fx: Control
    if art.has("hit"):
        fx = _pic(art["hit"], Vector2.ZERO, Vector2(sz, sz) * 1.2, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
    else:
        fx = Control.new()
        fx.size = Vector2(sz, sz) * 1.2
        fx.draw.connect(func(): fx.draw_arc(fx.size * 0.5, fx.size.x * 0.4, 0, TAU, 28, Color("#ffe08a"), 4.0))
    fx.position = at - fx.size * 0.5
    fx.pivot_offset = fx.size * 0.5
    fx.z_index = 3
    fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(fx)
    var tw := create_tween()
    tw.set_parallel(true)
    tw.tween_property(fx, "scale", Vector2(1.3, 1.3), 0.25)
    tw.tween_property(fx, "modulate:a", 0.0, 0.25)
    tw.chain().tween_callback(fx.queue_free)

## 小松鼠：有图用图；没图用代码画的占位——**大尾巴、尖耳朵、浅色肚皮**，一眼是松鼠不是老鼠（阿鱼：不可以是老鼠）
func _squirrel(sz: float) -> Control:
    if art.has("squirrel"):
        return _pic(art["squirrel"], Vector2.ZERO, Vector2(sz, sz), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
    var c := Control.new()
    c.size = Vector2(sz, sz)
    c.draw.connect(_draw_squirrel.bind(c))
    return c

func _draw_squirrel(n: Control) -> void:
    var s := n.size.x / 64.0     # 按 64 见方画，再按实际大小缩放
    var hit: bool = n.get_meta("hit", false)
    var brown := Color("#b8692a")
    # 大尾巴：从身子右后方往上卷，比头还高
    var tail := PackedVector2Array()
    for k in 24:
        var a := -PI * 0.15 + PI * 1.35 * float(k) / 23.0
        tail.append(Vector2(44, 30) * s + Vector2(cos(a) * 16.0, -sin(a) * 22.0) * s)
    for k in 24:
        var a := -PI * 0.15 + PI * 1.35 * float(23 - k) / 23.0
        tail.append(Vector2(44, 34) * s + Vector2(cos(a) * 7.0, -sin(a) * 10.0) * s)
    n.draw_colored_polygon(tail, Color("#d4843a"))
    # 身子
    n.draw_circle(Vector2(30, 44) * s, 15.0 * s, brown)
    n.draw_circle(Vector2(30, 47) * s, 9.0 * s, Color("#f3dcb8"))
    # 头
    var hc := Vector2(28, 24) * s
    # 尖耳朵（带一撮毛），老鼠是圆耳朵
    for ex in [-9.0, 7.0]:
        var ear := PackedVector2Array([hc + Vector2(ex - 3.0, -7) * s, hc + Vector2(ex + 1.0, -21) * s, hc + Vector2(ex + 5.0, -7) * s])
        n.draw_colored_polygon(ear, brown)
        n.draw_line(hc + Vector2(ex + 1.0, -21) * s, hc + Vector2(ex + 1.0, -25) * s, INK, 1.5)
    n.draw_circle(hc, 12.0 * s, brown)
    n.draw_circle(hc + Vector2(0, 5) * s, 7.0 * s, Color("#f3dcb8"))
    n.draw_arc(hc, 12.0 * s, 0, TAU, 24, INK, 1.5)
    if hit:
        # 被挡回去：眯眼
        n.draw_line(hc + Vector2(-7, -2) * s, hc + Vector2(-2, -2) * s, INK, 2.0)
        n.draw_line(hc + Vector2(2, -2) * s, hc + Vector2(7, -2) * s, INK, 2.0)
    else:
        n.draw_circle(hc + Vector2(-4.5, -2) * s, 2.2 * s, INK)
        n.draw_circle(hc + Vector2(4.5, -2) * s, 2.2 * s, INK)
    n.draw_circle(hc + Vector2(0, 3) * s, 1.8 * s, Color("#5a2e1a"))

## 一张图摆成一个不收点击的块
func _pic(tex: Texture2D, pos: Vector2, sz: Vector2, stretch: int) -> TextureRect:
    var tr := TextureRect.new()
    tr.texture = tex
    tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tr.stretch_mode = stretch
    tr.position = pos
    tr.size = sz
    tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return tr

## 14 张都在才用图；缺一张整套占位（跟作物图一个规矩）
func _load_art() -> Dictionary:
    var out := {}
    for f in ART_FILES:
        var path: String = ART_DIR + f + ".png"
        if not ResourceLoader.exists(path):
            return {}
        out[f] = load(path)
    return out

## 点错了（体验评审第 5 条）：原来整个游戏区闪一片红（0.4 透明度盖满），
## 喜宴桌上那是「出事了」的信号。改成那个盘子抖一下、辣椒左右摇头
func _shake_bad(i: int) -> void:
    if i < 0 or i >= holes_state.size():
        return
    var node = holes_state[i].get("node")
    for target_node in [node, plates[i] if i < plates.size() else null]:
        if target_node == null or not is_instance_valid(target_node):
            continue
        var c: Control = target_node
        var x0 := c.position.x
        var tw := create_tween()
        tw.tween_property(c, "position:x", x0 - 6.0, 0.05)
        tw.tween_property(c, "position:x", x0 + 6.0, 0.05)
        tw.tween_property(c, "position:x", x0 - 4.0, 0.05)
        tw.tween_property(c, "position:x", x0, 0.05)

## 辣椒（体验评审第 13 条）：原来是 #b0261e 的红底，和 12 号菜牌「肉」的 #a3262b 几乎一个色，
## 玩家学到的捷径变成「底色红 = 别碰」，连红烧肉一起躲了。
## 换成**一眼不同**的：墨绿底 + 亮黄描边，红的那一片里只有它是绿的。
## 9/23 起占位不写字（01：靠形状和颜色分），底上画一根弯辣椒
func _bad_tile(sz: float, _font_size := 24) -> Panel:
    var p := Panel.new()
    p.size = Vector2(sz, sz)
    p.add_theme_stylebox_override("panel", Tiles.box(Color("#1f5c3a"), 6, Color("#ffd447")))
    p.draw.connect(func():
        var s := sz / 64.0
        var pts := PackedVector2Array()
        for k in 13:
            var t := float(k) / 12.0
            pts.append(Vector2(20 + t * 26, 22 + sin(t * PI * 0.9) * 22 + t * 8) * s)
        p.draw_polyline(pts, Color("#e53935"), 9.0 * s)
        p.draw_line(Vector2(16, 18) * s, Vector2(22, 24) * s, Color("#7cc242"), 4.0 * s))
    return p

# ---------- 手势 ----------
func _gui_input(e: InputEvent) -> void:
    if over or paused:
        return
    if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
        var idx := _hole_at(e.position)
        if idx >= 0:
            hit(idx)
        _show_hand(e.position)
        accept_event()

## 点哪个盘子（体验评审第 3 条）：**先认冒出来那张菜本身**，认不到再认盘子。
## 菜冒起来比盘沿高出约 26 像素、菜高约 81 像素，上面三成露在盘子外头；原来只认盘子那个框，
## 于是「照着菜点没反应」，而且盘子上下只隔 14 像素，露出来那截落在**上一排**的框里——
## 玩家没点辣椒却被判倒扣，就是这么来的
func _hole_at(pos: Vector2) -> int:
    for i in holes_state.size():
        var st: Dictionary = holes_state[i]
        if not st["up"]:
            continue
        var node = st.get("node")
        if node != null and is_instance_valid(node) and Rect2((node as Control).position, (node as Control).size).has_point(pos):
            return i
    for i in plates.size():
        var p: Panel = plates[i]
        if Rect2(p.position, p.size).has_point(pos):
            return i
    return -1

## 图到了：点哪儿，那只手（只有手和袖子）在那儿按一下；占位不画手
func _show_hand(at: Vector2) -> void:
    if not art.has("hand"):
        return
    var h := _pic(art["hand"], Vector2.ZERO, Vector2(80, 80), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
    h.position = at - Vector2(40, 20)
    h.z_index = 4
    add_child(h)
    var tw := create_tween()
    tw.tween_interval(0.15)
    tw.tween_property(h, "modulate:a", 0.0, 0.15)
    tw.tween_callback(h.queue_free)
