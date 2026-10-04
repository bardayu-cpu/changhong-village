extends Node2D
## 分层场景（ASSETS.md 第 14 节）：画面就是 GPT 的场景图。底图打底，一块块积木叠在上面，人在积木之间走
## 谁在前谁在后按脚的高低定（y 排序）：每块积木的原点放在它着地的那一行，人的原点在脚底
## 数据由 tools/build_layered.py 生成：能走的格子、遮挡块、交互点都在 scene.json 里，手机上不用现算
## 对外的接口和 3D 的 hall.gd 一样，main.gd 两种都能用；镜头不转，只跟着人移动
signal reached(what: String)

const Spr = preload("res://scripts/sprites.gd")
const Life = preload("res://scripts/hall_life.gd")
const Festive = preload("res://scripts/hall_festive.gd")
const Ambient = preload("res://scripts/ambient/ambient.gd")   # 场景动效（宫灯呼吸），05 10/4
const GameCfg = preload("res://scripts/games/game_config.gd")
## 画布的图（底图、积木）从哪来统一走这里（HANDOFF §0.9）：现在从包里读，远程加载真机验过以后只改那一处
const Canvas = preload("res://scripts/canvas_assets.gd")
const DATA := "res://assets/layered/scene_roman_banquet/scene.json"
## 55 桌大厅（01 9/24 派，阿鱼 v11「真实还原酒宴当天」）：新场景，和 12 桌厅并存，main.gd 按开关挑一个搭（验收前玩家照旧玩 12 桌厅）
const DATA_55 := "res://assets/layered/scene_roman_banquet_55/scene.json"
## 第 46 版照 GPT 效果图还原的那套（9/24 夜阿鱼看了说不如第 44 版，01 定默认退回第 44 版，这套只在调试开关后面）
const DATA_V11 := "res://assets/layered/scene_roman_banquet_v11/scene.json"
const StageSigns = preload("res://scripts/stage_signs.gd")
const SPEED_M := 3.2      # 走路速度，米/秒；换成像素按人所在那一行的比例算
## 走路速度备选两档（HANDOFF：3.2 备选 2.4，阿鱼真机比一比）；调试版右下角的按钮切换 speed_m
const SPEED_CHOICES := [3.2, 2.4]
const PERSON_M := 1.75
## 坐着的样子（占位，9/17）：还没有坐姿帧，第 21 版人只是站到椅位上，阿鱼真机上看不出坐下了。
## 先把站姿帧从头往下截一段（下半身不画），抬到大约椅面的高度；等新画风人物的坐姿帧到了换掉
const SIT_KEEP := 0.62    # 留上半身：人高的这么多
const SIT_LIFT := 0.0     # 上半身下沿抬离椅位点多少（人高的比例）。椅位点量的就是画里的椅面，不用再抬
const SIT_ANIM := 0.3     # 从站的地方挪到椅子上用多久，秒（第 21 版是瞬移，挪一米不到，看不出动过）
## 椅位圈（画里椅面那一圈）相对桌子占地椭圆（x、y、rx、ry）的位置，9/17 对着试点积木 blk_table_round.png 量的：
## 后排椅面约 y 470、前排约 562、左右约 x ±65。A04 整批换桌子积木要重量
const SEAT_DY := -0.85    # 圈心在占地中心往上 0.85 个 ry
const SEAT_RX := -15.0    # 横半径 = rx - 15
const SEAT_RY := -6.0     # 竖半径 = ry - 6
## 走到椅子（或坐着的人）多近算「在旁边」：原来 60 像素，每张桌正前方那把（6 号）离最近能站的地方 63～69 像素，
## 12 把椅子永远不出「坐这儿」（9/18 晚查出来的）。放到 78，最远那把也够得着
const NEAR_R := 78.0

var cfg: Dictionary
var base_tex: Texture2D
var world: Node2D          # 开了 y 排序：积木、新人、玩家都在这里面
var cam: Camera2D
var player: Sprite2D
var me_ring: Node2D        # 脚下一圈淡金色、会呼吸的圈（04 10/2：人堆里找不到自己），在宴会厅一直在、不写字
var me_marks := true       # 脚下的圈、头顶的倒三角只在宴会厅出（迎宾院、后厅、草坪这些继承了这份代码的画布里关掉）
var me_mark: Polygon2D     # 头顶一个小金色倒三角，轻轻上下浮（01 E 10/2：脚下那圈在人堆里常被前面的桌子盖住）
var tag: Label
var tag_anchor: Node2D
var exit_mark: Polygon2D
var exit_mat_t := 0.0
var nav := AStarGrid2D.new()
var cell := 10.0
var cols := 0
var rows := 0
var walk := PackedByteArray()   # 1 = 能站
var path: Array = []
var pos := Vector2.ZERO
var face := "up"
var anim := 0.0
var look := Spr.PROC_ANIM
var look_fps := 7.7
var frame_h := 32.0
var look_hframes := 9      # 形象图集一行几帧；坐着时截半身会临时把 hframes 改成 1，站起来还原
var speed_m := SPEED_M     # 现在用的走路速度，米/秒
var stick := Vector2.ZERO   # 摇杆：屏幕方向，x 向右、y 向下，长度 0～1
var cam_pan := Vector2.ZERO # 手指左右拖出来的镜头偏移（画布像素，阿鱼 9/18 晚要能拖着看全厅）；人一走就慢慢收回到自己身上
var couple_armed := true
var exit_armed := false
var walking_enabled := true
var t := 0.0
var SPAWN := Vector2.ZERO
var COUPLE_SPOT := Vector2.ZERO
var couple_r := 70.0
var door := Vector2.ZERO
var door_r := 60.0
## 侧门通后厅（蓝图 3.2「东侧门 (1500, 600, 50) 通后厅」，9/19 任务 7 加进 scene.json 的 side_door）；scene.json 里没有就是 0，main 不管它。
## 10/4 方案 C（照阿鱼图只上下翻）：通后厅的改成西墙那道，画里那道东侧门改通后花园（写在 exits 里）。门在哪面墙，牌子、金光都往厅里挪
var side_door := Vector2.ZERO
var side_door_r := 0.0
var side_arrive := Vector2.ZERO   # 从后厅回来站哪（scene.json 的 arrive；没写就是门往厅里 60 像素）
## 多开的门（10/4 连图：西门通后花园）：scene.json 的 points 里写了 to 的，{pos, r, to, arrive}；main 照这个切
var exits: Array = []
var font: Font
var data_path := DATA      # 搭哪个厅：DATA（12 桌）或 DATA_55，build 之前由 main.gd 定
var big := false           # 是不是 55 桌大厅（场景名带 _55）
var signs: Node2D          # 婚礼台上的横幅和 LED 屏（只有配置里有 stage 的厅才有，现在是 55 桌大厅）
var festive = null         # 55 桌厅：红毯上方的红绸、开席 / 进厅 / 干杯的飘落（hall_festive.gd，01 E 10/2）
var life: Node2D           # 厅里的热闹：服务员、乐队、贺礼、彩带、灯笼光、别桌的 NPC 宾客（hall_life.gd，阿鱼 9/18）

func build(preset: int, nickname: String, f: Font) -> void:
    font = f
    cfg = JSON.parse_string(FileAccess.get_file_as_string(data_path))
    big = str(cfg.get("scene", "")).ends_with("_55")
    # 场景配置可以改座位圈、长凳、桌牌的规矩（55 桌大厅灰盒，01 D 9/29）；12 桌厅不写，照旧用上面的常数
    var sg: Dictionary = cfg.get("seat_geom", {})
    seat_abs = sg if bool(sg.get("abs", false)) else {}
    seat_dy = float(sg.get("dy", SEAT_DY)) if seat_abs.is_empty() else SEAT_DY
    seat_rx = float(sg.get("rx", SEAT_RX)) if seat_abs.is_empty() else SEAT_RX
    seat_ry = float(sg.get("ry", SEAT_RY)) if seat_abs.is_empty() else SEAT_RY
    var bc: Dictionary = cfg.get("bench", {})
    bench_x0 = float(bc.get("x0", BENCH_X0))
    bench_x1 = float(bc.get("x1", BENCH_X1))
    bench_y = float(bc.get("y", BENCH_Y))
    bench_draw = bool(bc.get("draw", true))
    sign_near = str(cfg.get("sign_mode", "")) == "near"
    # 每桌一个小游戏（55 桌厅，01 D 9/30 v8）：按北京日期分好，skip 里的桌（主桌）不挂；第 44 版厅没写这项，照 minigames.json 的 1～6 号桌
    var tg: Dictionary = cfg.get("table_games", {})
    if str(tg.get("mode", "")) == "daily":
        var ids: Array = []
        var skip: Array = tg.get("skip", [])
        for t in cfg.get("tables", []):
            if not skip.has(str(t["id"])):
                ids.append(str(t["id"]))
        var unix := game_unix if game_unix >= 0.0 else Time.get_unix_time_from_system()
        GameCfg.use_daily(ids, tg.get("games", []), GameCfg.beijing_day(unix, int(tg.get("tz_hours", 8))))
    else:
        GameCfg.clear_daily()
    base_tex = Canvas.texture(cfg["base"])
    var base := Sprite2D.new()
    base.texture = base_tex
    base.centered = false
    base.z_index = -10
    base.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(base)
    world = Node2D.new()
    world.y_sort_enabled = true
    add_child(world)
    _occluders()
    _books()
    _walk_grid()
    _bench()
    SPAWN = Vector2(cfg["spawn"][0], cfg["spawn"][1])
    for p in cfg["points"]:
        if p["id"] == "couple_table":
            COUPLE_SPOT = Vector2(p["x"], p["y"])
            couple_r = float(p["r"])
        elif p["id"] == "door":
            door = Vector2(p["x"], p["y"])
            door_r = float(p["r"])
        elif p["id"] == "side_door":
            side_door = Vector2(p["x"], p["y"])
            side_door_r = float(p["r"])
            var sa: Array = p.get("arrive", [])
            side_arrive = Vector2(sa[0], sa[1]) if sa.size() == 2 else side_off(60.0, 0.0)
        elif p.has("to"):
            var ar: Array = p.get("arrive", [p["x"], p["y"]])
            exits.append({"id": str(p["id"]), "pos": Vector2(p["x"], p["y"]), "r": float(p["r"]), "to": str(p["to"]), "arrive": Vector2(ar[0], ar[1])})
    _couple()
    if cfg.has("stage"):
        signs = StageSigns.new()
        signs.name = "stage_signs"
        signs.z_index = -5   # 贴在底图（-10）上面、人和桌子（0 起）下面：婚礼台是底图画的，字挂在台上
        add_child(signs)
        signs.setup(font, cfg["stage"])
    _player(preset, nickname)
    _exit_mark()
    if side_door != Vector2.ZERO:
        room_sign("后厅", side_off(-SIDE_DOOR_SIGN.x, SIDE_DOOR_SIGN.y), side_door.y)
        _west_door()
    for e in exits:   # 多开的门也挂名字牌（10/4 方案 C 东门「后花园」），牌子往门里挪
        var lb := ""
        for p in cfg["points"]:
            if str(p["id"]) == str(e["id"]):
                lb = str(p.get("label", ""))
        if lb != "":
            var ep: Vector2 = e["pos"]
            room_sign(lb, ep + Vector2(44.0 * _in_sign(ep), SIDE_DOOR_SIGN.y), ep.y)   # 跟侧门那块一样抬到人头以上
    life = Life.new()
    life.name = "life"
    add_child(life)
    life.build(self)
    if big:
        festive = Festive.new()
        add_child(festive)
        festive.build(self)
    Ambient.attach(self, str(cfg.get("scene", "")), cfg["occluders"])
    cam = Camera2D.new()
    cam.limit_left = 0
    cam.limit_top = 0
    cam.limit_right = int(cfg["size"][0])
    cam.limit_bottom = int(cfg["size"][1])
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 6.0
    add_child(cam)
    cam.make_current()
    _fit_zoom()
    get_viewport().size_changed.connect(_fit_zoom)
    snap_cam()

