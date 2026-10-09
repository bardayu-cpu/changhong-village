extends SceneTree
## 试验（不是正式代码）：宴会厅 55 桌满厅，手机撑不撑得住。01 9/24 派，方案见 回执/宴会厅55桌-方案.md
## 全用色块占位：地面一张瓦片铺满（重复贴图）、每桌一块桌子积木、每个 NPC 宾客一个上半身精灵（共用一张图，
## 和 hall_life.gd 的宾客同样结构、同样每帧的动作：吃一口低头、转头、举杯），4 个服务员来回走，镜头绕全厅走一圈。
## 要开窗口跑（headless 不画图，量不出帧率）：
##   Godot --path . --script res://tools/perf_hall55.gd --resolution 540x960 -- --tables=55 --per=6 --logic=1 --secs=16
## 打印每秒帧率、每帧脚本耗时、画图调用次数，最后一行是汇总

const PX_M := 48.0
const PITCH := Vector2(200, 150)
const SC := 84.0 / 32.0
const FH := 32.0
const KEEP := 19.0      # floor(32 * 0.62)

var args := {"tables": 55, "per": 6, "logic": 1, "secs": 16, "vsync": 0}
var W := 1600.0
var H := 2048.0
var world: Node2D
var cam: Camera2D
var guests: Array = []
var waiters: Array = []
var rng := RandomNumberGenerator.new()
var t := 0.0
var fps_log: Array = []
var proc_log: Array = []
var draw_log: Array = []
var next_sample := 1.0
var started := false
var slots: Array = []

func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--") and a.contains("="):
            var kv := a.substr(2).split("=")
            args[kv[0]] = int(kv[1])
    rng.seed = 55
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if int(args["vsync"]) == 1 else DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0

func tex_rect(w: int, h: int, c: Color, edge := Color(0, 0, 0, 0)) -> ImageTexture:
    var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(c)
    if edge.a > 0:
        for x in w:
            img.set_pixel(x, 0, edge)
            img.set_pixel(x, h - 1, edge)
    return ImageTexture.create_from_image(img)

## 桌子加一圈椅子的色块积木（1.8 米桌面 86×58，椅子圈 140×92）
func table_tex() -> ImageTexture:
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

## 宾客长相拼一张图：20 种颜色一行 9 帧，16×32（和 hall_life 的 guest_atlas 同尺寸）
func guest_atlas() -> ImageTexture:
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

func build() -> void:
    world = Node2D.new()
    world.y_sort_enabled = true
    get_root().add_child(world)
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
    get_root().add_child(floor)
    # 红毯
    var carpet := Sprite2D.new()
    carpet.texture = tex_rect(144, 8, Color("#b3202a"))
    carpet.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    carpet.region_enabled = true
    carpet.region_rect = Rect2(0, 0, 144, H - 260)
    carpet.centered = false
    carpet.position = Vector2(W * 0.5 - 72, 260)
    carpet.z_index = -9
    get_root().add_child(carpet)
    # 桌位：左右各 3 列、10 行，去掉 5 个（前排中间 2、进门中间 2、东侧门口 1）
    var cols := [210.0, 410.0, 610.0, 990.0, 1190.0, 1390.0]
    var skip := {"0:2": 1, "0:3": 1, "9:2": 1, "9:3": 1, "5:5": 1}
    for r in 10:
        for ci in 6:
            if skip.has("%d:%d" % [r, ci]):
                continue
            slots.append(Vector2(cols[ci], 410.0 + r * PITCH.y))
    var n := mini(int(args["tables"]), slots.size())
    if n < slots.size():
        # 少桌对照：挑离镜头起点最近的几桌（和现在 12 桌在一屏半里差不多）
        slots.sort_custom(func(a, b): return a.distance_to(Vector2(800, 700)) < b.distance_to(Vector2(800, 700)))
        slots = slots.slice(0, n)
    var ttex := table_tex()
    var atlas := guest_atlas()
    for c: Vector2 in slots:
        var s := Sprite2D.new()
        s.texture = ttex
        s.centered = false
        s.offset = Vector2(-75, -60 - 46)
        s.position = c + Vector2(0, 46)     # 着地点在椅子圈最前沿
        world.add_child(s)
        for k in int(args["per"]):
            var a := -PI / 2.0 + TAU * float(k * 10 / int(args["per"])) / 10.0
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
            cup.texture = tex_rect(4, 6, Color("#ffe9a0"))
            cup.visible = false
            node.add_child(cup)
            guests.append({"node": node, "body": body, "cup": cup, "row": row, "bite": rng.randf_range(0.2, 4.5),
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
    cam.zoom = Vector2(960.0 / 1024.0, 960.0 / 1024.0)
    get_root().add_child(cam)
    cam.make_current()
    print("桌 %d  NPC %d  节点 %d" % [slots.size(), guests.size(), get_node_count()])

func step_guest(g: Dictionary, dt: float) -> void:
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

var logic_us: Array = []
var frame_ms: Array = []

func _process(dt: float) -> bool:
    if not started:
        started = true
        var b0 := Time.get_ticks_usec()
        build()
        print("搭厅用时 %d 毫秒" % ((Time.get_ticks_usec() - b0) / 1000))
        print("参数 ", args)
        return false
    t += dt
    if t > 1.5:
        frame_ms.append(dt * 1000.0)
    # 镜头绕全厅走一圈（左上 → 右上 → 右下 → 左下），一圈 secs 秒
    var u := fmod(t / float(args["secs"]), 1.0) * 4.0
    var hx := 288.0
    var hy := 512.0
    var pts := [Vector2(hx, hy), Vector2(W - hx, hy), Vector2(W - hx, H - hy), Vector2(hx, H - hy), Vector2(hx, hy)]
    var i := int(u)
    cam.position = pts[i].lerp(pts[i + 1], u - i)
    var t0 := Time.get_ticks_usec()
    if int(args["logic"]) == 1:
        for g in guests:
            step_guest(g, dt)
    if t > 1.5:
        logic_us.append(Time.get_ticks_usec() - t0)
    for w in waiters:
        var s: Sprite2D = w["spr"]
        var d: Vector2 = w["to"] - s.position
        if d.length() < 4.0:
            w["to"] = slots[rng.randi_range(0, slots.size() - 1)] + Vector2(90, 0)
        else:
            s.position += d.normalized() * 1.5 * PX_M * dt
    if t >= next_sample and t > 1.5:
        next_sample = t + 1.0
        fps_log.append(Engine.get_frames_per_second())
        proc_log.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
        draw_log.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    if t >= float(args["secs"]) + 1.5:
        var f: Array = fps_log.duplicate()
        f.sort()
        var avg := 0.0
        for x in fps_log: avg += x
        avg /= maxf(fps_log.size(), 1)
        var pavg := 0.0
        for x in logic_us: pavg += x
        pavg /= maxf(logic_us.size(), 1) * 1000.0
        frame_ms.sort()
        var p99: float = frame_ms[int(frame_ms.size() * 0.99)]
        var dmax := 0
        for x in draw_log: dmax = maxi(dmax, int(x))
        print("汇总 桌 %d NPC %d 脚本 %s：帧率 平均 %.0f 最低 %.0f；每帧宾客脚本 %.3f 毫秒；最慢 1%% 的帧 %.2f 毫秒；画图调用 最多 %d；节点 %d" % [
            slots.size(), guests.size(), "开" if int(args["logic"]) == 1 else "关", avg, f[0], pavg, p99, dmax, get_node_count()])
        quit(0)
    return false
