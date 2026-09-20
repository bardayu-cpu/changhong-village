extends "res://scripts/games/mini_game.gd"
## 接喜糖（接物，T11/T12，蓝图 3.2）：喜糖从顶上随机 x 掉下来，篮子跟手指左右走去接；接到鞭炮算漏。
## 难度参数（minigames.json）：duration 时限（秒）、target 要接几颗、speed 下落像素/秒、
## interval 隔多久掉一个、misses 最多漏几颗、bad 掉下来的是鞭炮的比例
## 逻辑（下落、判定）和画面分开，都在 _game_tick 里：测试直接推时间、直接改 basket_x，不用真拖

var duration := 30.0
var target := 12
var speed := 170.0
var interval := 0.85
var misses_max := 6
var bad_ratio := 0.0

var time_left := 0.0
var caught := 0
var misses := 0
var spawn_timer := 0.0
var drops: Array = []   # 每颗 {x, y, bad, node}

var basket: Control
var basket_w := 100.0
var basket_h := 40.0
var basket_x := 0.0     # 篮子中心 x（逻辑位置，测试可以直接改）
var basket_y := 0.0     # 篮子顶沿 y
var dragging := false

## 30 秒限时原来从头到尾没人说（开始卡不写、玩的时候顶上也不显示），忽然就「时间到了」——
## 六个游戏里只有它这样（体验评审第 2 条）
func goal_text() -> String:
    return "%d 秒内接住 %d 颗喜糖，别接鞭炮（接到鞭炮才算漏，最多 %d 次）" % [
        int(p_float("duration", 30.0)), p_int("target", 12), p_int("misses", 6)]

func status_text() -> String:
    return "接到 %d/%d 漏 %d/%d 剩 %d 秒" % [caught, p_int("target", 12), misses, p_int("misses", 6), int(ceil(maxf(time_left, 0.0)))]

func _build() -> void:
    duration = p_float("duration", 30.0)
    target = p_int("target", 12)
    speed = maxf(p_float("speed", 170.0), 10.0)
    interval = maxf(p_float("interval", 0.85), 0.1)
    misses_max = p_int("misses", 6)
    bad_ratio = clampf(p_float("bad", 0.0), 0.0, 1.0)
    time_left = duration
    caught = 0
    misses = 0
    spawn_timer = 0.0
    drops.clear()
    for c in get_children():
        c.queue_free()

    basket_w = clampf(size.x * 0.22, 70.0, 100.0)
    basket_h = 40.0
    basket_y = size.y - basket_h - 12.0
    basket_x = size.x * 0.5
    basket = _make_basket()
    add_child(basket)
    _layout_basket()

func _make_basket() -> Control:
    var root := Control.new()
    root.size = Vector2(basket_w, basket_h + 14.0)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var handle := Panel.new()
    handle.size = Vector2(basket_w * 0.5, 10.0)
    handle.position = Vector2(basket_w * 0.25, 0.0)
    var hst := StyleBoxFlat.new()
    hst.bg_color = Color("#4a2f18")
    hst.set_corner_radius_all(5)
    handle.add_theme_stylebox_override("panel", hst)
    handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(handle)
    var body := Panel.new()
    body.position = Vector2(0.0, 14.0)
    body.size = Vector2(basket_w, basket_h)
    var st := StyleBoxFlat.new()
    st.bg_color = Color("#8a5a2f")
    st.border_color = Color("#4a2f18")
    st.set_border_width_all(3)
    st.set_corner_radius_all(10)
    body.add_theme_stylebox_override("panel", st)
    body.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(body)
    return root

func _layout_basket() -> void:
    if basket != null and is_instance_valid(basket):
        basket.position = Vector2(basket_x - basket_w * 0.5, basket_y - 14.0)

