extends Node2D
## 宴会厅的彩带与飘落（docs/宴会厅-彩带与飘落-说明.md，01 E 10/2；阿鱼「画面太整洁是不是应该多点彩带飞舞什么」）：
##   红绸：红毯两边每对灯柱之间一道（灯柱从场景里找，排法变了跟着变），3 格来回晃，每道错开
##   飘落：开席那一刻、每天第一次进厅、干杯三种；同一时间只放一阵，片数有上限，平时不飘
## 图（GPT 画的 B55S-P06、FX01～03）放到 assets/fx/ 下面就用上；没图时调试版用色块试，正式版不挂不飘。
## 摆在人和桌子上面（z 3）、牌子（z 4～5）下面；界面按钮在 SubViewport 外面，本来就盖在上面。只画、不收点击。
## 9/30 铺满彩带被阿鱼嫌乱，所以底线是「少、动、有时候」：挂的只在红毯上方，飘的只在热闹那一下

const Rel = preload("res://scripts/relatives.gd")
const GameCfg = preload("res://scripts/games/game_config.gd")

const SILK_TEX := "res://assets/fx/blk_B55S-P06_v1.png"   # 3 格横排，一格 160×56
const FX_TEX := {"petal": "res://assets/fx/fx_B55S-FX01_v1.png", "paper": "res://assets/fx/fx_B55S-FX02_v1.png",
    "ribbon": "res://assets/fx/fx_B55S-FX03_v1.png"}
const SILK_CELL := Vector2(160, 56)
const SILK_HANG := Vector2(11, 6)       # 左挂点（格内）；右挂点 (148, 6)，相距 137
const SILK_SPAN := 137.0
const SILK_FRAME_T := 0.5               # 一格约 0.5 秒，1→2→3→2→1 来回
# 灯柱零件 art_lantern.png 48×112：花冠最宽那一行 y 23，西灯里侧边 x 43、东灯里侧边 x 3
# （01 定挂在花冠里侧边上，不盖亮着的灯罩；整厅西 697、东 834，相距 137）
const CROWN_ROW := 23
const WEST_EDGE := 43
const EAST_EDGE := 3
const FX_CELL := {"petal": Vector2(12, 12), "paper": Vector2(10, 10), "ribbon": Vector2(16, 32)}
const FX_ROWS := {"petal": 4, "paper": 6, "ribbon": 3}   # 行 = 颜色，列 = 4 帧
const FX_FRAME_T := 0.12
# 三种飘落：放片放多久（秒）、每片活多久、屏幕上同时最多几片、花瓣 / 彩纸 / 卷彩带各占多少、落多快（像素/秒）
const KINDS := {
    "feast": {"spawn": 3.0, "life": Vector2(1.8, 2.6), "max": 90, "mix": [0.5, 0.4, 0.1], "fall": 300.0},   # 落到半屏多；04 10/2 嫌淡：60 片 4 秒 → 90 片 5 秒（片不放大）
    "entry": {"spawn": 0.8, "life": Vector2(1.2, 1.6), "max": 30, "mix": [0.5, 0.4, 0.1], "fall": 280.0},
    "toast": {"spawn": 0.5, "life": Vector2(0.8, 1.1), "max": 14, "mix": [1.0, 0.0, 0.0], "fall": 110.0},
}
const FADE := 0.35                      # 每片最后这么久淡掉
const LOW_FPS := 55.0                   # 掉到这以下，片数减半（红绸不受影响）
const DAY_FILE := "user://suqi_festive.json"
# 没图时调试版的色块（片要 1 像素深色描边：浅色片掉进米色地砖里就看不见了）
const BLOCK_COLORS := {
    "petal": [Color8(240, 150, 180), Color8(232, 190, 70), Color8(250, 246, 236), Color8(150, 30, 50)],
    "paper": [Color8(214, 40, 50), Color8(232, 190, 70), Color8(60, 110, 210), Color8(60, 160, 90), Color8(250, 246, 236), Color8(150, 80, 190)],
    "ribbon": [Color8(214, 40, 50), Color8(232, 190, 70), Color8(60, 110, 210)],
}

