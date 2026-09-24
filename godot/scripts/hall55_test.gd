extends Node2D
## 55 桌满厅色块试验（01 9/24 派，只在调试版日志面板里有入口）：真机上看 55 桌、三百多个 NPC 撑不撑得住。
## 不是正式的新厅：全用色块，排法照 回执/宴会厅55桌-方案.md（左右各 3 列 × 10 排，空 5 个位）。
## 每个 NPC 宾客的结构和每帧动作照 hall_life.gd（一个上半身精灵、共用一张图；吃一口低头、转头、举杯），4 个服务员来回走，
## 镜头自己绕全厅一圈一圈走。统计每 10 秒一轮：平均帧率、最低、最慢一帧、宾客脚本每帧多久
## 电脑上跑同一套：tools/perf_hall55.gd

const PX_M := 48.0
const PITCH := Vector2(200, 150)
const SC := 84.0 / 32.0
const FH := 32.0
const KEEP := 19.0      # floor(32 * 0.62)，和 hall_life 坐着的人露出来的一样
const W := 1600.0
const H := 2048.0
const LOOP_SECS := 16.0  # 镜头绕一圈多久

var per := 6             # 每桌几个 NPC
var logic := true        # 宾客动不动
var tables := 55
var cam: Camera2D
var guests: Array = []
var waiters: Array = []
var slots: Array = []
var rng := RandomNumberGenerator.new()
var t := 0.0
var build_ms := 0
# 统计（最近一轮）
var win_t := 0.0
var win_frames := 0
var win_worst := 0.0
var win_min_fps := 9999.0
var win_logic_us := 0
var sec_t := 0.0
var sec_frames := 0
var stats := {}          # 上一轮的：avg, min, worst_ms, logic_ms

func _ready() -> void:
    rng.seed = 55
    var b0 := Time.get_ticks_usec()
    _build()
    build_ms = int((Time.get_ticks_usec() - b0) / 1000)
    print("[suqi] 55 桌试验厅：桌 %d NPC %d 节点 %d 搭厅 %d 毫秒" % [slots.size(), guests.size(), _count(self), build_ms])

func _count(n: Node) -> int:
    var c := 1
    for ch in n.get_children():
        c += _count(ch)
    return c

func node_count() -> int:
    return _count(self)

func _tex_rect(w: int, h: int, c: Color) -> ImageTexture:
    var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(c)
    return ImageTexture.create_from_image(img)