func _game_tick(dt: float) -> void:
    time_left = maxf(time_left - dt, 0.0)
    spawn_timer += dt
    if spawn_timer >= interval:
        spawn_timer = 0.0
        _spawn_drop()

    var basket_left := basket_x - basket_w * 0.5
    var basket_right := basket_x + basket_w * 0.5
    var i := drops.size() - 1
    while i >= 0 and not over:
        var d: Dictionary = drops[i]
        d["y"] += speed * dt
        var node = d.get("node")
        if node != null and is_instance_valid(node):
            node.position = Vector2(d["x"] - node.size.x * 0.5, d["y"] - node.size.y * 0.5)
        if d["y"] >= basket_y and d["x"] >= basket_left and d["x"] <= basket_right:
            _collect(d, true)
            drops.remove_at(i)
        elif d["y"] > size.y + 30.0:
            _collect(d, false)
            drops.remove_at(i)
        i -= 1

    if not over and time_left <= 0.0 and caught < target:
        lose("时间到了，接了 %d 颗" % caught)

func _spawn_drop() -> void:
    var bad := rng.randf() < bad_ratio
    var dish_size := 40.0
    var node: Panel
    if bad:
        node = _bad_tile(dish_size)
    else:
        node = Tiles.dish_tile(10, dish_size, font, 24, "", art_set)   # 10 号菜牌是「糖」
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var x := rng.randf_range(dish_size * 0.5, maxf(size.x - dish_size * 0.5, dish_size * 0.5))
    node.position = Vector2(x - dish_size * 0.5, -dish_size)
    add_child(node)
    drops.append({"x": x, "y": -dish_size * 0.5, "bad": bad, "node": node})

## 一颗喜糖／鞭炮落地或落进篮子：喜糖进篮 +1，**喜糖落地不算漏**，鞭炮进篮算漏（篮子抖一下），鞭炮落地没事。
## 「漏」原来把每颗没接到的糖都算上，于是「接 12 颗最多漏 6 颗」实际是「头 18 颗里必须接中 67%」，
## 第 10 关更是「头 42 颗接中 93%」——六个游戏里只有它第 1 关就在为难长辈（体验评审第 1 条）。
## 现在「漏」只数接到鞭炮那一种：没接住的糖再掉一颗就是了，**接错东西才罚**
func _collect(d: Dictionary, in_basket: bool) -> void:
    var node = d.get("node")
    if node != null and is_instance_valid(node):
        node.queue_free()
    if in_basket:
        if d["bad"]:
            misses += 1
            _shake_basket()
        else:
            caught += 1
    if caught >= target:
        win()
    elif misses > misses_max:
        lose("漏掉太多了")

func _shake_basket() -> void:
    if basket == null or not is_instance_valid(basket):
        return
    var bx := basket.position.x
    var tw := create_tween()
    tw.tween_property(basket, "position:x", bx - 8.0, 0.05)
    tw.tween_property(basket, "position:x", bx + 8.0, 0.05)
    tw.tween_property(basket, "position:x", bx, 0.05)

func _bad_tile(sz: float, font_size := 24) -> Panel:
    var p := Panel.new()
    p.size = Vector2(sz, sz)
    p.add_theme_stylebox_override("panel", Tiles.box(Color("#b0261e")))
    var l := Tiles.label("炮", font, font_size, Color("#fff3e0"))
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
    if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
        dragging = e.pressed
        if e.pressed:
            _set_basket_x(e.position.x)
        accept_event()
    elif e is InputEventMouseMotion and dragging:
        _set_basket_x(e.position.x)
        accept_event()

func _unhandled_key_input(e: InputEvent) -> void:
    # 电脑上调试：方向键
    if over or paused or not (e is InputEventKey) or not e.pressed:
        return
    match e.keycode:
        KEY_LEFT: _set_basket_x(basket_x - 40.0)
        KEY_RIGHT: _set_basket_x(basket_x + 40.0)

func _set_basket_x(x: float) -> void:
    basket_x = clampf(x, basket_w * 0.5, size.x - basket_w * 0.5)
    _layout_basket()