var hall
var silk_tex: Texture2D = null
var fx_tex := {}
var debug_blocks := OS.has_feature("suqi_debug") or OS.is_debug_build()   # 没图时拿色块试（只有调试版、电脑上）
var silks: Array = []        # 每道红绸 {pos: 格左上角, phase}
var silk_t := 0.0
var silk_node: Node2D
var fall_node: Node2D
var pieces: Array = []       # 正在飘的片 {p, v, kind, row, life, age, sway, ph}
var cur := ""                # 正在放哪一阵（"" = 没在放）
var cur_cfg := {}
var cur_left := 0.0          # 这阵还要放多久的片
var cur_max := 0
var cur_pts: Array = []      # 干杯：两个人站的地方
var spawn_acc := 0.0
var queue: Array = []        # 排着的 [kind, pts]
var hold_wait := 0.0
var rng := RandomNumberGenerator.new()
# main.gd 给的：busy_fn 为真（不在厅里、小游戏、簿子、菜单……）时这阵不放、也不补；hold_fn 为真（干杯插图、换画布）时先等着
var busy_fn: Callable = func() -> bool: return false
var hold_fn: Callable = func() -> bool: return false
var fps_fn: Callable = func() -> float: return Engine.get_frames_per_second()
var unix_override := -1.0    # 测试用：假装现在是几点
var feast_seen := -1         # 上回看到的「按北京时间是不是饭点」：-1 还没看过（进厅那一下不算开席那一刻）
var feast_check_t := 0.0
var played: Array = []       # 测试看：放过哪几阵

func build(h) -> void:
    hall = h
    name = "festive"
    z_index = 3
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    rng.randomize()
    silk_tex = _tex(SILK_TEX)
    for k in FX_TEX:
        var t := _tex(FX_TEX[k])
        if t != null:
            fx_tex[k] = t
    # 没图时调试版拿色块试：色块照 GPT 那几张图的格子排好做成图，画法跟真图一样（绘制次数量出来就是真图的）
    if debug_blocks:
        if silk_tex == null:
            silk_tex = ImageTexture.create_from_image(_block_silk())
        for k in FX_TEX:
            if not fx_tex.has(k):
                fx_tex[k] = ImageTexture.create_from_image(_block_fx(k))
    silk_node = Node2D.new()
    silk_node.name = "silk"
    silk_node.draw.connect(_draw_silk)
    add_child(silk_node)
    fall_node = Node2D.new()
    fall_node.name = "fall"
    fall_node.draw.connect(_draw_fall)
    add_child(fall_node)
    if silk_tex != null:
        _find_silks()
    silk_node.queue_redraw()

static func _tex(path: String) -> Texture2D:
    return load(path) if ResourceLoader.exists(path) else null

## 飘落能不能放：图齐了（调试版没图时已经拿色块做成图了）
func can_fall() -> bool:
    return fx_tex.size() == FX_TEX.size()

## 红毯两边同一排的两盏灯算一对：西灯花冠里侧边到东灯花冠里侧边挂一道
func _find_silks() -> void:
    silks.clear()
    var west := {}
    var east := {}
    for o in hall.cfg.get("occluders", []):
        var id := str(o.get("id", ""))
        if not id.contains("落地宫灯") or not str(o.get("image", "")).ends_with("art_lantern.png"):
            continue
        var row := int(round(float(o["y"])))
        if id.contains("红毯西侧"):
            west[row] = Vector2(float(o["x"]), float(o["y"]))
        elif id.contains("红毯东侧"):
            east[row] = Vector2(float(o["x"]), float(o["y"]))
    var rows: Array = west.keys()
    rows.sort()
    var i := 0
    for row in rows:
        if not east.has(row):
            continue
        var hang := Vector2(west[row].x + WEST_EDGE, west[row].y + CROWN_ROW)
        silks.append({"pos": hang - SILK_HANG, "span": east[row].x + EAST_EDGE - hang.x, "phase": fmod(i * 0.37, 1.0) * 4.0 * SILK_FRAME_T})
        i += 1

## 1→2→3→2 来回，一格 SILK_FRAME_T 秒
func silk_frame(s: Dictionary) -> int:
    var k := int(floor((silk_t + float(s["phase"])) / SILK_FRAME_T)) % 4
    return [0, 1, 2, 1][k]

func _draw_silk() -> void:
    for s in silks:
        var f := silk_frame(s)
        var p: Vector2 = s["pos"]
        silk_node.draw_texture_rect_region(silk_tex, Rect2(p, SILK_CELL), Rect2(Vector2(f * SILK_CELL.x, 0), SILK_CELL))