## 一屏按 1024 高算（ASSETS v1.0：画布可以比一屏高）。不到 1024 高的画布照旧整张铺满，
## 比 1024 高的（9/20 起湖边、果园 1280）人和东西还是这么大，高出来的部分镜头上下跟着人走
const VIEW_H := 1024.0

## 一屏铺满多高，左右、上下跟着人移动（超出画布的部分由 cam 的 limit 挡住）
func _fit_zoom() -> void:
    var vh := float(get_viewport().get_visible_rect().size.y)
    var z := vh / minf(float(cfg["size"][1]), VIEW_H)
    cam.zoom = Vector2(z, z)

## 桌心的簿子（蓝图 3.2 桌簿）：每张摆出来的桌子一本。占位：代码画的小簿子（红封皮、米白内页、几道字迹），
## 正式的簿子积木 blk_guestbook 到了再换。按桌子着地那一行排前后，画在桌面上、在桌前的人后面
func _books() -> void:
    var tex := _book_texture()
    for t in cfg.get("tables", []):
        var s := Sprite2D.new()
        s.texture = tex
        s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        s.centered = true
        s.position = Vector2(float(t["x"]), float(t["y"]) + 0.5)
        s.offset = Vector2(0.0, _seat_center(t).y - float(t["y"]))
        world.add_child(s)