## 桌子加一圈椅子的色块积木（1.8 米桌面 86×58，椅子圈 140×92）
func _table_tex() -> ImageTexture:
    var img := Image.create(150, 110, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    var c := Vector2(75, 60)
    for y in 110:
        for x in 150:
            var d := Vector2((x - c.x) / 70.0, (y - c.y) / 46.0).length()
            var dt := Vector2((x - c.x) / 43.0, (y - c.y) / 29.0).length()
            if dt <= 1.0:
                img.set_pixel(x, y, Color("#b3202a") if y > c.y + 4 else Color("#d8433f"))
            elif d <= 1.0 and d > 0.78:
                img.set_pixel(x, y, Color("#5a3219"))
    return ImageTexture.create_from_image(img)

## 宾客长相拼一张图：20 种颜色一行 9 帧，16×32（和 hall_life 的宾客图同尺寸）
func _guest_atlas() -> ImageTexture:
    var img := Image.create(16 * 9, 32 * 20, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for r in 20:
        var body := Color.from_hsv(float(r) / 20.0, 0.5, 0.7)
        for f in 9:
            img.fill_rect(Rect2i(f * 16 + 4, r * 32 + 2, 8, 8), Color("#f1c8a0"))
            img.fill_rect(Rect2i(f * 16 + 3, r * 32 + 10, 10, 14), body)
            img.fill_rect(Rect2i(f * 16 + 4, r * 32 + 24, 3, 8), Color("#333333"))
            img.fill_rect(Rect2i(f * 16 + 9, r * 32 + 24, 3, 8), Color("#333333"))
    return ImageTexture.create_from_image(img)

func _build() -> void:
    # 地面：一张 64×64 瓦片重复铺满整厅
    var floor := Sprite2D.new()
    var tile := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    tile.fill(Color("#efe3cf"))
    tile.fill_rect(Rect2i(0, 0, 64, 1), Color("#d8c8ae"))
    tile.fill_rect(Rect2i(0, 0, 1, 64), Color("#d8c8ae"))
    floor.texture = ImageTexture.create_from_image(tile)
    floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    floor.region_enabled = true
    floor.region_rect = Rect2(0, 0, W, H)
    floor.centered = false
    floor.z_index = -10
    add_child(floor)
    var carpet := Sprite2D.new()
    carpet.texture = _tex_rect(144, 8, Color("#b3202a"))
    carpet.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    carpet.region_enabled = true
    carpet.region_rect = Rect2(0, 0, 144, H - 260)
    carpet.centered = false
    carpet.position = Vector2(W * 0.5 - 72, 260)
    carpet.z_index = -9
    add_child(carpet)
    var wall := Sprite2D.new()
    wall.texture = _tex_rect(8, 8, Color("#5c3424"))
    wall.region_enabled = true
    wall.region_rect = Rect2(0, 0, W, 170)
    wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    wall.centered = false
    wall.z_index = -9
    add_child(wall)
    var world := Node2D.new()
    world.y_sort_enabled = true
    add_child(world)
    # 桌位：左右各 3 列、10 排，空 5 个（前排中间 2、进门中间 2、东侧门口 1）
    var cols := [210.0, 410.0, 610.0, 990.0, 1190.0, 1390.0]
    var skip := {"0:2": 1, "0:3": 1, "9:2": 1, "9:3": 1, "5:5": 1}
    for r in 10:
        for ci in 6:
            if skip.has("%d:%d" % [r, ci]):
                continue
            slots.append(Vector2(cols[ci], 410.0 + r * PITCH.y))
    var n := mini(tables, slots.size())
    if n < slots.size():
        slots.sort_custom(func(a, b): return a.distance_to(Vector2(800, 700)) < b.distance_to(Vector2(800, 700)))
        slots = slots.slice(0, n)
    var ttex := _table_tex()
    var atlas := _guest_atlas()
    var cup_tex := _tex_rect(4, 6, Color("#ffe9a0"))
    for c: Vector2 in slots:
        var s := Sprite2D.new()
        s.texture = ttex
        s.centered = false
        s.offset = Vector2(-75, -60 - 46)
        s.position = c + Vector2(0, 46)     # 着地点在椅子圈最前沿
        world.add_child(s)
        for k in per:
            var a := -PI / 2.0 + TAU * float(k * 10 / per) / 10.0
            var at: Vector2 = c + Vector2(cos(a) * 55.0, sin(a) * 34.0)
            var node := Node2D.new()
            node.position = at
            world.add_child(node)
            var body := Sprite2D.new()
            body.texture = atlas
            body.region_enabled = true
            var row := rng.randi_range(0, 19)
            body.region_rect = Rect2(0, row * FH, 16, KEEP)
            body.offset = Vector2(0, -KEEP * 0.5)
            body.scale = Vector2(SC, SC)
            body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            node.add_child(body)
            var cup := Sprite2D.new()
            cup.texture = cup_tex
            cup.visible = false
            node.add_child(cup)
            guests.append({"body": body, "cup": cup, "row": row, "bite": rng.randf_range(0.2, 4.5),
                "dip": 0.0, "turn": 0.0, "next_turn": rng.randf_range(2.0, 8.0), "toast": rng.randf_range(2.0, 16.0)})
    for i in 4:
        var w := Sprite2D.new()
        w.texture = atlas
        w.region_enabled = true
        w.region_rect = Rect2(0, 0, 16, 32)
        w.offset = Vector2(0, -16)
        w.scale = Vector2(SC, SC)
        w.position = Vector2(1500, 1100)
        world.add_child(w)
        waiters.append({"spr": w, "to": slots[rng.randi_range(0, slots.size() - 1)]})
    cam = Camera2D.new()
    add_child(cam)
    _fit()
    cam.make_current()

func _fit() -> void:
    var vh := float(get_viewport().get_visible_rect().size.y)
    cam.zoom = Vector2(vh / 1024.0, vh / 1024.0)

func _step_guest(g: Dictionary, dt: float) -> void:
    g["bite"] -= dt
    if g["bite"] <= 0.0:
        g["bite"] = rng.randf_range(1.8, 4.5)
        g["dip"] = 0.35
    g["dip"] = maxf(g["dip"] - dt, 0.0)
    g["next_turn"] -= dt
    var body: Sprite2D = g["body"]
    if g["next_turn"] <= 0.0:
        g["next_turn"] = rng.randf_range(4.0, 9.0)
        if rng.randf() < 0.4:
            g["turn"] = rng.randf_range(1.4, 2.6)
            body.region_rect = Rect2(6 * 16.0, g["row"] * FH, 16.0, KEEP)
    if g["turn"] > 0.0:
        g["turn"] -= dt
        if g["turn"] <= 0.0:
            body.region_rect = Rect2(0, g["row"] * FH, 16.0, KEEP)
    body.offset = Vector2(0, -KEEP * 0.5 + (1.0 if g["dip"] > 0.0 else 0.0))
    g["toast"] -= dt
    var cup: Sprite2D = g["cup"]
    if g["toast"] <= 0.0:
        g["toast"] = rng.randf_range(9.0, 16.0)
    var k: float = g["toast"]
    cup.visible = k < 1.6
    if cup.visible:
        cup.position = Vector2(16.0, -KEEP * SC * (0.6 + 0.45 * sin(k)))

func _process(dt: float) -> void:
    t += dt
    _fit()
    # 镜头绕全厅走一圈（左上 → 右上 → 右下 → 左下），半屏宽高照手机竖屏算
    var vs := get_viewport().get_visible_rect().size / cam.zoom
    var hx := minf(vs.x * 0.5, W * 0.5)
    var hy := minf(vs.y * 0.5, H * 0.5)
    var u := fmod(t / LOOP_SECS, 1.0) * 4.0
    var pts := [Vector2(hx, hy), Vector2(W - hx, hy), Vector2(W - hx, H - hy), Vector2(hx, H - hy), Vector2(hx, hy)]
    var i := int(u)
    cam.position = pts[i].lerp(pts[i + 1], u - i)
    var t0 := Time.get_ticks_usec()
    if logic:
        for g in guests:
            _step_guest(g, dt)
    for w in waiters:
        var s: Sprite2D = w["spr"]
        var d: Vector2 = w["to"] - s.position
        if d.length() < 4.0:
            w["to"] = slots[rng.randi_range(0, slots.size() - 1)] + Vector2(90, 0)
        else:
            s.position += d.normalized() * 1.5 * PX_M * dt
    # 统计：头 1 秒不算（刚搭完）
    if t < 1.0:
        return
    win_logic_us += Time.get_ticks_usec() - t0
    win_frames += 1
    win_t += dt
    win_worst = maxf(win_worst, dt * 1000.0)
    sec_t += dt
    sec_frames += 1
    if sec_t >= 1.0:
        win_min_fps = minf(win_min_fps, sec_frames / sec_t)
        sec_t = 0.0
        sec_frames = 0
    if win_t >= 10.0:
        stats = {"avg": win_frames / win_t, "min": win_min_fps, "worst_ms": win_worst,
            "logic_ms": win_logic_us / 1000.0 / win_frames}
        print("[suqi] 55 桌试验厅 一轮：", stats)
        win_t = 0.0
        win_frames = 0
        win_worst = 0.0
        win_min_fps = 9999.0
        win_logic_us = 0

## 屏上那块字：这一轮还在量就只写现在的帧率
func report() -> String:
    var s := "55 桌试验厅  桌 %d  NPC %d%s\n现在 %d 帧/秒" % [slots.size(), guests.size(), "" if logic else "（不动）", Engine.get_frames_per_second()]
    if stats.is_empty():
        s += "\n量第一轮中（10 秒一轮）……"
    else:
        s += "\n上一轮：平均 %.0f  最低 %.0f 帧/秒\n最慢一帧 %.0f 毫秒  宾客动作 %.1f 毫秒/帧" % [
            stats["avg"], stats["min"], stats["worst_ms"], stats["logic_ms"]]
    return s