## 色块红绸：3 格，两个挂点之间一道往下垂的红绸、正中一个绣球，三格是往左、正中、往右晃；挂点一个金结
static func _block_silk() -> Image:
    var img := Image.create(int(SILK_CELL.x) * 3, int(SILK_CELL.y), false, Image.FORMAT_RGBA8)
    var dark := Color8(120, 10, 20)
    var red := Color8(220, 30, 40)
    var gold := Color8(232, 190, 70)
    for f in 3:
        var ox := f * int(SILK_CELL.x)
        var sway := (f - 1) * 5.0
        var a := SILK_HANG
        for x in range(int(a.x), int(a.x + SILK_SPAN) + 1):
            var t := (x - a.x) / SILK_SPAN
            var y := a.y + 30.0 * sin(t * PI)
            var xs := x + sway * sin(t * PI)
            img.fill_rect(Rect2i(ox + int(xs), int(y) - 3, 1, 7), dark)
            img.fill_rect(Rect2i(ox + int(xs), int(y) - 2, 1, 5), red)
            img.set_pixel(ox + int(xs), int(y) - 2, gold)   # 比红毯亮一档的正红、上沿压一道金（不然压在红毯上看不出来）
        var ball := Vector2i(ox + int(a.x + SILK_SPAN * 0.5 + sway), int(a.y + 40.0))
        for dy in range(-7, 8):
            for dx in range(-7, 8):
                var d := Vector2(dx, dy).length()
                if d <= 7.0:
                    img.set_pixelv(ball + Vector2i(dx, dy), dark if d > 6.0 else (gold if d < 2.0 else red))
        for e in [Vector2i(ox + int(a.x), int(a.y)), Vector2i(ox + int(a.x + SILK_SPAN), int(a.y))]:
            img.fill_rect(Rect2i(e.x - 2, e.y - 2, 5, 5), gold)
    return img

## 色块片：行 = 颜色，列 = 4 帧（翻、转用宽窄变化代替），1 像素深色描边
static func _block_fx(kind: String) -> Image:
    var cell: Vector2 = FX_CELL[kind]
    var cols: Array = BLOCK_COLORS[kind]
    var img := Image.create(int(cell.x) * 4, int(cell.y) * cols.size(), false, Image.FORMAT_RGBA8)
    for r in cols.size():
        for fr in 4:
            var w := maxi(2, int(round([1.0, 0.6, 0.25, 0.6][fr] * cell.x)))
            var rect := Rect2i(fr * int(cell.x) + (int(cell.x) - w) / 2, r * int(cell.y), w, int(cell.y))
            img.fill_rect(rect, (cols[r] as Color).darkened(0.45))
            img.fill_rect(rect.grow(-1), cols[r])
    return img

# ---------- 飘落 ----------

## 要放一阵：kind 是 feast / entry / toast，pts 是干杯那两个人站的地方。
## 同一时间只放一阵：正在放就排着（开席来了把排着的干杯都撤掉；正在放开席时来的干杯不要）
func request(kind: String, pts: Array = []) -> void:
    if not KINDS.has(kind) or not can_fall():
        return
    if kind == "toast" and (cur == "feast" or queue.any(func(q): return q[0] == "feast")):
        return
    if kind == "feast":
        queue = queue.filter(func(q): return q[0] != "toast")
    if queue.size() >= 3:
        return
    queue.append([kind, pts])
    hold_wait = 0.0

## 每天第一次走进宴会厅（北京日期）：放进厅那阵，记下今天
func enter_today() -> void:
    var day := GameCfg.beijing_day(_now())
    var last := ""
    if FileAccess.file_exists(DAY_FILE):
        var j = JSON.parse_string(FileAccess.get_file_as_string(DAY_FILE))
        if j is Dictionary:
            last = str(j.get("day", ""))
    if last == day:
        return
    var f := FileAccess.open(DAY_FILE, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify({"day": day}))
        f.close()
    request("entry")

func _now() -> float:
    return unix_override if unix_override >= 0.0 else Time.get_unix_time_from_system()

## 按北京时间是不是饭点（不看调试版强制开席：强制是测试、截图用的，不当「开席那一刻」）
func _feast_by_clock() -> bool:
    var rel = hall.life.relatives if hall.life != null else null
    if rel == null:
        return false
    return Rel.in_feast(Rel.beijing_hour(_now(), int(rel.conf.get("tz_hours", 8))), rel.conf.get("feast", []))

func _process(dt: float) -> void:
    if not silks.is_empty():
        var before := [] as Array
        for s in silks:
            before.append(silk_frame(s))
        silk_t += dt
        for i in silks.size():
            if silk_frame(silks[i]) != before[i]:
                silk_node.queue_redraw()
                break
    # 开席那一刻：每秒看一次钟，从「不是饭点」变成「饭点」那一下放（进厅时已经开席了不补）
    feast_check_t -= dt
    if feast_check_t <= 0.0:
        feast_check_t = 1.0
        var f := 1 if _feast_by_clock() else 0
        if feast_seen == 0 and f == 1 and not busy_fn.call():
            request("feast")
        feast_seen = f
    _step_fall(dt)