static func _book_texture() -> ImageTexture:
    # 8×5 个美术像素，每个 2×2 画布像素（和积木一样粗），16×10，约 0.33 米宽
    var rows := [".RRRRRR.", "RWWrWWWR", "RkWrWkWR", "RWWrWWWR", ".RRRRRR."]
    var pal := {"R": Color("#9e2a2b"), "r": Color("#6e1e1e"), "W": Color("#f4ead2"), "k": Color("#8a7a66")}
    var img := Image.create(16, 10, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for j in rows.size():
        var line: String = rows[j]
        for i in line.length():
            var ch := line[i]
            if pal.has(ch):
                img.fill_rect(Rect2i(i * 2, j * 2, 2, 2), pal[ch])
    return ImageTexture.create_from_image(img)

## 遮挡块：临时版用底图把这一块重画一遍（多边形贴底图），GPT 的积木到了换成积木图
func _occluders() -> void:
    for o in cfg["occluders"]:
        var foot := float(o["foot"])
        var holder := Node2D.new()
        holder.position = Vector2(0, foot)
        world.add_child(holder)
        if o.has("image"):
            var s := Sprite2D.new()
            s.texture = Canvas.texture(o["image"])
            s.centered = false
            s.offset = Vector2(o["x"], float(o["y"]) - foot)
            s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
            holder.add_child(s)
        else:
            # 一块可以由几个形状拼成（桌面加一把把椅子）
            for shape in o["polys"]:
                var pts := PackedVector2Array()
                var uvs := PackedVector2Array()
                for p in shape:
                    pts.append(Vector2(p[0], float(p[1]) - foot))
                    uvs.append(Vector2(p[0], p[1]))
                var poly := Polygon2D.new()
                poly.texture = base_tex
                poly.polygon = pts
                poly.uv = uvs
                poly.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
                holder.add_child(poly)

func _walk_grid() -> void:
    var g: Dictionary = cfg["walk_grid"]
    cell = float(g["cell"])
    cols = int(g["cols"])
    var lines: Array = g["rows"]
    rows = lines.size()
    walk.resize(cols * rows)
    nav.region = Rect2i(0, 0, cols, rows)
    nav.cell_size = Vector2.ONE
    nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    nav.update()
    for j in rows:
        var line: String = lines[j]
        for i in cols:
            var ok := line.unicode_at(i) == 49   # "1"
            walk[j * cols + i] = 1 if ok else 0
            if not ok:
                nav.set_point_solid(Vector2i(i, j), true)

## 人在这一行（脚的 y）应该画多高（像素）：按 scene.json 里两行的高度线性插值
func _px_h(y: float) -> float:
    var pp: Dictionary = cfg["person_px"]
    var k := (y - float(pp["far_y"])) / (float(pp["near_y"]) - float(pp["far_y"]))
    return lerpf(float(pp["far_h"]), float(pp["near_h"]), k)

func px_per_m(y: float) -> float:
    return _px_h(y) / PERSON_M

func _couple() -> void:
    var cp := Sprite2D.new()
    cp.name = "couple"
    cp.texture = load("res://assets/couple.png")
    cp.centered = false
    var foot := Vector2(cfg["couple"][0], cfg["couple"][1])
    # 合照立绘新郎头发顶着图上沿，整张高 = 新郎高。原来乘 1.25（以为上面有空），新郎成了客人的 1.48 倍；
    # 04 10/2 量过：1.0 时新郎约 1.18 倍、新娘约 1.02 倍，跟真人差不多（新郎高一点），合照原图不改
    var h := _px_h(foot.y) * 1.0
    var sc := h / float(cp.texture.get_height())
    cp.scale = Vector2(sc, sc)
    cp.offset = Vector2(-cp.texture.get_width() * 0.5, -cp.texture.get_height())
    cp.position = foot
    cp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    world.add_child(cp)

func _player(preset: int, nickname: String) -> void:
    # 脚下那圈：跟出口、签到台同一个画法（空心金边 + 淡光、一明一暗），淡一些、小一些；人站哪跟到哪，人藏起来它也藏。
    # 放进按前后排的 world 里、排在人前一格（节点 y 比脚小 1，画的时候再挪回来）：压在人后面、身后那排桌子前面，
    # 只有挡在人前面的桌子才盖住它（放在所有桌子下面的话，人站在两桌中间就整圈被盖住，找不到）
    me_ring = ring_mark(20.0, 8.0)
    for c in me_ring.get_children():
        (c as Node2D).position = Vector2(0, 1)
    world.add_child(me_ring)
    # 头顶的倒三角：画在人和桌子上面（z 3）、牌子（z 4～5）下面，不写字；金色、一圈深边
    me_mark = Polygon2D.new()
    me_mark.polygon = PackedVector2Array([Vector2(-8, -6), Vector2(8, -6), Vector2(0, 6)])   # 宽 16（04 10/2：12 小了点）
    me_mark.color = Color(1.0, 0.84, 0.35)
    me_mark.z_index = 3
    var mark_edge := Line2D.new()
    mark_edge.points = PackedVector2Array([Vector2(-8, -6), Vector2(8, -6), Vector2(0, 6), Vector2(-8, -6)])
    mark_edge.width = 1.5
    mark_edge.default_color = Color(0.45, 0.25, 0.05)
    me_mark.add_child(mark_edge)
    add_child(me_mark)
    player = Sprite2D.new()
    player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    world.add_child(player)
    tag_anchor = Node2D.new()
    tag_anchor.z_index = 5
    add_child(tag_anchor)
    tag = Label.new()
    tag.add_theme_color_override("font_color", Color("#F4D97A"))
    tag_anchor.add_child(tag)
    set_look(preset, nickname)

# ---------- 地上的记号（体验第二轮 新 3）----------
## 空心的一圈金边，外面一圈淡光，一明一暗地呼吸。原来是一块不透明的橘色椭圆，像地上一摊东西、桌上一块污渍，
## 不像「往这儿来」（04 第 43 版复看）。出口那圈金光、签到台头顶的记号都用它
static func ring_mark(rx: float, ry: float) -> Polygon2D:
    var holder := Polygon2D.new()   # 本身不画（没有 polygon），只当个壳，visible、position、modulate 照旧用
    var pts := PackedVector2Array()
    for i in 33:
        var a := TAU * float(i) / 32.0
        pts.append(Vector2(cos(a) * rx, sin(a) * ry))
    var glow := Line2D.new()
    glow.points = pts
    glow.width = 10.0
    glow.default_color = Color(1.0, 0.85, 0.4, 0.22)
    holder.add_child(glow)
    var edge := Line2D.new()
    edge.points = pts
    edge.width = 3.5
    edge.default_color = Color(1.0, 0.9, 0.5, 0.95)
    holder.add_child(edge)
    return holder

static func breathe_ring(m: Node2D, t_now: float) -> void:
    m.modulate.a = 0.55 + sin(t_now * 3.0) * 0.4
    m.scale = Vector2.ONE * (1.0 + sin(t_now * 3.0) * 0.06)

# ---------- 掉帧兜底（02 10/3「性能-真人物满厅」）----------
## 每秒看一眼帧数：连着 LOW_SECS 秒低于 LOW_FPS，宾客动作降到 15 帧一动、灯笼光不闪、音符不飘（hall_life.low_end）；
## 飘落片数本来在 55 帧以下就减半（hall_festive）。连着 RECOVER_SECS 秒高于 OK_FPS 再恢复。set_low_end 是测试、量性能时直接开关
const LOW_FPS := 50.0
const OK_FPS := 58.0
const LOW_SECS := 3
const RECOVER_SECS := 10
var low_end_forced := -1      # -1 自己判；0、1 强制
var _fps_acc := 0.0
var _low_n := 0
var _ok_n := 0

func set_low_end(on: bool) -> void:
    low_end_forced = 1 if on else 0
    _apply_low_end(on)

func _apply_low_end(on: bool) -> void:
    if life != null and life.get("low_end") != null and int(life.low_end) != (1 if on else 0):
        life.low_end = 1 if on else 0
        print("[suqi] 掉帧兜底 " + ("开：宾客动作 15 帧一动、灯笼光不闪、音符不飘" if on else "关：照常"))

func _low_end_tick(dt: float) -> void:
    if low_end_forced >= 0 or life == null:
        return
    _fps_acc += dt
    if _fps_acc < 1.0:
        return
    _fps_acc = 0.0
    var fps := Engine.get_frames_per_second()
    if fps > 0.0 and fps < LOW_FPS:
        _low_n += 1
        _ok_n = 0
        if _low_n >= LOW_SECS:
            _apply_low_end(true)
    elif fps >= OK_FPS:
        _ok_n += 1
        _low_n = 0
        if _ok_n >= RECOVER_SECS:
            _apply_low_end(false)
    else:
        _low_n = 0
        _ok_n = 0

# ---------- 屏幕边的金箭头（10/3 从 entrance.gd 挪上来：宴会厅指东侧门也用）----------
## 屏幕边的小箭头（签到台、后厅指厨房、宴会厅指东侧门共用）：want 为真、目标又在屏幕外时，贴着屏幕边（往里收 40）指着它，一闪一闪；
## 目标进了屏幕、或者 want 为假就收
func point_edge_arrow(arrow: Polygon2D, target: Vector2, want: bool) -> void:
    if not want or cam == null or cam.zoom.x <= 0.0:
        arrow.visible = false
        return
    var vs := get_viewport().get_visible_rect().size / cam.zoom
    var c := cam.get_screen_center_position()
    var view := Rect2(c - vs * 0.5, vs)
    var inner := view.grow(-40.0)
    if view.grow(-10.0).has_point(target):
        arrow.visible = false
        return
    arrow.visible = true
    arrow.position = Vector2(clampf(target.x, inner.position.x, inner.end.x), clampf(target.y, inner.position.y, inner.end.y))
    arrow.rotation = (target - arrow.position).angle()
    arrow.modulate.a = 0.7 + sin(t * 5.0) * 0.3

## 屏幕边那种金色小箭头（签到台、后厅指厨房共用）
static func edge_arrow() -> Polygon2D:
    var a := Polygon2D.new()
    a.polygon = PackedVector2Array([Vector2(16, 0), Vector2(-10, -11), Vector2(-4, 0), Vector2(-10, 11)])
    a.color = Color(1.0, 0.88, 0.45)
    var outline := Line2D.new()
    outline.points = PackedVector2Array([Vector2(16, 0), Vector2(-10, -11), Vector2(-4, 0), Vector2(-10, 11), Vector2(16, 0)])
    outline.width = 2.0
    outline.default_color = Color(0.2, 0.12, 0.08)
    a.add_child(outline)
    a.z_index = 8
    a.scale = Vector2(1.6, 1.6)   # 截图看原大小太小，放大一点
    a.visible = false
    return a

# ---------- 东侧门通后厅的记号（01 E 10/3，04「第一次来整条路」第 1 条：宴会厅里没人告诉你东侧门通后厅）----------
## 第一次坐下（或玩完第一个小游戏）以后，东侧门头上挂一圈会呼吸的金光，门在屏幕外时屏幕边出金箭头指着它（签到台那套）；
## 进过一次后厅就收（main 管开关，记在 court_save）。墙上不叠字
var door_hint := false
var door_mark: Polygon2D
var door_arrow: Polygon2D
const DOOR_MARK_UP := 30.0   # 金光挂在门那个点上面多高（门那块面板正前面一点，不飘到墙上）

func set_door_hint(on: bool) -> void:
    door_hint = on and side_door != Vector2.ZERO
    if door_hint and door_mark == null:
        door_mark = ring_mark(24.0, 24.0 * 0.55)
        door_mark.z_index = 4
        add_child(door_mark)
        door_arrow = edge_arrow()
        add_child(door_arrow)
    if door_mark != null:
        door_mark.position = side_off(20.0, -DOOR_MARK_UP)
        door_mark.visible = door_hint
        door_arrow.visible = false

func _door_hint_tick() -> void:
    if door_mark == null:
        return
    if door_hint:
        breathe_ring(door_mark, t)
    point_edge_arrow(door_arrow, door_mark.position, door_hint)

# ---------- 门口的名字牌（阿鱼 10/3「每个房间的门口需要用牌子写明这是哪里」；画风页第 0 节「房间门口可以挂写房间名的牌子」）----------
## 红底金字、金边的小匾，字用游戏字体，比世界里的字大一号（长辈看得清）。跟出口那种暖褐小木牌分开：木牌是「去哪」，红匾是「这是哪」。
## 挂在门旁边的墙上，不压门洞；按 foot 那条线跟人排前后（走廊里的人走过去在牌子前面）。不改像素画的底图，牌子是游戏里画的
const ROOM_SIGN_FONT := 22
const ROOM_SIGN_BG := Color("#a8281f")
const ROOM_SIGN_TEXT := Color("#f7e09a")
const ROOM_SIGN_EDGE := Color("#deb550")
const SIDE_DOOR_SIGN := Vector2(-44, -96)   # 宴会厅侧门：匾的下沿正中在门那个点往厅里 44、往上 96（贴着墙；再往外手机上会被屏幕边切掉）。x 是东墙的写法，西墙的门照 side_off 翻过来。
                                            # 10/4 03 测第 65 版：原来往上 34，盖住刚进门站在落点上的人上半身；抬到人头（84）以上
var room_signs: Array = []                   # 挂上的名字牌（测试、截图看）

## 10/4 方案 C（01 G 定）：通后厅的门挪到西墙，画里那儿没有门板——照东侧门（底图 x 1496～1536、y 1260～1318）的样子用代码画一扇，
## 左右对称、以门那个点为中心；叠在底图上、人和桌子下面（底图本身不动）。门在东墙（画里有门）就不画
const WEST_DOOR_RECTS := [   # [离外墙几像素起, 到几像素, 门顶往下几像素起, 到几像素, 颜色]，一圈一圈往里叠（量的东侧门）
    [0, 40, 0, 58, "#391f14"], [0, 36, 4, 56, "#67381c"], [0, 32, 6, 52, "#a66731"],
    [0, 30, 10, 42, "#e5b263"], [0, 30, 42, 50, "#703e1f"]]
func _west_door() -> void:
    if side_door == Vector2.ZERO or _in_sign(side_door) < 0.0:
        return
    var holder := Node2D.new()
    holder.name = "west_door"
    holder.z_index = -9   # 底图是 -10
    var top := side_door.y - 29.0
    for r in WEST_DOOR_RECTS:
        var p := Polygon2D.new()
        var x0 := float(r[0])
        var x1 := float(r[1])
        var y0 := top + float(r[2])
        var y1 := top + float(r[3])
        p.polygon = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
        p.color = Color(str(r[4]))
        holder.add_child(p)
    add_child(holder)

## 门往厅里是 +x（西墙的门）还是 -x（东墙的门）
func _in_sign(p: Vector2) -> float:
    return 1.0 if p.x < float(cfg["size"][0]) * 0.5 else -1.0

## 侧门往厅里 dx、往下 dy 那个点（dx 正数 = 往厅里）
func side_off(dx: float, dy: float) -> Vector2:
    return side_door + Vector2(dx * _in_sign(side_door), dy)

## 挂一块名字牌：at = 匾的下沿正中，foot = 排前后的那条线（没给就是 at.y）。回那块牌子（Node2D，字在它下面的 Label 里）
func room_sign(text: String, at: Vector2, foot := -1.0) -> Node2D:
    var holder := Node2D.new()
    holder.name = "room_sign_" + text
    var fy := at.y if foot < 0.0 else foot
    holder.position = Vector2(at.x, fy)
    var l := Label.new()
    l.text = text
    l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", ROOM_SIGN_FONT)
    l.add_theme_color_override("font_color", ROOM_SIGN_TEXT)
    var sb := StyleBoxFlat.new()
    sb.bg_color = ROOM_SIGN_BG
    sb.border_color = ROOM_SIGN_EDGE
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(3)
    sb.content_margin_left = 8; sb.content_margin_right = 8
    sb.content_margin_top = 1; sb.content_margin_bottom = 2
    sb.shadow_color = Color(0.13, 0.08, 0.06, 0.6)
    sb.shadow_size = 0
    sb.shadow_offset = Vector2(2, 2)
    l.add_theme_stylebox_override("normal", sb)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var lift := at.y - fy
    # 字体量好以后 Label 会自己再长一点：每回变大小都重新摆，下沿正中一直钉在 at 上（不然牌子往下掉、压到走廊）
    l.resized.connect(func(): l.position = Vector2(-l.size.x * 0.5, lift - l.size.y))
    l.size = l.get_combined_minimum_size()
    l.position = Vector2(-l.size.x * 0.5, lift - l.size.y)
    holder.add_child(l)
    world.add_child(holder)
    room_signs.append(holder)
    return holder

# ---------- 世界里的字（体验 B2、B3、B4）----------
## 世界里的字（人名、桌牌、物件名）原来 12 像素（约 8.5 点），长辈看不清，字心和地面几乎同色（1.04:1），全靠描边撑着。
## 改成 18（画面按屏高缩放约 0.94，屏上约 17，在 04 说的 16～18 里），垫一层暗底。像素字体本来就被镜头缩放过，不在 12 的倍数上
const WORLD_FONT := 18
const PLATE_BG := Color(0.08, 0.05, 0.1, 0.72)

## 给一块世界里的字垫暗底、设字号，大小只包住字；牌子以 (cx, bottom) 为下沿中点立着
func name_plate(l: Label, color := Color(1, 1, 1, 0.92)) -> void:
    l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", WORLD_FONT)
    if not l.has_theme_color_override("font_color"):
        l.add_theme_color_override("font_color", color)
    var sb := StyleBoxFlat.new()
    sb.bg_color = PLATE_BG
    sb.set_corner_radius_all(3)
    sb.content_margin_left = 4; sb.content_margin_right = 4
    sb.content_margin_top = 0; sb.content_margin_bottom = 1
    l.add_theme_stylebox_override("normal", sb)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.size = l.get_combined_minimum_size()

## 世界里挂字的几层（宴会厅：桌牌和别人的名字；灰盒画布另有物件名那层，entrance.gd 覆盖）
func _tag_holders() -> Array:
    return [seat_tags] if seat_tags != null else []

## 名字牌贴着屏幕边被切掉（草坪「…礼拱门·预留」、宴会厅「小李那桌·连…」，体验 B4）：牌子中点还在屏幕里的，往屏幕里收；
## 中点已经出了屏幕的（那张桌、那样东西大半在屏幕外）就先不显示——都往里收的话，屏幕边上会摞起一串别桌的牌子。
## 离开屏幕边以后回到原位（原位记在 meta "home"）
## 牌子离屏幕左右边至少留多少（屏幕像素）。原来是 4 个厅里的像素，55 桌厅镜头缩到 0.94，牌子的 1 像素金边贴着屏幕边
## 画出来时有时断一截，看着像被切掉（04 v7 新 2、v8v9 新 2；实测没出屏，是边框太贴边）
const TAG_EDGE := 8.0
func _keep_tags_on_screen() -> void:
    if cam == null or cam.zoom.x <= 0.0:
        return
    var half := float(get_viewport().get_visible_rect().size.x) * 0.5 / cam.zoom.x
    var cx := cam.get_screen_center_position().x
    var lo := cx - half + TAG_EDGE / cam.zoom.x
    var hi := cx + half - TAG_EDGE / cam.zoom.x
    for holder in _tag_holders():
        for c in holder.get_children():
            if not (c is Control):
                continue
            var l: Control = c
            if not l.has_meta("home"):
                l.set_meta("home", l.position.x)
            var home: float = l.get_meta("home")
            var mid := home + l.size.x * 0.5
            l.visible = mid >= lo and mid <= hi
            if sign_near and l.has_meta("tid") and not _sign_shown(str(l.get_meta("tid"))):
                l.visible = false   # 55 桌认桌：不是自己那桌、也没走近的桌，牌子不挂（这里每帧重算，得一起管）
            if l.has_meta("near_only") and not bool(l.get_meta("near_on")):
                l.visible = false   # 主桌家里人的称呼：走近谁亮谁（hall_life._family_near）
            l.position.x = clampf(home, lo, maxf(lo, hi - l.size.x))

func set_look(preset: int, nickname: String) -> void:
    var gl := Spr.gpt_look(preset)
    player.region_enabled = false   # 坐着时截过半身，换形象先还原
    player.frame = 0
    if gl.is_empty():
        player.texture = ImageTexture.create_from_image(Spr.sheet(preset))
        player.hframes = 9
        frame_h = 32.0
        look = Spr.PROC_ANIM
        look_fps = 7.7
    else:
        player.texture = gl["tex"]
        player.hframes = gl["hframes"]
        frame_h = float(gl["frame_h"])
        look = gl["anim"]
        look_fps = gl["fps"]
    look_hframes = player.hframes
    player.centered = true
    player.offset = Vector2(0, -frame_h * 0.5)   # 原点在脚底
    player.frame = look["up"]["idle"]
    tag.text = nickname
    name_plate(tag, Color("#F4D97A"))
    tag.position = Vector2(-tag.size.x * 0.5, -tag.size.y)   # 下沿中点立在头顶

func _exit_mark() -> void:
    exit_mark = ring_mark(door_r, door_r * 0.4)
    exit_mark.position = door
    exit_mark.z_index = -5
    exit_mark.visible = false
    add_child(exit_mark)

func arm_exit() -> void:
    exit_armed = true
    exit_mark.visible = true

# ---------- 走路 ----------
func _cell_of(p: Vector2) -> Vector2i:
    return Vector2i(clampi(int(p.x / cell), 0, cols - 1), clampi(int(p.y / cell), 0, rows - 1))

func _cell_pos(c: Vector2i) -> Vector2:
    return Vector2((c.x + 0.5) * cell, (c.y + 0.5) * cell)

## 这个位置能不能站：看它落在哪一格
func _free(p: Vector2, _r := 0.0) -> bool:
    if p.x < 0 or p.y < 0 or p.x >= cols * cell or p.y >= rows * cell:
        return false
    var c := _cell_of(p)
    return walk[c.y * cols + c.x] == 1

func _nearest_free(c: Vector2i) -> Vector2i:
    for rad in range(1, 40):
        for dj in range(-rad, rad + 1):
            for di in range(-rad, rad + 1):
                var n := c + Vector2i(di, dj)
                if nav.is_in_boundsv(n) and not nav.is_point_solid(n):
                    return n
    return c

func _cell_ok(c: Vector2i) -> bool:
    return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows and walk[c.y * cols + c.x] == 1

## 两点之间能不能直着走：线段经过的每一格都要能站（一格一格顺着走，斜着擦过的角也不漏）
func _clear(a: Vector2, b: Vector2) -> bool:
    var p := a / cell
    var q := b / cell
    var c := Vector2i(floori(p.x), floori(p.y))
    var end := Vector2i(floori(q.x), floori(q.y))
    var d := q - p
    var sx := 1 if d.x > 0.0 else -1
    var sy := 1 if d.y > 0.0 else -1
    var tdx := absf(1.0 / d.x) if d.x != 0.0 else INF
    var tdy := absf(1.0 / d.y) if d.y != 0.0 else INF
    var tx := (float(c.x + (1 if sx > 0 else 0)) - p.x) / d.x if d.x != 0.0 else INF
    var ty := (float(c.y + (1 if sy > 0 else 0)) - p.y) / d.y if d.y != 0.0 else INF
    var len_c := d.length()
    for guard in 2000:
        if not _cell_ok(c):
            return false
        if c == end:
            return true
        if absf(tx - ty) * len_c < 0.05:
            # 穿过（或几乎穿过）格子的角：角两边的格子也都要能站，走的时候差一点点也不会踩进去
            if not _cell_ok(c + Vector2i(sx, 0)) or not _cell_ok(c + Vector2i(0, sy)):
                return false
            c += Vector2i(sx, sy)
            tx += tdx
            ty += tdy
        elif tx < ty:
            c.x += sx
            tx += tdx
        else:
            c.y += sy
            ty += tdy
    return false

func tap(screen: Vector2) -> void:
    if not walking_enabled:
        return
    var t0 := Time.get_ticks_usec()
    var wp := get_viewport().get_canvas_transform().affine_inverse() * screen
    # 点到一位罗曼山庄服务员：顶上说一句这位叫什么，不走过去（10/2 阿鱼：每位服务员有个名字）
    if life != null and life.has_method("waiter_at"):
        var wn: String = life.waiter_at(wp)
        if wn != "":
            waiter_tap.emit(wn)
            return
    # 点到桌心的菜（椅位圈中间那一块）：告诉 main 开这桌的小游戏。坐在这桌就不走路（一走就站起来了）
    var tid := table_at(wp)
    if tid != "":
        game_tap.emit(tid)
        if seated and str(my_seat.get("table_id", "")) == tid:
            return
    go_to(wp)
    var ms := (Time.get_ticks_usec() - t0) / 1000.0
    if ms > 20.0:
        print("[suqi] 寻路用了 %d 毫秒" % int(ms))

func go_to(target: Vector2) -> void:
    stand_up()   # 坐着的时候点地面：先起身，再从起身点算路，不然路是从桌子占地里出发的
    var out := find_path(pos, target)
    if out.is_empty():
        return
    path = out

## 从 from 走到 target 要经过的拐点（不含起点，能直着走的格子合成一段）；走不到返回空。
## 玩家点地面、服务员在桌子之间走（hall_life.gd）都用它
func find_path(from: Vector2, target: Vector2) -> Array:
    var a := _cell_of(from)
    var b := _cell_of(target)
    if nav.is_point_solid(a): a = _nearest_free(a)
    if nav.is_point_solid(b): b = _nearest_free(b)
    var ids := nav.get_id_path(a, b)
    if ids.is_empty():
        return []
    var pts: Array = []
    for id in ids: pts.append(_cell_pos(id))
    if _free(target): pts[pts.size() - 1] = target
    var out: Array = []
    var cur := from
    var k := 0
    while k < pts.size():
        var far := k
        for m in range(pts.size() - 1, k, -1):
            if _clear(cur, pts[m]):
                far = m
                break
        out.append(pts[far])
        cur = pts[far]
        k = far + 1
    return out

## 55 桌大厅以后进厅（01 9/24：第一次站大门口看场面，以后直接站到自己那桌边上）：站到自己椅子边上最近的能走的格子。
## 还没分到座、分到了画面上没有的桌，返回 false，照旧站门口
func stand_by_my_table() -> bool:
    var p := _my_chair_pos()
    if p == Vector2.ZERO:
        return false
    # 自己那把是桌子后面（北边）的：离椅子最近的能走格子在桌子北边的缝里，人站在那儿被桌子挡掉下半截（04 10/2 第 4 条，
    # 看着像个小孩站在缝里）——跟起身一样站到桌头外边
    var t := _table_cfg(str(my_seat.get("table_id", "")))
    if not t.is_empty():
        p = _stand_spot(p, _seat_center(t))
    var c := _cell_of(p)
    if not _cell_ok(c):
        c = _nearest_free(c)
    reset_to(_cell_pos(c))
    return true

## 55 桌第一次进厅（01 D 9/29「第一次进厅镜头带你到自己那桌」）：人直接站到自己椅子边上，镜头从大门那儿
## 慢慢滑过去（CAM_TOUR 秒）。不让人从大门自己走过去：大门到第一排近 1900 像素，走要 12 秒，太长。
## 还没分到座、分到了画面上没有的桌，返回 false，照旧站门口
const CAM_TOUR := 2.4
var cam_tour := 0.0              # 镜头还要滑多久（秒）；人一走就停，交回给跟人的镜头
var cam_tour_from := Vector2.ZERO

func fly_to_my_table() -> bool:
    if cam == null:
        return false
    var from := cam.position
    if not stand_by_my_table():
        return false
    cam_pan = from - pos
    _clamp_pan()
    cam_tour_from = cam_pan
    cam_tour = CAM_TOUR
    return true

func reset_to(p: Vector2) -> void:
    pos = p
    path.clear()
    stick = Vector2.ZERO
    face = "up"
    seated = false
    sit_t = SIT_ANIM
    snap_cam()
    # 传送到新位置：椅子按钮、昵称按钮该收的收、该冒的冒，不等 0.15 秒的自然扫描
    _scan_chairs(1.0)

## 这个点落在哪张桌的桌心（椅位圈中间、放菜的那块桌面）；都不在返回 ""
func table_at(wp: Vector2) -> String:
    for t in cfg.get("tables", []):
        var c := _seat_center(t) + Vector2(0, -4)
        var d := wp - c
        if (d.x / 52.0) * (d.x / 52.0) + (d.y / 30.0) * (d.y / 30.0) <= 1.0:
            return str(t["id"])
    return ""

## 截图用：从某个点往旁边挪几米（换成这一行的像素）
func near(p: Vector2, v_m: Vector2) -> Vector2:
    return p + v_m * px_per_m(p.y)

## main.gd 里「别处左右拖」调这个（3D 厅是转镜头）。分层场景的镜头不转，改成左右挪着看全厅：
## 手指往左拖，画面跟着往左走（看右边）；拖到厅的边上就停
func rotate_cam(drag_px: float) -> void:
    if cam == null or cam.zoom.x <= 0.0:
        return
    cam_pan.x -= drag_px / cam.zoom.x
    _clamp_pan()

## 手指拖着看（55 桌大厅比一屏高，01 9/24：「镜头手指拖着看、上下左右跟人」）：上下左右都跟着手指走，
## 拖到厅的边上就停。12 桌厅只有一屏高，上下拖不动，和原来的 rotate_cam 一样
func pan_cam(drag: Vector2) -> void:
    if cam == null or cam.zoom.x <= 0.0:
        return
    cam_pan -= drag / cam.zoom.x
    _clamp_pan()

## 镜头中心不出厅：左右各留半屏宽，上下各留半屏高
func _clamp_pan() -> void:
    var vs := get_viewport().get_visible_rect().size * 0.5 / cam.zoom.x
    var sz := Vector2(float(cfg["size"][0]), float(cfg["size"][1]))
    var c := pos + cam_pan
    c.x = clampf(c.x, vs.x, sz.x - vs.x) if sz.x > vs.x * 2.0 else sz.x * 0.5
    c.y = clampf(c.y, vs.y, sz.y - vs.y) if sz.y > vs.y * 2.0 else sz.y * 0.5
    cam_pan = c - pos

func snap_cam() -> void:
    cam_pan = Vector2.ZERO
    if cam:
        cam.position = pos
        cam.reset_smoothing()

## 没有 3D 着色器要预热，等两帧就行
func warm_up() -> void:
    for i in 2:
        await get_tree().process_frame

func _face_for(d: Vector2) -> String:
    if absf(d.x) > absf(d.y) * 1.2:
        return "right" if d.x > 0.0 else "left"
    return "up" if d.y < 0.0 else "down"

## 摇杆走路：挡住了就试着只走一个方向，贴着桌边滑过去
func _stick_move(dt: float) -> bool:
    var step := stick * speed_m * px_per_m(pos.y) * dt
    face = _face_for(stick)
    for np: Vector2 in [pos + step, pos + Vector2(step.x, 0), pos + Vector2(0, step.y)]:
        if np != pos and _free(np):
            pos = np
            return true
    return false

func _process(dt: float) -> void:
    t += dt
    _door_hint_tick()
    _low_end_tick(dt)
    var moving := false
    if seated and sit_t < SIT_ANIM:
        # 坐下的那一下：从站的地方滑到椅位上，先快后慢，最后正好停在椅位
        sit_t = minf(sit_t + dt, SIT_ANIM)
        var k := sit_t / SIT_ANIM
        pos = sit_from.lerp(sit_seat, 1.0 - (1.0 - k) * (1.0 - k))
    if stick.length() > 0.15 and walking_enabled:
        stand_up()   # 坐着的时候推摇杆：先起身，从椅子外侧那一步开始走
        path.clear()
        moving = _stick_move(dt)
    elif not path.is_empty():
        var tgt: Vector2 = path[0]
        var to := tgt - pos
        var dist := to.length()
        var speed := speed_m * px_per_m(pos.y)
        if dist < 2.0:
            pos = tgt   # 到拐点就站准，下一段从算好的起点出发
            path.pop_front()
        else:
            var np := pos + to / dist * minf(dist, speed * dt)
            if _free(np):
                pos = np
                moving = true
            else:
                path.clear()
            face = _face_for(to)
    anim = anim + dt if moving else 0.0
    var fl: Dictionary = look[face]
    player.flip_h = fl["flip"]
    if seated:
        # 坐着（占位）：只画站姿帧的上半身，下沿抬到椅面高，见 SIT_KEEP、SIT_LIFT
        var fw := float(player.texture.get_width()) / float(look_hframes)
        var keep := floorf(frame_h * SIT_KEEP)
        if not player.region_enabled:
            player.frame = 0
            player.hframes = 1
            player.region_enabled = true
        player.region_rect = Rect2(float(fl["idle"]) * fw, 0.0, fw, keep)
        player.offset = Vector2(0.0, -keep * 0.5 - frame_h * SIT_LIFT - seat_lift * frame_h / _px_h(pos.y))
        player.z_index = 1 if seat_front else 0
        tag_anchor.position = pos - Vector2(0, _px_h(pos.y) * (SIT_KEEP + SIT_LIFT) + seat_lift + 2.0)
    else:
        if player.region_enabled:
            player.region_enabled = false
            player.hframes = look_hframes
            player.z_index = 0
        var walk_frames: Array = fl["walk"]
        player.frame = walk_frames[int(anim * look_fps) % walk_frames.size()] if moving else fl["idle"]
        # 占位人物的迈腿只有 1 像素，看着像滑行：走路时加一点上下起伏，重画的人物有走路帧后再收小
        var bob := -absf(sin(anim * look_fps * PI)) * 1.6 if moving else 0.0
        # 左右脚交替：每迈一步身体往落脚那边偏一点（上下走时看得最清楚）
        var sway := 0.0
        if moving:
            sway = 0.9 if int(anim * look_fps) % 4 < 2 else -0.9
        player.offset = Vector2(sway, -frame_h * 0.5 + bob)
        tag_anchor.position = pos - Vector2(0, _px_h(pos.y) + 2.0)
    player.position = pos
    var sc := _px_h(pos.y) / frame_h
    player.scale = Vector2(sc, sc)
    if cam_tour > 0.0:
        if moving:
            cam_tour = 0.0
        else:
            cam_tour = maxf(cam_tour - dt, 0.0)
            var k := 1.0 - cam_tour / CAM_TOUR
            cam_pan = cam_tour_from * (1.0 - k * k * (3.0 - 2.0 * k))   # 先慢后快再慢
    if moving or (seated and sit_t < SIT_ANIM):
        # 一走（或坐下那一下）镜头就慢慢回到自己身上，约半秒收回大半
        cam_pan = cam_pan.lerp(Vector2.ZERO, minf(dt * 4.0, 1.0))
    if cam:
        cam.position = pos + cam_pan
    if tag != null:
        # 体验第二轮 新 1：不显示自己的名字（你知道自己是谁，别人手机上照样看得到你）。原来压在亭子墙、麻将桌、新娘裙子上
        tag.visible = false
    _keep_tags_on_screen()
    if my_cup != null:
        cup_left = maxf(cup_left - dt, 0.0)
        my_cup.visible = cup_left > 0.0
        var body_h := _px_h(pos.y) * (SIT_KEEP if seated else 1.0)
        my_cup.position = pos + Vector2(-14.0 if face == "left" else 14.0, -body_h + 22.0)
    if exit_mark.visible:
        breathe_ring(exit_mark, t)
    if me_ring != null:
        me_ring.visible = me_marks and player.visible
        me_ring.position = pos - Vector2(0, 1)
        breathe_ring(me_ring, t)
        me_ring.modulate.a *= 0.6   # 比出口那圈淡：只是让人一眼找到自己，不是「往这儿来」
    if me_mark != null:
        me_mark.visible = me_marks and player.visible
        var head := _px_h(pos.y) * (SIT_KEEP if seated else 1.0) + (seat_lift if seated else 0.0)
        me_mark.position = pos + Vector2(0, -head - 12.0 + sin(t * 2.5) * 3.0)   # 头顶上方一点，上下浮 3 像素
    if couple_armed and pos.distance_to(COUPLE_SPOT) < couple_r:
        couple_armed = false
        path.clear()
        face = "up"
        reached.emit("couple")
    _scan_chairs(dt)
    if exit_armed and pos.distance_to(door) < door_r:
        exit_armed = false
        path.clear()
        reached.emit("exit")

# ---------- 长凳（蓝图 3.2「座位上限 120，满了新来的人坐在墙边的长凳上，长凳无限，能做所有动作」，01 9/19 派任务 5） ----------
## 占位，正式位置等整批底图。放在北墙根、舞台西边：贺礼堆（hall_life 的 gifts，x 331～489）西边那块空地。
## 这块原来不在能走的格子里（能走的从 y 320 起），放凳子不挡任何一条路。凳子前面补一条能走的窄道（BENCH_WALK），
## 从西头 T3 积木外面那段接回原来能走的地方：不补的话人只能站在 y 320 那一行，T3 后排椅子上的人总比凳子上的近，
## 凳子上的人点不到。凳子上只有看人、敬酒、想认识你，没有簿子、没有小游戏（那是桌子的）
const BENCH_ID := "bench"        # 服务端 seat 表里坐长凳的 table_id（server-claude config.BANQUET_BENCH_ID），chair_no 是 null
const BENCH_X0 := 112.0          # 坐的人从这儿
const BENCH_X1 := 322.0          # 排到这儿
const BENCH_Y := 244.0           # 椅位点（上半身下沿），和桌边椅子的椅位点一个意思；靠着北墙（墙根约 y 210）
const BENCH_GAP := 30.0          # 人少时一人占多宽（8 个人正好一排）；再多就把整条分匀、挤着叠
                                 # （01：坐不下可以叠，或者换第二排；第二排会堵住凳子前面那条道，后排也点不到，所以叠）
const BENCH_STAND_DY := 26.0     # 被敬酒时站起来：站在自己位置正前方这么远（在凳子前那条道上）
const BENCH_WALK := [Rect2(100, 260, 230, 30), Rect2(100, 290, 60, 30)]   # 补的能走的格子：凳子前一条横道，西头一段往下接回去
var bench_spots: Array = []      # [{openid, pos}]：长凳上的人（含自己，自己不画），按服务端 bench 的顺序

## 长凳上第 k 个（从 0 数，一共 n 个）坐哪：人少时一人 BENCH_GAP 宽、整排居中；坐不下就把整条分匀，挤着叠
func bench_pos(k: int, n: int) -> Vector2:
    var span := bench_x1 - bench_x0
    var gap := BENCH_GAP
    if n > 1 and float(n - 1) * BENCH_GAP > span:
        gap = span / float(n - 1)
    var start := (bench_x0 + bench_x1) * 0.5 - gap * float(n - 1) * 0.5
    return Vector2(start + gap * float(k), bench_y)

## 凳子（代码画的占位，和桌心簿子一样粗的像素）：靠背一块、凳面连腿一块。
## 靠背排在坐的人后面（着地点比椅位点靠里），凳面排在前面（盖住坐的人最下面一点，像坐在上面）；再把凳子前面那条道放开
func _bench() -> void:
    if not bench_draw:
        return   # 55 桌灰盒：凳子是底图旁边的色块遮挡块，能走的格子也是生成场景时算好的
    var w := int(BENCH_X1 - BENCH_X0) + 36
    var x := BENCH_X0 - 18.0
    var back := Sprite2D.new()
    back.texture = _bench_back_texture(w)
    back.centered = false
    back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    back.position = Vector2(x, BENCH_Y - 6.0)
    back.offset = Vector2(0, -26)
    back.name = "bench_back"
    world.add_child(back)
    var seat := Sprite2D.new()
    seat.texture = _bench_seat_texture(w)
    seat.centered = false
    seat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    seat.position = Vector2(x, BENCH_Y + 16.0)
    seat.offset = Vector2(0, -20)
    seat.name = "bench_seat"
    world.add_child(seat)
    for r in BENCH_WALK:
        var a := _cell_of(r.position)
        var b := _cell_of(r.end - Vector2(0.01, 0.01))
        for j in range(a.y, b.y + 1):
            for i in range(a.x, b.x + 1):
                walk[j * cols + i] = 1
                nav.set_point_solid(Vector2i(i, j), false)

const BENCH_DARK := Color("#3e2415")
const BENCH_WOOD := Color("#7a4e2c")
const BENCH_LIGHT := Color("#a8743f")

## 靠背：上下两根横木、几根立柱，w×26
static func _bench_back_texture(w: int) -> ImageTexture:
    var img := Image.create(w, 26, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for px in [0, int(w / 3.0) - 2, int(w * 2 / 3.0) - 2, w - 4]:
        img.fill_rect(Rect2i(px, 0, 4, 26), BENCH_DARK)
    img.fill_rect(Rect2i(0, 0, w, 6), BENCH_WOOD)
    img.fill_rect(Rect2i(0, 0, w, 2), BENCH_LIGHT)
    img.fill_rect(Rect2i(0, 12, w, 4), BENCH_WOOD)
    img.fill_rect(Rect2i(0, 16, w, 2), BENCH_DARK)
    return ImageTexture.create_from_image(img)

## 凳面连腿：凳面亮一道、前脸暗、几条腿，w×20
static func _bench_seat_texture(w: int) -> ImageTexture:
    var img := Image.create(w, 20, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for px in [4, int(w / 2.0) - 2, w - 8]:
        img.fill_rect(Rect2i(px, 8, 4, 12), BENCH_DARK)
    img.fill_rect(Rect2i(0, 0, w, 6), BENCH_WOOD)
    img.fill_rect(Rect2i(0, 0, w, 2), BENCH_LIGHT)
    img.fill_rect(Rect2i(0, 6, w, 4), BENCH_DARK)
    return ImageTexture.create_from_image(img)

# ---------- 席位：enterHall 的数据画成坐着的人（蓝图 3.2） ----------
signal chair_near(table_id: String, chair_no: int)   # 走到空椅子旁触发；chair_no 0 表示离开了
signal person_near(openid: String)   # 走到「有人坐、不是自己」的椅子旁触发（看人、敬酒，蓝图 3.2）；"" 表示走开了
signal table_near(table_id: String)   # 走到桌边（翻簿子，第 24 版）；"" 表示走开了
signal game_tap(table_id: String)     # 点了某张桌桌心的菜（席间小游戏，蓝图 3.2 9/19：坐下后点桌心的菜开游戏）
signal waiter_tap(text: String)       # 点到一位罗曼山庄服务员：「罗曼山庄服务员 · 名字」（10/2）

var seats_holder: Node2D
var seat_tags: Node2D
var seat_abs: Dictionary = {}   # 55 桌接图：座位圈的绝对量法（见 _seat_abs）；空的照旧用 seat_dy/rx/ry
var seat_dy := SEAT_DY           # 座位圈（场景配置 seat_geom 能改；55 桌灰盒的桌是一圈 140×92，圈心不往上挪）
var seat_rx := SEAT_RX
var seat_ry := SEAT_RY
var bench_x0 := BENCH_X0         # 长凳（场景配置 bench 能改；55 桌灰盒在第 1 排最西那个空位，色块画了凳子，代码不另画）
var bench_x1 := BENCH_X1
var bench_y := BENCH_Y
var bench_draw := true
const SIGN_BELOW := 55.0         # 55 桌桌牌挂在桌心往下多少（桌子占地下沿 46 再往下一点）
var game_unix := -1.0          # 测试用：分桌游戏按这个时间算北京日期；-1 用系统时间
var sign_near := false           # 认桌（01 D 9/29，55 桌）：只给自己那桌、走近的那桌挂牌，其余不挂
var table_signs: Dictionary = {} # table_id -> 桌牌（sign_near 时建好先藏着）
var main_seat_ok := false        # 55 桌：我是不是阿鱼、Toretto 本人（enterHall 的 mainSeatOk）；不是就走到主桌空椅子前也不冒「坐这儿」
var seat_marker: Polygon2D
var chairs: Array = []          # [{table_id, chair_no, pos}]
var seat_taken: Dictionary = {} # "T1:3" -> openid
var resident_nodes: Dictionary = {}  # openid -> {spr, preset, at, center}：坐着的住民，敬酒时要让他站起来（9/18 晚）
var cup_left := 0.0              # 自己举杯还剩几秒（敬酒、被敬酒时）
var my_cup: Sprite2D
var npc_taken: Dictionary = {}  # "T7:3" -> true：NPC 宾客坐着的椅子（hall_life.gd）。点不开；9/18 晚起照样出「坐这儿」，坐下时 NPC 让座
var table_names: Dictionary = {} # table_id -> 第一个坐下的人的昵称（桌牌）
var my_seat := {"table_id": "", "chair_no": 0}
var my_openid := ""              # set_seats 存的自己 openid：判断「是不是自己」，main 敬酒时也要用
var resident_names: Dictionary = {}  # set_seats 存的 data["names"]：openid -> {nick, avatar, inviter}，给 main 读昵称、形象、邀请人
var near_key := ""
var person_near_key := ""
var table_near_key := ""         # _scan_chairs 里翻簿子那部分最新一次发出的桌 id，""=没在任何桌边
var seat_scan := 0.0
var seated := false              # 坐在自己椅子上：停在椅位面朝桌心，一动就站起来
var seat_stand_spot := Vector2.ZERO   # 起身落脚的点：椅子外侧一步，保证不在桌子占地里
var sit_from := Vector2.ZERO     # 坐下那一下从哪滑过来
var sit_seat := Vector2.ZERO     # 滑到哪（椅位）
var sit_t := SIT_ANIM            # 滑了多久；等于 SIT_ANIM 表示没在滑
var seat_front := false          # 自己坐的椅子在桌子两边或前面：画在桌子前面（seat_in_front）
var seat_lift := 0.0             # 坐着时上半身往上抬多少画布像素：排前后用 pos（家具着地线 +1），画在椅面上（休息间座位，10/4）

## 椅子在画布上的位置：绕桌子占地一圈，1 号在正后方（靠里），顺时针
## 这张桌几把椅子：普通桌 10 把；55 桌厅的主桌大一号 13 把（scene.json 的 seats，阿鱼 9/29）
static func seats_of(t: Dictionary) -> int:
    return int(t.get("seats", 10))

## 55 桌接图 v1（9/30）：座位圈照零件图里椅子的位置量，写成「圈心离占地中心 dx、dy，半径 rx、ry」（abs）；
## 整厅一套（scene.json 的 seat_geom），哪张桌不一样（主桌那张图椅子圈大）桌上自己带 seat_geom
func _seat_abs(t: Dictionary) -> Dictionary:
    var own = t.get("seat_geom", null)
    if own is Dictionary and bool((own as Dictionary).get("abs", false)):
        return own
    return seat_abs

## 椅子圈从正北起每把等分；seat_geom 里写了 a0（度）就整圈转这么多（10/2 GPT 十椅桌：东西两头各一把，比正北起的圈转 18°）
func chair_world(t: Dictionary, no: int) -> Vector2:
    var sa := _seat_abs(t)
    var a := -PI / 2.0 + TAU * float(no - 1) / float(seats_of(t)) + deg_to_rad(float(sa.get("a0", 0.0)))
    var c := _seat_center(t)
    if not sa.is_empty():
        return Vector2(c.x + cos(a) * float(sa["rx"]), c.y + sin(a) * float(sa["ry"]))
    return Vector2(c.x + cos(a) * (float(t["rx"]) + seat_rx), c.y + sin(a) * (float(t["ry"]) + seat_ry))

## 椅位圈的圈心：桌子积木里画出来的那圈椅子，比桌子占地椭圆靠上（占地椭圆的中心在桌子着地的那一行）。
## 9/17 对着试点积木 blk_table_round.png 量的，原来按占地椭圆往外扩，坐下的人飘在椅子外面一大截
func _seat_center(t: Dictionary) -> Vector2:
    var sa := _seat_abs(t)
    if not sa.is_empty():
        return Vector2(float(t["x"]) + float(sa["dx"]), float(t["y"]) + float(sa["dy"]))
    return Vector2(float(t["x"]), float(t["y"]) + seat_dy * float(t["ry"]))

## 坐在这把椅子上的人画不画在桌子前面：桌子后面那几把（圈的上半截）照 y 排序躲在桌子后面；
## 两边和前面的画在桌子前面。桌子积木只有一条着地线，分不出人在桌子哪一侧，只能按椅子在圈上的位置定
func seat_in_front(t: Dictionary, seat: Vector2) -> bool:
    return seat.y >= _seat_center(t).y - 0.5 * float(t["ry"])

func set_seats(data: Dictionary, me_id: String) -> void:
    main_seat_ok = bool(data.get("mainSeatOk", false))
    if seats_holder != null:
        seats_holder.queue_free()
    if seat_tags != null:
        seat_tags.queue_free()
    table_signs.clear()
    seats_holder = Node2D.new()
    seats_holder.y_sort_enabled = true
    world.add_child(seats_holder)
    resident_nodes.clear()
    seat_tags = Node2D.new()
    seat_tags.z_index = 4
    add_child(seat_tags)
    chairs.clear()
    seat_taken.clear()
    table_names.clear()
    my_seat = data.get("me", my_seat)
    my_openid = me_id
    var names: Dictionary = data.get("names", {})
    resident_names = names
    var signed := {}
    var by_id := {}
    for t in cfg.get("tables", []):
        by_id[t["id"]] = t
    for tb in data.get("tables", []):
        if not by_id.has(tb["id"]):
            continue   # 试点只摆了两张桌，服务端多出来的桌先不画
        var t: Dictionary = by_id[tb["id"]]
        for no in range(1, seats_of(t) + 1):
            chairs.append({"table_id": tb["id"], "chair_no": no, "pos": chair_world(t, no)})
        var first_at := INF   # 桌牌：这桌最早坐下的人（sat_at 最小；旧数据没有 sat_at 就按列表里第一个）
        for s in tb.get("seats", []):
            var no := int(s["chair_no"])
            seat_taken["%s:%d" % [tb["id"], no]] = s["openid"]
            var info: Dictionary = names.get(s["openid"], {})
            var sat_at := float(s.get("sat_at", 0))
            if str(info.get("nick", "")) != "" and (not table_names.has(tb["id"]) or sat_at < first_at):
                table_names[tb["id"]] = str(info["nick"])
                first_at = sat_at
            if s["openid"] == me_id:
                continue   # 自己是走动的玩家，不画坐着的
            var at := chair_world(t, no)
            _seated(info, at, _seat_center(t), seat_in_front(t, at), str(s["openid"]))
        if table_names.has(tb["id"]):
            signed[tb["id"]] = true
            _table_sign(t, str(table_names[tb["id"]]))
    # 没有真人的桌也挂桌牌，只写游戏名（蓝图 3.2 9/19：桌牌带上游戏名，走到哪桌玩哪样）
    for t in cfg.get("tables", []):
        if not signed.has(t["id"]):
            _table_sign(t, "")
    if signs != null:
        var n: int = data.get("bench", []).size()
        for tb in data.get("tables", []):
            n += (tb.get("seats", []) as Array).size()
        signs.set_count(n)
    # 长凳（任务 5）：服务端的 bench 是 openid 列表，按顺序坐成一排；自己也占一个位置（金标画在那儿），不画坐着的。
    # 头上不挂名字：人挨得近，名字会叠成一片；走到跟前底下的名字按钮照样出
    bench_spots.clear()
    var bench_ids: Array = data.get("bench", [])
    for k in bench_ids.size():
        var oid := str(bench_ids[k])
        var at := bench_pos(k, bench_ids.size())
        bench_spots.append({"openid": oid, "pos": at})
        if oid == me_id:
            continue
        _seated(names.get(oid, {}), at, at + Vector2(0, 40), false, oid, false)
        resident_nodes[oid]["stand"] = at + Vector2(0, BENCH_STAND_DY)   # 被敬酒时站在凳子跟前，不往墙里退
    # 别桌的 NPC 宾客：真人坐了的椅子让出来（阿鱼 9/18 定留，见 hall_life.gd 开头）
    npc_taken = life.seat_guests(seat_taken) if life != null else {}
    _my_marker()
    # 椅子列表整个重建过（换桌、重进厅都会走到这）：旧的按钮状态可能对不上了，立刻重扫一次
    _scan_chairs(1.0)

## 桌牌「XX那桌·吃席」（蓝图 3.2：桌牌由引擎渲染，XX 是这桌第一个坐下的人；9/19 起带上这桌的小游戏名），立在桌心；
## 没有真人坐的桌只写游戏名
## 55 桌的桌号怎么念：主桌叫「主桌」，T12 叫「12 号桌」
static func table_label(tid: String) -> String:
    if tid == "MAIN":
        return "主桌"
    if tid.begins_with("T"):
        return "%s 号桌" % tid.substr(1)
    return tid

## 认桌（55 桌）：自己那桌一直挂牌，走近哪桌亮哪桌，其余不挂。
## 「坐这儿」出来时那把椅子的桌一定亮、「和外婆聊聊」这类主桌家里人的按钮出来时主桌一定亮（04 v8v9 新 1：
## 牌子按到桌边 60 算、「坐这儿」按到椅子 78 算，中间那一圈能坐下却看不见这桌今天玩什么）
func _sign_shown(tid: String) -> bool:
    if tid == str(my_seat.get("table_id", "")) or tid == table_near_key:
        return true
    if near_key != "" and tid == near_key.get_slice(":", 0):
        return true
    return tid == "MAIN" and life != null and str(life.get("family_lit")) != ""

func _refresh_near_signs() -> void:
    if not sign_near:
        return
    for tid in table_signs:
        var l: Label = table_signs[tid]
        if is_instance_valid(l):
            l.visible = _sign_shown(str(tid))

func _table_sign(t: Dictionary, nick: String) -> void:
    var l := Label.new()
    var game_title := GameCfg.title(GameCfg.game_for_table(str(t["id"])))
    var parts: Array[String] = []
    if sign_near:
        parts.append(table_label(str(t["id"])))   # 55 桌：只写桌号和游戏名（04 新 1：带「XX那桌」牌子 334 宽，压着玩家头上的名字）
    elif nick != "":
        parts.append(nick + "那桌")
    if game_title != "":
        parts.append(game_title)
    if parts.is_empty():
        return
    l.text = (" · " if sign_near else "·").join(parts)
    l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", WORLD_FONT)   # 原来 12，看不清（体验 B2）
    l.add_theme_color_override("font_color", Color("#F4D97A"))
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.05, 0.1, 0.8)
    sb.border_color = Color("#d4af37")
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(3)
    sb.content_margin_left = 4; sb.content_margin_right = 4
    sb.content_margin_top = 1; sb.content_margin_bottom = 1
    l.add_theme_stylebox_override("normal", sb)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.size = l.get_combined_minimum_size()   # 牌子只包住字，居中立在桌心
    l.position = _seat_center(t) - Vector2(l.size.x * 0.5, l.size.y + 8.0)   # 立在簿子上方，不挡簿子
    if sign_near:
        # 55 桌：挂在桌子下沿（桌心往下 55），不压桌面和桌上的东西（04 新 1：T11 的牌、主桌、1 号桌都被盖住过）
        l.position = Vector2(float(t["x"]), float(t["y"]) + SIGN_BELOW) - Vector2(l.size.x * 0.5, l.size.y * 0.5)
    l.name = "sign_" + str(t["id"])
    seat_tags.add_child(l)
    if sign_near:
        # 进树以后再量一次大小、摆一次（不在树里量出来偏窄，牌子往右歪；第 44 版的桌牌还是老样子，01 定下次一起修）
        l.size = l.get_combined_minimum_size()
        l.position = Vector2(float(t["x"]), float(t["y"]) + SIGN_BELOW) - Vector2(l.size.x * 0.5, l.size.y * 0.5)
        l.set_meta("tid", str(t["id"]))
        table_signs[str(t["id"])] = l
        l.visible = _sign_shown(str(t["id"]))

## 坐着的住民：和自己坐下一样画上半身（占位，SIT_KEEP、SIT_LIFT），不然别人像站在桌边、只有自己像坐着。
## center 是他面朝的地方（桌边的人朝桌心，长凳上的人朝厅里）；label 为 false 时头上不挂名字（长凳）
func _seated(info: Dictionary, at: Vector2, center: Vector2, front: bool, openid := "", label := true) -> void:
    var preset := int(info.get("avatar", -1))
    if preset < 0 or preset > 7:
        preset = 0
    var s := Sprite2D.new()
    var gl := Spr.gpt_look(preset)
    var lk: Dictionary
    var fh: float
    if gl.is_empty():
        s.texture = ImageTexture.create_from_image(Spr.sheet(preset))
        s.hframes = 9
        fh = 32.0
        lk = Spr.PROC_ANIM
    else:
        s.texture = gl["tex"]
        s.hframes = gl["hframes"]
        fh = float(gl["frame_h"])
        lk = gl["anim"]
    var fl: Dictionary = lk[_face_for(center - at)]
    var fw := float(s.texture.get_width()) / float(s.hframes)
    var keep := floorf(fh * SIT_KEEP)
    s.hframes = 1
    s.region_enabled = true
    s.region_rect = Rect2(float(fl["idle"]) * fw, 0.0, fw, keep)
    s.flip_h = fl["flip"]
    s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s.centered = true
    s.offset = Vector2(0, -keep * 0.5 - fh * SIT_LIFT)
    var sc := _px_h(at.y) / fh
    s.scale = Vector2(sc, sc)
    s.position = at
    s.z_index = 1 if front else 0
    seats_holder.add_child(s)
    if openid != "":
        resident_nodes[openid] = {"spr": s, "preset": preset, "at": at, "center": center}
    var nick := str(info.get("nick", ""))
    if label and nick != "" and font != null:
        var l := Label.new()
        l.text = nick
        name_plate(l)
        l.position = at - Vector2(l.size.x * 0.5, _px_h(at.y) * (SIT_KEEP + SIT_LIFT) + l.size.y + 2.0)
        seat_tags.add_child(l)

# ---------- 敬酒的样子（阿鱼 9/18 晚：被敬的人要站起来，两人碰杯）----------
const TOAST_SHOW := 2.8   # 站起来、举杯多久，秒（和 toast_scene.gd 的插图一样长）
const CUP_TEX := "res://assets/ambience/amb_cup.png"

## 我敬了坐着的某人：在我这边他从椅子上站起来（站到椅子外侧那一步），面朝我举杯，过一会儿坐回去
## 别人敬酒、回敬时站起来的地方（干杯飘落落在他头顶）；找不到这个人就回我自己站的地方
func resident_stand(openid: String) -> Vector2:
    var r: Dictionary = resident_nodes.get(openid, {})
    if r.is_empty():
        return pos
    return r["stand"] if r.has("stand") else _stand_spot(r["at"], r["center"])

func resident_toast(openid: String) -> bool:
    var r: Dictionary = resident_nodes.get(openid, {})
    if r.is_empty() or not is_instance_valid(r["spr"]):
        return false
    var seated_spr: Sprite2D = r["spr"]
    var preset: int = int(r["preset"])
    var stand: Vector2 = r["stand"] if r.has("stand") else _stand_spot(r["at"], r["center"])
    var st := Sprite2D.new()
    var gl := Spr.gpt_look(preset)
    var lk: Dictionary
    var fh: float
    if gl.is_empty():
        st.texture = ImageTexture.create_from_image(Spr.sheet(preset))
        st.hframes = 9
        fh = 32.0
        lk = Spr.PROC_ANIM
    else:
        st.texture = gl["tex"]
        st.hframes = gl["hframes"]
        fh = float(gl["frame_h"])
        lk = gl["anim"]
    var fl: Dictionary = lk[_face_for(pos - stand)]
    st.frame = int(fl["idle"])
    st.flip_h = bool(fl["flip"])
    st.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    st.centered = true
    st.offset = Vector2(0, -fh * 0.5)
    var k := _px_h(stand.y) / fh
    st.scale = Vector2(k, k)
    st.position = stand
    st.name = "toast_stand"
    world.add_child(st)
    seated_spr.visible = false
    var cup := _cup_sprite()
    cup.position = stand + Vector2(14.0 if pos.x >= stand.x else -14.0, -_px_h(stand.y) + 22.0)
    add_child(cup)
    get_tree().create_timer(TOAST_SHOW).timeout.connect(func():
        if is_instance_valid(st): st.queue_free()
        if is_instance_valid(cup): cup.queue_free()
        if is_instance_valid(seated_spr): seated_spr.visible = true)
    return true

## 自己举杯 secs 秒：酒杯在手边举到头旁边
func raise_cup(secs := TOAST_SHOW) -> void:
    if my_cup == null:
        my_cup = _cup_sprite()
        add_child(my_cup)
    cup_left = secs

## 有人敬我（在厅里当场收到）：坐着就站起来、举杯，插图完了没动过就坐回原位
func toasted_me() -> void:
    var was := seated
    var seat: Dictionary = my_seat.duplicate()
    if seated:
        stand_up()
    face = "down"
    raise_cup()
    if was:
        get_tree().create_timer(TOAST_SHOW).timeout.connect(func():
            if not seated and path.is_empty() and stick == Vector2.ZERO and my_seat == seat:
                sit_at(str(seat.get("table_id", "")), int(seat.get("chair_no", 0))))

func _cup_sprite() -> Sprite2D:
    var c := Sprite2D.new()
    if ResourceLoader.exists(CUP_TEX):
        c.texture = load(CUP_TEX)
    c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    c.z_index = 5
    c.visible = true
    return c

## 自己座位的小金标
func _my_marker() -> void:
    if seat_marker != null:
        seat_marker.queue_free()
        seat_marker = null
    var pos := _my_chair_pos()
    if pos == Vector2.ZERO:
        return
    seat_marker = Polygon2D.new()
    var pts := PackedVector2Array()
    for i in 16:
        var a := TAU * i / 16.0
        pts.append(Vector2(cos(a) * 14.0, sin(a) * 6.0))
    seat_marker.polygon = pts
    seat_marker.color = Color(1.0, 0.85, 0.4, 0.55)
    seat_marker.position = pos
    # 要画在底图和桌子上面才看得见：原来是 -5，沉到底图下面，电脑上也看不到（第 19 版修）
    seat_marker.z_index = 4
    add_child(seat_marker)

func _my_chair_pos() -> Vector2:
    if str(my_seat.get("table_id", "")) == BENCH_ID:
        for b in bench_spots:
            if b["openid"] == my_openid:
                return b["pos"]
        return Vector2.ZERO
    var my_no := chair_no_of(my_seat)
    for c in chairs:
        if c["table_id"] == my_seat.get("table_id", "") and c["chair_no"] == my_no:
            return c["pos"]
    return Vector2.ZERO

## 椅子号。坐长凳的没有号，服务端给 null——int(null) 在 Godot 里是报错，原来分到长凳的人一进厅就在这儿断掉，只剩「先找把空椅子坐下」
static func chair_no_of(seat: Dictionary) -> int:
    var v = seat.get("chair_no", 0)
    return 0 if v == null else int(v)

## 换桌成功后本地更新，不用重新拉 enterHall。顺便把人挪到那把椅子上坐下——
## 第 20 版只有金标挪了位置、人还站在原地，阿鱼没看出来成功，连点了四次
func apply_change(table_id: String, chair_no: int, me_id: String) -> void:
    var old := "%s:%d" % [my_seat.get("table_id", ""), chair_no_of(my_seat)]
    if seat_taken.get(old, "") == me_id:
        seat_taken.erase(old)
    # 从长凳换到椅子（任务 5）：凳子上自己那个位置空着，不再算自己的
    for i in range(bench_spots.size() - 1, -1, -1):
        if bench_spots[i]["openid"] == me_id:
            bench_spots.remove_at(i)
    my_seat = {"table_id": table_id, "chair_no": chair_no}
    var key := "%s:%d" % [table_id, chair_no]
    seat_taken[key] = me_id
    # 这把原来坐着 NPC：它站起来走掉，把椅子让给我（阿鱼 9/18 晚）
    if life != null and npc_taken.has(key):
        life.vacate(key)
        npc_taken = life.npc_taken
    if life != null and life.relatives != null:
        life.relatives.vacate(key)   # 55 桌：这把是亲友开席要坐的，亲友换一把
    if life != null and life.reserved_cards.has(key):
        var card: Label = life.reserved_cards[key]
        if is_instance_valid(card):
            card.queue_free()        # 阿鱼、Toretto 本人坐上去了：那张座签收掉
        life.reserved_cards.erase(key)
    _my_marker()
    sit_at(table_id, chair_no)

func _table_cfg(table_id: String) -> Dictionary:
    for t in cfg.get("tables", []):
        if str(t["id"]) == table_id:
            return t
    return {}

## 翻簿子的「离桌子占地椭圆一圈 60 像素内」：沿桌心到人的方向量出椭圆边界那一点，
## 两点距离相减，正数是在外面、负数是在里面。跟 chair_world 一样用 rx、ry 撑扁的圆算角度
func _table_edge_dist(t: Dictionary, p: Vector2) -> float:
    var c := Vector2(float(t["x"]), float(t["y"]))
    var d := p - c
    var rx: float = float(t["rx"])
    var ry: float = float(t["ry"])
    if d.length() < 0.001:
        return -minf(rx, ry)   # 正好站在桌心（理论上不会发生），当作在里面
    var ang := atan2(d.y / ry, d.x / rx)
    var edge := Vector2(cos(ang) * rx, sin(ang) * ry)
    return d.length() - edge.length()

## 坐下：人滑到椅子上（SIT_ANIM 秒），面朝桌心，停着不动，只画上半身（_process 里，占位）。
## 还没有坐姿帧（等新画风人物）；椅子和桌子画在同一块积木里挪不动，「拖椅子坐下」在待讨论里
func sit_at(table_id: String, chair_no: int) -> void:
    var t := _table_cfg(table_id)
    if t.is_empty():
        return   # 服务端把人分到了还没摆出来的桌，坐不了，main.gd 那边会提示先找把椅子
    var seat := chair_world(t, chair_no)
    var center := _seat_center(t)
    seat_front = seat_in_front(t, seat)
    path.clear()
    stick = Vector2.ZERO
    sit_from = pos
    sit_seat = seat
    sit_t = 0.0
    face = _face_for(center - seat)
    seated = true
    seat_stand_spot = _stand_spot(seat, center)
    # 坐下就把「坐这儿」收起来；站起来走近别的空椅子时，扫描会照旧弹出来
    seat_scan = 0.0
    if near_key != "":
        near_key = ""
        chair_near.emit("", 0)

## 起身落脚的点：从桌心往外，沿椅子那个方向退开一步，退到能站的地方为止
func _stand_spot(seat: Vector2, center: Vector2) -> Vector2:
    var dir := seat - center
    dir = dir.normalized() if dir.length() > 0.001 else Vector2(0.0, 1.0)
    var step := px_per_m(seat.y)
    # 桌子后面（北边）那几把：往外退就退到桌子北边的缝里，人站在那儿被桌子挡掉下半截，像个小孩（04 10/2 第 4 条）。
    # 改成站到离得近的那个桌头外边、跟桌心齐平：从椅子横着往桌头走，走出桌子占地第一个能站的地方
    if dir.y < -0.35:
        var sx := signf(dir.x) if absf(dir.x) > 0.01 else 1.0
        for k in 12:
            var q := Vector2(center.x + sx * (absf(seat.x - center.x) + step * (0.6 + 0.3 * k)), center.y + step * 0.15)
            if _free(q):
                return q
    for k in 10:
        var p := seat + dir * step * (0.6 + 0.3 * k)
        if _free(p):
            return p
    return _cell_pos(_nearest_free(_cell_of(seat)))

## 站起来：从椅子外侧那一步起身，不会卡在桌子占地里
func stand_up() -> void:
    if not seated:
        return
    seated = false
    sit_t = SIT_ANIM   # 正在往椅子上滑也立刻停
    seat_lift = 0.0
    if seat_stand_spot != Vector2.ZERO and _free(seat_stand_spot):
        pos = seat_stand_spot

## 每 0.15 秒扫一次：人旁边有没有空椅子（不含自己那把）；同时扫旁边坐着的人（看人、敬酒，蓝图 3.2）
func _scan_chairs(dt: float) -> void:
    if chairs.is_empty():
        return
    seat_scan += dt
    if seat_scan < 0.15:
        return
    seat_scan = 0.0
    # 坐着的时候不提「坐这儿」：刚坐下又冒出一个按钮，看着像没坐成。
    # 要「走近别的空椅子」总得先动，一动就起身了，那时照旧弹
    if seated:
        if near_key != "":
            near_key = ""
            chair_near.emit("", 0)
    else:
        var best_key := ""
        var best_tid := ""
        var best_no := 0
        var best_d := NEAR_R
        for c in chairs:
            var key: String = "%s:%d" % [c["table_id"], c["chair_no"]]
            if seat_taken.has(key):
                continue   # NPC 坐着的也算空椅子：坐下时 NPC 让座
            if life != null and life.family_keys.has(key):
                continue   # 55 桌主桌上阿鱼家里人的椅子：不让座，也不冒「坐这儿」
            if not main_seat_ok and str(c["table_id"]) == "MAIN":
                continue   # 主桌 1、2 号空椅子是阿鱼、Toretto 本人的，别人走到跟前不冒「坐这儿」（01 D 9/29）
            var d: float = pos.distance_to(c["pos"])
            if d < best_d:
                best_d = d
                best_key = key
                best_tid = c["table_id"]
                best_no = c["chair_no"]
        if best_key != near_key:
            near_key = best_key
            chair_near.emit(best_tid, best_no)
    # 看人：最近的「有人坐、不是自己」的椅子，NEAR_R 以内，和「坐这儿」一个距离。
    # 坐在自己椅子上时邻座照样能敬酒（第 22 版规则 6），所以这一段不受 seated 影响
    var best_pid := ""
    var best_pd := NEAR_R
    for c in chairs:
        var key: String = "%s:%d" % [c["table_id"], c["chair_no"]]
        var occ: String = str(seat_taken.get(key, ""))
        if occ == "" or occ == my_openid:
            continue
        var d: float = pos.distance_to(c["pos"])
        if d < best_pd:
            best_pd = d
            best_pid = occ
    # 长凳上的人一样能看、能敬（任务 5）。凳子在能走的格子外面，走进凳子前面那条道（BENCH_WALK）就是最近的
    for b in bench_spots:
        var occ: String = b["openid"]
        if occ == my_openid:
            continue
        var d: float = pos.distance_to(b["pos"])
        if d < best_pd:
            best_pd = d
            best_pid = occ
    if best_pid != person_near_key:
        person_near_key = best_pid
        person_near.emit(best_pid)
    # 翻簿子：走到桌边（占地椭圆边缘 60 像素内）冒「翻簿子」；坐在自己椅子上时也算自己那桌（蓝图 3.2，
    # 第 24 版规则 1），不受 seated 影响——跟看人一样，坐着也能翻自己桌上的簿子
    var best_table := ""
    if seated:
        var my_t := _table_cfg(str(my_seat.get("table_id", "")))
        if not my_t.is_empty():
            best_table = str(my_t["id"])
    if best_table == "":
        var best_td := 60.0
        for t in cfg.get("tables", []):
            var td: float = _table_edge_dist(t, pos)
            if td < best_td:
                best_td = td
                best_table = str(t["id"])
    if best_table != table_near_key:
        table_near_key = best_table
        table_near.emit(best_table)
        _refresh_near_signs()
