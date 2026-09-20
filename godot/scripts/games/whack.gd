extends "res://scripts/games/mini_game.gd"
## 打地鼠（夹菜，T9/T10，蓝图 3.2）：盘子排 3 列，菜从盘子里随机冒出来，点开就夹走；冒出辣椒点了倒扣分。
## 难度参数（minigames.json）：holes 盘子数、duration 时限（秒）、target 要夹几道、
## show 一道菜冒出来停几秒、interval 隔多久冒一道、bad 冒出来的是辣椒的比例
## 逻辑（hit(i) 夹第 i 个盘子）和画面分开，跟 g2048.gd 一样：测试直接调 hit()，不用真点

const Cfg = preload("res://scripts/games/game_config.gd")
const COLS := 3
const POP_TIME := 0.12   # 冒出来／缩回去的动画时长

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

func goal_text() -> String:
    return "%d 秒内夹 %d 道菜，别夹辣椒" % [p_int("duration", 30), p_int("target", 12)]

func status_text() -> String:
    return "夹了 %d/%d 剩 %d 秒" % [score, p_int("target", 12), int(ceil(time_left))]

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

    var rows := int(ceil(float(holes_n) / float(COLS)))
    var pad := 16.0
    var gap := 14.0
    var cell := minf((size.x - pad * 2.0 - gap * (COLS - 1)) / COLS, (size.y - pad * 2.0 - gap * (rows - 1)) / rows)
    cell = clampf(cell, 40.0, 130.0)
    var grid_w := cell * COLS + gap * (COLS - 1)
    var grid_h := cell * rows + gap * (rows - 1)
    var origin := Vector2((size.x - grid_w) * 0.5, (size.y - grid_h) * 0.5)
    for i in holes_n:
        var col := i % COLS
        var row := i / COLS
        var plate := Panel.new()
        plate.size = Vector2(cell, cell)
        plate.position = origin + Vector2(col * (cell + gap), row * (cell + gap))
        var st := StyleBoxFlat.new()
        st.bg_color = Color("#e8ddc0")
        st.border_color = Color("#c9b98a")
        st.set_border_width_all(3)
        st.set_corner_radius_all(int(cell * 0.5))
        plate.add_theme_stylebox_override("panel", st)
        plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(plate)
        plates.append(plate)
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
            lose("时间到了，夹了 %d 道" % score)
        return
    spawn_timer += dt
    if spawn_timer >= interval:
        spawn_timer = 0.0
        _try_spawn()

## 第 i 个盘子被点了：夹到菜 +1、点到辣椒 -1（最少到 0）、点空盘子 0
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
    _fly_away(i)
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
    var node: Panel
    if bad:
        node = _bad_tile(dish_size, fs)
    else:
        node = Tiles.dish_tile(rng.randi() % maxi(Cfg.tiles().size(), 1), dish_size, font, fs, "", art_set)
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

## 夹到了：弹一下飞走
func _fly_away(i: int) -> void:
    var st: Dictionary = holes_state[i]
    var node = st.get("node")
    if node != null and is_instance_valid(node):
        var tw := create_tween()
        tw.set_parallel(true)
        tw.tween_property(node, "position:y", node.position.y - 40.0, 0.18)
        tw.tween_property(node, "modulate:a", 0.0, 0.18)
        tw.chain().tween_callback(node.queue_free)
    holes_state[i] = {"up": false, "bad": false, "timer": 0.0, "node": null}

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
## 换成**一眼不同**的：墨绿底 + 亮黄描边 + 写「辣」，红的那一片里只有它是绿的
func _bad_tile(sz: float, font_size := 24) -> Panel:
    var p := Panel.new()
    p.size = Vector2(sz, sz)
    p.add_theme_stylebox_override("panel", Tiles.box(Color("#1f5c3a"), 6, Color("#ffd447")))
    var l := Tiles.label("辣", font, font_size, Color("#ffd447"))
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.size = p.size
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(l)
    return p

# ---------- 手势 ----------
func _gui_input(e: InputEvent) -> void:
    if over or paused:
        return
    if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
        var idx := _hole_at(e.position)
        if idx >= 0:
            hit(idx)
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