func _step_fall(dt: float) -> void:
    if cur == "" and not queue.is_empty():
        if hold_fn.call() and hold_wait < 8.0:
            hold_wait += dt   # 干杯插图、换画布还没完：等着（最多等 8 秒）
        else:
            var q: Array = queue.pop_front()
            if not busy_fn.call():   # 在小游戏、簿子、菜单里：这阵不放，回来也不补
                _start(q[0], q[1])
    if cur == "" and pieces.is_empty():
        return
    if cur != "" and cur_left > 0.0:
        cur_left -= dt
        var life: Vector2 = cur_cfg["life"]
        spawn_acc += dt * float(cur_max) / minf((life.x + life.y) * 0.5, float(cur_cfg["spawn"]))   # 放得开：短的那阵也放得满
        while spawn_acc >= 1.0:
            spawn_acc -= 1.0
            if pieces.size() < cur_max:
                _spawn()
    var keep: Array = []
    for p in pieces:
        p["age"] += dt
        if p["age"] >= p["life"]:
            continue
        p["p"] += p["v"] * dt
        keep.append(p)
    pieces = keep
    if cur != "" and cur_left <= 0.0 and pieces.is_empty():
        cur = ""
    fall_node.queue_redraw()

func _start(kind: String, pts: Array) -> void:
    cur = kind
    cur_cfg = KINDS[kind]
    cur_left = float(cur_cfg["spawn"])
    cur_max = int(cur_cfg["max"])
    var fps: float = fps_fn.call()
    if fps > 0.0 and fps < LOW_FPS:
        cur_max = int(cur_max / 2.0)   # 手机掉帧：同时片数减半
    cur_pts = pts
    spawn_acc = 1.0
    played.append(kind)
    print("[suqi] 飘落 ", kind, " 最多 ", cur_max, " 片")

## 屏幕上看得见的那块（整厅坐标）
func view_rect() -> Rect2:
    var cam: Camera2D = hall.cam
    var size: Vector2 = get_viewport_rect().size / cam.zoom
    return Rect2(cam.get_screen_center_position() - size * 0.5, size)

func _spawn() -> void:
    var mix: Array = cur_cfg["mix"]
    var r := rng.randf()
    var kind := "petal" if r < float(mix[0]) else ("paper" if r < float(mix[0]) + float(mix[1]) else "ribbon")
    var life: Vector2 = cur_cfg["life"]
    var fall: float = float(cur_cfg["fall"]) * rng.randf_range(0.8, 1.2) * (0.85 if kind == "petal" else (1.15 if kind == "ribbon" else 1.0))
    var p: Vector2
    if cur == "toast" and not cur_pts.is_empty():
        var at: Vector2 = cur_pts[rng.randi() % cur_pts.size()]
        p = at + Vector2(rng.randf_range(-26, 26), rng.randf_range(-150, -120))   # 头顶上方落下来
    else:
        var v := view_rect()
        p = Vector2(rng.randf_range(v.position.x, v.end.x), v.position.y - rng.randf_range(0, 40))   # 从屏幕上沿往下落
    pieces.append({"p": p, "v": Vector2(rng.randf_range(-20, 20), fall), "kind": kind, "row": rng.randi() % int(FX_ROWS[kind]),
        "life": rng.randf_range(life.x, life.y), "age": 0.0, "sway": rng.randf_range(10, 22), "ph": rng.randf() * TAU})

## 同一种片挨着画（一种一张图），换图才断一次批，绘制次数多 3 次左右
func _draw_fall() -> void:
    for kind in FX_CELL:
        for p in pieces:
            if p["kind"] == kind:
                _draw_piece(p)

func _draw_piece(p: Dictionary) -> void:
    var kind: String = p["kind"]
    var cell: Vector2 = FX_CELL[kind]
    var age: float = p["age"]
    var a := clampf((float(p["life"]) - age) / FADE, 0.0, 1.0)
    var at: Vector2 = p["p"] + Vector2(sin(age * 3.0 + float(p["ph"])) * float(p["sway"]), 0)
    var fr := int(floor(age / FX_FRAME_T + float(p["ph"]))) % 4
    var dst := Rect2((at - cell * 0.5).round(), cell)
    fall_node.draw_texture_rect_region(fx_tex[kind], dst, Rect2(Vector2(fr * cell.x, int(p["row"]) * cell.y), cell), Color(1, 1, 1, a))
